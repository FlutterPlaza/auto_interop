import '../schema/unified_type_schema.dart';

/// Result of cross-package dependency resolution.
class DependencyResolution {
  /// Topologically sorted build order (packages that depend on nothing first).
  final List<String> buildOrder;

  /// Maps package → set of packages it depends on.
  final Map<String, Set<String>> dependencies;

  /// Version conflicts: same package name referenced with different versions.
  final List<VersionConflict> conflicts;

  /// Type references that could not be resolved in any loaded package.
  final List<UnresolvedReference> unresolvedReferences;

  const DependencyResolution({
    required this.buildOrder,
    required this.dependencies,
    this.conflicts = const [],
    this.unresolvedReferences = const [],
  });

  bool get hasConflicts => conflicts.isNotEmpty;
  bool get hasUnresolved => unresolvedReferences.isNotEmpty;
}

/// A version conflict between package references.
class VersionConflict {
  final String package;
  final List<String> versions;

  const VersionConflict({required this.package, required this.versions});

  @override
  String toString() => '$package: ${versions.join(' vs ')}';
}

/// A type reference that could not be resolved in any loaded package.
class UnresolvedReference {
  final String typeName;
  final String referencedIn;

  const UnresolvedReference(
      {required this.typeName, required this.referencedIn});

  @override
  String toString() => '$typeName (referenced in $referencedIn)';
}

/// Resolves cross-package dependencies and determines build order.
class DependencyResolver {
  const DependencyResolver();

  /// Resolves dependencies across a list of [schemas].
  DependencyResolution resolve(List<UnifiedTypeSchema> schemas) {
    final dependencies = <String, Set<String>>{};
    final conflicts = <VersionConflict>[];
    final unresolvedRefs = <UnresolvedReference>[];

    // Build map of package → defined type names
    final packageTypes = <String, Set<String>>{};
    for (final schema in schemas) {
      packageTypes[schema.package] = schema.definedTypeNames;
    }

    // Detect version conflicts
    final versionMap = <String, Set<String>>{}; // package → versions seen
    for (final schema in schemas) {
      versionMap.putIfAbsent(schema.package, () => {}).add(schema.version);
    }
    for (final entry in versionMap.entries) {
      if (entry.value.length > 1) {
        conflicts.add(VersionConflict(
          package: entry.key,
          versions: entry.value.toList(),
        ));
      }
    }

    // Collect cross-package type references
    for (final schema in schemas) {
      final deps = <String>{};
      final ownTypes = packageTypes[schema.package]!;
      final referencedNames = _collectReferencedNames(schema);

      for (final ref in referencedNames) {
        if (ownTypes.contains(ref)) continue;

        var resolved = false;
        for (final otherEntry in packageTypes.entries) {
          if (otherEntry.key == schema.package) continue;
          if (otherEntry.value.contains(ref)) {
            deps.add(otherEntry.key);
            resolved = true;
            break;
          }
        }
        if (!resolved) {
          // Check it's not a built-in type
          if (!_isBuiltinType(ref)) {
            unresolvedRefs.add(UnresolvedReference(
              typeName: ref,
              referencedIn: schema.package,
            ));
          }
        }
      }

      if (deps.isNotEmpty) {
        dependencies[schema.package] = deps;
      }
    }

    // Topological sort
    final buildOrder = _topologicalSort(
      schemas.map((s) => s.package).toSet(),
      dependencies,
    );

    return DependencyResolution(
      buildOrder: buildOrder,
      dependencies: dependencies,
      conflicts: conflicts,
      unresolvedReferences: unresolvedRefs,
    );
  }

  Set<String> _collectReferencedNames(UnifiedTypeSchema schema) {
    final refs = <String>{};
    void walkType(UtsType type) {
      if (type.ref != null) refs.add(type.ref!);
      type.typeArguments?.forEach(walkType);
      type.parameterTypes?.forEach(walkType);
      if (type.returnType != null) walkType(type.returnType!);
    }

    for (final cls in [...schema.classes, ...schema.types]) {
      if (cls.superclass != null) refs.add(cls.superclass!);
      refs.addAll(cls.interfaces);
      for (final field in cls.fields) {
        walkType(field.type);
      }
      for (final method in cls.methods) {
        walkType(method.returnType);
        for (final param in method.parameters) {
          walkType(param.type);
        }
      }
    }
    for (final func in schema.functions) {
      walkType(func.returnType);
      for (final param in func.parameters) {
        walkType(param.type);
      }
    }
    return refs;
  }

  bool _isBuiltinType(String name) {
    const builtins = {
      'String',
      'int',
      'double',
      'bool',
      'DateTime',
      'void',
      'dynamic',
      'Object',
      'Uint8List',
      'List',
      'Map',
      'Set',
      'Future',
      'Stream',
    };
    return builtins.contains(name);
  }

  /// Kahn's algorithm for topological sort.
  List<String> _topologicalSort(
    Set<String> allPackages,
    Map<String, Set<String>> dependencies,
  ) {
    // Build in-degree map
    final inDegree = <String, int>{};
    final reverseGraph = <String, Set<String>>{}; // dep → dependents
    for (final pkg in allPackages) {
      inDegree.putIfAbsent(pkg, () => 0);
    }
    for (final entry in dependencies.entries) {
      for (final dep in entry.value) {
        if (allPackages.contains(dep)) {
          inDegree[entry.key] = (inDegree[entry.key] ?? 0) + 1;
          reverseGraph.putIfAbsent(dep, () => {}).add(entry.key);
        }
      }
    }

    // BFS with queue of zero in-degree nodes
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) queue.add(entry.key);
    }
    queue.sort(); // Deterministic order

    final result = <String>[];
    while (queue.isNotEmpty) {
      final node = queue.removeAt(0);
      result.add(node);
      for (final dependent in reverseGraph[node] ?? <String>{}) {
        inDegree[dependent] = inDegree[dependent]! - 1;
        if (inDegree[dependent] == 0) {
          queue.add(dependent);
          queue.sort();
        }
      }
    }

    // If not all packages are in result, there's a cycle — add remaining
    for (final pkg in allPackages) {
      if (!result.contains(pkg)) result.add(pkg);
    }

    return result;
  }
}
