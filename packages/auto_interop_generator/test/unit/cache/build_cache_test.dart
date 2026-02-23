import 'dart:io';

import 'package:auto_interop_generator/src/cache/build_cache.dart';
import 'package:auto_interop_generator/src/cache/checksum.dart';
import 'package:test/test.dart';

void main() {
  group('Checksum', () {
    test('produces consistent hex strings', () {
      final hash1 = Checksum.of('hello');
      final hash2 = Checksum.of('hello');
      expect(hash1, equals(hash2));
      expect(hash1.length, 64); // SHA-256 = 64 hex chars
    });

    test('produces different hashes for different content', () {
      expect(Checksum.of('hello'), isNot(Checksum.of('world')));
    });

    test('ofAll is order-independent', () {
      final hash1 = Checksum.ofAll(['a', 'b', 'c']);
      final hash2 = Checksum.ofAll(['c', 'a', 'b']);
      expect(hash1, equals(hash2));
    });

    test('ofAll differs from individual checksums', () {
      final combined = Checksum.ofAll(['hello', 'world']);
      final single = Checksum.of('hello');
      expect(combined, isNot(single));
    });
  });

  group('PackageCacheEntry', () {
    test('roundtrip serialization', () {
      final entry = PackageCacheEntry(
        inputChecksum: 'abc123',
        outputChecksums: {'file.dart': 'def456', 'file.kt': 'ghi789'},
        generatedAt: DateTime.utc(2024, 6, 15, 10, 30),
      );

      final json = entry.toJson();
      final restored = PackageCacheEntry.fromJson(json);

      expect(restored.inputChecksum, 'abc123');
      expect(restored.outputChecksums, hasLength(2));
      expect(restored.outputChecksums['file.dart'], 'def456');
      expect(restored.generatedAt, DateTime.utc(2024, 6, 15, 10, 30));
    });
  });

  group('BuildCache', () {
    test('roundtrip serialization', () {
      final cache = BuildCache(configChecksum: 'config_hash');
      cache.recordBuild(
        'date-fns',
        inputChecksum: 'input_hash',
        outputChecksums: {'date_fns.dart': 'out_hash'},
      );

      final json = cache.toJson();
      final restored = BuildCache.fromJson(json);

      expect(restored.configChecksum, 'config_hash');
      expect(restored.packages, hasLength(1));
      expect(restored.packages['date-fns']!.inputChecksum, 'input_hash');
    });

    test('needsRebuild returns true for unknown packages', () {
      final cache = BuildCache(configChecksum: '');
      expect(cache.needsRebuild('unknown', 'any_hash'), isTrue);
    });

    test('needsRebuild returns false when checksum matches', () {
      final cache = BuildCache(configChecksum: '');
      cache.recordBuild(
        'pkg',
        inputChecksum: 'hash1',
        outputChecksums: {},
      );
      expect(cache.needsRebuild('pkg', 'hash1'), isFalse);
    });

    test('needsRebuild returns true when checksum differs', () {
      final cache = BuildCache(configChecksum: '');
      cache.recordBuild(
        'pkg',
        inputChecksum: 'hash1',
        outputChecksums: {},
      );
      expect(cache.needsRebuild('pkg', 'hash2'), isTrue);
    });

    group('file persistence', () {
      late Directory tmpDir;

      setUp(() {
        tmpDir = Directory.systemTemp.createTempSync('build_cache_test_');
      });

      tearDown(() {
        tmpDir.deleteSync(recursive: true);
      });

      test('save and load roundtrip', () {
        final file = File('${tmpDir.path}/cache.json');
        final cache = BuildCache(configChecksum: 'cfg');
        cache.recordBuild(
          'lodash',
          inputChecksum: 'lodash_in',
          outputChecksums: {'lodash.dart': 'lodash_out'},
        );
        cache.save(file);

        final loaded = BuildCache.load(file);
        expect(loaded.configChecksum, 'cfg');
        expect(loaded.packages['lodash']!.inputChecksum, 'lodash_in');
      });

      test('load returns empty cache for missing file', () {
        final file = File('${tmpDir.path}/does_not_exist.json');
        final cache = BuildCache.load(file);
        expect(cache.configChecksum, '');
        expect(cache.packages, isEmpty);
      });

      test('load returns empty cache for malformed file', () {
        final file = File('${tmpDir.path}/bad.json');
        file.writeAsStringSync('not valid json {{{');
        final cache = BuildCache.load(file);
        expect(cache.configChecksum, '');
        expect(cache.packages, isEmpty);
      });
    });
  });
}
