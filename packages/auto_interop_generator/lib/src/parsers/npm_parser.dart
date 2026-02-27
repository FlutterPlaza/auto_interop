import '../schema/unified_type_schema.dart';
import '../type_mapping/js_to_dart.dart';
import 'parser_base.dart';

/// Parses TypeScript declaration files (.d.ts) into a [UnifiedTypeSchema].
///
/// Handles:
/// - Exported function declarations
/// - Class declarations with methods and properties
/// - Interface declarations (→ data classes)
/// - Type aliases (→ data classes)
/// - Enum declarations (string and numeric)
/// - Generic types
/// - Optional parameters
/// - Async types (Promise, ReadableStream)
/// - Callback/function types
/// - Filtering of private APIs (underscore prefix)
class NpmParser extends ParserBase {
  final JsToDartMapper _typeMapper = JsToDartMapper();
  final List<ParseWarning> _warnings = [];

  @override
  ParseResult parseWithValidation({
    required String content,
    required String packageName,
    required String version,
  }) {
    _warnings.clear();
    final schema = parse(
      content: content,
      packageName: packageName,
      version: version,
    );
    final baseResult = validateResult(schema);
    return ParseResult(schema,
        warnings: [...baseResult.warnings, ..._warnings]);
  }

  @override
  PackageSource get source => PackageSource.npm;

