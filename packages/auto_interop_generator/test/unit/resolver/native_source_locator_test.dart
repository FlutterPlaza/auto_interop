import 'dart:io';

import 'package:auto_interop_generator/src/config/package_spec.dart';
import 'package:auto_interop_generator/src/resolver/native_source_locator.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart'
    show PackageSource;
import 'package:test/test.dart';

void main() {
  late NativeSourceLocator locator;
  late Directory tempDir;

  setUp(() {
    locator = NativeSourceLocator();
    tempDir = Directory.systemTemp.createTempSync('nb_locator_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('NativeSourceLocator', () {
    group('explicit sourcePath', () {
      test('locates files from explicit path', () {
        final sourceDir = Directory('${tempDir.path}/sources')
          ..createSync();
        File('${sourceDir.path}/Example.swift')
            .writeAsStringSync('class Example {}');
        File('${sourceDir.path}/Helper.swift')
            .writeAsStringSync('struct Helper {}');

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Example',
          version: '1.0.0',
          sourcePath: sourceDir.path,
        );

        final result = locator.locate(spec);
        expect(result.found, isTrue);
        expect(result.files, hasLength(2));
        expect(result.location, sourceDir.path);
        expect(result.warning, isNull);
      });

      test('returns warning when sourcePath does not exist', () {
        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Example',
          version: '1.0.0',
          sourcePath: '${tempDir.path}/nonexistent',
        );

        final result = locator.locate(spec);
        expect(result.found, isFalse);
        expect(result.warning, contains('not found'));
      });

      test('returns warning when sourcePath has no matching files', () {
        final sourceDir = Directory('${tempDir.path}/empty')..createSync();
        File('${sourceDir.path}/readme.txt')
            .writeAsStringSync('not a source file');

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Example',
          version: '1.0.0',
          sourcePath: sourceDir.path,
        );

        final result = locator.locate(spec);
        expect(result.found, isFalse);
        expect(result.warning, contains('No source files'));
      });
    });

    group('cocoapods auto-detect', () {
      test('finds sources in Pods/<Name>/', () {
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          final podsDir = Directory('Pods/Alamofire')
            ..createSync(recursive: true);
          File('${podsDir.path}/Session.swift')
              .writeAsStringSync('class Session {}');

          final spec = PackageSpec(
            source: PackageSource.cocoapods,
            package: 'Alamofire',
            version: '5.9.0',
          );

          final result = locator.locate(spec);
          expect(result.found, isTrue);
          expect(result.files, hasLength(1));
        } finally {
          Directory.current = originalDir;
        }
      });

      test('returns warning when no pods directory exists', () {
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;

          final spec = PackageSpec(
            source: PackageSource.cocoapods,
            package: 'Alamofire',
            version: '5.9.0',
          );

          final result = locator.locate(spec);
          expect(result.found, isFalse);
          expect(result.warning, contains('Could not find'));
        } finally {
          Directory.current = originalDir;
        }
      });
    });

    group('npm auto-detect', () {
      test('finds types from package.json types field', () {
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          final moduleDir = Directory('node_modules/date-fns')
            ..createSync(recursive: true);
          File('${moduleDir.path}/package.json').writeAsStringSync(
              '{"types": "index.d.ts"}');
          File('${moduleDir.path}/index.d.ts')
              .writeAsStringSync('export function format(): string;');

          final spec = PackageSpec(
            source: PackageSource.npm,
            package: 'date-fns',
            version: '3.0.0',
          );

          final result = locator.locate(spec);
          expect(result.found, isTrue);
          expect(result.files, hasLength(1));
        } finally {
          Directory.current = originalDir;
        }
      });

      test('returns warning when node_modules missing', () {
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;

          final spec = PackageSpec(
            source: PackageSource.npm,
            package: 'date-fns',
            version: '3.0.0',
          );

          final result = locator.locate(spec);
          expect(result.found, isFalse);
          expect(result.warning, contains('node_modules'));
        } finally {
          Directory.current = originalDir;
        }
      });
    });

    group('gradle auto-detect', () {
      test('always returns warning requiring sourcePath', () {
        final spec = PackageSpec(
          source: PackageSource.gradle,
          package: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );

        final result = locator.locate(spec);
        expect(result.found, isFalse);
        expect(result.warning, contains('source_path'));
      });

      test('works with explicit sourcePath', () {
        final sourceDir = Directory('${tempDir.path}/gradle-src')
          ..createSync();
        File('${sourceDir.path}/OkHttpClient.kt')
            .writeAsStringSync('class OkHttpClient {}');

        final spec = PackageSpec(
          source: PackageSource.gradle,
          package: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
          sourcePath: sourceDir.path,
        );

        final result = locator.locate(spec);
        expect(result.found, isTrue);
        expect(result.files, hasLength(1));
      });
    });

    group('spm auto-detect', () {
      test('returns warning when .build/checkouts not found', () {
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;

          final spec = PackageSpec(
            source: PackageSource.spm,
            package: 'Vapor',
            version: '4.0.0',
          );

          final result = locator.locate(spec);
          expect(result.found, isFalse);
          expect(result.warning, contains('Could not find'));
        } finally {
          Directory.current = originalDir;
        }
      });
    });
  });
}
