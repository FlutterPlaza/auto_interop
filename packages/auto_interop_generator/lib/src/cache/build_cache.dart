import 'dart:convert';
import 'dart:io';

/// Cache entry for a single package's build state.
class PackageCacheEntry {
  /// SHA-256 checksum of the input schema (UTS JSON or type definition).
  final String inputChecksum;

  /// SHA-256 checksums of generated output files, keyed by filename.
  final Map<String, String> outputChecksums;

  /// Timestamp of the last successful generation.
  final DateTime generatedAt;

  const PackageCacheEntry({
    required this.inputChecksum,
    required this.outputChecksums,
    required this.generatedAt,
  });

  factory PackageCacheEntry.fromJson(Map<String, dynamic> json) {
    return PackageCacheEntry(
      inputChecksum: json['inputChecksum'] as String,
      outputChecksums: Map<String, String>.from(json['outputChecksums'] as Map),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'inputChecksum': inputChecksum,
        'outputChecksums': outputChecksums,
        'generatedAt': generatedAt.toIso8601String(),
      };
}

/// Persistent build cache stored as `.auto_interop_cache.json`.
///
/// Tracks config checksum and per-package input/output checksums to
/// enable incremental rebuilds — skipping packages whose inputs have
/// not changed.
class BuildCache {
  /// SHA-256 checksum of the auto_interop.yaml config file.
  String configChecksum;

  /// Per-package cache entries, keyed by package name.
  final Map<String, PackageCacheEntry> packages;

  BuildCache({
    required this.configChecksum,
    Map<String, PackageCacheEntry>? packages,
  }) : packages = packages ?? {};

  /// Loads the cache from [file]. Returns an empty cache if the file
  /// does not exist or is malformed.
  factory BuildCache.load(File file) {
    if (!file.existsSync()) {
      return BuildCache(configChecksum: '');
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return BuildCache.fromJson(json);
    } on Object {
      return BuildCache(configChecksum: '');
    }
  }

  factory BuildCache.fromJson(Map<String, dynamic> json) {
    final packagesJson = (json['packages'] as Map<String, dynamic>?) ?? {};
    final packages = packagesJson.map(
      (key, value) => MapEntry(
        key,
        PackageCacheEntry.fromJson(value as Map<String, dynamic>),
      ),
    );
    return BuildCache(
      configChecksum: json['configChecksum'] as String? ?? '',
      packages: packages,
    );
  }

  Map<String, dynamic> toJson() => {
        'configChecksum': configChecksum,
        'packages': packages.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

  /// Saves the cache to [file] as formatted JSON.
  void save(File file) {
    final encoder = const JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(toJson()));
  }

  /// Returns `true` if [packageName] needs regeneration based on
  /// comparing [currentInputChecksum] against the cached value.
  bool needsRebuild(String packageName, String currentInputChecksum) {
    final entry = packages[packageName];
    if (entry == null) return true;
    return entry.inputChecksum != currentInputChecksum;
  }

  /// Records a successful build for [packageName].
  void recordBuild(
    String packageName, {
    required String inputChecksum,
    required Map<String, String> outputChecksums,
  }) {
    packages[packageName] = PackageCacheEntry(
      inputChecksum: inputChecksum,
      outputChecksums: outputChecksums,
      generatedAt: DateTime.now(),
    );
  }
}
