/// Manages Swift Package Manager dependencies in Package.swift.
///
/// Adds, updates, and removes package dependencies without corrupting
/// existing file content.
class SpmInstaller {
  /// Adds or updates a dependency in Package.swift content.
  ///
  /// [packageUrl] is the Git URL (e.g., 'https://github.com/Alamofire/Alamofire').
  /// [version] is the version (e.g., '5.9.0').
  /// [productName] is the library product name (e.g., 'Alamofire').
  ///
  /// Returns the updated Package.swift content.
  String addDependency({
    required String packageSwiftContent,
    required String packageUrl,
    required String version,
    String? productName,
  }) {
    final existing = _findDependency(packageSwiftContent, packageUrl);

    if (existing != null) {
      // Update existing dependency version
      final newDep = _formatDependency(packageUrl, version);
      return packageSwiftContent.replaceFirst(existing, newDep);
    }

    // Add to dependencies array
    final depsArrayMatch =
        RegExp(r'dependencies\s*:\s*\[').firstMatch(packageSwiftContent);
    if (depsArrayMatch != null) {
      final closingBracket =
          _findMatchingBracket(packageSwiftContent, depsArrayMatch.end - 1);
      if (closingBracket != -1) {
        final newDep = _formatDependency(packageUrl, version);
        final before = packageSwiftContent.substring(0, closingBracket);
        final after = packageSwiftContent.substring(closingBracket);

        // Check if array is empty or has existing entries
        final arrayContent = packageSwiftContent
            .substring(depsArrayMatch.end, closingBracket)
            .trim();
        if (arrayContent.isEmpty) {
          return '$before\n        $newDep,\n    $after';
        }
        return '$before,\n        $newDep\n    $after';
      }
    }

    // No dependencies array found — can't add
    return packageSwiftContent;
  }

  /// Removes a dependency from Package.swift content.
  String removeDependency({
    required String packageSwiftContent,
    required String packageUrl,
  }) {
    final lines = packageSwiftContent.split('\n');
    final result = <String>[];

    for (final line in lines) {
      if (line.contains(packageUrl)) {
        continue; // Skip the matching dependency line
      }
      result.add(line);
    }

    return result.join('\n');
  }

  /// Checks if a dependency exists in Package.swift content.
  bool hasDependency({
    required String packageSwiftContent,
    required String packageUrl,
  }) {
    return _findDependency(packageSwiftContent, packageUrl) != null;
  }

  /// Gets the version of a dependency, or null if not found.
  String? getDependencyVersion({
    required String packageSwiftContent,
    required String packageUrl,
  }) {
    final match =
        RegExp('url:\\s*"${RegExp.escape(packageUrl)}".*?from:\\s*"([^"]+)"')
            .firstMatch(packageSwiftContent);
    if (match != null) return match.group(1);

    // Try exact version pattern
    final exactMatch =
        RegExp('url:\\s*"${RegExp.escape(packageUrl)}".*?exact:\\s*"([^"]+)"')
            .firstMatch(packageSwiftContent);
    return exactMatch?.group(1);
  }

  /// Adds multiple dependencies at once.
  String addDependencies({
    required String packageSwiftContent,
    required List<SpmDependency> dependencies,
  }) {
    var content = packageSwiftContent;
    for (final dep in dependencies) {
      content = addDependency(
        packageSwiftContent: content,
        packageUrl: dep.url,
        version: dep.version,
        productName: dep.productName,
      );
    }
    return content;
  }

  // --- Private helpers ---

  String? _findDependency(String content, String packageUrl) {
    final pattern =
        RegExp('\\.package\\(url:\\s*"${RegExp.escape(packageUrl)}"[^)]*\\)');
    final match = pattern.firstMatch(content);
    return match?.group(0);
  }

  String _formatDependency(String packageUrl, String version) {
    return '.package(url: "$packageUrl", from: "$version")';
  }

  int _findMatchingBracket(String content, int openPos) {
    var depth = 0;
    for (var i = openPos; i < content.length; i++) {
      if (content[i] == '[') {
        depth++;
      } else if (content[i] == ']') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}

/// Represents a Swift Package Manager dependency.
class SpmDependency {
  final String url;
  final String version;
  final String? productName;

  const SpmDependency({
    required this.url,
    required this.version,
    this.productName,
  });
}
