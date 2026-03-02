import 'dart:convert';

import '../cache/checksum.dart';
import '../cache/parse_cache.dart';
import '../config/package_spec.dart';
import '../parsers/ast/ast_gradle_parser.dart';
import '../parsers/ast/ast_npm_parser.dart';
import '../parsers/ast/ast_parser_base.dart';
import '../parsers/ast/ast_swift_parser.dart';
import '../parsers/gradle_parser.dart';
import '../parsers/npm_parser.dart';
import '../parsers/parser_base.dart';
import '../parsers/swift_parser.dart';
import '../schema/unified_type_schema.dart';
import 'native_source_locator.dart';
import 'override_loader.dart';
import 'registry_client.dart';

/// Describes how a schema was resolved.
enum SchemaSource {
  override,
  projectOverride,
  globalOverride,
  registry,
  cache,
  parsed,
}

/// Result of resolving a schema for a package.
class SchemaResolution {
  /// The resolved schema, or `null` if resolution failed.
  final UnifiedTypeSchema? schema;

  /// How the schema was obtained.
  final SchemaSource? source;

  /// Warning message if resolution failed or had issues.
  final String? warning;

  /// Parse warnings from the parser, if any.
  final List<ParseWarning> parseWarnings;

  const SchemaResolution({
    this.schema,
    this.source,
    this.warning,
    this.parseWarnings = const [],
  });
}

/// Orchestrates schema resolution with a six-step priority:
///
/// 1. CLI `--override` flag (JSON string)
/// 2. Project overrides (`auto_interop_overrides/`)
/// 3. Global overrides (`~/.auto_interop/overrides/`)
/// 4. Registry cache (local cache, fresh < TTL)
/// 5. Registry fetch (download from GitHub, verify SHA-256, cache)
/// 6. Source file parsing (existing regex fallback)
class SchemaResolver {
  final NativeSourceLocator _locator;
  final ParseCache _parseCache;
  final OverrideLoader? _overrideLoader;
  final RegistryClient? _registryClient;
  final bool _useRegistry;
  final bool _useAst;

  SchemaResolver({
    NativeSourceLocator? locator,
    ParseCache? parseCache,
    OverrideLoader? overrideLoader,
    RegistryClient? registryClient,
    bool useRegistry = true,
    bool useAst = true,
  })  : _locator = locator ?? NativeSourceLocator(),
        _parseCache = parseCache ?? ParseCache(),
        _overrideLoader = overrideLoader,
        _registryClient = registryClient,
        _useRegistry = useRegistry,
        _useAst = useAst;

  /// Resolves a schema for the given [spec].
  ///
  /// Resolution order:
  /// 1. If [overrideSchema] is provided (JSON string from CLI `--override`), use it.
  /// 2. Check project-level overrides directory.
  /// 3. Check global overrides directory.
  /// 4-5. Check cloud registry (cache then fetch).
  /// 6. Locate source files, compute checksum, check parse cache / parse.
  Future<SchemaResolution> resolve(PackageSpec spec,
      {String? overrideSchema}) async {
    // Step 1: CLI --override flag
    if (overrideSchema != null) {
      try {
        final json = jsonDecode(overrideSchema) as Map<String, dynamic>;
        final schema = UnifiedTypeSchema.fromJson(json);
        return SchemaResolution(
          schema: schema,
          source: SchemaSource.override,
        );
      } catch (e) {
        return SchemaResolution(
          warning: 'Failed to parse override schema: $e',
        );
      }
    }

    // Steps 2-3: Override loader (project then global)
    final overrideLoader = _overrideLoader;
    if (overrideLoader != null) {
      final overrideResult = overrideLoader.load(
        spec.package,
        source: spec.source.name,
        version: spec.version,
      );
      if (overrideResult != null) {
        return SchemaResolution(
          schema: overrideResult.schema,
          source: overrideResult.isProjectLevel
              ? SchemaSource.projectOverride
              : SchemaSource.globalOverride,
        );
      }
    }

    // Steps 4-5: Registry (cache then fetch)
    final registryClient = _registryClient;
    if (_useRegistry && registryClient != null) {
      final registryKey = _registryKey(spec);
      final registryResult =
          await registryClient.fetch(registryKey, spec.version);
      if (registryResult.schema != null) {
        return SchemaResolution(
          schema: registryResult.schema,
          source: SchemaSource.registry,
          warning: registryResult.warning,
        );
      }
      // Registry miss/failure is not fatal — fall through to parsing
    }

    // Step 6: Locate + parse from source
    return _resolveFromSource(spec);
  }

  /// Builds a registry key like `npm/date-fns` or `cocoapods/Alamofire`.
  static String _registryKey(PackageSpec spec) {
    return '${spec.source.name}/${spec.package}';
  }

