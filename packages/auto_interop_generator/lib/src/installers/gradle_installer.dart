/// Manages Gradle dependencies in `build.gradle` or `build.gradle.kts` files.
///
/// Adds, updates, and removes dependencies without corrupting existing file
/// content. Supports both Groovy DSL (.gradle) and Kotlin DSL (.gradle.kts).
class GradleInstaller {
  /// Adds or updates a dependency in the given build.gradle content.
  ///
  /// [group] is the Maven group (e.g., 'com.squareup.okhttp3').
  /// [artifact] is the artifact name (e.g., 'okhttp').
  /// [version] is the version string (e.g., '4.12.0').
  /// [configuration] is the dependency configuration (default: 'implementation').
  ///
  /// Returns the updated file content.
  String addDependency({
    required String buildGradleContent,
    required String group,
    required String artifact,
    required String version,
    String configuration = 'implementation',
    bool isKotlinDsl = false,
  }) {
    final coordinate = '$group:$artifact:$version';
    final existing = _findDependency(
        buildGradleContent, group, artifact, isKotlinDsl: isKotlinDsl);

    if (existing != null) {
      // Update existing dependency version
      return buildGradleContent.replaceFirst(existing, _formatDep(
        configuration: configuration,
        coordinate: coordinate,
        isKotlinDsl: isKotlinDsl,
      ));
    }

    // Add new dependency to dependencies block
    final depsBlockMatch = _findDependenciesBlock(buildGradleContent);
    if (depsBlockMatch != null) {
      final insertPos = depsBlockMatch.closingBracePos;
      final indent = isKotlinDsl ? '    ' : '    ';
      final newDep = '$indent${_formatDep(
        configuration: configuration,
        coordinate: coordinate,
        isKotlinDsl: isKotlinDsl,
      )}\n';
      return buildGradleContent.substring(0, insertPos) +
          newDep +
          buildGradleContent.substring(insertPos);
    }

    // No dependencies block exists — create one
    final newBlock = '\ndependencies {\n    ${_formatDep(
      configuration: configuration,
      coordinate: coordinate,
      isKotlinDsl: isKotlinDsl,
    )}\n}\n';
    return buildGradleContent + newBlock;
  }

  /// Removes a dependency from the build.gradle content.
  String removeDependency({
    required String buildGradleContent,
    required String group,
    required String artifact,
    bool isKotlinDsl = false,
  }) {
    final lines = buildGradleContent.split('\n');
    final result = <String>[];
    final depPattern = '$group:$artifact';

    for (final line in lines) {
      if (line.contains(depPattern)) {
        continue; // Skip the matching dependency line
      }
      result.add(line);
    }

    return result.join('\n');
  }

  /// Checks if a dependency exists in the build.gradle content.
  bool hasDependency({
    required String buildGradleContent,
    required String group,
    required String artifact,
    bool isKotlinDsl = false,
  }) {
    return _findDependency(
            buildGradleContent, group, artifact, isKotlinDsl: isKotlinDsl) !=
        null;
  }

  /// Gets the version of a dependency, or null if not found.
  String? getDependencyVersion({
    required String buildGradleContent,
    required String group,
    required String artifact,
  }) {
    final pattern =
        RegExp('$group:$artifact:([^"\'\\s]+)');
    final match = pattern.firstMatch(buildGradleContent);
    return match?.group(1);
  }

  /// Adds multiple dependencies at once.
  String addDependencies({
    required String buildGradleContent,
    required List<GradleDependency> dependencies,
    bool isKotlinDsl = false,
  }) {
    var content = buildGradleContent;
    for (final dep in dependencies) {
      content = addDependency(
        buildGradleContent: content,
        group: dep.group,
        artifact: dep.artifact,
        version: dep.version,
        configuration: dep.configuration,
        isKotlinDsl: isKotlinDsl,
      );
    }
    return content;
  }

  // --- Private helpers ---

  String? _findDependency(
      String content, String group, String artifact,
      {bool isKotlinDsl = false}) {
    final depPattern = '$group:$artifact';
    // Match both Groovy and Kotlin DSL formats
    final patterns = [
      // Groovy: implementation 'group:artifact:version'
      RegExp("\\w+\\s+['\"]$depPattern:[^'\"]+['\"]"),
      // Kotlin: implementation("group:artifact:version")
      RegExp('\\w+\\(["\']$depPattern:[^"\']+["\']\\)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(content);
      if (match != null) return match.group(0);
    }
    return null;
  }

  String _formatDep({
    required String configuration,
    required String coordinate,
    required bool isKotlinDsl,
  }) {
    if (isKotlinDsl) {
      return '$configuration("$coordinate")';
    }
    return "$configuration '$coordinate'";
  }

  _DepsBlock? _findDependenciesBlock(String content) {
    final match = RegExp(r'dependencies\s*\{').firstMatch(content);
    if (match == null) return null;

    final openBrace = match.end - 1;
    var depth = 1;
    for (var i = match.end; i < content.length; i++) {
      if (content[i] == '{') depth++;
      if (content[i] == '}') {
        depth--;
        if (depth == 0) {
          return _DepsBlock(
            openBracePos: openBrace,
            closingBracePos: i,
          );
        }
      }
    }
    return null;
  }
}

/// Represents a Gradle dependency.
class GradleDependency {
  final String group;
  final String artifact;
  final String version;
  final String configuration;

  const GradleDependency({
    required this.group,
    required this.artifact,
    required this.version,
    this.configuration = 'implementation',
  });
}

class _DepsBlock {
  final int openBracePos;
  final int closingBracePos;
  _DepsBlock({required this.openBracePos, required this.closingBracePos});
}