  @override
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  }) {
    final functions = <UtsMethod>[];
    final classes = <UtsClass>[];
    final types = <UtsClass>[];
    final enums = <UtsEnum>[];

    final lines = content.split('\n');
    var i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      // Skip empty lines and comments
      if (line.isEmpty || line.startsWith('//')) {
        i++;
        continue;
      }

      // Collect JSDoc comment
      String? documentation;
      if (line.startsWith('/**')) {
        final docResult = _parseJsDoc(lines, i);
        documentation = docResult.doc;
        i = docResult.endIndex;
        continue;
      }

      // Store doc for next declaration
      if (i > 0) {
        documentation = _lookbackForDoc(lines, i);
      }

      // Exported function
      if (_isExportedFunction(line)) {
        final fn = _parseFunction(lines, i, documentation);
        if (fn != null && !_isPrivate(fn.method.name)) {
          functions.add(fn.method);
          i = fn.endIndex;
          continue;
        }
      }

      // Exported class
      if (_isExportedClass(line)) {
        final cls = _parseClass(lines, i, documentation);
        if (cls != null) {
          classes.add(cls.cls);
          i = cls.endIndex;
          continue;
        }
      }

      // Exported interface
      if (_isExportedInterface(line)) {
        final iface = _parseInterface(lines, i, documentation);
        if (iface != null) {
          types.add(iface.cls);
          i = iface.endIndex;
          continue;
        }
      }

      // Exported type alias
      if (_isExportedTypeAlias(line)) {
        final typeAlias = _parseTypeAlias(lines, i, documentation);
        if (typeAlias != null) {
          types.add(typeAlias.cls);
          i = typeAlias.endIndex;
          continue;
        }
      }

      // Exported enum
      if (_isExportedEnum(line)) {
        final enumDef = _parseEnum(lines, i, documentation);
        if (enumDef != null) {
          enums.add(enumDef.enumDef);
          i = enumDef.endIndex;
          continue;
        }
      }

      i++;
    }

    return UnifiedTypeSchema(
      package: packageName,
      source: PackageSource.npm,
      version: version,
      classes: classes,
      functions: functions,
      types: types,
      enums: enums,
    );
  }

  // --- Detection ---

  bool _isExportedFunction(String line) =>
      line.startsWith('export declare function ') ||
      line.startsWith('export function ') ||
      line.startsWith('export default function ');

  bool _isExportedClass(String line) =>
      line.startsWith('export declare class ') ||
      line.startsWith('export class ') ||
      line.startsWith('export default class ');

  bool _isExportedInterface(String line) =>
      line.startsWith('export interface ') ||
      line.startsWith('export default interface ') ||
      line.startsWith('export declare interface ');

  bool _isExportedTypeAlias(String line) =>
      line.startsWith('export type ') ||
      line.startsWith('export default type ');

  bool _isExportedEnum(String line) =>
      line.startsWith('export declare enum ') ||
      line.startsWith('export enum ') ||
      line.startsWith('export default enum ');

  bool _isPrivate(String name) =>
      name.startsWith('_');

  // --- Function parsing ---

  _ParsedMethod? _parseFunction(
      List<String> lines, int startIndex, String? documentation) {
    // Collect full declaration (may span multiple lines)
    final fullDecl = _collectDeclaration(lines, startIndex);
    final line = fullDecl.text;
    final endIndex = fullDecl.endIndex;

    // Extract function name (with optional generics)
    final nameMatch = RegExp(
      r'export\s+(?:declare\s+|default\s+)?function\s+(\w+)(?:<[^>]*>)?\s*\(',
    ).firstMatch(line);

    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;

    // Find the matching closing paren for the parameter list
    final paramsStart = nameMatch.end - 1; // index of '('
    final paramsEnd = _findMatchingParen(line, paramsStart);
    if (paramsEnd < 0) return null;

    final paramsStr = line.substring(paramsStart + 1, paramsEnd);

    // Extract return type: everything after "): " until ";"
    final afterParams = line.substring(paramsEnd + 1).trim();
    final colonMatch = RegExp(r'^:\s*(.+?)\s*;?\s*$').firstMatch(afterParams);
    if (colonMatch == null) return null;

    final returnTypeStr = colonMatch.group(1)!;

    final parameters = _parseParameters(paramsStr);
    final returnType = _mapTsType(returnTypeStr);

    return _ParsedMethod(
      method: UtsMethod(
        name: name,
        isStatic: true,
        isAsync: returnTypeStr.startsWith('Promise<'),
        parameters: parameters,
        returnType: returnType,
        documentation: documentation,
      ),
      endIndex: endIndex,
    );
  }

  /// Finds the matching closing parenthesis for an opening one at [start].
  int _findMatchingParen(String text, int start) {
    var depth = 0;
    for (var i = start; i < text.length; i++) {
      if (text[i] == '(') depth++;
      if (text[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Parses a class/interface/type-alias method member using depth-tracking.
  /// Handles: `name<T>(params): ReturnType;` and optionally
  /// `name(params) => ReturnType;` when [allowArrow] is true.
  UtsMethod? _parseMethodMember(String memberLine, String? documentation,
      {bool allowArrow = false}) {
    // Extract method name
    final nameMatch = RegExp(r'^(\w+)').firstMatch(memberLine);
    if (nameMatch == null) return null;

    final methodName = nameMatch.group(1)!;

    // Find the opening paren at angle-bracket depth 0
    var openParen = -1;
    var angleDepth = 0;
    for (var i = nameMatch.end; i < memberLine.length; i++) {
      if (memberLine[i] == '<') {
        angleDepth++;
      } else if (memberLine[i] == '>') {
        angleDepth--;
      } else if (memberLine[i] == '(' && angleDepth == 0) {
        openParen = i;
        break;
      }
    }
    if (openParen < 0) return null;

    final closeParen = _findMatchingParen(memberLine, openParen);
    if (closeParen < 0) return null;

    final paramsStr = memberLine.substring(openParen + 1, closeParen);
    final afterParen = memberLine.substring(closeParen + 1).trim();

    // Extract return type: ": Type;" or "=> Type;"
    String? returnTypeStr;
    final colonMatch = RegExp(r'^:\s*(.+?)\s*;?\s*$').firstMatch(afterParen);
    if (colonMatch != null) {
      returnTypeStr = colonMatch.group(1)!;
    } else if (allowArrow) {
      final arrowMatch =
          RegExp(r'^=>\s*(.+?)\s*;?\s*$').firstMatch(afterParen);
      if (arrowMatch != null) {
        returnTypeStr = arrowMatch.group(1)!.replaceAll(';', '');
      }
    }
    if (returnTypeStr == null) return null;

    return UtsMethod(
      name: methodName,
      isAsync: returnTypeStr.startsWith('Promise<'),
      parameters: _parseParameters(paramsStr),
      returnType: _mapTsType(returnTypeStr),
      documentation: documentation,
    );
  }

  // --- Class parsing ---

  _ParsedClass? _parseClass(
      List<String> lines, int startIndex, String? documentation) {
    final headerLine = lines[startIndex].trim();

    // Extract class name
    final nameMatch = RegExp(
      r'export\s+(?:declare\s+|default\s+)?class\s+(\w+)',
    ).firstMatch(headerLine);
    if (nameMatch == null) return null;

    final className = nameMatch.group(1)!;
    final blockEnd = _findBlockEnd(lines, startIndex);
    final methods = <UtsMethod>[];
    final fields = <UtsField>[];

    String? memberDoc;
    for (var i = startIndex + 1; i < blockEnd; i++) {
      final memberLine = lines[i].trim();
      if (memberLine.isEmpty || memberLine == '}') continue;

      // Collect member doc
      if (memberLine.startsWith('/**')) {
        final docResult = _parseJsDoc(lines, i);
        memberDoc = docResult.doc;
        i = docResult.endIndex - 1; // -1 because loop will increment
        continue;
      }

      // Skip constructor
      if (memberLine.startsWith('constructor')) {
        memberDoc = null;
        continue;
      }

      // Parse method using depth-tracking
      final method = _parseMethodMember(memberLine, memberDoc);
      if (method != null) {
        if (!_isPrivate(method.name)) {
          methods.add(method);
        }
        memberDoc = null;
        continue;
      }

      // Parse property: name: type;
      final propMatch = RegExp(
        r'(?:readonly\s+)?(\w+)(\??)\s*:\s*(.+?)\s*;',
      ).firstMatch(memberLine);

      if (propMatch != null) {
        final propName = propMatch.group(1)!;
        if (!_isPrivate(propName)) {
          final isOptional = propMatch.group(2) == '?';
          fields.add(UtsField(
            name: propName,
            type: _mapTsType(propMatch.group(3)!),
            nullable: isOptional,
            isReadOnly: memberLine.startsWith('readonly'),
            documentation: memberDoc,
          ));
        }
        memberDoc = null;
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: className,
        kind: UtsClassKind.concreteClass,
        methods: methods,
        fields: fields,
        documentation: documentation,
      ),
      endIndex: blockEnd + 1,
    );
  }

  // --- Interface parsing ---

  _ParsedClass? _parseInterface(
      List<String> lines, int startIndex, String? documentation) {
    final headerLine = lines[startIndex].trim();

    final nameMatch = RegExp(
      r'export\s+(?:default\s+|declare\s+)?interface\s+(\w+)(?:<[^>]*>)?',
    ).firstMatch(headerLine);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final blockEnd = _findBlockEnd(lines, startIndex);
    final fields = <UtsField>[];
    final methods = <UtsMethod>[];

    String? memberDoc;
    for (var i = startIndex + 1; i < blockEnd; i++) {
      final memberLine = lines[i].trim();
      if (memberLine.isEmpty || memberLine == '}') continue;

      if (memberLine.startsWith('/**')) {
        final docResult = _parseJsDoc(lines, i);
        memberDoc = docResult.doc;
        i = docResult.endIndex - 1;
        continue;
      }

      // Method signature using depth-tracking
      final method = _parseMethodMember(memberLine, memberDoc);
      if (method != null) {
        methods.add(method);
        memberDoc = null;
        continue;
      }

      // Property: name?: type;
      final propMatch = RegExp(
        r'(?:readonly\s+)?(\w+)(\??)\s*:\s*(.+?)\s*;',
      ).firstMatch(memberLine);

      if (propMatch != null) {
        final isOptional = propMatch.group(2) == '?';
        fields.add(UtsField(
          name: propMatch.group(1)!,
          type: _mapTsType(propMatch.group(3)!),
          nullable: isOptional,
          isReadOnly: memberLine.startsWith('readonly'),
          documentation: memberDoc,
        ));
        memberDoc = null;
      }
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: methods.isEmpty ? UtsClassKind.dataClass : UtsClassKind.concreteClass,
        fields: fields,
        methods: methods,
        documentation: documentation,
      ),
      endIndex: blockEnd + 1,
    );
  }

  // --- Type alias parsing ---

  _ParsedClass? _parseTypeAlias(
      List<String> lines, int startIndex, String? documentation) {
    final headerLine = lines[startIndex].trim();

    // Check if it's a type alias with object body: export type Foo = { ... };
    final nameMatch = RegExp(
      r'export\s+(?:default\s+)?type\s+(\w+)(?:<[^>]*>)?\s*=\s*\{',
    ).firstMatch(headerLine);

    if (nameMatch == null) {
      // Simple type alias (single line) — skip for now
      return _ParsedClass(
        cls: UtsClass(name: 'SKIP', kind: UtsClassKind.dataClass),
        endIndex: startIndex + 1,
      );
    }

    final name = nameMatch.group(1)!;
    final blockEnd = _findBlockEnd(lines, startIndex);
    final fields = <UtsField>[];
    final methods = <UtsMethod>[];

    String? memberDoc;
    for (var i = startIndex + 1; i < blockEnd; i++) {
      final memberLine = lines[i].trim();
      if (memberLine.isEmpty || memberLine == '};' || memberLine == '}') continue;

      if (memberLine.startsWith('/**')) {
        final docResult = _parseJsDoc(lines, i);
        memberDoc = docResult.doc;
        i = docResult.endIndex - 1;
        continue;
      }

      // Method signature using depth-tracking
      final methodResult = _parseMethodMember(memberLine, memberDoc,
          allowArrow: true);
      if (methodResult != null) {
        methods.add(methodResult);
        memberDoc = null;
        continue;
      }

      // Property
      final propMatch = RegExp(
        r'(\w+)(\??)\s*:\s*(.+?)\s*;?$',
      ).firstMatch(memberLine);

      if (propMatch != null) {
        final propType = propMatch.group(3)!.replaceAll(';', '').trim();
        // Check if this is a function type: (params) => returnType
        final fnMatch = RegExp(
          r'^\(([^)]*)\)\s*=>\s*(.+)$',
        ).firstMatch(propType);

        if (fnMatch != null) {
          // It's a method-like property with function type
          methods.add(UtsMethod(
            name: propMatch.group(1)!,
            parameters: _parseParameters(fnMatch.group(1)!),
            returnType: _mapTsType(fnMatch.group(2)!),
            documentation: memberDoc,
          ));
        } else {
          fields.add(UtsField(
            name: propMatch.group(1)!,
            type: _mapTsType(propType),
            nullable: propMatch.group(2) == '?',
            documentation: memberDoc,
          ));
        }
        memberDoc = null;
      }
    }

    // Skip dummy entries
    if (name == 'SKIP') {
      return _ParsedClass(
        cls: UtsClass(name: name, kind: UtsClassKind.dataClass),
        endIndex: blockEnd + 1,
      );
    }

    return _ParsedClass(
      cls: UtsClass(
        name: name,
        kind: methods.isEmpty ? UtsClassKind.dataClass : UtsClassKind.concreteClass,
        fields: fields,
        methods: methods,
        documentation: documentation,
      ),
      endIndex: blockEnd + 1,
    );
  }

  // --- Enum parsing ---

  _ParsedEnum? _parseEnum(
      List<String> lines, int startIndex, String? documentation) {
    final headerLine = lines[startIndex].trim();

    final nameMatch = RegExp(
      r'export\s+(?:declare\s+|default\s+)?enum\s+(\w+)',
    ).firstMatch(headerLine);
    if (nameMatch == null) return null;

    final name = nameMatch.group(1)!;
    final blockEnd = _findBlockEnd(lines, startIndex);
    final values = <UtsEnumValue>[];

    for (var i = startIndex + 1; i < blockEnd; i++) {
      final memberLine = lines[i].trim();
      if (memberLine.isEmpty || memberLine == '}') continue;

      // Pattern: Name = "value", or Name = 123,
      final valueMatch = RegExp(
        r'(\w+)\s*=\s*(?:"([^"]+)"|(\d+))\s*,?',
      ).firstMatch(memberLine);

      if (valueMatch != null) {
        final valueName = valueMatch.group(1)!;
        final stringVal = valueMatch.group(2);
        final numVal = valueMatch.group(3);
        values.add(UtsEnumValue(
          name: _toCamelCase(valueName),
          rawValue: stringVal ?? (numVal != null ? int.parse(numVal) : null),
        ));
      }
    }

    return _ParsedEnum(
      enumDef: UtsEnum(
        name: name,
        values: values,
        documentation: documentation,
      ),
      endIndex: blockEnd + 1,
    );
  }

  // --- Parameter parsing ---

  List<UtsParameter> _parseParameters(String paramsStr) {
    final params = <UtsParameter>[];
    if (paramsStr.trim().isEmpty) return params;

    final parts = _splitParams(paramsStr);

    for (final part in parts) {
      final p = part.trim();
      if (p.isEmpty) continue;

      // Warn and skip rest params (...args: any[])
      if (p.startsWith('...')) {
        _warnings.add(ParseWarning(
          'Rest parameter "$p" skipped — not supported.',
          suggestion:
              'Consider using a fixed-arity overload or providing '
              'a manual type definition.',
        ));
        continue;
      }

      // Pattern: name?: type or name: type
      final match = RegExp(
        r'^(\w+)(\??):\s*(.+)$',
      ).firstMatch(p);

      if (match != null) {
        final name = match.group(1)!;
        final isOptional = match.group(2) == '?';
        var typeStr = match.group(3)!.trim();

        // Handle inline object types: { ... }
        if (typeStr.startsWith('{')) {
          params.add(UtsParameter(
            name: name,
            type: UtsType.dynamicType(),
            isOptional: isOptional,
            isNamed: isOptional,
          ));
          continue;
        }

        // Handle callback types: (x: T) => R
        final callbackMatch = RegExp(
          r'^\(([^)]*)\)\s*=>\s*(.+)$',
        ).firstMatch(typeStr);

        if (callbackMatch != null) {
          final callbackParams = _parseCallbackParamTypes(callbackMatch.group(1)!);
          final callbackReturn = _mapTsType(callbackMatch.group(2)!);
          params.add(UtsParameter(
            name: name,
            type: UtsType.callback(
              parameterTypes: callbackParams,
              returnType: callbackReturn,
            ),
            isOptional: isOptional,
            isNamed: isOptional,
          ));
          continue;
        }

        params.add(UtsParameter(
          name: name,
          type: _mapTsType(typeStr),
          isOptional: isOptional,
          isNamed: isOptional,
        ));
      }
    }

    return params;
  }

  /// Parses callback parameter types (just types, possibly with names).
  List<UtsType> _parseCallbackParamTypes(String paramsStr) {
    if (paramsStr.trim().isEmpty) return [];
    final parts = _splitParams(paramsStr);
    final types = <UtsType>[];
    for (final part in parts) {
      final p = part.trim();
      if (p.isEmpty) continue;
      // Either "name: type" or just "type"
      final colonIdx = p.indexOf(':');
      if (colonIdx >= 0) {
        types.add(_mapTsType(p.substring(colonIdx + 1).trim()));
      } else {
        types.add(_mapTsType(p));
      }
    }
    return types;
  }

  /// Splits parameter list by commas, respecting nested generics and callbacks.
  List<String> _splitParams(String params) {
    final result = <String>[];
    var depth = 0;
    var parenDepth = 0;
    var braceDepth = 0;
    var start = 0;

    for (var i = 0; i < params.length; i++) {
      switch (params[i]) {
        case '<':
          depth++;
          break;
        case '>':
          depth--;
          break;
        case '(':
          parenDepth++;
          break;
        case ')':
          parenDepth--;
          break;
        case '{':
          braceDepth++;
          break;
        case '}':
          braceDepth--;
          break;
        case ',':
          if (depth == 0 && parenDepth == 0 && braceDepth == 0) {
            result.add(params.substring(start, i));
            start = i + 1;
          }
          break;
      }
    }
    result.add(params.substring(start));
    return result;
  }

  // --- Type mapping ---

  UtsType _mapTsType(String tsType) {
    return _typeMapper.mapType(tsType.trim());
  }

  // --- Helper methods ---

  /// Collects a declaration that may span multiple lines until a semicolon.
  _CollectedDeclaration _collectDeclaration(List<String> lines, int start) {
    final buffer = StringBuffer();
    var i = start;
    while (i < lines.length) {
      final line = lines[i].trim();
      buffer.write(line);
      if (line.endsWith(';')) {
        return _CollectedDeclaration(
          text: buffer.toString(),
          endIndex: i + 1,
        );
      }
      buffer.write(' ');
      i++;
    }
    return _CollectedDeclaration(text: buffer.toString(), endIndex: i);
  }

  /// Finds the closing brace of a block starting at [startIndex].
  int _findBlockEnd(List<String> lines, int startIndex) {
    var depth = 0;
    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      for (final ch in line.runes) {
        if (ch == '{'.codeUnitAt(0)) depth++;
        if (ch == '}'.codeUnitAt(0)) depth--;
        if (depth == 0 && i > startIndex) return i;
      }
    }
    return lines.length - 1;
  }

  /// Parses a JSDoc block comment.
  _DocResult _parseJsDoc(List<String> lines, int startIndex) {
    final buffer = StringBuffer();
    var i = startIndex;

    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.startsWith('/**') && line.endsWith('*/')) {
        // Single-line doc: /** text */
        final text = line
            .replaceFirst('/**', '')
            .replaceFirst('*/', '')
            .trim();
        if (text.isNotEmpty) buffer.write(text);
        return _DocResult(
          doc: buffer.isEmpty ? null : buffer.toString(),
          endIndex: i + 1,
        );
      }

      if (line.startsWith('/**')) {
        final text = line.replaceFirst('/**', '').trim();
        if (text.isNotEmpty) buffer.write(text);
      } else if (line.endsWith('*/')) {
        final text = line.replaceFirst('*/', '').replaceFirst('*', '').trim();
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(text);
        }
        return _DocResult(
          doc: buffer.isEmpty ? null : buffer.toString(),
          endIndex: i + 1,
        );
      } else if (line.startsWith('*')) {
        final text = line.replaceFirst('*', '').trim();
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(text);
        }
      }

      i++;
    }

    return _DocResult(doc: buffer.isEmpty ? null : buffer.toString(), endIndex: i);
  }

  /// Looks backward from a line to find a JSDoc comment immediately preceding it.
  String? _lookbackForDoc(List<String> lines, int index) {
    if (index <= 0) return null;
    final prevLine = lines[index - 1].trim();
    if (prevLine.endsWith('*/')) {
      // Walk backward to find /**
      var start = index - 1;
      while (start >= 0) {
        if (lines[start].trim().startsWith('/**')) {
          final docResult = _parseJsDoc(lines, start);
          return docResult.doc;
        }
        start--;
      }
    }
    return null;
  }

  /// Converts PascalCase or UPPER_CASE to camelCase.
  String _toCamelCase(String input) {
    if (input.isEmpty) return input;
    // If it's all uppercase with underscores (e.g. UP, DOWN), lowercase it
    if (RegExp(r'^[A-Z][a-z]').hasMatch(input)) {
      return input[0].toLowerCase() + input.substring(1);
    }
    return input.toLowerCase();
  }
}

// --- Internal data classes ---

class _ParsedMethod {
  final UtsMethod method;
  final int endIndex;
  _ParsedMethod({required this.method, required this.endIndex});
}

class _ParsedClass {
  final UtsClass cls;
  final int endIndex;
  _ParsedClass({required this.cls, required this.endIndex});
}

class _ParsedEnum {
  final UtsEnum enumDef;
  final int endIndex;
  _ParsedEnum({required this.enumDef, required this.endIndex});
}

class _DocResult {
  final String? doc;
  final int endIndex;
  _DocResult({required this.doc, required this.endIndex});
}

class _CollectedDeclaration {
  final String text;
  final int endIndex;
  _CollectedDeclaration({required this.text, required this.endIndex});
}