  /// Locates source, checks parse cache, parses (tries AST first, then regex).
  Future<SchemaResolution> _resolveFromSource(PackageSpec spec) async {
    final locationResult = _locator.locate(spec);
    if (!locationResult.found) {
      return SchemaResolution(
        warning: locationResult.warning ??
            'No source files found for "${spec.package}".',
      );
    }

    // Check parse cache
    final sourceChecksum = Checksum.ofAll(locationResult.files.values);
    final cached = _parseCache.get(spec.package, sourceChecksum);
    if (cached != null) {
      return SchemaResolution(
        schema: cached,
        source: SchemaSource.cache,
      );
    }

    // Try AST parser first if enabled
    ParseResult result;
    if (_useAst) {
      final astParser = _astParserForSource(spec.source);
      if (astParser != null) {
        result = await astParser.parseFilesAsync(
          files: locationResult.files,
          packageName: spec.package,
          version: spec.version,
        );
      } else {
        final parser = _parserForSource(spec.source);
        result = parser.parseFilesWithValidation(
          files: locationResult.files,
          packageName: spec.package,
          version: spec.version,
        );
      }
    } else {
      final parser = _parserForSource(spec.source);
      result = parser.parseFilesWithValidation(
        files: locationResult.files,
        packageName: spec.package,
        version: spec.version,
      );
    }

    // Resolve unknown types to nativeObject
    final resolved = resolveUnknownTypes(result);

    // Cache the result
    _parseCache.put(spec.package, sourceChecksum, resolved.schema);

    return SchemaResolution(
      schema: resolved.schema,
      source: SchemaSource.parsed,
      parseWarnings: resolved.warnings,
    );
  }

  /// Returns the appropriate parser for the given source type.
  static ParserBase _parserForSource(PackageSource source) {
    switch (source) {
      case PackageSource.cocoapods:
      case PackageSource.spm:
        return SwiftParser();
      case PackageSource.gradle:
        return GradleParser();
      case PackageSource.npm:
        return NpmParser();
    }
  }

  /// Returns the appropriate AST-based parser for the given source type.
  static AstParserBase? _astParserForSource(PackageSource source) {
    switch (source) {
      case PackageSource.cocoapods:
      case PackageSource.spm:
        return AstSwiftParser();
      case PackageSource.gradle:
        return AstGradleParser();
      case PackageSource.npm:
        return AstNpmParser();
    }
  }

  /// Resolves unresolved type references to `nativeObject`.
  ///
  /// Any `UtsType(kind: object)` whose name/ref is NOT defined in the schema
  /// gets converted to `UtsType.nativeObject()` with a warning.
  static ParseResult resolveUnknownTypes(ParseResult result) {
    final schema = result.schema;
    final definedNames = schema.definedTypeNames;
    final warnings = List<ParseWarning>.from(result.warnings);

    // Walk all type references and replace unknown object types with dynamic
    final resolvedClasses = schema.classes
        .map((cls) => _resolveClassTypes(cls, definedNames, warnings))
        .toList();
    final resolvedTypes = schema.types
        .map((cls) => _resolveClassTypes(cls, definedNames, warnings))
        .toList();
    final resolvedFunctions = schema.functions
        .map((m) => _resolveMethodTypes(m, definedNames, warnings))
        .toList();

    final resolvedSchema = UnifiedTypeSchema(
      package: schema.package,
      source: schema.source,
      version: schema.version,
      classes: resolvedClasses,
      functions: resolvedFunctions,
      types: resolvedTypes,
      enums: schema.enums,
      nativeImports: schema.nativeImports,
      nativeFields: schema.nativeFields,
    );

    return ParseResult(resolvedSchema, warnings: warnings);
  }

  static UtsClass _resolveClassTypes(
      UtsClass cls, Set<String> definedNames, List<ParseWarning> warnings) {
    return UtsClass(
      name: cls.name,
      kind: cls.kind,
      fields: cls.fields
          .map((f) => UtsField(
                name: f.name,
                type: _resolveType(f.type, definedNames, warnings),
                nullable: f.nullable,
                isReadOnly: f.isReadOnly,
                defaultValue: f.defaultValue,
                documentation: f.documentation,
              ))
          .toList(),
      methods: cls.methods
          .map((m) => _resolveMethodTypes(m, definedNames, warnings))
          .toList(),
      superclass: cls.superclass,
      interfaces: cls.interfaces,
      sealedSubclasses: cls.sealedSubclasses,
      documentation: cls.documentation,
      constructorParameters: cls.constructorParameters,
    );
  }

  static UtsMethod _resolveMethodTypes(
      UtsMethod method, Set<String> definedNames, List<ParseWarning> warnings) {
    return UtsMethod(
      name: method.name,
      isStatic: method.isStatic,
      isAsync: method.isAsync,
      parameters: method.parameters
          .map((p) => UtsParameter(
                name: p.name,
                type: _resolveType(p.type, definedNames, warnings),
                isOptional: p.isOptional,
                isNamed: p.isNamed,
                defaultValue: p.defaultValue,
                documentation: p.documentation,
                nativeLabel: p.nativeLabel,
                nativeType: p.nativeType,
              ))
          .toList(),
      returnType: _resolveType(method.returnType, definedNames, warnings),
      documentation: method.documentation,
      nativeBody: method.nativeBody,
    );
  }

