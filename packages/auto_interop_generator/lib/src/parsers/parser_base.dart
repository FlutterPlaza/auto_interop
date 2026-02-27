import '../schema/unified_type_schema.dart';

/// Thrown when parsing fails or produces a suspicious result.
///
/// Includes actionable guidance: suggests using pre-built type definitions
/// or providing a manual UTS override via `--override`.
class ParseWarning {
  final String message;
  final String? suggestion;
  const ParseWarning(this.message, {this.suggestion});

  @override
  String toString() =>
      suggestion != null ? '$message\n  Suggestion: $suggestion' : message;
}

/// Result of parsing a native package source.
class ParseResult {
  final UnifiedTypeSchema schema;
  final List<ParseWarning> warnings;

  const ParseResult(this.schema, {this.warnings = const []});

  /// Whether the parse result is empty (no API surface found).
  bool get isEmpty =>
      schema.classes.isEmpty &&
      schema.functions.isEmpty &&
      schema.types.isEmpty &&
      schema.enums.isEmpty;
}

/// Base class for native package API parsers.
///
/// Each parser reads source files from a specific platform (npm, cocoapods,
/// gradle) and produces a [UnifiedTypeSchema] as output.
abstract class ParserBase {
  /// Parses the given source content and returns a [UnifiedTypeSchema].
  ///
  /// [content] is the raw text content of the source file(s).
  /// [packageName] is the name of the native package.
  /// [version] is the package version.
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  });

  /// Parses with validation, returning warnings for empty or suspicious results.
  ParseResult parseWithValidation({
    required String content,
    required String packageName,
    required String version,
  }) {
    final schema = parse(
      content: content,
      packageName: packageName,
      version: version,
    );
    return validateResult(schema);
  }

  /// Validates a parsed schema and returns warnings for common issues.
  ParseResult validateResult(UnifiedTypeSchema schema) {
    final warnings = <ParseWarning>[];

    final totalApis = schema.classes.length +
        schema.functions.length +
        schema.types.length +
        schema.enums.length;

    if (totalApis == 0) {
      warnings.add(ParseWarning(
        'Parsing produced an empty API surface for "${schema.package}".',
        suggestion: 'Check if a pre-built type definition exists: '
            'dart run auto_interop_generator:generate list\n'
            '  Or provide a manual UTS override: '
            '--override ${schema.package}.uts.json',
      ));
    } else if (totalApis <= 2 && schema.classes.isEmpty) {
      warnings.add(ParseWarning(
        'Parsing found very few API entries ($totalApis) for "${schema.package}". '
        'The source may not have been parsed completely.',
        suggestion: 'Consider using a pre-built type definition or providing '
            'a manual UTS override for better coverage.',
      ));
    }

    // Check for classes with no methods (might indicate parse failure)
    for (final cls in schema.classes) {
      if (cls.methods.isEmpty && cls.fields.isEmpty) {
        warnings.add(ParseWarning(
          'Class "${cls.name}" has no methods or fields. '
          'This may indicate a parsing issue.',
        ));
      }
    }

    return ParseResult(schema, warnings: warnings);
  }

  /// Parses multiple source files and merges the results.
  ///
  /// [files] maps file paths to their content.
  UnifiedTypeSchema parseFiles({
    required Map<String, String> files,
    required String packageName,
    required String version,
  }) {
    final schemas = <UnifiedTypeSchema>[];
    for (final entry in files.entries) {
      schemas.add(parse(
        content: entry.value,
        packageName: packageName,
        version: version,
      ));
    }
    return mergeSchemas(schemas, packageName: packageName, version: version);
  }

  /// Parses multiple files with validation.
  ParseResult parseFilesWithValidation({
    required Map<String, String> files,
    required String packageName,
    required String version,
  }) {
    final schema = parseFiles(
      files: files,
      packageName: packageName,
      version: version,
    );
    return validateResult(schema);
  }

  /// Merges multiple schemas into one.
  UnifiedTypeSchema mergeSchemas(
    List<UnifiedTypeSchema> schemas, {
    required String packageName,
    required String version,
  }) {
    if (schemas.isEmpty) {
      return UnifiedTypeSchema(
        package: packageName,
        source: source,
        version: version,
      );
    }
    if (schemas.length == 1) return schemas.first;

    final classes = <UtsClass>[];
    final functions = <UtsMethod>[];
    final types = <UtsClass>[];
    final enums = <UtsEnum>[];
    final seenNames = <String>{};

    for (final schema in schemas) {
      for (final cls in schema.classes) {
        if (seenNames.add(cls.name)) classes.add(cls);
      }
      for (final fn in schema.functions) {
        if (seenNames.add(fn.name)) functions.add(fn);
      }
      for (final type in schema.types) {
        if (seenNames.add(type.name)) types.add(type);
      }
      for (final e in schema.enums) {
        if (seenNames.add(e.name)) enums.add(e);
      }
    }

    return UnifiedTypeSchema(
      package: packageName,
      source: source,
      version: version,
      classes: classes,
      functions: functions,
      types: types,
      enums: enums,
    );
  }

  /// The source type this parser handles.
  PackageSource get source;
}
