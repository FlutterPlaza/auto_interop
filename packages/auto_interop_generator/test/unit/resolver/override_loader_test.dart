import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/resolver/override_loader.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  UnifiedTypeSchema _makeSchema(String name) => UnifiedTypeSchema(
        package: name,
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

  String _toJson(UnifiedTypeSchema schema) =>
      const JsonEncoder.withIndent('  ').convert(schema.toJson());

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('override_loader_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('OverrideLoader', () {
    group('flat naming', () {
      test('loads exact name match from project dir', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final schema = _makeSchema('date-fns');
        File('${projectDir.path}/date-fns.uts.json')
            .writeAsStringSync(_toJson(schema));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('date-fns');
        expect(result, isNotNull);
        expect(result!.schema.package, 'date-fns');
        expect(result.isProjectLevel, isTrue);
      });

      test('loads snake_case fallback', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final schema = _makeSchema('date-fns');
        File('${projectDir.path}/date_fns.uts.json')
            .writeAsStringSync(_toJson(schema));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('date-fns');
        expect(result, isNotNull);
        expect(result!.schema.package, 'date-fns');
      });

      test('loads lowercase fallback', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final schema = _makeSchema('Alamofire');
        File('${projectDir.path}/alamofire.uts.json')
            .writeAsStringSync(_toJson(schema));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('Alamofire');
        expect(result, isNotNull);
        expect(result!.schema.package, 'Alamofire');
      });
    });

    group('structured naming', () {
      test('loads from {source}/{package}/{version}.uts.json', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final schema = _makeSchema('date-fns');
        final structuredDir = Directory('${projectDir.path}/npm/date-fns')
          ..createSync(recursive: true);
        File('${structuredDir.path}/3.6.0.uts.json')
            .writeAsStringSync(_toJson(schema));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('date-fns', source: 'npm', version: '3.6.0');
        expect(result, isNotNull);
        expect(result!.schema.package, 'date-fns');
        expect(result.filePath, contains('npm/date-fns/3.6.0.uts.json'));
      });

      test('falls back to flat when structured not found', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final schema = _makeSchema('date-fns');
        File('${projectDir.path}/date-fns.uts.json')
            .writeAsStringSync(_toJson(schema));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('date-fns', source: 'npm', version: '4.0.0');
        expect(result, isNotNull);
        expect(result!.schema.package, 'date-fns');
      });
    });

    group('project-before-global priority', () {
      test('prefers project override over global', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final globalDir = Directory('${tempDir.path}/global_overrides')
          ..createSync();

        final projectSchema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '2.0.0',
        );
        final globalSchema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '1.0.0',
        );

        File('${projectDir.path}/date-fns.uts.json')
            .writeAsStringSync(_toJson(projectSchema));
        File('${globalDir.path}/date-fns.uts.json')
            .writeAsStringSync(_toJson(globalSchema));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: globalDir.path,
        );

        final result = loader.load('date-fns');
        expect(result, isNotNull);
        expect(result!.isProjectLevel, isTrue);
        expect(result.schema.version, '2.0.0');
      });

      test('falls back to global when project has no override', () {
        final globalDir = Directory('${tempDir.path}/global_overrides')
          ..createSync();
        final schema = _makeSchema('Alamofire');
        File('${globalDir.path}/Alamofire.uts.json')
            .writeAsStringSync(_toJson(schema));

        final loader = OverrideLoader(
          projectDir: '${tempDir.path}/no_such_project_dir',
          globalDir: globalDir.path,
        );

        final result = loader.load('Alamofire');
        expect(result, isNotNull);
        expect(result!.isProjectLevel, isFalse);
        expect(result.schema.package, 'Alamofire');
      });
    });

    group('missing dirs', () {
      test('returns null when neither directory exists', () {
        final loader = OverrideLoader(
          projectDir: '${tempDir.path}/nope1',
          globalDir: '${tempDir.path}/nope2',
        );

        final result = loader.load('date-fns');
        expect(result, isNull);
      });

      test('returns null when directories exist but no matching file', () {
        Directory('${tempDir.path}/project_overrides').createSync();
        Directory('${tempDir.path}/global_overrides').createSync();

        final loader = OverrideLoader(
          projectDir: '${tempDir.path}/project_overrides',
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('nonexistent-pkg');
        expect(result, isNull);
      });
    });

    group('scan by package field', () {
      test('finds override by scanning package field in JSON', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        // File is named differently than the package
        final schema = _makeSchema('com.squareup.okhttp3:okhttp');
        File('${projectDir.path}/okhttp.uts.json')
            .writeAsStringSync(_toJson(schema));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('com.squareup.okhttp3:okhttp');
        expect(result, isNotNull);
        expect(result!.schema.package, 'com.squareup.okhttp3:okhttp');
      });
    });

    group('invalid files', () {
      test('skips malformed JSON files gracefully', () {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        File('${projectDir.path}/bad.uts.json')
            .writeAsStringSync('not valid json');

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final result = loader.load('bad');
        expect(result, isNull);
      });
    });
  });
}
