import '../generators/dart_reserved.dart';
import '../schema/unified_type_schema.dart';

/// Severity level for analysis diagnostics.
enum DiagnosticSeverity { error, warning, info }

/// A single diagnostic from the analyzer.
class AnalysisDiagnostic {
  final DiagnosticSeverity severity;
  final String message;
  final String? context;

  const AnalysisDiagnostic({
    required this.severity,
    required this.message,
    this.context,
  });

  bool get isError => severity == DiagnosticSeverity.error;

  @override
  String toString() {
    final prefix = severity.name.toUpperCase();
    final ctx = context != null ? ' ($context)' : '';
    return '[$prefix] $message$ctx';
  }
}

/// Result of analyzing an API surface.
class AnalysisResult {
  final List<AnalysisDiagnostic> diagnostics;

  const AnalysisResult(this.diagnostics);

  bool get hasErrors => diagnostics.any((d) => d.isError);
  bool get hasWarnings =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.warning);

  List<AnalysisDiagnostic> get errors =>
      diagnostics.where((d) => d.isError).toList();
  List<AnalysisDiagnostic> get warnings => diagnostics
      .where((d) => d.severity == DiagnosticSeverity.warning)
      .toList();
}

/// Validates a [UnifiedTypeSchema] for correctness and completeness.
///
/// Checks for:
/// - Missing type references
/// - Circular dependencies between types
/// - Unsupported type combinations
/// - Naming conflicts
/// - Empty API surfaces
class ApiSurfaceAnalyzer {
  const ApiSurfaceAnalyzer();

  /// Analyzes the given [schema] and returns diagnostics.
  AnalysisResult analyze(UnifiedTypeSchema schema) {
    final diagnostics = <AnalysisDiagnostic>[];

    _checkEmptySurface(schema, diagnostics);
    _checkMissingTypeReferences(schema, diagnostics);
    _checkCircularDependencies(schema, diagnostics);
    _checkUnsupportedTypeCombos(schema, diagnostics);
    _checkNamingConflicts(schema, diagnostics);

    return AnalysisResult(diagnostics);
  }

  void _checkEmptySurface(
      UnifiedTypeSchema schema, List<AnalysisDiagnostic> diagnostics) {
    if (schema.classes.isEmpty &&
        schema.functions.isEmpty &&
        schema.types.isEmpty &&
        schema.enums.isEmpty) {
      diagnostics.add(AnalysisDiagnostic(
        severity: DiagnosticSeverity.warning,
        message: 'Empty API surface for package "${schema.package}"',
        context: 'No classes, functions, types, or enums defined',
      ));
    }
  }

  void _checkMissingTypeReferences(
      UnifiedTypeSchema schema, List<AnalysisDiagnostic> diagnostics) {
    final definedNames = schema.definedTypeNames;
    // Also include primitive type names that don't need resolution
    final builtinNames = {
      'String',
      'int',
      'double',
      'bool',
      'DateTime',
      'void',
      'dynamic',
      'Object',
      'Uint8List',
    };

    void checkType(UtsType type, String location) {
      if ((type.kind == UtsTypeKind.object ||
              type.kind == UtsTypeKind.enumType) &&
          type.ref != null) {
        if (!definedNames.contains(type.ref!) &&
            !builtinNames.contains(type.ref!)) {
          diagnostics.add(AnalysisDiagnostic(
            severity: DiagnosticSeverity.warning,
            message: 'Unresolved type reference "${type.ref}"',
            context: location,
          ));
        }
      }
      type.typeArguments?.forEach((t) => checkType(t, location));
      type.parameterTypes?.forEach((t) => checkType(t, location));
      if (type.returnType != null) checkType(type.returnType!, location);
    }

    for (final cls in [...schema.classes, ...schema.types]) {
      for (final field in cls.fields) {
        checkType(field.type, '${cls.name}.${field.name}');
      }
      for (final method in cls.methods) {
        checkType(method.returnType, '${cls.name}.${method.name}()');
        for (final param in method.parameters) {
          checkType(param.type, '${cls.name}.${method.name}(${param.name})');
        }
      }
    }
    for (final func in schema.functions) {
      checkType(func.returnType, '${func.name}()');
      for (final param in func.parameters) {
        checkType(param.type, '${func.name}(${param.name})');
      }
    }
  }

