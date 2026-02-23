/// Tracks cross-package type references for invalidation.
///
/// When a type from package A is referenced in package B's schema,
/// a change to A must also trigger regeneration of B.
class DependencyGraph {
  /// Maps package name → set of packages it depends on.
  final Map<String, Set<String>> _dependencies = {};

  /// Records that [dependent] references types defined in [dependency].
  void addDependency(String dependent, String dependency) {
    _dependencies.putIfAbsent(dependent, () => {}).add(dependency);
  }

  /// Returns the direct dependencies of [package].
  Set<String> directDependencies(String package) {
    return _dependencies[package] ?? {};
  }

  /// Given a set of [changedPackages], returns the full invalidation set
  /// including all transitively dependent packages.
  Set<String> invalidationSet(Set<String> changedPackages) {
    final result = <String>{...changedPackages};
    final queue = [...changedPackages];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      // Find all packages that depend on `current`
      for (final entry in _dependencies.entries) {
        if (entry.value.contains(current) && result.add(entry.key)) {
          queue.add(entry.key);
        }
      }
    }

    return result;
  }

  /// Returns all known package names in the graph.
  Set<String> get allPackages {
    final pkgs = <String>{..._dependencies.keys};
    for (final deps in _dependencies.values) {
      pkgs.addAll(deps);
    }
    return pkgs;
  }
}
