import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../schema/unified_type_schema.dart';

/// Cache entry for a single parsed package.
class ParseCacheEntry {
  /// SHA-256 checksum of the source files used for parsing.
  final String sourceChecksum;

  /// Timestamp of when the schema was parsed.
  final DateTime parsedAt;

  const ParseCacheEntry({
    required this.sourceChecksum,
    required this.parsedAt,
  });

  factory ParseCacheEntry.fromJson(Map<String, dynamic> json) {
    return ParseCacheEntry(
      sourceChecksum: json['sourceChecksum'] as String,
      parsedAt: DateTime.parse(json['parsedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceChecksum': sourceChecksum,
        'parsedAt': parsedAt.toIso8601String(),
      };
}

/// Caches parsed `.uts.json` schemas in `.auto_interop_cache/` with
/// checksum-based invalidation.
///
/// Layout:
/// ```
/// .auto_interop_cache/
///   schemas/<package_key>.uts.json   — cached parsed schema
///   parse_manifest.json              — maps package → sourceChecksum + parsedAt
/// ```
class ParseCache {
  /// Root directory for the parse cache.
  final String cacheDir;

  ParseCache({this.cacheDir = '.auto_interop_cache'});

  String get _schemasDir => p.join(cacheDir, 'schemas');
  String get _manifestPath => p.join(cacheDir, 'parse_manifest.json');

  /// Returns the cached schema for [packageName] if the [sourceChecksum]
  /// matches the cached entry. Returns `null` on cache miss.
  UnifiedTypeSchema? get(String packageName, String sourceChecksum) {
    final manifest = _loadManifest();
    final entry = manifest[packageName];
    if (entry == null) return null;
    if (entry.sourceChecksum != sourceChecksum) return null;

    final schemaFile = File(p.join(_schemasDir, '$packageName.uts.json'));
    if (!schemaFile.existsSync()) return null;

    try {
      final json =
          jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;
      return UnifiedTypeSchema.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Stores a parsed [schema] for [packageName] with the given [sourceChecksum].
  void put(
      String packageName, String sourceChecksum, UnifiedTypeSchema schema) {
    // Ensure directories exist
    Directory(_schemasDir).createSync(recursive: true);

    // Write schema file
    final schemaFile = File(p.join(_schemasDir, '$packageName.uts.json'));
    final encoder = const JsonEncoder.withIndent('  ');
    schemaFile.writeAsStringSync(encoder.convert(schema.toJson()));

    // Update manifest
    final manifest = _loadManifest();
    manifest[packageName] = ParseCacheEntry(
      sourceChecksum: sourceChecksum,
      parsedAt: DateTime.now(),
    );
    _saveManifest(manifest);
  }

  /// Removes the cached entry for [packageName].
  void remove(String packageName) {
    final schemaFile = File(p.join(_schemasDir, '$packageName.uts.json'));
    if (schemaFile.existsSync()) {
      schemaFile.deleteSync();
    }

    final manifest = _loadManifest();
    manifest.remove(packageName);
    _saveManifest(manifest);
  }

  /// Clears the entire parse cache.
  void clear() {
    final dir = Directory(cacheDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  /// Lists all cached package names.
  List<String> listCached() {
    final manifest = _loadManifest();
    return manifest.keys.toList()..sort();
  }

  Map<String, ParseCacheEntry> _loadManifest() {
    final file = File(_manifestPath);
    if (!file.existsSync()) return {};
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return json.map(
        (key, value) => MapEntry(
          key,
          ParseCacheEntry.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  void _saveManifest(Map<String, ParseCacheEntry> manifest) {
    Directory(cacheDir).createSync(recursive: true);
    final file = File(_manifestPath);
    final encoder = const JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(
      manifest.map((key, value) => MapEntry(key, value.toJson())),
    ));
  }
}
