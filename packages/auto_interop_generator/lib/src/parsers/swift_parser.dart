import '../schema/unified_type_schema.dart';
import '../type_mapping/swift_to_dart.dart';
import 'parser_base.dart';

/// Parses Swift (.swift / .swiftinterface) source files into a
/// [UnifiedTypeSchema].
///
/// Handles:
/// - Classes (public, open)
/// - Structs (→ dataClass)
/// - Protocols (→ abstractClass)
/// - Enums with associated values (→ sealedClass)
/// - Simple enums
/// - Functions with async/await (→ Future)
/// - AsyncStream/AsyncSequence (→ Stream)
/// - Closures (→ callback)
/// - Optionals (→ nullable)
/// - Extensions (folds methods into the base class)
/// - Static/class methods
/// - Access control filtering (only public/open)
class SwiftParser extends ParserBase {
  final SwiftToDartMapper _mapper = SwiftToDartMapper();

  @override
  PackageSource get source => PackageSource.cocoapods;

  @override
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  }) {
    final lines = content.split('\n');
    final classes = <UtsClass>[];
    final functions = <UtsMethod>[];
    final types = <UtsClass>[];
    final enums = <UtsEnum>[];
    final extensions = <String, List<UtsMethod>>{};
    final extensionInterfaces = <String, List<String>>{};

    var i = 0;
    while (i < lines.length) {
      final rawLine = lines[i].trim();

      // Skip empty lines, imports, and /// doc comment lines
      if (rawLine.isEmpty ||
          rawLine.startsWith('import ') ||
          rawLine.startsWith('///')) {
        i++;
        continue;
      }

      // Collect /** ... */ documentation blocks
      final docResult = _collectDocBlock(lines, i);
      if (docResult.endIndex > i) {
        i = docResult.endIndex;
        continue;
      }

      final doc = _lookbackForDoc(lines, i);

      // Strip attributes before matcher checks
      final line = _stripAttributes(rawLine);

      // Skip typealias declarations
      if (line.startsWith('typealias ')) {
        i++;
        continue;
      }

      // Skip private/fileprivate/internal declarations
      if (_isNonPublic(line)) {
        i = _skipBlock(lines, i);
        continue;
      }

      // Extension
      if (_matchesExtension(line)) {
        final result = _parseExtension(lines, i);
        if (result != null) {
          extensions
              .putIfAbsent(result.targetName, () => [])
              .addAll(result.methods);
          // Add nested types from extensions to the schema
          enums.addAll(result.nestedEnums);
          types.addAll(result.nestedClasses);
          // Collect protocol conformance from extensions
          if (result.interfaces.isNotEmpty) {
            extensionInterfaces
                .putIfAbsent(result.targetName, () => [])
                .addAll(result.interfaces);
          }
          i = result.endIndex;
          continue;
        }
      }

      // Protocol
      if (_matchesProtocol(line)) {
        final result = _parseProtocol(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          i = result.endIndex;
          continue;
        }
      }

      // Enum with associated values
      if (_matchesEnum(line)) {
        final result = _parseEnum(lines, i, doc);
        if (result != null) {
          if (result.isSealedClass) {
            classes.add(result.sealedClass!);
            for (final sub in result.subclasses) {
              types.add(sub);
            }
          } else {
            enums.add(result.enumDef!);
          }
          i = result.endIndex;
          continue;
        }
      }

      // Struct
      if (_matchesStruct(line)) {
        final result = _parseStruct(lines, i, doc);
        if (result != null) {
          types.add(result.cls);
          enums.addAll(result.nestedEnums);
          types.addAll(result.nestedClasses);
          i = result.endIndex;
          continue;
        }
      }

      // Class
      if (_matchesClass(line)) {
        final result = _parseClass(lines, i, doc);
        if (result != null) {
          classes.add(result.cls);
          enums.addAll(result.nestedEnums);
          types.addAll(result.nestedClasses);
          i = result.endIndex;
          continue;
        }
      }

      // Top-level function
      if (_matchesFunction(line)) {
        final sig = _collectFunctionSignature(lines, i);
        final method = _parseFunction(sig.text, doc);
        if (method != null) {
          functions.add(method);
        }
        i = sig.endIndex + 1;
        continue;
      }

      i++;
    }

    // Fold extension methods and interfaces into their base classes/types
    for (final entry in extensions.entries) {
      final targetName = entry.key;
      final extMethods = entry.value;
      final extInterfaces = extensionInterfaces[targetName] ?? [];

      var found = false;
      // Search in both classes and types (structs go to types)
      for (final list in [classes, types]) {
        for (var ci = 0; ci < list.length; ci++) {
          if (list[ci].name == targetName) {
            list[ci] = UtsClass(
              name: list[ci].name,
              nativeName: list[ci].nativeName,
              kind: list[ci].kind,
              fields: list[ci].fields,
              methods: [...list[ci].methods, ...extMethods],
              superclass: list[ci].superclass,
              interfaces: {...list[ci].interfaces, ...extInterfaces}.toList(),
              sealedSubclasses: list[ci].sealedSubclasses,
              documentation: list[ci].documentation,
              constructorParameters: list[ci].constructorParameters,
              constructorThrows: list[ci].constructorThrows,
            );
            found = true;
            break;
          }
        }
        if (found) break;
      }
      // If the base class wasn't found in this file, create it
      if (!found) {
        classes.add(UtsClass(
          name: targetName,
          kind: UtsClassKind.concreteClass,
          interfaces: extInterfaces,
          methods: extMethods,
        ));
      }
    }

    // Promote structs (data classes) to concrete classes when they implement
    // a protocol that is a reference type (abstract class with instance methods).
    // This ensures they get handle-based management so they can be passed where
    // the protocol type is expected.
    final referenceProtocols = classes
        .where((c) =>
            c.kind == UtsClassKind.abstractClass &&
            c.methods.any((m) => !m.isStatic))
        .map((c) => c.name)
        .toSet();
    final toPromote = <UtsClass>[];
    types.removeWhere((t) {
      if (t.kind == UtsClassKind.dataClass &&
          t.interfaces.any((i) => referenceProtocols.contains(i))) {
        toPromote.add(UtsClass(
          name: t.name,
          nativeName: t.nativeName,
          kind: UtsClassKind.concreteClass,
          fields: t.fields,
          methods: t.methods,
          superclass: t.superclass,
          interfaces: t.interfaces,
          sealedSubclasses: t.sealedSubclasses,
          documentation: t.documentation,
          constructorParameters: t.constructorParameters,
          constructorThrows: t.constructorThrows,
        ));
        return true;
      }
      return false;
    });
    classes.addAll(toPromote);

    final schema = UnifiedTypeSchema(
      package: packageName,
      source: PackageSource.cocoapods,
      version: version,
      classes: classes,
      functions: functions,
      types: types,
      enums: enums,
    );

    // Resolve dotted type references (e.g., SHA2.Variant → SHA2Variant)
    return _resolveNestedTypeRefs(schema);
  }

  // ========== Matchers ==========

  bool _isNonPublic(String line) {
    if (line.startsWith('private ') || line.startsWith('fileprivate ')) {
      return true;
    }
    if (line.startsWith('internal ')) {
      return true;
    }
    return false;
  }

  bool _matchesClass(String line) {
    if (line.contains('struct ') ||
        line.contains('protocol ') ||
        line.contains('enum ') ||
        line.contains('extension ') ||
        line.contains('func ')) {
      return false;
    }
    return RegExp(r'(?:public\s+|open\s+)?(?:final\s+)?class\s+\w+')
        .hasMatch(line);
  }

  bool _matchesStruct(String line) =>
      RegExp(r'(?:public\s+)?struct\s+\w+').hasMatch(line);

  bool _matchesProtocol(String line) =>
      RegExp(r'(?:public\s+)?protocol\s+\w+').hasMatch(line);

  bool _matchesEnum(String line) =>
      RegExp(r'(?:public\s+)?enum\s+\w+').hasMatch(line);

  bool _matchesExtension(String line) =>
      RegExp(r'extension\s+\w+').hasMatch(line);

  bool _matchesFunction(String line) {
    return RegExp(r'(?:public\s+)?(?:static\s+|class\s+)?func\s+\w+')
        .hasMatch(line);
  }

  bool _matchesInit(String line) {
    return RegExp(
            r'(?:public\s+|open\s+)?(?:convenience\s+)?(?:required\s+)?init\s*\(')
        .hasMatch(line);
  }

  List<UtsParameter> _parseInit(String line) {
    final openParen = line.indexOf('(');
    if (openParen == -1) return [];
    final closeParen = _findMatchingParen(line, openParen);
    if (closeParen == -1) return [];

    final paramStr = line.substring(openParen + 1, closeParen);
    return _parseSwiftParams(paramStr);
  }

  // ========== Parsers ==========

  _ParsedClass? _parseClass(List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch =
        RegExp(r'(?:public\s+|open\s+)?(?:final\s+)?class\s+(\w+)')
            .firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final interfaces = _parseInheritanceClause(line);
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    final fields = <UtsField>[];
    final constructorParams = <UtsParameter>[];
    final nestedEnums = <UtsEnum>[];
    final nestedClasses = <UtsClass>[];
    var foundInit = false;
    var ctorThrows = false;

    for (var j = 0; j < bodyLines.length; j++) {
      final rawBodyLine = bodyLines[j].trim();
      if (rawBodyLine.isEmpty ||
          rawBodyLine.startsWith('///') ||
          rawBodyLine.startsWith('/**') ||
          rawBodyLine.startsWith('*')) {
        continue;
      }

      final bodyLine = _stripAttributes(rawBodyLine);

      // Skip non-public members
      if (bodyLine.startsWith('private ') ||
          bodyLine.startsWith('fileprivate ')) {
        j = _skipBlockInBody(bodyLines, j);
        continue;
      }

      final memberDoc = _lookbackForDoc(bodyLines, j);

      // Nested enum
      if (_matchesEnum(bodyLine)) {
        final result = _parseEnum(bodyLines, j, memberDoc);
        if (result != null) {
          if (result.isSealedClass) {
            nestedClasses.add(_prefixClass(name, result.sealedClass!));
            for (final sub in result.subclasses) {
              nestedClasses.add(_prefixClass(name, sub));
            }
          } else {
            nestedEnums.add(_prefixEnum(name, result.enumDef!));
          }
          j = result.endIndex - 1;
          continue;
        }
      }

      // Nested struct
      if (_matchesStruct(bodyLine)) {
        final result = _parseStruct(bodyLines, j, memberDoc);
        if (result != null) {
          nestedClasses.add(_prefixClass(name, result.cls));
          nestedEnums
              .addAll(result.nestedEnums.map((e) => _prefixEnum(name, e)));
          nestedClasses
              .addAll(result.nestedClasses.map((c) => _prefixClass(name, c)));
          j = result.endIndex - 1;
          continue;
        }
      }

      // Nested class
      if (_matchesClass(bodyLine)) {
        final result = _parseClass(bodyLines, j, memberDoc);
        if (result != null) {
          nestedClasses.add(_prefixClass(name, result.cls));
          nestedEnums
              .addAll(result.nestedEnums.map((e) => _prefixEnum(name, e)));
          nestedClasses
              .addAll(result.nestedClasses.map((c) => _prefixClass(name, c)));
          j = result.endIndex - 1;
          continue;
        }
      }

      if (_matchesInit(bodyLine)) {
        foundInit = true;
        final sig = _collectFunctionSignature(bodyLines, j);
        final params = _parseInit(sig.text);
        constructorParams.addAll(params);
        // Detect throws/rethrows after the closing paren
        final afterParams = sig.text.substring(sig.text.lastIndexOf(')') + 1);
        if (RegExp(r'\bthrows\b|\brethrows\b').hasMatch(afterParams)) {
          ctorThrows = true;
        }
        j = sig.endIndex;
        continue;
      }

      if (_matchesFunction(bodyLine)) {
        final sig = _collectFunctionSignature(bodyLines, j);
        final method = _parseFunction(sig.text, memberDoc);
        if (method != null) {
          methods.add(method);
        }
        j = sig.endIndex;
      } else if (_matchesProperty(bodyLine)) {
        final field = _parseProperty(bodyLine, memberDoc);
        if (field != null) {
          fields.add(field);
        }
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.concreteClass,
        interfaces: interfaces,
        methods: methods,
        fields: fields,
        constructorParameters: foundInit ? constructorParams : null,
        constructorThrows: ctorThrows,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
      nestedEnums: nestedEnums,
      nestedClasses: nestedClasses,
    );
  }

  _ParsedClass? _parseStruct(List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'(?:public\s+)?struct\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final interfaces = _parseInheritanceClause(line);
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final fields = <UtsField>[];
    final methods = <UtsMethod>[];
    final constructorParams = <UtsParameter>[];
    final nestedEnums = <UtsEnum>[];
    final nestedClasses = <UtsClass>[];
    var foundInit = false;
    var ctorThrows = false;

    for (var j = 0; j < bodyLines.length; j++) {
      final rawBodyLine = bodyLines[j].trim();
      if (rawBodyLine.isEmpty ||
          rawBodyLine.startsWith('///') ||
          rawBodyLine.startsWith('/**') ||
          rawBodyLine.startsWith('*')) {
        continue;
      }

      final bodyLine = _stripAttributes(rawBodyLine);

      if (bodyLine.startsWith('private ') ||
          bodyLine.startsWith('fileprivate ')) {
        j = _skipBlockInBody(bodyLines, j);
        continue;
      }

      final memberDoc = _lookbackForDoc(bodyLines, j);

      // Nested enum
      if (_matchesEnum(bodyLine)) {
        final result = _parseEnum(bodyLines, j, memberDoc);
        if (result != null) {
          if (result.isSealedClass) {
            nestedClasses.add(_prefixClass(name, result.sealedClass!));
            for (final sub in result.subclasses) {
              nestedClasses.add(_prefixClass(name, sub));
            }
          } else {
            nestedEnums.add(_prefixEnum(name, result.enumDef!));
          }
          j = result.endIndex - 1;
          continue;
        }
      }

      // Nested struct
      if (_matchesStruct(bodyLine)) {
        final result = _parseStruct(bodyLines, j, memberDoc);
        if (result != null) {
          nestedClasses.add(_prefixClass(name, result.cls));
          nestedEnums
              .addAll(result.nestedEnums.map((e) => _prefixEnum(name, e)));
          nestedClasses
              .addAll(result.nestedClasses.map((c) => _prefixClass(name, c)));
          j = result.endIndex - 1;
          continue;
        }
      }

      if (_matchesInit(bodyLine)) {
        foundInit = true;
        final sig = _collectFunctionSignature(bodyLines, j);
        final params = _parseInit(sig.text);
        constructorParams.addAll(params);
        // Detect throws/rethrows after the closing paren
        final afterParams = sig.text.substring(sig.text.lastIndexOf(')') + 1);
        if (RegExp(r'\bthrows\b|\brethrows\b').hasMatch(afterParams)) {
          ctorThrows = true;
        }
        j = sig.endIndex;
        continue;
      }

      if (_matchesProperty(bodyLine)) {
        final field = _parseProperty(bodyLine, memberDoc);
        if (field != null) {
          fields.add(field);
        }
      } else if (_matchesFunction(bodyLine)) {
        final sig = _collectFunctionSignature(bodyLines, j);
        final method = _parseFunction(sig.text, memberDoc);
        if (method != null) {
          methods.add(method);
        }
        j = sig.endIndex;
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.dataClass,
        interfaces: interfaces,
        fields: fields,
        methods: methods,
        constructorParameters: foundInit ? constructorParams : null,
        constructorThrows: ctorThrows,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
      nestedEnums: nestedEnums,
      nestedClasses: nestedClasses,
    );
  }

  _ParsedClass? _parseProtocol(
      List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch =
        RegExp(r'(?:public\s+)?protocol\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    final fields = <UtsField>[];

    for (var j = 0; j < bodyLines.length; j++) {
      final rawBodyLine = bodyLines[j].trim();
      if (rawBodyLine.isEmpty) continue;

      final bodyLine = _stripAttributes(rawBodyLine);

      final memberDoc = _lookbackForDoc(bodyLines, j);

      // Protocol property requirement: var name: Type { get }
      if (_matchesProtocolProperty(bodyLine)) {
        final field = _parseProtocolProperty(bodyLine, memberDoc);
        if (field != null) {
          fields.add(field);
        }
      } else if (_matchesFunctionDecl(bodyLine)) {
        final sig = _collectFunctionSignature(bodyLines, j);
        final method = _parseFunctionDecl(sig.text, memberDoc);
        if (method != null) {
          methods.add(method);
        }
        j = sig.endIndex;
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: UtsClassKind.abstractClass,
        methods: methods,
        fields: fields,
        documentation: doc,
      ),
      endIndex: endIndex + 1,
    );
  }

  _ParsedEnumResult? _parseEnum(
      List<String> lines, int startIndex, String? doc) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'(?:public\s+)?enum\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    // Detect if this enum has associated values
    final hasAssociatedValues = bodyLines.any((l) {
      final trimmed = l.trim();
      return trimmed.startsWith('case ') && trimmed.contains('(');
    });

    if (hasAssociatedValues) {
      return _parseSealedEnum(name, bodyLines, endIndex, doc);
    }

    return _parseSimpleEnum(name, line, bodyLines, endIndex, doc);
  }

  _ParsedEnumResult _parseSimpleEnum(String name, String headerLine,
      List<String> bodyLines, int endIndex, String? doc) {
    final values = <UtsEnumValue>[];

    for (var j = 0; j < bodyLines.length; j++) {
      final bodyLine = bodyLines[j].trim();
      if (bodyLine.isEmpty || bodyLine == '}') continue;

      // case value1, value2, value3
      // case value1
      // case value = "rawValue"
      if (bodyLine.startsWith('case ')) {
        final casePart = bodyLine.substring(5).trim();

        // Handle comma-separated cases: case a, b, c
        final parts = casePart.split(',');
        for (final part in parts) {
          var p = part.trim();
          if (p.isEmpty) continue;

          String? rawValue;
          // Handle raw value: case name = "value"
          if (p.contains('=')) {
            final eqIdx = p.indexOf('=');
            rawValue = p.substring(eqIdx + 1).trim();
            // Strip quotes
            if (rawValue.startsWith('"') && rawValue.endsWith('"')) {
              rawValue = rawValue.substring(1, rawValue.length - 1);
            }
            p = p.substring(0, eqIdx).trim();
          }

          values.add(UtsEnumValue(
            name: p,
            rawValue: rawValue ?? p,
          ));
        }
      }
    }

    return _ParsedEnumResult(
      enumDef: UtsEnum(name: name, values: values, documentation: doc),
      endIndex: endIndex + 1,
    );
  }

  _ParsedEnumResult _parseSealedEnum(
      String name, List<String> bodyLines, int endIndex, String? doc) {
    final subclasses = <UtsClass>[];
    final subclassNames = <String>[];

    for (var j = 0; j < bodyLines.length; j++) {
      final bodyLine = bodyLines[j].trim();
      if (bodyLine.isEmpty || bodyLine == '}') continue;

      final caseDoc = _lookbackForDoc(bodyLines, j);

      if (bodyLine.startsWith('case ')) {
        final casePart = bodyLine.substring(5).trim();

        // case name(param: Type, param: Type)
        final caseMatch = RegExp(r'(\w+)\s*\(([^)]*)\)').firstMatch(casePart);
        if (caseMatch != null) {
          final caseName = caseMatch.group(1)!;
          final paramStr = caseMatch.group(2) ?? '';
          subclassNames.add(caseName);

          final fields = _parseEnumAssociatedValues(paramStr);
          subclasses.add(UtsClass(
            name: caseName,
            kind: UtsClassKind.dataClass,
            fields: fields,
            superclass: name,
            documentation: caseDoc,
          ));
        } else {
          // case name (no associated values in sealed enum)
          final simpleMatch = RegExp(r'(\w+)').firstMatch(casePart);
          if (simpleMatch != null) {
            final caseName = simpleMatch.group(1)!;
            subclassNames.add(caseName);
            subclasses.add(UtsClass(
              name: caseName,
              kind: UtsClassKind.concreteClass,
              superclass: name,
              documentation: caseDoc,
            ));
          }
        }
      }
    }

    return _ParsedEnumResult(
      sealedClass: UtsClass(
        name: name,
        kind: UtsClassKind.sealedClass,
        sealedSubclasses: subclassNames,
        documentation: doc,
      ),
      subclasses: subclasses,
      endIndex: endIndex + 1,
    );
  }

  List<UtsField> _parseEnumAssociatedValues(String paramStr) {
    final fields = <UtsField>[];
    for (final param in _splitParams(paramStr)) {
      final p = param.trim();
      if (p.isEmpty) continue;

      // name: Type
      final match = RegExp(r'(\w+)\s*:\s*(.+)').firstMatch(p);
      if (match != null) {
        final name = match.group(1)!;
        var typeStr = match.group(2)!.trim();
        final isNullable = typeStr.endsWith('?');
        if (isNullable) typeStr = typeStr.substring(0, typeStr.length - 1);

        fields.add(UtsField(
          name: name,
          type: _mapper.mapType(typeStr),
          nullable: isNullable,
        ));
      }
    }
    return fields;
  }

  _ParsedExtension? _parseExtension(List<String> lines, int startIndex) {
    final line = lines[startIndex].trim();
    final nameMatch = RegExp(r'extension\s+(\w+)').firstMatch(line);
    if (nameMatch == null) return null;

    final targetName = nameMatch.group(1)!;
    final interfaces = _parseInheritanceClause(line);
    final endIndex = _findBlockEnd(lines, startIndex);
    final bodyLines = lines.sublist(startIndex + 1, endIndex);

    final methods = <UtsMethod>[];
    final nestedEnums = <UtsEnum>[];
    final nestedClasses = <UtsClass>[];

    for (var j = 0; j < bodyLines.length; j++) {
      final rawBodyLine = bodyLines[j].trim();
      if (rawBodyLine.isEmpty ||
          rawBodyLine.startsWith('///') ||
          rawBodyLine.startsWith('/**') ||
          rawBodyLine.startsWith('*')) {
        continue;
      }

      final bodyLine = _stripAttributes(rawBodyLine);

      if (bodyLine.startsWith('private ') ||
          bodyLine.startsWith('fileprivate ')) {
        j = _skipBlockInBody(bodyLines, j);
        continue;
      }

      final memberDoc = _lookbackForDoc(bodyLines, j);

      // Nested enum
      if (_matchesEnum(bodyLine)) {
        final result = _parseEnum(bodyLines, j, memberDoc);
        if (result != null) {
          if (result.isSealedClass) {
            nestedClasses
                .add(_prefixClass(targetName, result.sealedClass!));
            for (final sub in result.subclasses) {
              nestedClasses.add(_prefixClass(targetName, sub));
            }
          } else {
            nestedEnums.add(_prefixEnum(targetName, result.enumDef!));
          }
          j = result.endIndex - 1;
          continue;
        }
      }

      // Nested struct
      if (_matchesStruct(bodyLine)) {
        final result = _parseStruct(bodyLines, j, memberDoc);
        if (result != null) {
          nestedClasses.add(_prefixClass(targetName, result.cls));
          nestedEnums.addAll(
              result.nestedEnums.map((e) => _prefixEnum(targetName, e)));
          nestedClasses.addAll(
              result.nestedClasses.map((c) => _prefixClass(targetName, c)));
          j = result.endIndex - 1;
          continue;
        }
      }

      // Nested class
      if (_matchesClass(bodyLine)) {
        final result = _parseClass(bodyLines, j, memberDoc);
        if (result != null) {
          nestedClasses.add(_prefixClass(targetName, result.cls));
          nestedEnums.addAll(
              result.nestedEnums.map((e) => _prefixEnum(targetName, e)));
          nestedClasses.addAll(
              result.nestedClasses.map((c) => _prefixClass(targetName, c)));
          j = result.endIndex - 1;
          continue;
        }
      }

      if (_matchesFunction(bodyLine)) {
        final sig = _collectFunctionSignature(bodyLines, j);
        final method = _parseFunction(sig.text, memberDoc);
        if (method != null) {
          methods.add(method);
        }
        j = sig.endIndex;
      }
    }

    return _ParsedExtension(
      targetName: targetName,
      methods: methods,
      nestedEnums: nestedEnums,
      nestedClasses: nestedClasses,
      interfaces: interfaces,
      endIndex: endIndex + 1,
    );
  }

  // ========== Function/Method Parsing ==========

  UtsMethod? _parseFunction(String line, String? doc) {
    final isStatic =
        line.contains('static func') || line.contains('class func');
    final isAsync = line.contains(' async');

    // Extract function name
    final nameMatch = RegExp(
            r'(?:public\s+|open\s+)?(?:static\s+|class\s+)?func\s+(\w+)\s*\(')
        .firstMatch(line);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;

    // Extract params using depth-tracking (handles nested parens in closures)
    final openParen = line.indexOf('(', nameMatch.start);
    if (openParen == -1) return null;
    final closeParen = _findMatchingParen(line, openParen);
    if (closeParen == -1) return null;

    final paramStr = line.substring(openParen + 1, closeParen);
    final afterParams = line.substring(closeParen + 1).trim();

    // Extract return type from what's after the closing paren
    // Pattern: [async] [throws] [-> ReturnType] [{]
    String? returnTypeStr;
    final arrowMatch =
        RegExp(r'(?:async\s+)?(?:throws\s+)?->\s*(.+?)(?:\s*\{|$)')
            .firstMatch(afterParams);
    if (arrowMatch != null) {
      returnTypeStr = arrowMatch.group(1)?.trim();
    }

    UtsType returnType;
    if (returnTypeStr == null || returnTypeStr.isEmpty) {
      returnType = UtsType.voidType();
    } else {
      returnType = _mapper.mapType(returnTypeStr);
    }

    // For async functions, wrap in Future if not already
    if (isAsync && returnType.kind != UtsTypeKind.future) {
      returnType = UtsType.future(returnType);
    }

    final parameters = _parseSwiftParams(paramStr);

    return UtsMethod(
      name: name,
      isStatic: isStatic,
      isAsync: isAsync ||
          returnType.kind == UtsTypeKind.future ||
          returnType.kind == UtsTypeKind.stream,
      parameters: parameters,
      returnType: returnType,
      documentation: doc,
    );
  }

  /// Parses a function declaration (without body — e.g., in protocols).
  UtsMethod? _parseFunctionDecl(String line, String? doc) {
    return _parseFunction(line, doc);
  }

  bool _matchesFunctionDecl(String line) {
    return RegExp(r'func\s+\w+').hasMatch(line);
  }

  List<UtsParameter> _parseSwiftParams(String paramStr) {
    final params = <UtsParameter>[];
    for (final param in _splitParams(paramStr)) {
      final p = param.trim();
      if (p.isEmpty) continue;

      // Swift parameter patterns:
      // name: Type
      // _ name: Type
      // label name: Type
      // name: Type = defaultValue
      // name: (Type) -> Type  (closure)

      // Check for closure type
      final closureMatch =
          RegExp(r'(?:(\w+)\s+)?(\w+)\s*:\s*(\(.*\)\s*->\s*.+)').firstMatch(p);
      if (closureMatch != null) {
        final name = closureMatch.group(2)!;
        final closureTypeStr = closureMatch.group(3)!;
        final closureType = _parseClosureType(closureTypeStr);
        final isNullable = closureTypeStr.endsWith('?');

        params.add(UtsParameter(
          name: name,
          type: isNullable ? closureType.asNullable() : closureType,
          isOptional: isNullable,
        ));
        continue;
      }

      // Regular parameter: [label] name: Type [= default]
      final regularMatch =
          RegExp(r'(?:(\w+)\s+)?(\w+)\s*:\s*(.+)').firstMatch(p);
      if (regularMatch != null) {
        final name = regularMatch.group(2)!;
        var rest = regularMatch.group(3)!.trim();

        // Check for default value
        String? defaultValue;
        final typeAndDefault = _splitTypeAndDefault(rest);
        rest = typeAndDefault.type;
        defaultValue = typeAndDefault.defaultValue;

        final isNullable = rest.endsWith('?');
        if (isNullable) rest = rest.substring(0, rest.length - 1);

        var type = _mapper.mapType(rest.trim());
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

  UtsType _parseClosureType(String closureStr) {
    // Parse: (Type, Type) -> ReturnType
    // or: ((Type, Type) -> ReturnType)?
    var str = closureStr.trim();

    // Handle optional closure
    if (str.endsWith('?')) {
      str = str.substring(0, str.length - 1).trim();
    }
    // Strip outer parens wrapping the whole closure type
    if (str.startsWith('(') && !str.startsWith('((')) {
      // Find the -> after the params
    }

    final arrowIdx = str.lastIndexOf('->');
    if (arrowIdx == -1) {
      return UtsType.callback(
        parameterTypes: [],
        returnType: UtsType.voidType(),
      );
    }

    final paramPart = str.substring(0, arrowIdx).trim();
    final returnPart = str.substring(arrowIdx + 2).trim();

    // Parse params from (Type, Type)
    var innerParams = paramPart;
    if (innerParams.startsWith('(') && innerParams.endsWith(')')) {
      innerParams = innerParams.substring(1, innerParams.length - 1);
    }

    final paramTypes = <UtsType>[];
    if (innerParams.isNotEmpty) {
      for (final pt in _splitParams(innerParams)) {
        final t = pt.trim();
        if (t.isNotEmpty) {
          paramTypes.add(_mapper.mapType(t));
        }
      }
    }

    final returnType = returnPart == 'Void' || returnPart.isEmpty
        ? UtsType.voidType()
        : _mapper.mapType(returnPart);

    return UtsType.callback(
      parameterTypes: paramTypes,
      returnType: returnType,
    );
  }

  // ========== Property Parsing ==========

  bool _matchesProperty(String line) {
    return RegExp(r'(?:public\s+|open\s+)?(?:static\s+)?(?:var|let)\s+\w+\s*:')
        .hasMatch(line);
  }

  bool _matchesProtocolProperty(String line) {
    return RegExp(r'var\s+\w+\s*:.*\{\s*get').hasMatch(line);
  }

  UtsField? _parseProperty(String line, String? doc) {
    final isReadOnly = line.contains('let ');
    final match = RegExp(
            r'(?:public\s+|open\s+)?(?:static\s+)?(?:var|let)\s+(\w+)\s*:\s*([^={\n]+)')
        .firstMatch(line);
    if (match == null) return null;

    final name = match.group(1)!;
    var typeStr = match.group(2)!.trim();
    final isNullable = typeStr.endsWith('?');
    if (isNullable) typeStr = typeStr.substring(0, typeStr.length - 1);

    return UtsField(
      name: name,
      type: _mapper.mapType(typeStr),
      nullable: isNullable,
      isReadOnly: isReadOnly,
      documentation: doc,
    );
  }

  UtsField? _parseProtocolProperty(String line, String? doc) {
    // var name: Type { get }  or  var name: Type { get set }
    final match =
        RegExp(r'var\s+(\w+)\s*:\s*([^{]+)\s*\{(.+)\}').firstMatch(line);
    if (match == null) return null;

    final name = match.group(1)!;
    var typeStr = match.group(2)!.trim();
    final accessors = match.group(3)!.trim();
    final isReadOnly = !accessors.contains('set');
    final isNullable = typeStr.endsWith('?');
    if (isNullable) typeStr = typeStr.substring(0, typeStr.length - 1);

    return UtsField(
      name: name,
      type: _mapper.mapType(typeStr),
      nullable: isNullable,
      isReadOnly: isReadOnly,
      documentation: doc,
    );
  }

  // ========== Common Helpers ==========

  /// Strips leading Swift attributes like @discardableResult, @available(...).
  String _stripAttributes(String line) {
    var result = line;
    while (result.startsWith('@')) {
      final parenIdx = result.indexOf('(');
      final spaceIdx = result.indexOf(' ');

      if (parenIdx >= 0 && (spaceIdx < 0 || parenIdx < spaceIdx)) {
        final closeIdx = _findMatchingParen(result, parenIdx);
        if (closeIdx >= 0) {
          result = result.substring(closeIdx + 1).trim();
        } else {
          break;
        }
      } else if (spaceIdx >= 0) {
        result = result.substring(spaceIdx + 1).trim();
      } else {
        break;
      }
    }
    return result;
  }

  /// Finds the closing parenthesis matching the opening one at [openPos].
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

  /// Collects a function signature that may span multiple lines.
  /// Returns the joined text and the last line index.
  _CollectedSignature _collectFunctionSignature(
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

      // Parens are balanced — check if we have a complete signature
      if (line.contains('{')) break;

      final currentText = buffer.toString();
      if (currentText.contains('->')) break;

      // Peek at next line for continuation (return type, throws, async, {)
      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        if (nextLine.isEmpty ||
            (!nextLine.startsWith('->') &&
                !nextLine.startsWith('async') &&
                !nextLine.startsWith('throws') &&
                !nextLine.startsWith('{'))) {
          break;
        }
      } else {
        break;
      }
    }

    return _CollectedSignature(text: buffer.toString(), endIndex: lastIndex);
  }

  _TypeAndDefault _splitTypeAndDefault(String input) {
    var depth = 0;
    for (var i = 0; i < input.length; i++) {
      switch (input[i]) {
        case '<':
        case '(':
          depth++;
          break;
        case '>':
        case ')':
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

  int _findBlockEnd(List<String> lines, int startIndex) {
    var depth = 0;
    var foundOpen = false;

    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      var inString = false;

      for (var j = 0; j < line.length; j++) {
        final ch = line[j];

        // Skip line comments
        if (!inString &&
            ch == '/' &&
            j + 1 < line.length &&
            line[j + 1] == '/') {
          break;
        }

        // Toggle string tracking (skip escaped quotes)
        if (ch == '"' && (j == 0 || line[j - 1] != '\\')) {
          inString = !inString;
          continue;
        }

        if (inString) continue;

        if (ch == '{') {
          depth++;
          foundOpen = true;
        } else if (ch == '}') {
          depth--;
          if (foundOpen && depth == 0) {
            // Ensure callers can safely do sublist(startIndex + 1, result)
            return i < startIndex + 1 ? startIndex + 1 : i;
          }
        }
      }
    }
    return lines.length - 1;
  }

  int _skipBlock(List<String> lines, int startIndex) {
    final line = lines[startIndex].trim();
    if (line.contains('{')) {
      return _findBlockEnd(lines, startIndex) + 1;
    }
    return startIndex + 1;
  }

  int _skipBlockInBody(List<String> bodyLines, int startIndex) {
    final line = bodyLines[startIndex].trim();
    if (line.contains('{')) {
      var depth = 0;
      var foundOpen = false;
      for (var i = startIndex; i < bodyLines.length; i++) {
        final bodyLine = bodyLines[i];
        var inString = false;

        for (var j = 0; j < bodyLine.length; j++) {
          final ch = bodyLine[j];

          if (!inString &&
              ch == '/' &&
              j + 1 < bodyLine.length &&
              bodyLine[j + 1] == '/') {
            break;
          }

          if (ch == '"' && (j == 0 || bodyLine[j - 1] != '\\')) {
            inString = !inString;
            continue;
          }

          if (inString) continue;

          if (ch == '{') {
            depth++;
            foundOpen = true;
          } else if (ch == '}') {
            depth--;
            if (foundOpen && depth == 0) return i;
          }
        }
      }
    }
    return startIndex;
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

  // ========== Documentation ==========

  String? _lookbackForDoc(List<String> lines, int index) {
    var i = index - 1;

    // Collect consecutive /// lines
    final tripleSlashLines = <String>[];
    while (i >= 0) {
      final line = lines[i].trim();
      if (line.startsWith('///')) {
        tripleSlashLines.insert(0, line.substring(3).trim());
        i--;
      } else {
        break;
      }
    }
    if (tripleSlashLines.isNotEmpty) {
      return tripleSlashLines.join('\n').trim();
    }

    // Look for /** ... */ block
    i = index - 1;
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
        var cleaned = first;
        if (cleaned.endsWith('*/')) {
          cleaned = cleaned.substring(0, cleaned.length - 2).trim();
        }
        if (cleaned.isNotEmpty && !cleaned.startsWith('*')) {
          docLines.insert(0, cleaned);
        }
        break;
      }
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

    return docLines.isEmpty ? null : docLines.join('\n').trim();
  }

  _DocResult _collectDocBlock(List<String> lines, int index) {
    final line = lines[index].trim();
    if (!line.startsWith('/**')) return _DocResult(null, index);

    for (var i = index; i < lines.length; i++) {
      if (lines[i].contains('*/')) {
        return _DocResult(null, i + 1);
      }
    }
    return _DocResult(null, index);
  }

  // ========== Inheritance Parsing ==========

  /// Extracts protocol/superclass names from a Swift declaration's
  /// inheritance clause (e.g., `class Foo: Bar, Baz {` → `['Bar', 'Baz']`).
  List<String> _parseInheritanceClause(String line) {
    final braceIdx = line.indexOf('{');
    final searchEnd = braceIdx != -1 ? braceIdx : line.length;

    // Find the `:` that's outside `<>` angle brackets
    var depth = 0;
    var colonIdx = -1;
    for (var i = 0; i < searchEnd; i++) {
      switch (line[i]) {
        case '<':
          depth++;
          break;
        case '>':
          depth--;
          break;
        case ':':
          if (depth == 0) {
            colonIdx = i;
          }
          break;
      }
      if (colonIdx != -1) break;
    }

    if (colonIdx == -1) return [];
    var clause = line.substring(colonIdx + 1, searchEnd).trim();

    // Strip `where` clause if present
    final whereIdx = clause.indexOf(' where ');
    if (whereIdx != -1) {
      clause = clause.substring(0, whereIdx);
    }

    return clause
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ========== Nested Type Helpers ==========

  /// Prefixes an enum name with its parent type name (e.g., SHA2 + Variant → SHA2Variant).
  UtsEnum _prefixEnum(String parent, UtsEnum e) {
    final flatName = '$parent${e.name}';
    final dotName = '$parent.${e.name}';
    return UtsEnum(
      name: flatName,
      nativeName: dotName,
      values: e.values,
      documentation: e.documentation,
    );
  }

  /// Prefixes a class name with its parent type name (e.g., SHA2 + Variant → SHA2Variant).
  UtsClass _prefixClass(String parent, UtsClass c) {
    final flatName = '$parent${c.name}';
    final dotName = '$parent.${c.name}';
    return UtsClass(
      name: flatName,
      nativeName: dotName,
      kind: c.kind,
      fields: c.fields,
      methods: c.methods,
      superclass: c.superclass != null ? '$parent${c.superclass}' : null,
      interfaces: c.interfaces,
      sealedSubclasses: c.sealedSubclasses.map((s) => '$parent$s').toList(),
      documentation: c.documentation,
      constructorParameters: c.constructorParameters,
      constructorThrows: c.constructorThrows,
    );
  }

  // ========== Dotted Type Resolution ==========

  /// Resolves dotted type references (e.g., `SHA2.Variant` → `SHA2Variant`)
  /// throughout the schema, updating type kinds when the target is found.
  UnifiedTypeSchema _resolveNestedTypeRefs(UnifiedTypeSchema schema) {
    final enumNames = schema.enums.map((e) => e.name).toSet();
    final classNames = schema.classes.map((c) => c.name).toSet();
    final typeNames = schema.types.map((t) => t.name).toSet();

    // --- Step 1: Promote sealed classes → enum when subclasses are undefined ---
    final promotedEnums = <UtsEnum>[];
    final classesToRemove = <String>{};
    for (final cls in schema.classes) {
      if (cls.kind == UtsClassKind.sealedClass &&
          cls.sealedSubclasses.isNotEmpty) {
        final allUndefined = cls.sealedSubclasses.every((sub) =>
            !classNames.contains(sub) &&
            !typeNames.contains(sub) &&
            !enumNames.contains(sub));
        if (allUndefined) {
          promotedEnums.add(UtsEnum(
            name: cls.name,
            nativeName: cls.nativeName,
            values:
                cls.sealedSubclasses.map((s) => UtsEnumValue(name: s)).toList(),
            documentation: cls.documentation,
          ));
          classesToRemove.add(cls.name);
          enumNames.add(cls.name);
        }
      }
    }

    final updatedClasses =
        schema.classes.where((c) => !classesToRemove.contains(c.name)).toList();
    final updatedEnums = [...schema.enums, ...promotedEnums];

    // --- Step 2: Resolve dotted type references ---
    UtsType resolveType(UtsType type) {
      if (type.kind == UtsTypeKind.object && type.name.contains('.')) {
        final originalName = type.name; // e.g., 'SHA2.Variant'
        final joined = type.name.split('.').join(); // e.g., 'SHA2Variant'
        if (enumNames.contains(joined)) {
          return UtsType(
            kind: UtsTypeKind.enumType,
            name: joined,
            nullable: type.nullable,
            ref: joined,
            nativeName: originalName,
          );
        }
        if (classNames.contains(joined) || typeNames.contains(joined)) {
          return UtsType(
            kind: type.kind,
            name: joined,
            nullable: type.nullable,
            typeArguments: type.typeArguments,
            nativeName: originalName,
          );
        }
      }
      // Also resolve enum references that aren't dotted (e.g., after promotion)
      if (type.kind == UtsTypeKind.object && enumNames.contains(type.name)) {
        return UtsType(
          kind: UtsTypeKind.enumType,
          name: type.name,
          nullable: type.nullable,
          ref: type.name,
          nativeName: type.nativeName,
        );
      }
      // Recurse into type arguments
      if (type.typeArguments != null && type.typeArguments!.isNotEmpty) {
        final resolved = type.typeArguments!.map(resolveType).toList();
        if (_typeArgsChanged(type.typeArguments!, resolved)) {
          return UtsType(
            kind: type.kind,
            name: type.name,
            nullable: type.nullable,
            typeArguments: resolved,
            returnType: type.returnType,
            parameterTypes: type.parameterTypes,
            nativeName: type.nativeName,
          );
        }
      }
      return type;
    }

    UtsField resolveField(UtsField f) {
      final resolved = resolveType(f.type);
      if (identical(resolved, f.type)) return f;
      return UtsField(
        name: f.name,
        type: resolved,
        nullable: f.nullable,
        isReadOnly: f.isReadOnly,
        defaultValue: f.defaultValue,
        documentation: f.documentation,
      );
    }

    UtsParameter resolveParam(UtsParameter p) {
      final resolved = resolveType(p.type);
      if (identical(resolved, p.type)) return p;
      return UtsParameter(
        name: p.name,
        type: resolved,
        isOptional: p.isOptional,
        isNamed: p.isNamed,
        defaultValue: p.defaultValue,
        documentation: p.documentation,
        nativeLabel: p.nativeLabel,
        nativeType: p.nativeType,
      );
    }

    UtsMethod resolveMethod(UtsMethod m) {
      final resolvedReturn = resolveType(m.returnType);
      final resolvedParams = m.parameters.map(resolveParam).toList();
      return UtsMethod(
        name: m.name,
        isStatic: m.isStatic,
        isAsync: m.isAsync,
        parameters: resolvedParams,
        returnType: resolvedReturn,
        documentation: m.documentation,
        nativeBody: m.nativeBody,
      );
    }

    UtsClass resolveClass(UtsClass c) {
      return UtsClass(
        name: c.name,
        nativeName: c.nativeName,
        kind: c.kind,
        fields: c.fields.map(resolveField).toList(),
        methods: c.methods.map(resolveMethod).toList(),
        superclass: c.superclass,
        interfaces: c.interfaces,
        sealedSubclasses: c.sealedSubclasses,
        documentation: c.documentation,
        constructorParameters:
            c.constructorParameters?.map(resolveParam).toList(),
        constructorThrows: c.constructorThrows,
      );
    }

    // --- Step 3: Also set nativeName on enum/class definitions for nested types ---
    final resolvedEnums = updatedEnums.map((e) {
      // If this enum was originally a nested type (name was flattened),
      // check if any promoted enum already has nativeName set
      return e;
    }).toList();

    return UnifiedTypeSchema(
      package: schema.package,
      source: schema.source,
      version: schema.version,
      classes: updatedClasses.map(resolveClass).toList(),
      functions: schema.functions.map(resolveMethod).toList(),
      types: schema.types.map(resolveClass).toList(),
      enums: resolvedEnums,
      nativeImports: schema.nativeImports,
      nativeFields: schema.nativeFields,
    );
  }

  bool _typeArgsChanged(List<UtsType> original, List<UtsType> resolved) {
    for (var i = 0; i < original.length; i++) {
      if (!identical(original[i], resolved[i])) return true;
    }
    return false;
  }
}

// ========== Internal Helper Classes ==========

class _ParsedClass {
  final UtsClass cls;
  final int endIndex;
  final List<UtsEnum> nestedEnums;
  final List<UtsClass> nestedClasses;
  _ParsedClass({
    required this.cls,
    required this.endIndex,
    this.nestedEnums = const [],
    this.nestedClasses = const [],
  });
}

class _ParsedEnumResult {
  final UtsEnum? enumDef;
  final UtsClass? sealedClass;
  final List<UtsClass> subclasses;
  final int endIndex;

  bool get isSealedClass => sealedClass != null;

  _ParsedEnumResult({
    this.enumDef,
    this.sealedClass,
    this.subclasses = const [],
    required this.endIndex,
  });
}

class _ParsedExtension {
  final String targetName;
  final List<UtsMethod> methods;
  final List<UtsEnum> nestedEnums;
  final List<UtsClass> nestedClasses;
  final List<String> interfaces;
  final int endIndex;
  _ParsedExtension({
    required this.targetName,
    required this.methods,
    this.nestedEnums = const [],
    this.nestedClasses = const [],
    this.interfaces = const [],
    required this.endIndex,
  });
}

class _DocResult {
  final String? doc;
  final int endIndex;
  _DocResult(this.doc, this.endIndex);
}

class _CollectedSignature {
  final String text;
  final int endIndex;
  _CollectedSignature({required this.text, required this.endIndex});
}

class _TypeAndDefault {
  final String type;
  final String? defaultValue;
  _TypeAndDefault({required this.type, this.defaultValue});
}
