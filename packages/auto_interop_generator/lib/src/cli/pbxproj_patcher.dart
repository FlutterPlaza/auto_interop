import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Patches Xcode `.pbxproj` files to add Swift source files.
///
/// Adds the four required entries for each file:
/// 1. PBXFileReference — declares the file exists
/// 2. PBXBuildFile — declares it should be compiled
/// 3. PBXGroup (Runner) — adds it to the Runner group in the project navigator
/// 4. PBXSourcesBuildPhase — adds it to the compile sources phase
///
/// Uses deterministic MD5-based IDs so that re-running produces stable output.
class PbxprojPatcher {
  const PbxprojPatcher();

  /// Returns true if [content] already contains a PBXFileReference for [fileName].
  bool hasFileReference(String content, String fileName) {
    return content.contains('/* $fileName */');
  }

  /// Adds a Swift file to the pbxproj [content] and returns the modified content.
  ///
  /// Inserts PBXFileReference, PBXBuildFile, Runner group child, and
  /// Sources build phase entries. Returns [content] unchanged if the file
  /// is already referenced.
  String addSwiftFile(String content, String fileName) {
    if (hasFileReference(content, fileName)) return content;

    final fileRefId = _generateId(fileName, 'fileref');
    final buildFileId = _generateId(fileName, 'build');

    var result = content;
    result = _addFileReference(result, fileRefId, fileName);
    result = _addBuildFile(result, buildFileId, fileRefId, fileName);
    result = _addToRunnerGroup(result, fileRefId, fileName);
    result = _addToSourcesBuildPhase(result, buildFileId, fileName);

    return result;
  }

  /// Generates a deterministic 24-character hex ID from [fileName] and [salt].
  String _generateId(String fileName, String salt) {
    final input = 'auto_interop:$fileName:$salt';
    final hash = md5.convert(utf8.encode(input)).toString();
    // pbxproj IDs are 24 hex chars
    return hash.substring(0, 24).toUpperCase();
  }

  /// Inserts a PBXFileReference entry before the end of that section.
  String _addFileReference(String content, String id, String fileName) {
    const marker = '/* End PBXFileReference section */';
    final idx = content.indexOf(marker);
    if (idx == -1) return content;

    final entry = '\t\t$id /* $fileName */ = '
        '{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
        'path = $fileName; sourceTree = "<group>"; };\n';

    return content.substring(0, idx) + entry + content.substring(idx);
  }

  /// Inserts a PBXBuildFile entry before the end of that section.
  String _addBuildFile(
      String content, String buildId, String fileRefId, String fileName) {
    const marker = '/* End PBXBuildFile section */';
    final idx = content.indexOf(marker);
    if (idx == -1) return content;

    final entry = '\t\t$buildId /* $fileName in Sources */ = '
        '{isa = PBXBuildFile; fileRef = $fileRefId /* $fileName */; };\n';

    return content.substring(0, idx) + entry + content.substring(idx);
  }

  /// Adds the file reference ID to the Runner group's children list.
  String _addToRunnerGroup(String content, String fileRefId, String fileName) {
    // Find the Runner group — look for a PBXGroup with name or path = Runner
    // that contains a children array. Try the comment form first, then the
    // name/path attribute form.
    final runnerGroupPattern = RegExp(
      r'/\* Runner \*/ = \{[^}]*children = \(\s*',
      multiLine: true,
    );
    var match = runnerGroupPattern.firstMatch(content);
    if (match == null) {
      // Fallback: look for a PBXGroup with path = Runner or name = Runner
      final fallbackPattern = RegExp(
        r'isa = PBXGroup;[^}]*(?:path|name) = Runner;[^}]*children = \(\s*',
        multiLine: true,
      );
      match = fallbackPattern.firstMatch(content);
      if (match == null) {
        // Try reverse order: children before path/name
        final reversePattern = RegExp(
          r'isa = PBXGroup;[^}]*children = \(\s*(?=[^)]*\);[^}]*(?:path|name) = Runner)',
          multiLine: true,
        );
        match = reversePattern.firstMatch(content);
      }
    }
    if (match == null) return content;

    final insertPos = match.end;
    final entry = '\t\t\t\t$fileRefId /* $fileName */,\n';

    return content.substring(0, insertPos) +
        entry +
        content.substring(insertPos);
  }

  /// Adds the build file ID to the Sources build phase's files list.
  ///
  /// Iterates all PBXSourcesBuildPhase matches and picks the one belonging
  /// to the Runner target (contains AppDelegate or GeneratedPluginRegistrant),
  /// falling back to the first match.
  String _addToSourcesBuildPhase(
      String content, String buildId, String fileName) {
    final sourcesBuildPhasePattern = RegExp(
      r'isa = PBXSourcesBuildPhase;[^}]*files = \(\s*',
      multiLine: true,
    );
    final matches = sourcesBuildPhasePattern.allMatches(content).toList();
    if (matches.isEmpty) return content;

    // Find the Runner target's build phase by checking if its files list
    // contains AppDelegate or GeneratedPluginRegistrant.
    RegExpMatch? runnerMatch;
    for (final match in matches) {
      // Look at the files list after this match until the closing paren
      final closeParen = content.indexOf(')', match.end);
      if (closeParen == -1) continue;
      final filesBlock = content.substring(match.end, closeParen);
      if (filesBlock.contains('AppDelegate') ||
          filesBlock.contains('GeneratedPluginRegistrant')) {
        runnerMatch = match;
        break;
      }
    }
    // Fallback to first match
    final match = runnerMatch ?? matches.first;

    final insertPos = match.end;
    final entry = '\t\t\t\t$buildId /* $fileName in Sources */,\n';

    return content.substring(0, insertPos) +
        entry +
        content.substring(insertPos);
  }
}
