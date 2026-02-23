import 'dart:io';

import 'package:auto_interop_generator/src/resolver/build_manifest.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('manifest_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('BuildManifest', () {
    test('returns empty manifest when file does not exist', () {
      final manifest = BuildManifest.load('${tempDir.path}/nonexistent');
      expect(manifest.entries, isEmpty);
    });

    test('save and load round-trips correctly', () {
      final buildDir = '${tempDir.path}/build';
      final manifest = BuildManifest();
      manifest.record('date-fns', '3.0.0', 'npm', '/some/path');

      manifest.save(buildDir);

      final loaded = BuildManifest.load(buildDir);
      expect(loaded.entries, hasLength(1));
      expect(loaded.entries['date-fns']!.version, '3.0.0');
      expect(loaded.entries['date-fns']!.platform, 'npm');
      expect(loaded.entries['date-fns']!.path, '/some/path');
    });

    test('isUpToDate returns false for unknown package', () {
      final manifest = BuildManifest();
      expect(manifest.isUpToDate('unknown', '1.0.0'), isFalse);
    });

    test('isUpToDate returns false for version mismatch', () {
      final manifest = BuildManifest();
      manifest.record('pkg', '1.0.0', 'npm', tempDir.path);
      expect(manifest.isUpToDate('pkg', '2.0.0'), isFalse);
    });

    test('isUpToDate returns true when version matches and path exists', () {
      final manifest = BuildManifest();
      manifest.record('pkg', '1.0.0', 'npm', tempDir.path);
      expect(manifest.isUpToDate('pkg', '1.0.0'), isTrue);
    });

    test('isUpToDate returns false when path no longer exists', () {
      final manifest = BuildManifest();
      manifest.record('pkg', '1.0.0', 'npm', '${tempDir.path}/gone');
      expect(manifest.isUpToDate('pkg', '1.0.0'), isFalse);
    });

    test('record overwrites existing entry', () {
      final manifest = BuildManifest();
      manifest.record('pkg', '1.0.0', 'npm', '/old');
      manifest.record('pkg', '2.0.0', 'npm', '/new');
      expect(manifest.entries['pkg']!.version, '2.0.0');
      expect(manifest.entries['pkg']!.path, '/new');
    });

    test('handles malformed JSON gracefully', () {
      final buildDir = tempDir.path;
      File('$buildDir/.manifest.json').writeAsStringSync('not json');
      final manifest = BuildManifest.load(buildDir);
      expect(manifest.entries, isEmpty);
    });
  });
}
