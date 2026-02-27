import 'dart:convert';
import 'dart:io';

/// Entry for a single downloaded package in the build manifest.
class ManifestEntry {
  /// The package version that was downloaded.
  final String version;

  /// The platform/source type (cocoapods, gradle, npm, spm).
  final String platform;

  /// The local path where sources were downloaded.
  final String path;

  /// Timestamp of the download.
  final DateTime downloadedAt;

  const ManifestEntry({
    required this.version,
    required this.platform,
    required this.path,
    required this.downloadedAt,
  });

  factory ManifestEntry.fromJson(Map<String, dynamic> json) {
    return ManifestEntry(
      version: json['version'] as String,
      platform: json['platform'] as String,
      path: json['path'] as String,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'platform': platform,
        'path': path,
        'downloadedAt': downloadedAt.toIso8601String(),
      };
}

/// Tracks which packages have been downloaded so we can skip re-downloading.
///
/// Stored at `build/auto_interop/.manifest.json`.
class BuildManifest {
  /// Per-package entries, keyed by package name.
  final Map<String, ManifestEntry> entries;

  BuildManifest({Map<String, ManifestEntry>? entries})
      : entries = entries ?? {};

  /// Loads the manifest from [buildDir]. Returns an empty manifest if the
  /// file does not exist or is malformed.
  factory BuildManifest.load(String buildDir) {
    final file = File('$buildDir/.manifest.json');
    if (!file.existsSync()) {
      return BuildManifest();
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return BuildManifest.fromJson(json);
    } on Object {
      return BuildManifest();
    }
  }

  factory BuildManifest.fromJson(Map<String, dynamic> json) {
    final entriesJson = (json['entries'] as Map<String, dynamic>?) ?? {};
    final entries = entriesJson.map(
      (key, value) => MapEntry(
        key,
        ManifestEntry.fromJson(value as Map<String, dynamic>),
      ),
    );
    return BuildManifest(entries: entries);
  }

  Map<String, dynamic> toJson() => {
        'entries': entries.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

  /// Saves the manifest to [buildDir].
  void save(String buildDir) {
    final dir = Directory(buildDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('$buildDir/.manifest.json');
    final encoder = const JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(toJson()));
  }

  /// Returns `true` if [package] at [version] is already downloaded.
  bool isUpToDate(String package, String version) {
    final entry = entries[package];
    if (entry == null) return false;
    if (entry.version != version) return false;
    // Verify the path still exists
    return Directory(entry.path).existsSync();
  }

  /// Records a successful download.
  void record(String package, String version, String platform, String path) {
    entries[package] = ManifestEntry(
      version: version,
      platform: platform,
      path: path,
      downloadedAt: DateTime.now(),
    );
  }
}
