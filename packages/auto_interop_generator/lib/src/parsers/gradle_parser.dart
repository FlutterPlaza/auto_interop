import '../schema/unified_type_schema.dart';
import '../type_mapping/java_to_dart.dart';
import '../type_mapping/kotlin_to_dart.dart';
import 'parser_base.dart';

/// Parses Kotlin (.kt) and Java (.java) source files into a
/// [UnifiedTypeSchema].
///
/// Handles:
/// - Kotlin: classes, data classes, sealed classes, enum classes, interfaces,
///   suspend functions, Flow, companion objects, nullable types
/// - Java: classes, interfaces, enums, static methods, annotations
class GradleParser extends ParserBase {
  final KotlinToDartMapper _kotlinMapper = KotlinToDartMapper();
  final JavaToDartMapper _javaMapper = JavaToDartMapper();

  @override
  PackageSource get source => PackageSource.gradle;

  @override
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  }) {
    // Auto-detect language from content
    if (_isKotlin(content)) {
      return _parseKotlin(content, packageName, version);
    }
    return _parseJava(content, packageName, version);
  }

  /// Parses multiple files, auto-detecting language per file.
  @override
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

  bool _isKotlin(String content) {
    // Kotlin-specific patterns
    if (content.contains('fun ')) return true;
    if (content.contains('val ')) return true;
    if (content.contains('var ')) return true;
    if (content.contains('data class ')) return true;
    if (content.contains('sealed class ')) return true;
    if (content.contains('enum class ')) return true;
    if (content.contains('suspend ')) return true;
    if (content.contains('companion object')) return true;
    if (content.contains(': Unit')) return true;
    return false;
  }

  // ========== Kotlin Parsing ==========

  UnifiedTypeSchema _parseKotlin(
      String content, String packageName, String version) {
    final lines = content.split('\n');
    final classes = <UtsClass>[];
    final functions = <UtsMethod>[];
    final types = <UtsClass>[];
    final enums = <UtsEnum>[];
    final seenFunctionNames = <String>{};
    final extensions = <String, List<UtsMethod>>{};

    var i = 0;
    while (i < lines.length) {
      final rawLine = lines[i].trim();

      // Skip empty lines, imports, package
      if (rawLine.isEmpty ||
          rawLine.startsWith('import ') ||
          rawLine.startsWith('package ')) {
        i++;
        continue;
      }

      // Collect documentation
      final docResult = _collectKDoc(lines, i);
      if (docResult.endIndex > i) {
        i = docResult.endIndex;
        continue;
      }

      final doc = _lookbackForKDoc(lines, i);

      // Strip annotations before matcher checks
      final line = _stripAnnotations(rawLine);

      // Skip private/internal/protected declarations
      if (line.startsWith('private ') ||
          line.startsWith('internal ') ||
          line.startsWith('protected ')) {
        i = _skipBlock(lines, i);
        continue;
      }

      // Skip typealias declarations
      if (line.startsWith('typealias ')) {
        i++;
        continue;
      }

      // Sealed class
      if (_matchesSealedClass(line)) {
        final result = _parseKotlinSealedClass(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          for (final sub in result.subclasses) {
            types.add(sub);
          }
          i = result.endIndex;
          continue;
        }
      }

      // Data class
      if (_matchesDataClass(line)) {
        final result = _parseKotlinDataClass(lines, i, doc);
        if (result != null) {
          types.add(result.cls);
          i = result.endIndex;
          continue;
        }
      }

      // Enum class
      if (_matchesEnumClass(line)) {
        final result = _parseKotlinEnum(lines, i, doc);
        if (result != null) {
          enums.add(result.enumDef);
          i = result.endIndex;
          continue;
        }
      }

      // Interface
      if (_matchesInterface(line)) {
        final result = _parseKotlinInterface(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          i = result.endIndex;
          continue;
        }
      }

      // Object declaration (singleton)
      if (_matchesObject(line)) {
        final result = _parseKotlinObject(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          i = result.endIndex;
          continue;
        }
      }

      // Class (regular/open/abstract)
      if (_matchesClass(line)) {
        final result = _parseKotlinClass(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          i = result.endIndex;
          continue;
        }
      }

      // Extension function
      if (_matchesExtensionFunction(line)) {
        final sig = _collectKotlinSignature(lines, i);
        final receiver = _getExtensionReceiver(sig.text);
        final method = _parseKotlinExtensionFunction(sig.text, doc);
        if (method != null && receiver != null && !_isPrivate(method.name)) {
          extensions.putIfAbsent(receiver, () => []).add(method);
        }
        i = sig.endIndex + 1;
        continue;
      }

      // Top-level function
      if (_matchesFunction(line)) {
        final sig = _collectKotlinSignature(lines, i);
        final method = _parseKotlinFunction(sig.text, doc);
        if (method != null &&
            !_isPrivate(method.name) &&
            seenFunctionNames.add(method.name)) {
          functions.add(method);
        }
        i = sig.endIndex + 1;
        continue;
      }

      i++;
    }

    // Fold extension methods into their base classes
    for (final entry in extensions.entries) {
      final targetName = entry.key;
      final extMethods = entry.value;

      var found = false;
      for (var ci = 0; ci < classes.length; ci++) {
        if (classes[ci].name == targetName) {
          classes[ci] = UtsClass(
            name: classes[ci].name,
            kind: classes[ci].kind,
            fields: classes[ci].fields,
            methods: [...classes[ci].methods, ...extMethods],
            superclass: classes[ci].superclass,
            interfaces: classes[ci].interfaces,
            sealedSubclasses: classes[ci].sealedSubclasses,
            documentation: classes[ci].documentation,
          );
          found = true;
          break;
        }
      }
      if (!found) {
        classes.add(UtsClass(
          name: targetName,
          kind: UtsClassKind.concreteClass,
          methods: extMethods,
        ));
      }
    }

    return UnifiedTypeSchema(
      package: packageName,
      source: PackageSource.gradle,
      version: version,
      classes: classes,
      functions: functions,
      types: types,
      enums: enums,
    );
  }

  // --- Kotlin matchers ---

  bool _matchesSealedClass(String line) =>
      RegExp(r'sealed\s+class\s+').hasMatch(line);

  bool _matchesDataClass(String line) =>
      RegExp(r'data\s+class\s+').hasMatch(line);

  bool _matchesEnumClass(String line) =>
      RegExp(r'enum\s+class\s+').hasMatch(line);

  bool _matchesInterface(String line) =>
      RegExp(r'(?:^|\s)interface\s+').hasMatch(line) &&
      !line.contains('public interface') && // handled by Java parser
      _isKotlinDecl(line);

  bool _matchesClass(String line) {
    if (line.startsWith('data ') ||
        line.startsWith('sealed ') ||
        line.startsWith('enum ')) {
      return false;
    }
    return RegExp(r'(?:^|(?:public|open|abstract|internal)\s+)*class\s+')
        .hasMatch(line);
  }

  bool _matchesFunction(String line) =>
      RegExp(r'(?:suspend\s+)?fun\s+').hasMatch(line) &&
      !_matchesExtensionFunction(line);

  bool _matchesExtensionFunction(String line) =>
      RegExp(r'(?:suspend\s+)?fun\s+\w+\.\w+\s*[<(]').hasMatch(line);

  bool _matchesObject(String line) {
    if (line.contains('companion object')) return false;
    return RegExp(r'(?:^|\s)object\s+\w+').hasMatch(line);
  }

  bool _isKotlinDecl(String line) =>
      !line.startsWith('public ') || line.contains(' fun ');

  // --- Kotlin parsers ---

  _ParsedClass? _parseKotlinClass(
      List<String> lines, int startIndex, String? doc) {
    final line = _stripAnnotations(lines[startIndex].trim());
    final nameMatch =
        RegExp(r'(?:public\s+|open\s+|abstract\s+|internal\s+)*class\s+(\w+)')
            .firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    if (_isPrivate(name)) return null;

    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    final fields = <UtsField>[];
    final seenMethodNames = <String>{};
    var isAbstract = line.contains('abstract ');

    var j = 0;
    while (j < bodyLines.length) {
      var bodyLine = _stripAnnotations(bodyLines[j].trim());

      if (bodyLine.startsWith('companion object')) {
        // Parse companion methods as static + companion fields
        final compEnd = _findBlockEndInBody(bodyLines, j);
        var k = j + 1;
        while (k < compEnd) {
          var compLine = _stripAnnotations(bodyLines[k].trim());
          final compDoc = _lookbackForKDoc(bodyLines, k);

          if (compLine.startsWith('private ') ||
              compLine.startsWith('internal ') ||
              compLine.startsWith('protected ')) {
            k++;
            continue;
          }

          if (_matchesFunction(compLine)) {
            final sig = _collectKotlinSignature(bodyLines, k);
            final method = _parseKotlinFunction(sig.text, compDoc);
            if (method != null &&
                !_isPrivate(method.name) &&
                seenMethodNames.add(method.name)) {
              methods.add(UtsMethod(
                name: method.name,
                isStatic: true,
                isAsync: method.isAsync,
                parameters: method.parameters,
                returnType: method.returnType,
                documentation: method.documentation,
              ));
            }
            k = sig.endIndex + 1;
            continue;
          } else if (compLine.startsWith('val ') ||
              compLine.startsWith('var ')) {
            final field = _parseKotlinField(compLine, compDoc);
            if (field != null) {
              fields.add(field);
            }
          }
          k++;
        }
        j = compEnd;
        continue;
      }

      if (bodyLine.startsWith('private ') ||
          bodyLine.startsWith('internal ') ||
          bodyLine.startsWith('protected ')) {
        j++;
        continue;
      }

      final bodyDoc = _lookbackForKDoc(bodyLines, j);

      if (_matchesFunction(bodyLine)) {
        final sig = _collectKotlinSignature(bodyLines, j);
        final method = _parseKotlinFunction(sig.text, bodyDoc);
        if (method != null &&
            !_isPrivate(method.name) &&
            seenMethodNames.add(method.name)) {
          methods.add(method);
        }
        j = sig.endIndex + 1;
        continue;
      } else if (bodyLine.startsWith('val ') || bodyLine.startsWith('var ')) {
        final field = _parseKotlinField(bodyLine, bodyDoc);
        if (field != null) {
          fields.add(field);
        }
      }

      j++;
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: isAbstract
            ? UtsClassKind.abstractClass
            : UtsClassKind.concreteClass,
        methods: methods,
        fields: fields,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  _ParsedClass? _parseKotlinDataClass(
      List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'data\s+class\s+(\w+)\s*\(').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;

    // Collect the full constructor parameters (may span multiple lines)
    final paramStr = _collectParenthesized(lines, startIndex);
    final fields = _parseKotlinDataClassFields(paramStr);

    // Find end of the declaration
    var endIndex = startIndex;
    for (var i = startIndex; i < lines.length; i++) {
      if (lines[i].contains(')')) {
        endIndex = i + 1;
        // Check if there's a body block
        if (lines[i].trim().endsWith('{')) {
          endIndex = _findBlockEnd(lines, i) + 1;
        }
        break;
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.dataClass,
        fields: fields,
        documentation: doc,
      ),
      endIndex: endIndex,
    );
  }

  List<UtsField> _parseKotlinDataClassFields(String paramStr) {
    final fields = <UtsField>[];
    // Remove surrounding parens
    var inner = paramStr.trim();
    if (inner.startsWith('(')) inner = inner.substring(1);
    if (inner.endsWith(')')) inner = inner.substring(0, inner.length - 1);

    for (final param in _splitParams(inner)) {
      final p = param.trim();
      if (p.isEmpty) continue;

      // Parse: val/var name: Type = default
      // Use manual parsing to handle generic types like Map<String, String>
      final valVarMatch = RegExp(r'^(val|var)\s+(\w+)\s*:\s*').firstMatch(p);
      if (valVarMatch != null) {
        final isReadOnly = valVarMatch.group(1) == 'val';
        final name = valVarMatch.group(2)!;
        final afterColon = p.substring(valVarMatch.end);

        // Extract type and default value, respecting angle bracket depth
        final typeAndDefault = _splitTypeAndDefault(afterColon);
        var typeStr = typeAndDefault.type.trim();
        final isNullable = typeStr.endsWith('?');
        if (isNullable) typeStr = typeStr.substring(0, typeStr.length - 1);

        fields.add(UtsField(
          name: name,
          type: _kotlinMapper.mapType(typeStr),
          nullable: isNullable,
          isReadOnly: isReadOnly,
        ));
      }
    }
    return fields;
  }

  _ParsedSealedClass? _parseKotlinSealedClass(
      List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'sealed\s+class\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final subclasses = <UtsClass>[];
    final sealedSubclassNames = <String>[];

    for (var j = 0; j < bodyLines.length; j++) {
      final bodyLine = bodyLines[j].trim();

      if (bodyLine.startsWith('data class ')) {
        final subMatch =
            RegExp(r'data\s+class\s+(\w+)\s*\(').firstMatch(bodyLine);
        if (subMatch != null) {
          final subName = subMatch.group(1)!;
          sealedSubclassNames.add(subName);

          final paramStr = _collectParenthesizedInBody(bodyLines, j);
          final fields = _parseKotlinDataClassFields(paramStr);

          subclasses.add(UtsClass(
            name: subName,
            kind: UtsClassKind.dataClass,
            fields: fields,
            superclass: name,
          ));
        }
      } else if (bodyLine.startsWith('object ')) {
        final subMatch = RegExp(r'object\s+(\w+)').firstMatch(bodyLine);
        if (subMatch != null) {
          final subName = subMatch.group(1)!;
          sealedSubclassNames.add(subName);
          subclasses.add(UtsClass(
            name: subName,
            kind: UtsClassKind.concreteClass,
            superclass: name,
          ));
        }
      }
    }

    return _ParsedSealedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.sealedClass,
        sealedSubclasses: sealedSubclassNames,
        documentation: doc,
      ),
      subclasses: subclasses,
      endIndex: endIndex + 1,
    );
  }

  _ParsedEnum? _parseKotlinEnum(
      List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'enum\s+class\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final values = <UtsEnumValue>[];
    for (var j = 0; j < bodyLines.length; j++) {
      final bodyLine = bodyLines[j].trim();
      if (bodyLine.isEmpty || bodyLine == '}') continue;

      final valueDoc = _lookbackForKDoc(bodyLines, j);

      // Match enum values: NAME, or NAME; or just NAME
      final valueMatch = RegExp(r'^(\w+)\s*[,;]?\s*$').firstMatch(bodyLine);
      if (valueMatch != null) {
        final valueName = valueMatch.group(1)!;
        values.add(UtsEnumValue(
          name: _toCamelCase(valueName),
          rawValue: valueName,
          documentation: valueDoc,
        ));
      }
    }

    return _ParsedEnum(
      enumDef: UtsEnum(
        name: name,
        values: values,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  _ParsedClass? _parseKotlinInterface(
      List<String> lines, int startIndex, String? doc) {
    final line = _stripAnnotations(lines[startIndex].trim());
    final nameMatch = RegExp(r'interface\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    var j = 0;
    while (j < bodyLines.length) {
      var bodyLine = _stripAnnotations(bodyLines[j].trim());
      if (bodyLine.isEmpty) {
        j++;
        continue;
      }

      final methodDoc = _lookbackForKDoc(bodyLines, j);

      if (_matchesFunction(bodyLine)) {
        final sig = _collectKotlinSignature(bodyLines, j);
        final method = _parseKotlinFunction(sig.text, methodDoc);
        if (method != null) {
          methods.add(method);
        }
        j = sig.endIndex + 1;
        continue;
      }

      j++;
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.abstractClass,
        methods: methods,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  UtsMethod? _parseKotlinFunction(String line, String? doc) {
    final isSuspend = line.contains('suspend ');
    // Extract function name
    final nameMatch =
        RegExp(r'(?:suspend\s+)?fun\s+(\w+)\s*\(').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;

    // Find matching paren using depth tracking
    final openParen = line.indexOf('(', nameMatch.start);
    if (openParen == -1) return null;
    final closeParen = _findMatchingParen(line, openParen);
    if (closeParen == -1) return null;

    final paramStr = line.substring(openParen + 1, closeParen);

    // Extract return type using depth tracking
    final afterParen = line.substring(closeParen + 1).trim();
    String? returnTypeStr;
    if (afterParen.startsWith(':')) {
      returnTypeStr = _extractReturnType(afterParen.substring(1).trim());
    }

    UtsType returnType;
    if (returnTypeStr == null || returnTypeStr.isEmpty) {
      returnType = UtsType.voidType();
    } else {
      returnType = _kotlinMapper.mapType(returnTypeStr);
    }

    // For suspend functions, wrap in Future if not already
    if (isSuspend && returnType.kind != UtsTypeKind.future) {
      returnType = UtsType.future(returnType);
    }

    final parameters = _parseKotlinParams(paramStr);

    return UtsMethod(
      name: name,
      isStatic: false,
      isAsync: isSuspend || returnType.kind == UtsTypeKind.future,
      parameters: parameters,
      returnType: returnType,
      documentation: doc,
    );
  }

  List<UtsParameter> _parseKotlinParams(String paramStr) {
    final params = <UtsParameter>[];
    for (final param in _splitParams(paramStr)) {
      final p = param.trim();
      if (p.isEmpty) continue;

      // Parse: name: Type = default
      // Use manual parsing to handle generic types with commas
      final nameMatch = RegExp(r'^(\w+)\s*:\s*').firstMatch(p);
      if (nameMatch != null) {
        final name = nameMatch.group(1)!;
        final afterColon = p.substring(nameMatch.end);

        final typeAndDefault = _splitTypeAndDefault(afterColon);
        var typeStr = typeAndDefault.type.trim();
        final defaultValue = typeAndDefault.defaultValue;
        final isNullable = typeStr.endsWith('?');
        if (isNullable) typeStr = typeStr.substring(0, typeStr.length - 1);

        var type = _kotlinMapper.mapType(typeStr);
        if (isNullable) type = type.asNullable();

        params.add(UtsParameter(
          name: name,
          type: type,
          isOptional: defaultValue != null || isNullable,
          isNamed: defaultValue != null,
          defaultValue: defaultValue,
        ));
      }
    }
    return params;
  }

  UtsField? _parseKotlinField(String line, String? doc) {
    final isReadOnly = line.startsWith('val ');
    final nameMatch = RegExp(r'(?:val|var)\s+(\w+)\s*:\s*').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final afterColon = line.substring(nameMatch.end);

    // Extract type using depth tracking (handles Map<String, String>)
    final typeAndDefault = _splitTypeAndDefault(afterColon);
    var typeStr = typeAndDefault.type.trim();

    // Remove trailing { for computed properties
    final braceIdx = _findBraceAtDepthZero(typeStr);
    if (braceIdx >= 0) typeStr = typeStr.substring(0, braceIdx).trim();

    final isNullable = typeStr.endsWith('?');
    if (isNullable) typeStr = typeStr.substring(0, typeStr.length - 1);

    return UtsField(
      name: name,
      type: _kotlinMapper.mapType(typeStr),
      nullable: isNullable,
      isReadOnly: isReadOnly,
      documentation: doc,
    );
  }

  _ParsedClass? _parseKotlinObject(
      List<String> lines, int startIndex, String? doc) {
    final line = _stripAnnotations(lines[startIndex].trim());
    final nameMatch = RegExp(r'object\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    if (_isPrivate(name)) return null;

    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    final fields = <UtsField>[];
    final seenMethodNames = <String>{};

    var j = 0;
    while (j < bodyLines.length) {
      var bodyLine = _stripAnnotations(bodyLines[j].trim());
      if (bodyLine.isEmpty) {
        j++;
        continue;
      }

      if (bodyLine.startsWith('private ') ||
          bodyLine.startsWith('internal ') ||
          bodyLine.startsWith('protected ')) {
        j++;
        continue;
      }

      final bodyDoc = _lookbackForKDoc(bodyLines, j);

      if (_matchesFunction(bodyLine)) {
        final sig = _collectKotlinSignature(bodyLines, j);
        final method = _parseKotlinFunction(sig.text, bodyDoc);
        if (method != null &&
            !_isPrivate(method.name) &&
            seenMethodNames.add(method.name)) {
          methods.add(UtsMethod(
            name: method.name,
            isStatic: true,
            isAsync: method.isAsync,
            parameters: method.parameters,
            returnType: method.returnType,
            documentation: method.documentation,
          ));
        }
        j = sig.endIndex + 1;
        continue;
      } else if (bodyLine.startsWith('val ') || bodyLine.startsWith('var ')) {
        final field = _parseKotlinField(bodyLine, bodyDoc);
        if (field != null) {
          fields.add(field);
        }
      }

      j++;
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.concreteClass,
        methods: methods,
        fields: fields,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  String? _getExtensionReceiver(String line) {
    final match =
        RegExp(r'(?:suspend\s+)?fun\s+(\w+)\.\w+\s*[<(]').firstMatch(line);
    return match?.group(1);
  }

  UtsMethod? _parseKotlinExtensionFunction(String line, String? doc) {
    final isSuspend = line.contains('suspend ');
    final nameMatch =
        RegExp(r'(?:suspend\s+)?fun\s+\w+\.(\w+)\s*(?:<[^>]*>)?\s*\(')
            .firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;

    final openParen = line.indexOf('(', nameMatch.start);
    if (openParen == -1) return null;
    final closeParen = _findMatchingParen(line, openParen);
    if (closeParen == -1) return null;

    final paramStr = line.substring(openParen + 1, closeParen);
    final afterParen = line.substring(closeParen + 1).trim();

    String? returnTypeStr;
    if (afterParen.startsWith(':')) {
      returnTypeStr = _extractReturnType(afterParen.substring(1).trim());
    }

    UtsType returnType;
    if (returnTypeStr == null || returnTypeStr.isEmpty) {
      returnType = UtsType.voidType();
    } else {
      returnType = _kotlinMapper.mapType(returnTypeStr);
    }

    if (isSuspend && returnType.kind != UtsTypeKind.future) {
      returnType = UtsType.future(returnType);
    }

    final parameters = _parseKotlinParams(paramStr);

    return UtsMethod(
      name: name,
      isStatic: false,
      isAsync: isSuspend || returnType.kind == UtsTypeKind.future,
      parameters: parameters,
      returnType: returnType,
      documentation: doc,
    );
  }

  // ========== Java Parsing ==========

  UnifiedTypeSchema _parseJava(
      String content, String packageName, String version) {
    final lines = content.split('\n');
    final classes = <UtsClass>[];
    final functions = <UtsMethod>[];
    final types = <UtsClass>[];
    final enums = <UtsEnum>[];

    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();

      // Skip empty, imports, package
      if (line.isEmpty ||
          line.startsWith('import ') ||
          line.startsWith('package ')) {
        i++;
        continue;
      }

      final doc = _lookbackForJavaDoc(lines, i);

      // Skip non-public
      if (!line.startsWith('public ') && !line.startsWith('/**')) {
        if (line.startsWith('private ') || line.startsWith('protected ')) {
          i = _skipBlock(lines, i);
          continue;
        }
      }

      // Enum
      if (_matchesJavaEnum(line)) {
        final result = _parseJavaEnum(lines, i, doc);
        if (result != null) {
          enums.add(result.enumDef);
          i = result.endIndex;
          continue;
        }
      }

      // Interface
      if (_matchesJavaInterface(line)) {
        final result = _parseJavaInterface(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          i = result.endIndex;
          continue;
        }
      }

      // Class
      if (_matchesJavaClass(line)) {
        final result = _parseJavaClass(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          i = result.endIndex;
          continue;
        }
      }

      i++;
    }

    return UnifiedTypeSchema(
      package: packageName,
      source: PackageSource.gradle,
      version: version,
      classes: classes,
      functions: functions,
      types: types,
      enums: enums,
    );
  }

  // --- Java matchers ---

  bool _matchesJavaClass(String line) =>
      RegExp(r'public\s+(?:abstract\s+|static\s+|final\s+)*class\s+')
          .hasMatch(line);

  bool _matchesJavaInterface(String line) =>
      RegExp(r'public\s+interface\s+').hasMatch(line);

  bool _matchesJavaEnum(String line) =>
      RegExp(r'public\s+enum\s+').hasMatch(line);

  bool _matchesJavaMethod(String line, {bool publicOnly = false}) {
    if (line.startsWith('private ') || line.startsWith('protected ')) {
      return false;
    }
    if (publicOnly && !line.contains('public ')) {
      return false;
    }
    // Check for a method pattern using depth-tracking:
    // [modifiers] ReturnType methodName(
    return _findOpenParenAtDepthZero(line) > 0 &&
        RegExp(r'\w+\s*\(').hasMatch(line);
  }

  // --- Java parsers ---

  _ParsedClass? _parseJavaClass(
      List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch =
        RegExp(r'public\s+(?:abstract\s+|static\s+|final\s+)*class\s+(\w+)')
            .firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final isAbstract = line.contains('abstract ');
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    final seenMethodNames = <String>{};
    for (var j = 0; j < bodyLines.length; j++) {
      final bodyLine = bodyLines[j].trim();
      if (bodyLine.isEmpty) continue;

      final methodDoc = _lookbackForJavaDoc(bodyLines, j);

      if (_matchesJavaMethod(bodyLine, publicOnly: true)) {
        final method = _parseJavaMethod(bodyLine, methodDoc);
        if (method != null && seenMethodNames.add(method.name)) {
          methods.add(method);
        }
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: isAbstract
            ? UtsClassKind.abstractClass
            : UtsClassKind.concreteClass,
        methods: methods,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  _ParsedClass? _parseJavaInterface(
      List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'public\s+interface\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    for (var j = 0; j < bodyLines.length; j++) {
      final bodyLine = bodyLines[j].trim();
      if (bodyLine.isEmpty) continue;

      final methodDoc = _lookbackForJavaDoc(bodyLines, j);

      // Interface methods: ReturnType methodName(params);
      final method = _parseJavaMethod(bodyLine, methodDoc);
      if (method != null) {
        methods.add(method);
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.abstractClass,
        methods: methods,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  _ParsedEnum? _parseJavaEnum(List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'public\s+enum\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final values = <UtsEnumValue>[];
    for (var j = 0; j < bodyLines.length; j++) {
      final bodyLine = bodyLines[j].trim();
      if (bodyLine.isEmpty || bodyLine == '}') continue;

      final valueDoc = _lookbackForJavaDoc(bodyLines, j);

      // Match enum constants: NAME, or NAME; or NAME
      final valueMatch = RegExp(r'^(\w+)\s*[,;]?\s*$').firstMatch(bodyLine);
      if (valueMatch != null) {
        final valueName = valueMatch.group(1)!;
        values.add(UtsEnumValue(
          name: _toCamelCase(valueName),
          rawValue: valueName,
          documentation: valueDoc,
        ));
      }
    }

    return _ParsedEnum(
      enumDef: UtsEnum(
        name: name,
        values: values,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  UtsMethod? _parseJavaMethod(String line, String? doc) {
    final isStatic = line.contains('static ');

    // Strip modifiers
    var clean = line.trim();
    for (final mod in [
      'public ',
      'static ',
      'final ',
      'abstract ',
      'synchronized ',
    ]) {
      clean = clean.replaceFirst(mod, '');
    }
    clean = clean.trim();

    // Find the opening paren at angle-bracket depth 0
    final openParen = _findOpenParenAtDepthZero(clean);
    if (openParen == -1) return null;

    final closeParen = _findMatchingParen(clean, openParen);
    if (closeParen == -1) return null;

    final paramStr = clean.substring(openParen + 1, closeParen);

    // Everything before ( is "ReturnType methodName"
    final beforeParen = clean.substring(0, openParen).trim();

    // Split into return type and method name at the last space at depth 0
    final lastSpaceIdx = _findLastSpaceAtDepthZero(beforeParen);
    if (lastSpaceIdx == -1) return null;

    final returnTypeStr = beforeParen.substring(0, lastSpaceIdx).trim();
    final name = beforeParen.substring(lastSpaceIdx + 1).trim();

    return UtsMethod(
      name: name,
      isStatic: isStatic,
      parameters: _parseJavaParams(paramStr),
      returnType: _javaMapper.mapType(returnTypeStr),
      documentation: doc,
    );
  }

  List<UtsParameter> _parseJavaParams(String paramStr) {
    final params = <UtsParameter>[];
    for (final param in _splitParams(paramStr)) {
      final p = param.trim();
      if (p.isEmpty) continue;

      // Match: Type name  or  @Nullable Type name
      final isNullable = p.contains('@Nullable');
      final clean = p.replaceAll('@Nullable', '').trim();
      final match = RegExp(r'(\S+)\s+(\w+)$').firstMatch(clean);
      if (match != null) {
        var typeStr = match.group(1)!;
        final name = match.group(2)!;
        var type = _javaMapper.mapType(typeStr);
        if (isNullable) type = type.asNullable();

        params.add(UtsParameter(
          name: name,
          type: type,
        ));
      }
    }
    return params;
  }

  // ========== Common Helpers ==========

  /// Strips leading annotations like @JvmStatic, @Throws(IOException::class).
  String _stripAnnotations(String line) {
    var result = line;
    while (result.startsWith('@')) {
      final parenIdx = result.indexOf('(');
      final spaceIdx = result.indexOf(' ');

      if (parenIdx >= 0 && (spaceIdx < 0 || parenIdx < spaceIdx)) {
        // Has parenthesized args: @Foo(bar) rest
        final closeIdx = _findMatchingParen(result, parenIdx);
        if (closeIdx >= 0) {
          result = result.substring(closeIdx + 1).trim();
        } else {
          break;
        }
      } else if (spaceIdx >= 0) {
        // Simple annotation: @Foo rest
        result = result.substring(spaceIdx + 1).trim();
      } else {
        break;
      }
    }
    return result;
  }

  /// Collects a Kotlin function signature that may span multiple lines.
  _CollectedSignature _collectKotlinSignature(
      List<String> lines, int startIndex) {
    final buffer = StringBuffer();
    var parenDepth = 0;
    var foundOpenParen = false;
    var lastIndex = startIndex;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (i > startIndex) buffer.write(' ');
      buffer.write(line);
      lastIndex = i;

      for (var j = 0; j < line.length; j++) {
        if (line[j] == '(') {
          parenDepth++;
          foundOpenParen = true;
        } else if (line[j] == ')') {
          parenDepth--;
        }
      }

      // Keep collecting until parens are balanced
      if (!foundOpenParen || parenDepth > 0) continue;

      // Parens balanced — check if signature is complete
      if (line.contains('{')) break;

      final currentText = buffer.toString();
      // If we already have a return type, we're done
      if (RegExp(r'\)\s*:').hasMatch(currentText)) break;

      // Peek at next line for return type or body
      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        if (nextLine.isEmpty ||
            (!nextLine.startsWith(':') && !nextLine.startsWith('{'))) {
          break;
        }
      } else {
        break;
      }
    }

    return _CollectedSignature(text: buffer.toString(), endIndex: lastIndex);
  }

  /// Splits a type+default string like "`Map<String, String>` = emptyMap()"
  /// into the type part and optional default value, respecting angle brackets.
  _TypeAndDefault _splitTypeAndDefault(String input) {
    var depth = 0;
    for (var i = 0; i < input.length; i++) {
      switch (input[i]) {
        case '<':
          depth++;
          break;
        case '>':
          depth--;
          break;
        case '=':
          if (depth == 0) {
            return _TypeAndDefault(
              type: input.substring(0, i).trim(),
              defaultValue: input.substring(i + 1).trim(),
            );
          }
          break;
      }
    }
    return _TypeAndDefault(type: input.trim());
  }

  /// Finds the matching closing parenthesis for an opening one at [openPos].
  int _findMatchingParen(String text, int openPos) {
    var depth = 0;
    for (var i = openPos; i < text.length; i++) {
      if (text[i] == '(') {
        depth++;
      } else if (text[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Extracts a return type from text after `:`, respecting angle bracket depth.
  /// Stops at `{` or end of text.
  String? _extractReturnType(String text) {
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      switch (text[i]) {
        case '<':
          depth++;
          break;
        case '>':
          depth--;
          break;
        case '{':
          if (depth == 0) {
            final result = text.substring(0, i).trim();
            return result.isEmpty ? null : result;
          }
          break;
      }
    }
    final result = text.trim();
    return result.isEmpty ? null : result;
  }

  /// Finds the first `{` at angle-bracket depth 0.
  int _findBraceAtDepthZero(String text) {
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '<') {
        depth++;
      } else if (text[i] == '>') {
        depth--;
      } else if (text[i] == '{' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  /// Finds the first `(` at angle-bracket depth 0.
  int _findOpenParenAtDepthZero(String text) {
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '<') {
        depth++;
      } else if (text[i] == '>') {
        depth--;
      } else if (text[i] == '(' && depth == 0) {
        return i;
      }
    }
    return -1;
  }

  /// Finds the last space at angle-bracket depth 0.
  int _findLastSpaceAtDepthZero(String text) {
    var depth = 0;
    var lastSpace = -1;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '<') {
        depth++;
      } else if (text[i] == '>') {
        depth--;
      } else if (text[i] == ' ' && depth == 0) {
        lastSpace = i;
      }
    }
    return lastSpace;
  }

  bool _isPrivate(String name) => name.startsWith('_');

  int _findBlockEnd(List<String> lines, int startIndex) {
    var depth = 0;
    var foundOpen = false;
    for (var i = startIndex; i < lines.length; i++) {
      for (final ch in lines[i].runes) {
        if (ch == 0x7B) {
          // {
          depth++;
          foundOpen = true;
        } else if (ch == 0x7D) {
          // }
          depth--;
          if (foundOpen && depth == 0) return i;
        }
      }
    }
    return lines.length - 1;
  }

  int _findBlockEndInBody(List<String> bodyLines, int startIndex) {
    var depth = 0;
    var foundOpen = false;
    for (var i = startIndex; i < bodyLines.length; i++) {
      for (final ch in bodyLines[i].runes) {
        if (ch == 0x7B) {
          depth++;
          foundOpen = true;
        } else if (ch == 0x7D) {
          depth--;
          if (foundOpen && depth == 0) return i;
        }
      }
    }
    return bodyLines.length;
  }

  int _skipBlock(List<String> lines, int startIndex) {
    final line = lines[startIndex].trim();
    if (line.contains('{')) {
      return _findBlockEnd(lines, startIndex) + 1;
    }
    return startIndex + 1;
  }

  String _collectParenthesized(List<String> lines, int startIndex) {
    final buffer = StringBuffer();
    var depth = 0;
    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      for (var j = 0; j < line.length; j++) {
        final ch = line[j];
        if (ch == '(') {
          depth++;
          if (depth == 1) continue; // skip opening paren
        }
        if (ch == ')') {
          depth--;
          if (depth == 0) {
            buffer.write(')');
            return '($buffer';
          }
        }
        if (depth > 0) buffer.write(ch);
      }
      if (depth > 0) buffer.write(' ');
    }
    return '($buffer)';
  }

  String _collectParenthesizedInBody(List<String> bodyLines, int startIndex) {
    return _collectParenthesized(bodyLines, startIndex);
  }

  List<String> _splitParams(String params) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < params.length; i++) {
      switch (params[i]) {
        case '<':
        case '(':
        case '{':
          depth++;
          break;
        case '>':
        case ')':
        case '}':
          depth--;
          break;
        case ',':
          if (depth == 0) {
            result.add(params.substring(start, i));
            start = i + 1;
          }
          break;
      }
    }
    if (start < params.length) {
      result.add(params.substring(start));
    }
    return result;
  }

  // --- KDoc / JavaDoc ---

  String? _lookbackForKDoc(List<String> lines, int index) {
    return _lookbackForDoc(lines, index);
  }

  String? _lookbackForJavaDoc(List<String> lines, int index) {
    return _lookbackForDoc(lines, index);
  }

  String? _lookbackForDoc(List<String> lines, int index) {
    // Look for /** ... */ block ending just before this line
    var i = index - 1;
    while (i >= 0 && lines[i].trim().isEmpty) {
      i--;
    }
    if (i < 0) return null;

    final lastLine = lines[i].trim();
    if (!lastLine.endsWith('*/')) return null;

    // Single-line /** doc */
    if (lastLine.startsWith('/**') && lastLine.endsWith('*/')) {
      return lastLine.replaceFirst('/**', '').replaceFirst('*/', '').trim();
    }

    // Multi-line doc
    final docLines = <String>[];
    while (i >= 0) {
      final line = lines[i].trim();
      if (line.startsWith('/**')) {
        final first = line.replaceFirst('/**', '').trim();
        // Strip trailing */ if on the same line
        var cleaned = first;
        if (cleaned.endsWith('*/')) {
          cleaned = cleaned.substring(0, cleaned.length - 2).trim();
        }
        if (cleaned.isNotEmpty && !cleaned.startsWith('*')) {
          docLines.insert(0, cleaned);
        }
        break;
      }
      // Skip bare closing */
      if (line == '*/') {
        i--;
        continue;
      }
      if (line.startsWith('*')) {
        var content = line.substring(1).trim();
        if (content.endsWith('*/')) {
          content = content.substring(0, content.length - 2).trim();
        }
        if (content.isNotEmpty && !content.startsWith('@')) {
          docLines.insert(0, content);
        }
      }
      i--;
    }

    return docLines.isEmpty ? null : docLines.join(' ').trim();
  }

  _DocResult _collectKDoc(List<String> lines, int index) {
    final line = lines[index].trim();
    if (!line.startsWith('/**')) return _DocResult(null, index);

    // Find end of doc block
    for (var i = index; i < lines.length; i++) {
      if (lines[i].contains('*/')) {
        return _DocResult(null, i + 1);
      }
    }
    return _DocResult(null, index);
  }

  String _toCamelCase(String upper) {
    if (upper.isEmpty) return upper;
    // UPPER_CASE → upperCase
    final parts = upper.split('_');
    return parts.first.toLowerCase() +
        parts
            .skip(1)
            .map((s) => s.isEmpty
                ? ''
                : s[0].toUpperCase() + s.substring(1).toLowerCase())
            .join();
  }
}

// --- Internal helper classes ---

class _ParsedClass {
  final UtsClass cls;
  final int endIndex;
  _ParsedClass({required this.cls, required this.endIndex});
}

class _ParsedSealedClass {
  final UtsClass cls;
  final List<UtsClass> subclasses;
  final int endIndex;
  _ParsedSealedClass({
    required this.cls,
    required this.subclasses,
    required this.endIndex,
  });
}

class _ParsedEnum {
  final UtsEnum enumDef;
  final int endIndex;
  _ParsedEnum({required this.enumDef, required this.endIndex});
}

class _DocResult {
  final String? doc;
  final int endIndex;
  _DocResult(this.doc, this.endIndex);
}

class _TypeAndDefault {
  final String type;
  final String? defaultValue;
  _TypeAndDefault({required this.type, this.defaultValue});
}

class _CollectedSignature {
  final String text;
  final int endIndex;
  _CollectedSignature({required this.text, required this.endIndex});
}