  void _checkCircularDependencies(
      UnifiedTypeSchema schema, List<AnalysisDiagnostic> diagnostics) {
    // Build adjacency from type name → referenced type names
    final graph = <String, Set<String>>{};
    final definedNames = schema.definedTypeNames;

    for (final cls in [...schema.classes, ...schema.types]) {
      final refs = <String>{};
      void collectRefs(UtsType type) {
        if ((type.kind == UtsTypeKind.object ||
                type.kind == UtsTypeKind.enumType) &&
            type.ref != null &&
            definedNames.contains(type.ref!) &&
            type.ref != cls.name) {
          refs.add(type.ref!);
        }
        type.typeArguments?.forEach(collectRefs);
        type.parameterTypes?.forEach(collectRefs);
        if (type.returnType != null) collectRefs(type.returnType!);
      }

      for (final field in cls.fields) {
        collectRefs(field.type);
      }
      if (refs.isNotEmpty) {
        graph[cls.name] = refs;
      }
    }

    // DFS cycle detection
    final visited = <String>{};
    final inStack = <String>{};

    bool dfs(String node, List<String> path) {
      if (inStack.contains(node)) {
        final cycleStart = path.indexOf(node);
        final cycle = path.sublist(cycleStart)..add(node);
        diagnostics.add(AnalysisDiagnostic(
          severity: DiagnosticSeverity.error,
          message: 'Circular type dependency detected',
          context: cycle.join(' → '),
        ));
        return true;
      }
      if (visited.contains(node)) return false;

      visited.add(node);
      inStack.add(node);
      path.add(node);

      for (final dep in graph[node] ?? <String>{}) {
        if (dfs(dep, path)) return true;
      }

      path.removeLast();
      inStack.remove(node);
      return false;
    }

    for (final node in graph.keys) {
      if (!visited.contains(node)) {
        dfs(node, []);
      }
    }
  }

  void _checkUnsupportedTypeCombos(
      UnifiedTypeSchema schema, List<AnalysisDiagnostic> diagnostics) {
    void checkType(UtsType type, String location) {
      // Map with non-primitive keys
      if (type.kind == UtsTypeKind.map && type.typeArguments != null) {
        final keyType = type.typeArguments!.first;
        if (keyType.kind != UtsTypeKind.primitive &&
            keyType.kind != UtsTypeKind.enumType) {
          diagnostics.add(AnalysisDiagnostic(
            severity: DiagnosticSeverity.warning,
            message:
                'Map with non-primitive key type "${keyType.toDartType()}"',
            context: location,
          ));
        }
      }

      // Deeply nested generics (>3 levels)
      if (_genericDepth(type) > 3) {
        diagnostics.add(AnalysisDiagnostic(
          severity: DiagnosticSeverity.warning,
          message: 'Deeply nested generic type (>3 levels)',
          context: '$location: ${type.toDartType()}',
        ));
      }

      type.typeArguments?.forEach((t) => checkType(t, location));
    }

    for (final cls in [...schema.classes, ...schema.types]) {
      for (final field in cls.fields) {
        checkType(field.type, '${cls.name}.${field.name}');
      }
      for (final method in cls.methods) {
        checkType(method.returnType, '${cls.name}.${method.name}()');
        for (final param in method.parameters) {
          checkType(param.type, '${cls.name}.${method.name}(${param.name})');
        }
      }
    }
    for (final func in schema.functions) {
      checkType(func.returnType, '${func.name}()');
      for (final param in func.parameters) {
        checkType(param.type, '${func.name}(${param.name})');
      }
    }
  }

  int _genericDepth(UtsType type) {
    if (type.typeArguments == null || type.typeArguments!.isEmpty) return 0;
    var max = 0;
    for (final arg in type.typeArguments!) {
      final d = _genericDepth(arg);
      if (d > max) max = d;
    }
    return 1 + max;
  }

  void _checkNamingConflicts(
      UnifiedTypeSchema schema, List<AnalysisDiagnostic> diagnostics) {
    final names = <String, String>{}; // name → kind

    void register(String name, String kind) {
      if (names.containsKey(name)) {
        diagnostics.add(AnalysisDiagnostic(
          severity: DiagnosticSeverity.error,
          message:
              'Naming conflict: "$name" defined as both ${names[name]} and $kind',
        ));
      } else {
        names[name] = kind;
      }
    }

    for (final cls in schema.classes) {
      register(cls.name, 'class');
    }
    for (final type in schema.types) {
      register(type.name, 'type');
    }
    for (final e in schema.enums) {
      register(e.name, 'enum');
    }

    // Check for Dart reserved word collisions
    for (final name in names.keys) {
      if (dartReservedWords.contains(name.toLowerCase())) {
        diagnostics.add(AnalysisDiagnostic(
          severity: DiagnosticSeverity.warning,
          message: 'Name "$name" collides with Dart reserved word',
        ));
      }
    }
  }
}
