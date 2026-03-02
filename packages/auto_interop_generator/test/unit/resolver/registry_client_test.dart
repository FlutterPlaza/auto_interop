import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/resolver/registry_client.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  UnifiedTypeSchema makeSchema(String name) => UnifiedTypeSchema(
        package: name,
        source: PackageSource.npm,
        version: '3.6.0',
        functions: [
          UtsMethod(
            name: 'format',
            isStatic: true,
            returnType: UtsType.primitive('String'),
          ),
        ],
      );

  String toJson(UnifiedTypeSchema schema) =>
      const JsonEncoder.withIndent('  ').convert(schema.toJson());

  /// Computes the SHA-256 hex digest of [data] using the same algorithm
  /// as RegistryClient (via the public `_sha256Hex` static, accessed
  /// through `RegistryClient` internals). We replicate the built-in
  /// SHA-256 here to generate valid test checksums.
  String sha256Hex(String data) {
    // Use the same minimal pure-Dart SHA-256 that registry_client uses.
    // We can't access the private _Sha256 class, so we compute it ourselves.
    final bytes = utf8.encode(data);
    return _sha256(bytes);
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('registry_client_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('RegistryClient', () {
    group('fetch flow', () {
      test('fetches and caches a schema from registry', () async {
        final cacheDir = '${tempDir.path}/cache';
        final schemaBody = toJson(makeSchema('date-fns'));
        final checksum = sha256Hex(schemaBody);

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256: checksum,
                ),
              },
            ),
          },
        );
        final indexBody = jsonEncode(index.toJson());

        var fetchCount = 0;
        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          fetchCount++;
          if (url.path.endsWith('index.json')) {
            return HttpFetchResult(
              statusCode: 200,
              body: indexBody,
              etag: '"abc123"',
            );
          }
          return HttpFetchResult(statusCode: 200, body: schemaBody);
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final result = await client.fetch('npm/date-fns', '3.6.0');
        expect(result.schema, isNotNull);
        expect(result.schema!.package, 'date-fns');
        expect(result.warning, isNull);
        expect(fetchCount, 2); // index + schema

        // Second fetch should use cache
        final result2 = await client.fetch('npm/date-fns', '3.6.0');
        expect(result2.schema, isNotNull);
        expect(result2.fromCache, isTrue);
      });

      test('falls back to latestVersion when exact version not found',
          () async {
        final cacheDir = '${tempDir.path}/cache';
        final schemaBody = toJson(makeSchema('date-fns'));
        final checksum = sha256Hex(schemaBody);

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256: checksum,
                ),
              },
            ),
          },
        );

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          if (url.path.endsWith('index.json')) {
            return HttpFetchResult(
              statusCode: 200,
              body: jsonEncode(index.toJson()),
            );
          }
          return HttpFetchResult(statusCode: 200, body: schemaBody);
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        // Request version "4.0.0" which doesn't exist → falls back to 3.6.0
        final result = await client.fetch('npm/date-fns', '4.0.0');
        expect(result.schema, isNotNull);
        expect(result.schema!.package, 'date-fns');
      });
    });

    group('cache freshness', () {
      test('uses cached index when TTL not expired', () async {
        final cacheDir = '${tempDir.path}/cache';
        final schemaBody = toJson(makeSchema('date-fns'));
        final checksum = sha256Hex(schemaBody);

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256: checksum,
                ),
              },
            ),
          },
        );

        // Pre-populate cache
        Directory(cacheDir).createSync(recursive: true);
        File('$cacheDir/index.json')
            .writeAsStringSync(jsonEncode(index.toJson()));
        File('$cacheDir/index_meta.json').writeAsStringSync(jsonEncode({
          'fetchedAt': DateTime.now().toIso8601String(),
          'etag': '"abc"',
        }));

        // Pre-cache schema too
        final schemaDir = Directory('$cacheDir/schemas/npm/date-fns')
          ..createSync(recursive: true);
        File('${schemaDir.path}/3.6.0.uts.json').writeAsStringSync(schemaBody);

        var fetchCalled = false;
        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          fetchCalled = true;
          return const HttpFetchResult(statusCode: 500, body: '');
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final result = await client.fetch('npm/date-fns', '3.6.0');
        expect(result.schema, isNotNull);
        expect(result.fromCache, isTrue);
        expect(fetchCalled, isFalse); // Should not have hit network
      });
    });

    group('TTL expiry', () {
      test('re-fetches index when TTL expired', () async {
        final cacheDir = '${tempDir.path}/cache';
        final schemaBody = toJson(makeSchema('date-fns'));
        final checksum = sha256Hex(schemaBody);

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256: checksum,
                ),
              },
            ),
          },
        );

        // Pre-populate cache with expired timestamp
        Directory(cacheDir).createSync(recursive: true);
        File('$cacheDir/index.json')
            .writeAsStringSync(jsonEncode(index.toJson()));
        File('$cacheDir/index_meta.json').writeAsStringSync(jsonEncode({
          'fetchedAt': DateTime.now()
              .subtract(const Duration(days: 10))
              .toIso8601String(),
          'etag': '"old"',
        }));

        var indexFetched = false;
        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          if (url.path.endsWith('index.json')) {
            indexFetched = true;
            return HttpFetchResult(
              statusCode: 200,
              body: jsonEncode(index.toJson()),
              etag: '"new"',
            );
          }
          return HttpFetchResult(statusCode: 200, body: schemaBody);
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          ttl: const Duration(days: 7),
          fetcher: mockFetcher,
        );

        final result = await client.fetch('npm/date-fns', '3.6.0');
        expect(result.schema, isNotNull);
        expect(indexFetched, isTrue); // Should re-fetch
      });
    });

    group('offline fallback', () {
      test('uses stale cache when network fails', () async {
        final cacheDir = '${tempDir.path}/cache';
        final schemaBody = toJson(makeSchema('date-fns'));

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256: 'doesntmatter',
                ),
              },
            ),
          },
        );

        // Pre-populate stale cache
        Directory(cacheDir).createSync(recursive: true);
        File('$cacheDir/index.json')
            .writeAsStringSync(jsonEncode(index.toJson()));
        File('$cacheDir/index_meta.json').writeAsStringSync(jsonEncode({
          'fetchedAt': DateTime.now()
              .subtract(const Duration(days: 30))
              .toIso8601String(),
        }));

        // Pre-cache schema
        final schemaDir = Directory('$cacheDir/schemas/npm/date-fns')
          ..createSync(recursive: true);
        File('${schemaDir.path}/3.6.0.uts.json').writeAsStringSync(schemaBody);

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          throw const SocketException('No internet');
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        // Index fetch will fail, but should fall back to stale cache.
        // Schema is already cached locally.
        final result = await client.fetch('npm/date-fns', '3.6.0');
        expect(result.schema, isNotNull);
        expect(result.fromCache, isTrue);
      });

      test('returns warning when no cache and network fails', () async {
        final cacheDir = '${tempDir.path}/empty_cache';

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          throw const SocketException('No internet');
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final result = await client.fetch('npm/date-fns', '3.6.0');
        expect(result.schema, isNull);
        expect(result.warning, isNotNull);
        expect(result.warning, contains('Could not load registry index'));
      });
    });

    group('checksum verification', () {
      test('accepts schema with valid checksum', () async {
        final cacheDir = '${tempDir.path}/cache';
        final schemaBody = toJson(makeSchema('date-fns'));
        final checksum = sha256Hex(schemaBody);

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256: checksum,
                ),
              },
            ),
          },
        );

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          if (url.path.endsWith('index.json')) {
            return HttpFetchResult(
              statusCode: 200,
              body: jsonEncode(index.toJson()),
            );
          }
          return HttpFetchResult(statusCode: 200, body: schemaBody);
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final result = await client.fetch('npm/date-fns', '3.6.0');
        expect(result.schema, isNotNull);
        expect(result.warning, isNull);
      });

      test('rejects schema with mismatched checksum', () async {
        final cacheDir = '${tempDir.path}/cache';
        final schemaBody = toJson(makeSchema('date-fns'));

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256:
                      'badhash000000000000000000000000000000000000000000000000000000000',
                ),
              },
            ),
          },
        );

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          if (url.path.endsWith('index.json')) {
            return HttpFetchResult(
              statusCode: 200,
              body: jsonEncode(index.toJson()),
            );
          }
          return HttpFetchResult(statusCode: 200, body: schemaBody);
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final result = await client.fetch('npm/date-fns', '3.6.0');
        expect(result.schema, isNull);
        expect(result.warning, contains('SHA-256 mismatch'));
      });
    });

    group('listPackages', () {
      test('lists available packages from index', () async {
        final cacheDir = '${tempDir.path}/cache';

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {},
            ),
            'cocoapods/Alamofire': RegistryPackageEntry(
              latestVersion: '5.9.0',
              versions: {},
            ),
          },
        );

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          return HttpFetchResult(
            statusCode: 200,
            body: jsonEncode(index.toJson()),
          );
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final packages = await client.listPackages();
        expect(packages, ['cocoapods/Alamofire', 'npm/date-fns']);
      });

      test('returns empty list when registry is unreachable', () async {
        final cacheDir = '${tempDir.path}/empty_cache';

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          throw const SocketException('No internet');
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final packages = await client.listPackages();
        expect(packages, isEmpty);
      });
    });

    group('package not found', () {
      test('returns warning for unknown package', () async {
        final cacheDir = '${tempDir.path}/cache';

        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {},
        );

        Future<HttpFetchResult> mockFetcher(Uri url,
            {String? ifNoneMatch}) async {
          return HttpFetchResult(
            statusCode: 200,
            body: jsonEncode(index.toJson()),
          );
        }

        final client = RegistryClient(
          cacheDir: cacheDir,
          fetcher: mockFetcher,
        );

        final result = await client.fetch('npm/unknown', '1.0.0');
        expect(result.schema, isNull);
        expect(result.warning, contains('not found in registry'));
      });
    });

    group('RegistryIndex serialization', () {
      test('round-trips through JSON', () {
        final index = RegistryIndex(
          version: 1,
          updatedAt: '2026-02-23T00:00:00Z',
          packages: {
            'npm/date-fns': RegistryPackageEntry(
              latestVersion: '3.6.0',
              versions: {
                '3.6.0': const RegistryVersionEntry(
                  path: 'registry/npm/date-fns/3.6.0.uts.json',
                  sha256: 'abc123',
                ),
              },
            ),
          },
        );

        final json = index.toJson();
        final restored = RegistryIndex.fromJson(json);
        expect(restored.version, 1);
        expect(restored.packages.keys, ['npm/date-fns']);
        expect(
          restored.packages['npm/date-fns']!.versions['3.6.0']!.sha256,
          'abc123',
        );
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal pure-Dart SHA-256 for test checksum generation
// (mirrors the implementation in registry_client.dart)
// ---------------------------------------------------------------------------

String _sha256(List<int> data) {
  const k = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];

  int rotr(int x, int n) =>
      ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

  final bitLen = data.length * 8;
  final padded = List<int>.from(data)..add(0x80);
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
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
      final s0 = rotr(w[i - 15], 7) ^
          rotr(w[i - 15], 18) ^
          ((w[i - 15] & 0xffffffff) >>> 3);
      final s1 = rotr(w[i - 2], 17) ^
          rotr(w[i - 2], 19) ^
          ((w[i - 2] & 0xffffffff) >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }

    var a = h0, b = h1, c = h2, d = h3;
    var e = h4, f = h5, g = h6, h = h7;

    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
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
