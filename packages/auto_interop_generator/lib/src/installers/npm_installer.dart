import 'dart:convert';

/// Manages npm dependencies in a `package.json` file.
///
/// Adds, updates, and removes npm package dependencies without corrupting
/// existing file content. Handles deduplication and version constraints.
class NpmInstaller {
  /// Adds or updates a dependency in the given `package.json` content.
  ///
  /// Returns the updated JSON string. If the dependency already exists
  /// with the same version, the content is returned unchanged. If it
  /// exists with a different version, it is updated.
  String addDependency({
    required String packageJsonContent,
    required String packageName,
    required String version,
    bool isDev = false,
  }) {
    final json = _parseJson(packageJsonContent);
    final key = isDev ? 'devDependencies' : 'dependencies';

    json.putIfAbsent(key, () => <String, dynamic>{});
    final deps = json[key] as Map<String, dynamic>;

    deps[packageName] = version;

    return _encodeJson(json);
  }

  /// Removes a dependency from the given `package.json` content.
  ///
  /// Checks both `dependencies` and `devDependencies`.
  /// Returns the updated JSON string.
  String removeDependency({
    required String packageJsonContent,
    required String packageName,
  }) {
    final json = _parseJson(packageJsonContent);

    final deps = json['dependencies'] as Map<String, dynamic>?;
    deps?.remove(packageName);

    final devDeps = json['devDependencies'] as Map<String, dynamic>?;
    devDeps?.remove(packageName);

    return _encodeJson(json);
  }

  /// Checks if a dependency exists in the given `package.json` content.
  ///
  /// Checks both `dependencies` and `devDependencies`.
  bool hasDependency({
    required String packageJsonContent,
    required String packageName,
  }) {
    final json = _parseJson(packageJsonContent);

    final deps = json['dependencies'] as Map<String, dynamic>?;
    if (deps?.containsKey(packageName) == true) return true;

    final devDeps = json['devDependencies'] as Map<String, dynamic>?;
    if (devDeps?.containsKey(packageName) == true) return true;

    return false;
  }

  /// Returns the version of a dependency, or null if not found.
  ///
  /// Checks both `dependencies` and `devDependencies`.
  String? getDependencyVersion({
    required String packageJsonContent,
    required String packageName,
  }) {
    final json = _parseJson(packageJsonContent);

    final deps = json['dependencies'] as Map<String, dynamic>?;
    if (deps?.containsKey(packageName) == true) {
      return deps![packageName] as String;
    }

    final devDeps = json['devDependencies'] as Map<String, dynamic>?;
    if (devDeps?.containsKey(packageName) == true) {
      return devDeps![packageName] as String;
    }

    return null;
  }

  /// Creates a minimal `package.json` with the given dependencies.
  String createPackageJson({
    required String name,
    String version = '1.0.0',
    Map<String, String> dependencies = const {},
    Map<String, String> devDependencies = const {},
  }) {
    final json = <String, dynamic>{
      'name': name,
      'version': version,
      'private': true,
    };

    if (dependencies.isNotEmpty) {
      json['dependencies'] = Map<String, dynamic>.from(dependencies);
    }

    if (devDependencies.isNotEmpty) {
      json['devDependencies'] = Map<String, dynamic>.from(devDependencies);
    }

    return _encodeJson(json);
  }

  /// Adds multiple dependencies at once.
  ///
  /// [packages] maps package names to version strings.
  String addDependencies({
    required String packageJsonContent,
    required Map<String, String> packages,
    bool isDev = false,
  }) {
    var content = packageJsonContent;
    for (final entry in packages.entries) {
      content = addDependency(
        packageJsonContent: content,
        packageName: entry.key,
        version: entry.value,
        isDev: isDev,
      );
    }
    return content;
  }

  Map<String, dynamic> _parseJson(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw NpmInstallerException(
        'Invalid package.json: ${e.message}',
      );
    }
  }

  String _encodeJson(Map<String, dynamic> json) {
    return '${const JsonEncoder.withIndent('  ').convert(json)}\n';
  }
}

/// Exception thrown when the npm installer encounters an error.
class NpmInstallerException implements Exception {
  final String message;
  const NpmInstallerException(this.message);

  @override
  String toString() => 'NpmInstallerException: $message';
}
