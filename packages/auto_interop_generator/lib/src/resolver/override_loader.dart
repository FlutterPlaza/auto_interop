import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../schema/unified_type_schema.dart';

/// Result of loading a UTS override file.
class OverrideLoadResult {
  /// The loaded schema.
  final UnifiedTypeSchema schema;

  /// Whether this override came from the project-level directory.
  final bool isProjectLevel;

  /// The file path that was loaded.
  final String filePath;

  const OverrideLoadResult({
    required this.schema,
    required this.isProjectLevel,
    required this.filePath,
  });
}

/// Loads `.uts.json` override files from project and global directories.
///
/// Resolution order:
/// 1. Project directory: `auto_interop_overrides/` (or configured path)
/// 2. Global directory: `~/.auto_interop/overrides/`
///
/// Within each directory, two naming patterns are tried:
/// - Flat: `{package_name}.uts.json`
/// - Structured: `{source}/{package}/{version}.uts.json`
///
/// Additionally, naming-convention fallbacks are applied:
/// exact name -> snake_case -> lowercase -> scan by `package` field.
class OverrideLoader {
  /// Project-level overrides directory.
  final String projectDir;

  /// Global overrides directory.
  final String globalDir;

  OverrideLoader({
    this.projectDir = 'auto_interop_overrides',
    String? globalDir,
  }) : globalDir = globalDir ?? _defaultGlobalDir();

  static String _defaultGlobalDir() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.auto_interop', 'overrides');
  }

  /// Attempts to load an override for the given [packageName].
  ///
  /// Optionally narrows the search with [source] and [version] for
  /// structured directory layouts.
  ///
  /// Returns `null` if no override is found.
  OverrideLoadResult? load(
    String packageName, {
    String? source,
    String? version,
  }) {
    // Try project dir first
    final projectResult = _loadFromDir(
      packageName,
      projectDir,
      isProjectLevel: true,
      source: source,
      version: version,
    );
    if (projectResult != null) return projectResult;

    // Try global dir
    return _loadFromDir(
      packageName,
      globalDir,
      isProjectLevel: false,
      source: source,
      version: version,
    );
  }

  OverrideLoadResult? _loadFromDir(
    String packageName,
    String dirPath, {
    required bool isProjectLevel,
    String? source,
    String? version,
  }) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return null;

    // 1. Try structured path: {source}/{package}/{version}.uts.json
    if (source != null && version != null) {
      final structuredPath =
          p.join(dirPath, source, packageName, '$version.uts.json');
      final schema = _tryLoadFile(structuredPath);
      if (schema != null) {
        return OverrideLoadResult(
          schema: schema,
          isProjectLevel: isProjectLevel,
          filePath: structuredPath,
        );
      }
    }

    // 2. Try flat naming with convention fallbacks
    for (final name in _namingCandidates(packageName)) {
      final flatPath = p.join(dirPath, '$name.uts.json');
      final schema = _tryLoadFile(flatPath);
      if (schema != null) {
        return OverrideLoadResult(
          schema: schema,
          isProjectLevel: isProjectLevel,
          filePath: flatPath,
        );
      }
    }

    // 3. Scan all .uts.json files for matching `package` field
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.uts.json')) continue;
      final schema = _tryLoadFile(entity.path);
      if (schema != null && schema.package == packageName) {
        return OverrideLoadResult(
          schema: schema,
          isProjectLevel: isProjectLevel,
          filePath: entity.path,
        );
      }
    }

    return null;
  }

  /// Returns naming candidates in priority order: exact, snake_case, lowercase.
  static List<String> _namingCandidates(String packageName) {
    final candidates = <String>[packageName];

    final snakeCase = packageName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
    if (snakeCase != packageName) candidates.add(snakeCase);

    final lower = packageName.toLowerCase();
    if (lower != packageName && lower != snakeCase) candidates.add(lower);

    return candidates;
  }

  UnifiedTypeSchema? _tryLoadFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return UnifiedTypeSchema.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
