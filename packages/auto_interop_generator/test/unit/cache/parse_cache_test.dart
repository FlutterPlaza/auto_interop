import 'dart:io';

import 'package:auto_interop_generator/src/cache/parse_cache.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ParseCache cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nb_parse_cache_test_');
    cache = ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ParseCache', () {
    final testSchema = UnifiedTypeSchema(
      package: 'test-package',
      source: PackageSource.npm,
      version: '1.0.0',
      functions: [
        UtsMethod(
          name: 'hello',
          isStatic: true,
          returnType: UtsType.primitive('String'),
        ),
      ],
    );

    test('get returns null on empty cache', () {
      final result = cache.get('test-package', 'abc123');
      expect(result, isNull);
    });

    test('put and get roundtrips schema', () {
      cache.put('test-package', 'abc123', testSchema);
      final result = cache.get('test-package', 'abc123');
      expect(result, isNotNull);
      expect(result!.package, 'test-package');
      expect(result.version, '1.0.0');
      expect(result.functions, hasLength(1));
      expect(result.functions.first.name, 'hello');
    });

    test('get returns null on checksum mismatch', () {
      cache.put('test-package', 'abc123', testSchema);
      final result = cache.get('test-package', 'different-checksum');
      expect(result, isNull);
    });

    test('get returns null for unknown package', () {
      cache.put('test-package', 'abc123', testSchema);
      final result = cache.get('other-package', 'abc123');
      expect(result, isNull);
    });

    test('remove deletes package from cache', () {
      cache.put('test-package', 'abc123', testSchema);
      expect(cache.get('test-package', 'abc123'), isNotNull);

      cache.remove('test-package');
      expect(cache.get('test-package', 'abc123'), isNull);
    });

    test('clear removes entire cache directory', () {
      cache.put('pkg1', 'sum1', testSchema);
      cache.put('pkg2', 'sum2', testSchema);

      cache.clear();

      expect(cache.get('pkg1', 'sum1'), isNull);
      expect(cache.get('pkg2', 'sum2'), isNull);
      expect(cache.listCached(), isEmpty);
    });

    test('listCached returns sorted package names', () {
      cache.put('zebra', 'z1', testSchema);
      cache.put('alpha', 'a1', testSchema);
      cache.put('middle', 'm1', testSchema);

      expect(cache.listCached(), ['alpha', 'middle', 'zebra']);
    });

    test('put overwrites existing entry', () {
      cache.put('test-package', 'old-sum', testSchema);
      expect(cache.get('test-package', 'old-sum'), isNotNull);

      final updatedSchema = UnifiedTypeSchema(
        package: 'test-package',
        source: PackageSource.npm,
        version: '2.0.0',
      );
      cache.put('test-package', 'new-sum', updatedSchema);

      expect(cache.get('test-package', 'old-sum'), isNull);
      expect(cache.get('test-package', 'new-sum'), isNotNull);
      expect(cache.get('test-package', 'new-sum')!.version, '2.0.0');
    });

    test('survives malformed manifest', () {
      // Create a malformed manifest
      final cacheDir = Directory('${tempDir.path}/.auto_interop_cache')
        ..createSync(recursive: true);
      File('${cacheDir.path}/parse_manifest.json')
          .writeAsStringSync('not valid json');

      // Should not throw, just return empty
      expect(cache.listCached(), isEmpty);
      expect(cache.get('anything', 'any'), isNull);
    });
  });
}
