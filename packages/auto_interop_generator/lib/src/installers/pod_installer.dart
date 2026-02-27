/// Manages CocoaPods dependencies in Podfile.
///
/// Adds, updates, and removes pod declarations without corrupting existing
/// file content. Supports version operators (~>, >=, etc.) and target blocks.
class PodInstaller {
  /// Adds or updates a pod in the Podfile content.
  ///
  /// [podName] is the pod name (e.g., 'Alamofire').
  /// [version] is the version constraint (e.g., '~> 5.9').
  /// [target] is the optional target name to add the pod to.
  ///
  /// Returns the updated Podfile content.
  String addDependency({
    required String podfileContent,
    required String podName,
    required String version,
    String? target,
  }) {
    final existing = _findPod(podfileContent, podName);

    if (existing != null) {
      // Update existing pod version
      final newPod = "pod '$podName', '$version'";
      return podfileContent.replaceFirst(existing, newPod);
    }

    // Add new pod
    final newLine = "  pod '$podName', '$version'";

    if (target != null) {
      // Find the specific target block
      final targetPattern =
          RegExp("target\\s+'$target'\\s+do", multiLine: true);
      final targetMatch = targetPattern.firstMatch(podfileContent);
      if (targetMatch != null) {
        return _insertInBlock(podfileContent, targetMatch.end, newLine);
      }
    }

    // Try to find any target block and insert there
    final anyTarget = RegExp(r"target\s+'[^']+'\s+do", multiLine: true);
    final anyMatch = anyTarget.firstMatch(podfileContent);
    if (anyMatch != null) {
      return _insertInBlock(podfileContent, anyMatch.end, newLine);
    }

    // No target block — append at the end
    final trimmed = podfileContent.trimRight();
    return '$trimmed\n$newLine\n';
  }

  /// Removes a pod from the Podfile content.
  String removeDependency({
    required String podfileContent,
    required String podName,
  }) {
    final lines = podfileContent.split('\n');
    final result = <String>[];

    for (final line in lines) {
      if (_isPodLine(line, podName)) {
        continue; // Skip the matching pod line
      }
      result.add(line);
    }

    return result.join('\n');
  }

  /// Checks if a pod exists in the Podfile content.
  bool hasDependency({
    required String podfileContent,
    required String podName,
  }) {
    return _findPod(podfileContent, podName) != null;
  }

  /// Gets the version of a pod, or null if not found.
  String? getDependencyVersion({
    required String podfileContent,
    required String podName,
  }) {
    final match = RegExp("pod\\s+'$podName'\\s*,\\s*'([^']+)'")
        .firstMatch(podfileContent);
    return match?.group(1);
  }

  /// Adds multiple pods at once.
  String addDependencies({
    required String podfileContent,
    required List<PodDependency> dependencies,
    String? target,
  }) {
    var content = podfileContent;
    for (final dep in dependencies) {
      content = addDependency(
        podfileContent: content,
        podName: dep.name,
        version: dep.version,
        target: target,
      );
    }
    return content;
  }

  /// Creates a minimal Podfile with the given target and pods.
  String createPodfile({
    required String platform,
    required String platformVersion,
    required String target,
    List<PodDependency> pods = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln("platform :$platform, '$platformVersion'");
    buffer.writeln();
    buffer.writeln("target '$target' do");
    buffer.writeln('  use_frameworks!');
    for (final pod in pods) {
      buffer.writeln("  pod '${pod.name}', '${pod.version}'");
    }
    buffer.writeln('end');
    return buffer.toString();
  }

  // --- Private helpers ---

  String? _findPod(String content, String podName) {
    final pattern = RegExp("pod\\s+'$podName'\\s*(?:,\\s*'[^']*')?");
    final match = pattern.firstMatch(content);
    return match?.group(0);
  }

  bool _isPodLine(String line, String podName) {
    return RegExp("^\\s*pod\\s+'$podName'").hasMatch(line);
  }

  String _insertInBlock(String content, int afterPos, String newLine) {
    // Find the next line break after afterPos
    final nextNewline = content.indexOf('\n', afterPos);
    if (nextNewline == -1) {
      return '$content\n$newLine\n';
    }
    return '${content.substring(0, nextNewline + 1)}$newLine\n${content.substring(nextNewline + 1)}';
  }
}

/// Represents a CocoaPods dependency.
class PodDependency {
  final String name;
  final String version;

  const PodDependency({
    required this.name,
    required this.version,
  });
}