  static UtsType _resolveType(
      UtsType type, Set<String> definedNames, List<ParseWarning> warnings) {
    // Check if this is an unresolved object type
    if (type.kind == UtsTypeKind.object &&
        type.ref != null &&
        !definedNames.contains(type.ref)) {
      // Only promote to nativeObject if the ref is a valid Dart identifier.
      // Raw closure signatures, protocol existentials, union types etc.
      // (e.g. "() -> Void", "any Error", "A | B") fall back to dynamic.
      if (_isValidDartIdentifier(type.ref!)) {
        warnings.add(ParseWarning(
          'Unknown type "${type.ref}" resolved to nativeObject',
        ));
        return UtsType.nativeObject(type.ref!, nullable: type.nullable);
      } else {
        warnings.add(ParseWarning(
          'Unknown type "${type.ref}" resolved to dynamic (not a valid identifier)',
        ));
        return UtsType.dynamicType(nullable: type.nullable);
      }
    }

    // Recurse into type arguments
    final resolvedTypeArgs = type.typeArguments
        ?.map((t) => _resolveType(t, definedNames, warnings))
        .toList();
    final resolvedParamTypes = type.parameterTypes
        ?.map((t) => _resolveType(t, definedNames, warnings))
        .toList();
    final resolvedReturnType = type.returnType != null
        ? _resolveType(type.returnType!, definedNames, warnings)
        : null;

    final effectiveTypeArgs = resolvedTypeArgs ?? type.typeArguments;

    // Auto-convert non-primitive Map keys to dynamic
    if (type.kind == UtsTypeKind.map &&
        effectiveTypeArgs != null &&
        effectiveTypeArgs.length >= 2) {
      final keyType = effectiveTypeArgs.first;
      if (keyType.kind != UtsTypeKind.primitive &&
          keyType.kind != UtsTypeKind.enumType &&
          keyType.kind != UtsTypeKind.dynamic) {
        warnings.add(ParseWarning(
          'Map key type "${keyType.toDartType()}" converted to dynamic',
        ));
        return UtsType.map(
          UtsType.dynamicType(),
          effectiveTypeArgs[1],
          nullable: type.nullable,
        );
      }
    }

    // Return original if nothing changed
    if (resolvedTypeArgs == null &&
        resolvedParamTypes == null &&
        resolvedReturnType == null) {
      return type;
    }

    return UtsType(
      kind: type.kind,
      name: type.name,
      nullable: type.nullable,
      ref: type.ref,
      typeArguments: resolvedTypeArgs ?? type.typeArguments,
      parameterTypes: resolvedParamTypes ?? type.parameterTypes,
      returnType: resolvedReturnType ?? type.returnType,
    );
  }

  /// Filters a schema to include only the items listed in [imports].
  ///
  /// If [imports] is empty, returns the full schema unchanged.
  /// Transitively includes types referenced by imported items.
  static UnifiedTypeSchema filterByImports(
      UnifiedTypeSchema schema, List<String> imports) {
    if (imports.isEmpty) return schema;

    final wanted = <String>{...imports};

    // Transitively collect referenced type names
    void walkType(UtsType type) {
      if (type.ref != null) wanted.add(type.ref!);
      type.typeArguments?.forEach(walkType);
      type.parameterTypes?.forEach(walkType);
      if (type.returnType != null) walkType(type.returnType!);
    }

    // Keep expanding until stable
    var previousSize = 0;
    while (wanted.length != previousSize) {
      previousSize = wanted.length;
      for (final cls in [...schema.classes, ...schema.types]) {
        if (!wanted.contains(cls.name)) continue;
        if (cls.superclass != null) wanted.add(cls.superclass!);
        wanted.addAll(cls.interfaces);
        wanted.addAll(cls.sealedSubclasses);
        for (final field in cls.fields) {
          walkType(field.type);
        }
        for (final method in cls.methods) {
          walkType(method.returnType);
          for (final param in method.parameters) {
            walkType(param.type);
          }
        }
        if (cls.constructorParameters != null) {
          for (final param in cls.constructorParameters!) {
            walkType(param.type);
          }
        }
      }
      for (final func in schema.functions) {
        if (!wanted.contains(func.name)) continue;
        walkType(func.returnType);
        for (final param in func.parameters) {
          walkType(param.type);
        }
      }
    }

    return UnifiedTypeSchema(
      package: schema.package,
      source: schema.source,
      version: schema.version,
      classes: schema.classes.where((c) => wanted.contains(c.name)).toList(),
      functions:
          schema.functions.where((f) => wanted.contains(f.name)).toList(),
      types: schema.types.where((t) => wanted.contains(t.name)).toList(),
      enums: schema.enums.where((e) => wanted.contains(e.name)).toList(),
      nativeImports: schema.nativeImports,
      nativeFields: schema.nativeFields,
    );
  }

  /// Returns true if [name] is a valid Dart class identifier (e.g. `URLRequest`).
  /// Returns false for raw foreign syntax like closures, protocol existentials,
  /// union types, dot-notation nested types, or partial fragments.
  static bool _isValidDartIdentifier(String name) {
    return RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(name);
  }
}
