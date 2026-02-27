import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:auto_interop_generator/src/type_definitions/type_definition_loader.dart';
import 'package:test/test.dart';

void main() {
  final defsDir = 'test/fixtures/definitions';

  group('TypeDefinitionLoader', () {
    late TypeDefinitionLoader loader;

    setUp(() {
      loader = TypeDefinitionLoader(definitionsDir: defsDir);
    });

    test('listAvailable returns all definition files', () {
      final available = loader.listAvailable();
      expect(
          available,
          containsAll([
            'alamofire',
            'date_fns',
            'lodash',
            'okhttp3',
            'sdwebimage',
            'uuid',
          ]));
    });

    test('load returns schema for existing definition', () {
      final schema = loader.load('date_fns');
      expect(schema, isNotNull);
      expect(schema!.package, 'date-fns');
      expect(schema.version, '3.6.0');
      expect(schema.source, PackageSource.npm);
    });

    test('load returns null for non-existing definition', () {
      final schema = loader.load('nonexistent');
      expect(schema, isNull);
    });

    test('loadForPackage finds by snake_case conversion', () {
      final schema = loader.loadForPackage('date-fns');
      expect(schema, isNotNull);
      expect(schema!.package, 'date-fns');
    });

    test('loadForPackage finds by lowercase', () {
      final schema = loader.loadForPackage('Alamofire');
      expect(schema, isNotNull);
      expect(schema!.package, 'Alamofire');
    });

    test('loadForPackage returns null for unknown package', () {
      final schema = loader.loadForPackage('unknown-package');
      expect(schema, isNull);
    });
  });

  group('Pre-built definitions', () {
    group('date-fns', () {
      test('has expected structure', () {
        final schema = _loadDefinition('date_fns');
        expect(schema.package, 'date-fns');
        expect(schema.source, PackageSource.npm);
        expect(schema.functions, isNotEmpty);
      });

      test('roundtrips through JSON', () {
        _verifyRoundtrip('date_fns');
      });
    });

    group('lodash', () {
      test('has expected structure', () {
        final schema = _loadDefinition('lodash');
        expect(schema.package, 'lodash');
        expect(schema.source, PackageSource.npm);
        expect(schema.functions, isNotEmpty);
      });

      test('roundtrips through JSON', () {
        _verifyRoundtrip('lodash');
      });
    });

    group('uuid', () {
      test('has expected structure', () {
        final schema = _loadDefinition('uuid');
        expect(schema.package, 'uuid');
        expect(schema.source, PackageSource.npm);
      });

      test('roundtrips through JSON', () {
        _verifyRoundtrip('uuid');
      });
    });

    group('okhttp3', () {
      test('has expected structure', () {
        final schema = _loadDefinition('okhttp3');
        expect(schema.package, 'com.squareup.okhttp3:okhttp');
        expect(schema.source, PackageSource.gradle);
        expect(schema.classes, isNotEmpty);
      });

      test('roundtrips through JSON', () {
        _verifyRoundtrip('okhttp3');
      });
    });

    group('Alamofire', () {
      test('has expected structure', () {
        final schema = _loadDefinition('alamofire');
        expect(schema.package, 'Alamofire');
        expect(schema.source, PackageSource.cocoapods);
        expect(schema.classes, isNotEmpty);
      });

      test('roundtrips through JSON', () {
        _verifyRoundtrip('alamofire');
      });
    });

    group('SDWebImage', () {
      test('has expected structure', () {
        final schema = _loadDefinition('sdwebimage');
        expect(schema.package, 'SDWebImage');
        expect(schema.source, PackageSource.cocoapods);
        expect(schema.classes, isNotEmpty);
      });

      test('roundtrips through JSON', () {
        _verifyRoundtrip('sdwebimage');
      });
    });
  });

  group('save and load', () {
    late Directory tempDir;
    late TypeDefinitionLoader loader;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('nb_typedef_test_');
      loader = TypeDefinitionLoader(definitionsDir: tempDir.path);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('can save and reload a schema', () {
      final schema = UnifiedTypeSchema(
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

      loader.save('test_package', schema);
      final loaded = loader.load('test_package');
      expect(loaded, isNotNull);
      expect(loaded!.package, 'test-package');
      expect(loaded.functions, hasLength(1));
      expect(loaded.functions.first.name, 'hello');
    });

    test('listAvailable includes saved definitions', () {
      final schema = UnifiedTypeSchema(
        package: 'my-lib',
        source: PackageSource.npm,
        version: '2.0.0',
      );
      loader.save('my_lib', schema);
      expect(loader.listAvailable(), contains('my_lib'));
    });
  });
}

UnifiedTypeSchema _loadDefinition(String name) {
  final file = File('test/fixtures/definitions/$name.uts.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return UnifiedTypeSchema.fromJson(json);
}

void _verifyRoundtrip(String name) {
  final file = File('test/fixtures/definitions/$name.uts.json');
  final originalJson = file.readAsStringSync();
  final schema = UnifiedTypeSchema.fromJson(
      jsonDecode(originalJson) as Map<String, dynamic>);
  final reserializedJson =
      const JsonEncoder.withIndent('  ').convert(schema.toJson());
  expect(reserializedJson, originalJson);
}
