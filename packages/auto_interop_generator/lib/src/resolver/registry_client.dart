import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../schema/unified_type_schema.dart';

/// Result of an HTTP fetch operation.
class HttpFetchResult {
  final int statusCode;
  final String body;
  final String? etag;

  const HttpFetchResult({
    required this.statusCode,
    required this.body,
    this.etag,
  });

  bool get isOk => statusCode >= 200 && statusCode < 300;
}

/// Signature for an HTTP GET function, injectable for testing.
typedef HttpFetcher = Future<HttpFetchResult> Function(Uri url,
    {String? ifNoneMatch});

/// An entry in the registry index for a specific package version.
class RegistryVersionEntry {
  final String path;
  final String sha256;

  const RegistryVersionEntry({required this.path, required this.sha256});

  factory RegistryVersionEntry.fromJson(Map<String, dynamic> json) {
    return RegistryVersionEntry(
      path: json['path'] as String,
      sha256: json['sha256'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'path': path, 'sha256': sha256};
}

/// An entry in the registry index for a package (all versions).
class RegistryPackageEntry {
  final String latestVersion;
  final Map<String, RegistryVersionEntry> versions;

  const RegistryPackageEntry({
    required this.latestVersion,
    required this.versions,
  });

  factory RegistryPackageEntry.fromJson(Map<String, dynamic> json) {
    final versionsMap = <String, RegistryVersionEntry>{};
    final rawVersions = json['versions'] as Map<String, dynamic>? ?? {};
    for (final entry in rawVersions.entries) {
      versionsMap[entry.key] =
          RegistryVersionEntry.fromJson(entry.value as Map<String, dynamic>);
    }
    return RegistryPackageEntry(
      latestVersion: json['latestVersion'] as String,
      versions: versionsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'latestVersion': latestVersion,
        'versions': versions.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// The full registry index.
class RegistryIndex {
  final int version;
  final String updatedAt;
  final Map<String, RegistryPackageEntry> packages;

  const RegistryIndex({
    required this.version,
    required this.updatedAt,
    required this.packages,
  });

  factory RegistryIndex.fromJson(Map<String, dynamic> json) {
    final packagesMap = <String, RegistryPackageEntry>{};
    final rawPackages = json['packages'] as Map<String, dynamic>? ?? {};
    for (final entry in rawPackages.entries) {
      packagesMap[entry.key] =
          RegistryPackageEntry.fromJson(entry.value as Map<String, dynamic>);
    }
    return RegistryIndex(
      version: json['version'] as int? ?? 1,
      updatedAt: json['updatedAt'] as String? ?? '',
      packages: packagesMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'updatedAt': updatedAt,
        'packages': packages.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Metadata about the cached index (fetch time, etag).
class _IndexMeta {
  final DateTime fetchedAt;
  final String? etag;

  const _IndexMeta({required this.fetchedAt, this.etag});

  factory _IndexMeta.fromJson(Map<String, dynamic> json) {
    return _IndexMeta(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      etag: json['etag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        if (etag != null) 'etag': etag,
      };
}

/// Result of fetching a schema from the registry.
class RegistryFetchResult {
  final UnifiedTypeSchema? schema;
  final String? warning;
  final bool fromCache;

  const RegistryFetchResult(
      {this.schema, this.warning, this.fromCache = false});
}

/// Client for fetching verified `.uts.json` schemas from the cloud registry.
///
/// Registry URL: `https://raw.githubusercontent.com/FlutterPlaza/auto_interop_registry/main/`
///
/// Cache directory: `~/.auto_interop/registry_cache/`
///
/// TTL: 7 days (configurable).
class RegistryClient {
  /// Base URL of the registry.
  final String registryBaseUrl;

  /// Local cache directory path.
  final String cacheDir;

  /// Cache TTL duration.
  final Duration ttl;

  /// HTTP fetcher (injectable for testing).
  final HttpFetcher _fetcher;

  RegistryClient({
    this.registryBaseUrl =
        'https://raw.githubusercontent.com/FlutterPlaza/auto_interop_registry/main/',
    String? cacheDir,
    this.ttl = const Duration(days: 7),
    HttpFetcher? fetcher,
  })  : cacheDir = cacheDir ?? _defaultCacheDir(),
        _fetcher = fetcher ?? _defaultFetcher;

  static String _defaultCacheDir() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.auto_interop', 'registry_cache');
  }

  /// Default HTTP fetcher using dart:io HttpClient.
  static Future<HttpFetchResult> _defaultFetcher(Uri url,
      {String? ifNoneMatch}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      if (ifNoneMatch != null) {
        request.headers.set('If-None-Match', ifNoneMatch);
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final etag = response.headers.value('etag');
      return HttpFetchResult(
        statusCode: response.statusCode,
        body: body,
        etag: etag,
      );
    } finally {
      client.close();
    }
  }

  /// Fetches a schema for the given package from the registry.
  ///
  /// [packageKey] should be in the format `{source}/{package}` e.g. `npm/date-fns`.
  /// [version] is the desired version; falls back to `latestVersion` if not found.
  Future<RegistryFetchResult> fetch(String packageKey, String version) async {
    // 1. Load or fetch the index
    final index = await _getIndex();
    if (index == null) {
      return const RegistryFetchResult(
        warning: 'Could not load registry index (offline?)',
      );
    }

    // 2. Look up the package
    final pkgEntry = index.packages[packageKey];
    if (pkgEntry == null) {
      return RegistryFetchResult(
        warning: 'Package "$packageKey" not found in registry',
      );
    }

    // 3. Version matching: exact -> latestVersion
    var versionEntry = pkgEntry.versions[version];
    String resolvedVersion = version;
    if (versionEntry == null) {
      resolvedVersion = pkgEntry.latestVersion;
      versionEntry = pkgEntry.versions[resolvedVersion];
    }
    if (versionEntry == null) {
      return RegistryFetchResult(
        warning: 'No version match for "$packageKey@$version" in registry',
      );
    }

    // 4. Check local cache for schema file
    final cachedSchemaPath =
        p.join(cacheDir, 'schemas', packageKey, '$resolvedVersion.uts.json');
    final cachedSchemaFile = File(cachedSchemaPath);
    if (cachedSchemaFile.existsSync()) {
      final schema = _tryLoadSchema(cachedSchemaFile);
      if (schema != null) {
        return RegistryFetchResult(schema: schema, fromCache: true);
      }
    }

    // 5. Download from registry
    try {
      final url = Uri.parse('$registryBaseUrl${versionEntry.path}');
      final result = await _fetcher(url);
      if (!result.isOk) {
        // Try stale cache
        return _fallbackToStaleSchema(cachedSchemaFile,
            warning: 'Registry returned ${result.statusCode} for $packageKey');
      }

      // 6. Verify SHA-256
      final bodyBytes = utf8.encode(result.body);
      final digest = _sha256Hex(bodyBytes);
      if (digest != versionEntry.sha256) {
        return RegistryFetchResult(
          warning: 'SHA-256 mismatch for "$packageKey@$resolvedVersion": '
              'expected ${versionEntry.sha256}, got $digest',
        );
      }

      // 7. Cache the schema file
      cachedSchemaFile.parent.createSync(recursive: true);
      cachedSchemaFile.writeAsStringSync(result.body);

      final json = jsonDecode(result.body) as Map<String, dynamic>;
      final schema = UnifiedTypeSchema.fromJson(json);
      return RegistryFetchResult(schema: schema);
    } catch (e) {
      return _fallbackToStaleSchema(cachedSchemaFile,
          warning: 'Registry fetch failed for "$packageKey": $e');
    }
  }

  /// Lists all packages available in the registry index.
  Future<List<String>> listPackages() async {
    final index = await _getIndex();
    if (index == null) return [];
    return index.packages.keys.toList()..sort();
  }

  /// Force-fetches a specific package definition and caches it.
  Future<RegistryFetchResult> forceFetch(
      String packageKey, String version) async {
    // Invalidate any cached schema for this package/version
    final cachedSchemaPath =
        p.join(cacheDir, 'schemas', packageKey, '$version.uts.json');
    final cachedFile = File(cachedSchemaPath);
    if (cachedFile.existsSync()) cachedFile.deleteSync();

    return fetch(packageKey, version);
  }

  // ---------------------------------------------------------------------------
  // Index management
  // ---------------------------------------------------------------------------

  Future<RegistryIndex?> _getIndex() async {
    final indexFile = File(p.join(cacheDir, 'index.json'));
    final metaFile = File(p.join(cacheDir, 'index_meta.json'));

    // Check if cached index is still fresh
    if (indexFile.existsSync() && metaFile.existsSync()) {
      try {
        final meta = _IndexMeta.fromJson(
          jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>,
        );
        final age = DateTime.now().difference(meta.fetchedAt);
        if (age < ttl) {
          final json =
              jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
          return RegistryIndex.fromJson(json);
        }

        // Stale — try to re-fetch with etag
        return _fetchIndex(staleEtag: meta.etag);
      } catch (_) {
        // Corrupted cache — re-fetch
        return _fetchIndex();
      }
    }

    return _fetchIndex();
  }

  Future<RegistryIndex?> _fetchIndex({String? staleEtag}) async {
    final indexFile = File(p.join(cacheDir, 'index.json'));
    final metaFile = File(p.join(cacheDir, 'index_meta.json'));

    try {
      final url = Uri.parse('${registryBaseUrl}index.json');
      final result = await _fetcher(url, ifNoneMatch: staleEtag);

      if (result.statusCode == 304 && indexFile.existsSync()) {
        // Not modified — update fetchedAt
        final meta = _IndexMeta(fetchedAt: DateTime.now(), etag: staleEtag);
        metaFile.parent.createSync(recursive: true);
        metaFile.writeAsStringSync(jsonEncode(meta.toJson()));
        final json =
            jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
        return RegistryIndex.fromJson(json);
      }

      if (!result.isOk) {
        // Fallback to stale cache
        if (indexFile.existsSync()) {
          final json =
              jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
          return RegistryIndex.fromJson(json);
        }
        return null;
      }

      // Save fresh index + meta
      indexFile.parent.createSync(recursive: true);
      indexFile.writeAsStringSync(result.body);

      final meta = _IndexMeta(fetchedAt: DateTime.now(), etag: result.etag);
      metaFile.writeAsStringSync(jsonEncode(meta.toJson()));

      final json = jsonDecode(result.body) as Map<String, dynamic>;
      return RegistryIndex.fromJson(json);
    } catch (_) {
      // Network failure — use stale cache if available
      if (indexFile.existsSync()) {
        try {
          final json =
              jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
          return RegistryIndex.fromJson(json);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  RegistryFetchResult _fallbackToStaleSchema(File cachedFile,
      {required String warning}) {
    if (cachedFile.existsSync()) {
      final schema = _tryLoadSchema(cachedFile);
      if (schema != null) {
        return RegistryFetchResult(
          schema: schema,
          warning: '$warning (using stale cache)',
          fromCache: true,
        );
      }
    }
    return RegistryFetchResult(warning: warning);
  }

  UnifiedTypeSchema? _tryLoadSchema(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return UnifiedTypeSchema.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Computes SHA-256 hex digest using dart:io's built-in support.
  static String _sha256Hex(List<int> bytes) {
    // Use Dart's built-in SHA-256 from dart:convert/dart:io
    // We re-implement using the same approach as the existing Checksum class
    // to avoid adding a crypto dependency.
    //
    // dart:io provides no built-in SHA-256, so we shell out to the
    // platform or use a pure-Dart implementation.
    // For simplicity and to avoid new deps, we use a minimal pure-Dart SHA-256.
    return _Sha256._hash(bytes);
  }
}

// ---------------------------------------------------------------------------
// Minimal pure-Dart SHA-256 (no external dependency)
// ---------------------------------------------------------------------------

class _Sha256 {
  static const _k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2, // @formatter:on
  ];

  static int _rotr(int x, int n) =>
      ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

  static String _hash(List<int> data) {
    // Pre-processing
    final bitLen = data.length * 8;
    final padded = List<int>.from(data)..add(0x80);
    while (padded.length % 64 != 56) {
      padded.add(0);
    }
    // Append length as 64-bit big-endian
    for (var i = 56; i >= 0; i -= 8) {
      padded.add((bitLen >> i) & 0xff);
    }

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    for (var offset = 0; offset < padded.length; offset += 64) {
      final w = List<int>.filled(64, 0);
      for (var i = 0; i < 16; i++) {
        w[i] = (padded[offset + i * 4] << 24) |
            (padded[offset + i * 4 + 1] << 16) |
            (padded[offset + i * 4 + 2] << 8) |
            padded[offset + i * 4 + 3];
      }
      for (var i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^
            _rotr(w[i - 15], 18) ^
            ((w[i - 15] & 0xffffffff) >>> 3);
        final s1 = _rotr(w[i - 2], 17) ^
            _rotr(w[i - 2], 19) ^
            ((w[i - 2] & 0xffffffff) >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }

      var a = h0, b = h1, c = h2, d = h3;
      var e = h4, f = h5, g = h6, h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xffffffff;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    String hex(int v) => v.toRadixString(16).padLeft(8, '0');
    return '${hex(h0)}${hex(h1)}${hex(h2)}${hex(h3)}'
        '${hex(h4)}${hex(h5)}${hex(h6)}${hex(h7)}';
  }
}
