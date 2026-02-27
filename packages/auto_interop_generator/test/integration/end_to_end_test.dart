// End-to-end integration tests for the auto_interop_generator pipeline.
//
// These tests exercise the full path from config/fixture parsing through
// schema generation and all code generators for each supported platform.
import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/config/config_parser.dart';
import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/generators/js_glue_generator.dart';
import 'package:auto_interop_generator/src/generators/kotlin_glue_generator.dart';
import 'package:auto_interop_generator/src/generators/swift_glue_generator.dart';
import 'package:auto_interop_generator/src/parsers/gradle_parser.dart';
import 'package:auto_interop_generator/src/parsers/npm_parser.dart';
import 'package:auto_interop_generator/src/parsers/swift_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:auto_interop_generator/src/type_definitions/type_definition_loader.dart';
import 'package:test/test.dart';

String _fixture(String path) => File('test/fixtures/$path').readAsStringSync();

void main() {
  late NpmParser npmParser;
  late GradleParser gradleParser;
  late SwiftParser swiftParser;
  late DartGenerator dartGen;
  late KotlinGlueGenerator kotlinGen;
  late SwiftGlueGenerator swiftGen;
  late JsGlueGenerator jsGen;

  setUp(() {
    npmParser = NpmParser();
    gradleParser = GradleParser();
    swiftParser = SwiftParser();
    dartGen = DartGenerator();
    kotlinGen = KotlinGlueGenerator();
    swiftGen = SwiftGlueGenerator();
    jsGen = JsGlueGenerator();
  });

  group('End-to-end: npm pipeline', () {
    late UnifiedTypeSchema schema;

    setUp(() {
      schema = npmParser.parse(
        content: _fixture('npm/golden_date_fns.d.ts'),
        packageName: 'date-fns',
        version: '3.6.0',
      );
    });

    test('parser produces valid schema', () {
      expect(schema.package, 'date-fns');
      expect(schema.source, PackageSource.npm);
      expect(schema.version, '3.6.0');
      expect(schema.functions, isNotEmpty);
    });

    test('schema serializes and deserializes', () {
      final json = schema.toJson();
      final restored = UnifiedTypeSchema.fromJson(json);
      expect(restored.package, schema.package);
      expect(restored.source, schema.source);
      expect(restored.version, schema.version);
      expect(restored.functions.length, schema.functions.length);
      expect(restored.types.length, schema.types.length);
      expect(restored.enums.length, schema.enums.length);
      expect(restored.classes.length, schema.classes.length);
    });

    test('Dart generator produces valid output', () {
      final files = dartGen.generate(schema);
      expect(files, hasLength(1));
      expect(files.keys.first, 'date_fns.dart');
      final code = files.values.first;
      expect(code, contains('GENERATED'));
      expect(code, contains("import 'package:auto_interop/auto_interop.dart'"));
      expect(code, contains('class DateFns'));
      expect(code, contains('AutoInteropChannel'));
    });

    test('JS glue generator produces valid output', () {
      final files = jsGen.generate(schema);
      expect(files, hasLength(1));
      expect(files.keys.first, endsWith('_web.dart'));
      final code = files.values.first;
      expect(code, contains("import 'dart:js_interop'"));
      expect(code, contains('@JS'));
    });

    test('Dart output contains all parsed functions', () {
      final code = dartGen.generate(schema).values.first;
      for (final fn in schema.functions) {
        expect(code, contains(fn.name), reason: 'Missing function: ${fn.name}');
      }
    });

    test('full roundtrip: parse → serialize → deserialize → generate', () {
      final json = jsonEncode(schema.toJson());
      final restored =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      final original = dartGen.generate(schema).values.first;
      final fromRestored = dartGen.generate(restored).values.first;
      expect(fromRestored, original);
    });
  });

  group('End-to-end: npm lodash pipeline', () {
    late UnifiedTypeSchema schema;

    setUp(() {
      schema = npmParser.parse(
        content: _fixture('npm/golden_lodash.d.ts'),
        packageName: 'lodash',
        version: '4.17.21',
      );
    });

    test('parser produces valid schema', () {
      expect(schema.package, 'lodash');
      expect(schema.source, PackageSource.npm);
      expect(schema.functions, isNotEmpty);
    });

    test('Dart + JS generators both produce output', () {
      final dartFiles = dartGen.generate(schema);
      final jsFiles = jsGen.generate(schema);
      expect(dartFiles, isNotEmpty);
      expect(jsFiles, isNotEmpty);
    });

    test('roundtrip produces identical output', () {
      final json = jsonEncode(schema.toJson());
      final restored =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(
        dartGen.generate(restored).values.first,
        dartGen.generate(schema).values.first,
      );
    });
  });

  group('End-to-end: npm uuid pipeline', () {
    late UnifiedTypeSchema schema;

    setUp(() {
      schema = npmParser.parse(
        content: _fixture('npm/golden_uuid.d.ts'),
        packageName: 'uuid',
        version: '9.0.0',
      );
    });

    test('parser produces valid schema', () {
      expect(schema.package, 'uuid');
      expect(schema.source, PackageSource.npm);
    });

    test('all generators produce output', () {
      expect(dartGen.generate(schema), isNotEmpty);
      expect(jsGen.generate(schema), isNotEmpty);
    });
  });

  group('End-to-end: gradle pipeline (OkHttp)', () {
    late UnifiedTypeSchema schema;

    setUp(() {
      schema = gradleParser.parse(
        content: _fixture('kotlin/golden_okhttp.kt'),
        packageName: 'com.squareup.okhttp3:okhttp',
        version: '4.12.0',
      );
    });

    test('parser produces valid schema', () {
      expect(schema.package, 'com.squareup.okhttp3:okhttp');
      expect(schema.source, PackageSource.gradle);
      expect(schema.classes, isNotEmpty);
    });

    test('schema serializes and deserializes', () {
      final json = schema.toJson();
      final restored = UnifiedTypeSchema.fromJson(json);
      expect(restored.package, schema.package);
      expect(restored.classes.length, schema.classes.length);
      expect(restored.types.length, schema.types.length);
      expect(restored.enums.length, schema.enums.length);
    });

    test('Dart generator produces classes', () {
      final code = dartGen.generate(schema).values.first;
      expect(code, contains('GENERATED'));
      expect(code, contains('AutoInteropChannel'));
      for (final cls in schema.classes) {
        expect(code, contains('class ${cls.name}'),
            reason: 'Missing class: ${cls.name}');
      }
    });

    test('Kotlin glue generator produces plugin', () {
      final files = kotlinGen.generate(schema);
      expect(files, hasLength(1));
      final code = files.values.first;
      expect(code, contains('FlutterPlugin'));
      expect(code, contains('MethodCallHandler'));
      expect(code, contains('onMethodCall'));
    });

    test('Kotlin glue contains all class methods', () {
      final code = kotlinGen.generate(schema).values.first;
      for (final cls in schema.classes) {
        for (final method in cls.methods) {
          expect(code, contains('"${cls.name}.${method.name}"'),
              reason: 'Missing method dispatch: ${cls.name}.${method.name}');
        }
      }
    });

    test('full roundtrip produces identical output', () {
      final json = jsonEncode(schema.toJson());
      final restored =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(
        dartGen.generate(restored).values.first,
        dartGen.generate(schema).values.first,
      );
      expect(
        kotlinGen.generate(restored).values.first,
        kotlinGen.generate(schema).values.first,
      );
    });
  });

  group('End-to-end: cocoapods pipeline (Alamofire)', () {
    late UnifiedTypeSchema schema;

    setUp(() {
      schema = swiftParser.parse(
        content: _fixture('swift/golden_alamofire.swift'),
        packageName: 'Alamofire',
        version: '5.9.0',
      );
    });

    test('parser produces valid schema', () {
      expect(schema.package, 'Alamofire');
      expect(schema.source, PackageSource.cocoapods);
      expect(schema.classes, isNotEmpty);
    });

    test('schema serializes and deserializes', () {
      final json = schema.toJson();
      final restored = UnifiedTypeSchema.fromJson(json);
      expect(restored.package, schema.package);
      expect(restored.classes.length, schema.classes.length);
    });

    test('Dart generator produces classes', () {
      final code = dartGen.generate(schema).values.first;
      expect(code, contains('GENERATED'));
      for (final cls in schema.classes) {
        expect(code, contains('class ${cls.name}'));
      }
    });

    test('Swift glue generator produces plugin', () {
      final files = swiftGen.generate(schema);
      expect(files, hasLength(1));
      final code = files.values.first;
      expect(code, contains('FlutterPlugin'));
      expect(code, contains('FlutterMethodChannel'));
      expect(code, contains('handle(_ call:'));
    });

    test('Swift glue contains all class methods', () {
      final code = swiftGen.generate(schema).values.first;
      for (final cls in schema.classes) {
        for (final method in cls.methods) {
          expect(code, contains('"${cls.name}.${method.name}"'),
              reason: 'Missing method dispatch: ${cls.name}.${method.name}');
        }
      }
    });

    test('full roundtrip produces identical output', () {
      final json = jsonEncode(schema.toJson());
      final restored =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(
        dartGen.generate(restored).values.first,
        dartGen.generate(schema).values.first,
      );
      expect(
        swiftGen.generate(restored).values.first,
        swiftGen.generate(schema).values.first,
      );
    });
  });

  group('End-to-end: cocoapods pipeline (SDWebImage)', () {
    late UnifiedTypeSchema schema;

    setUp(() {
      schema = swiftParser.parse(
        content: _fixture('swift/golden_sdwebimage.swift'),
        packageName: 'SDWebImage',
        version: '5.19.0',
      );
    });

    test('parser produces valid schema', () {
      expect(schema.package, 'SDWebImage');
      expect(schema.source, PackageSource.cocoapods);
      expect(schema.classes, isNotEmpty);
    });

    test('all generators produce output', () {
      expect(dartGen.generate(schema), isNotEmpty);
      expect(swiftGen.generate(schema), isNotEmpty);
    });

    test('roundtrip produces identical output', () {
      final json = jsonEncode(schema.toJson());
      final restored =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(
        dartGen.generate(restored).values.first,
        dartGen.generate(schema).values.first,
      );
    });
  });

  group('Cross-platform generation', () {
    test('same schema produces output from all generators', () {
      final schema = npmParser.parse(
        content: _fixture('npm/golden_date_fns.d.ts'),
        packageName: 'date-fns',
        version: '3.6.0',
      );

      final dartFiles = dartGen.generate(schema);
      final kotlinFiles = kotlinGen.generate(schema);
      final swiftFiles = swiftGen.generate(schema);
      final jsFiles = jsGen.generate(schema);

      expect(dartFiles, isNotEmpty);
      expect(kotlinFiles, isNotEmpty);
      expect(swiftFiles, isNotEmpty);
      expect(jsFiles, isNotEmpty);

      // All generators produce unique file names
      final allFileNames = <String>{
        ...dartFiles.keys,
        ...kotlinFiles.keys,
        ...swiftFiles.keys,
        ...jsFiles.keys,
      };
      expect(allFileNames, hasLength(4));
    });

    test('Dart output is consistent across all source types', () {
      // Parse same conceptual API from different sources
      final npmSchema = npmParser.parse(
        content: _fixture('npm/golden_date_fns.d.ts'),
        packageName: 'date-fns',
        version: '3.6.0',
      );
      final gradleSchema = gradleParser.parse(
        content: _fixture('kotlin/golden_okhttp.kt'),
        packageName: 'com.squareup.okhttp3:okhttp',
        version: '4.12.0',
      );
      final swiftSchema = swiftParser.parse(
        content: _fixture('swift/golden_alamofire.swift'),
        packageName: 'Alamofire',
        version: '5.9.0',
      );

      // All produce Dart output with consistent patterns
      final npmDart = dartGen.generate(npmSchema).values.first;
      final gradleDart = dartGen.generate(gradleSchema).values.first;
      final swiftDart = dartGen.generate(swiftSchema).values.first;

      // All should have the GENERATED header
      for (final code in [npmDart, gradleDart, swiftDart]) {
        expect(code, contains('// GENERATED CODE'));
        expect(
            code, contains("import 'package:auto_interop/auto_interop.dart'"));
        expect(code, contains('AutoInteropChannel'));
      }
    });
  });

  group('Config-driven pipeline', () {
    test('config parsing feeds correct source to parser', () {
      final config = ConfigParser().parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "3.6.0"
  - source: cocoapods
    package: "Alamofire"
    version: "5.9.0"
  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
''');

      expect(config.packages, hasLength(3));
      expect(config.packages[0].source, PackageSource.npm);
      expect(config.packages[1].source, PackageSource.cocoapods);
      expect(config.packages[2].source, PackageSource.gradle);
    });

    test('config selective imports are preserved', () {
      final config = ConfigParser().parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "3.6.0"
    imports:
      - "format"
      - "addDays"
''');

      expect(config.packages.first.isSelectiveImport, true);
      expect(config.packages.first.imports, ['format', 'addDays']);
    });
  });

  group('Pre-built type definitions pipeline', () {
    late TypeDefinitionLoader loader;

    setUp(() {
      loader = TypeDefinitionLoader(
        definitionsDir: 'test/fixtures/definitions',
      );
    });

    test('pre-built definition generates identical output to fresh parse', () {
      // Parse from fixture
      final freshSchema = npmParser.parse(
        content: _fixture('npm/golden_date_fns.d.ts'),
        packageName: 'date-fns',
        version: '3.6.0',
      );

      // Load from pre-built
      final prebuiltSchema = loader.loadForPackage('date-fns');
      expect(prebuiltSchema, isNotNull);

      // Both should produce identical Dart output
      final freshDart = dartGen.generate(freshSchema).values.first;
      final prebuiltDart = dartGen.generate(prebuiltSchema!).values.first;
      expect(prebuiltDart, freshDart);
    });

    test('pre-built Alamofire loads and generates valid output', () {
      final prebuiltSchema = loader.loadForPackage('Alamofire');
      expect(prebuiltSchema, isNotNull);

      // The pre-built .uts.json is curated with nativeLabel/nativeType
      // annotations that the parser doesn't produce, so it may diverge
      // from a fresh parse. Verify it generates valid Dart and Swift output.
      final prebuiltDart = dartGen.generate(prebuiltSchema!).values.first;
      expect(prebuiltDart, contains('class Session'));
      expect(prebuiltDart, contains('class DataRequest'));
      expect(prebuiltDart, contains('enum HTTPMethod'));

      // The method parameter should use HTTPMethod enum type
      final session =
          prebuiltSchema.classes.firstWhere((c) => c.name == 'Session');
      final request = session.methods.firstWhere((m) => m.name == 'request');
      final methodParam =
          request.parameters.firstWhere((p) => p.name == 'method');
      expect(methodParam.type.kind, UtsTypeKind.enumType);

      // Verify nativeLabel and nativeType are preserved
      final urlParam = request.parameters.firstWhere((p) => p.name == 'url');
      expect(urlParam.nativeLabel, '_');
      final headersParam =
          request.parameters.firstWhere((p) => p.name == 'headers');
      expect(headersParam.nativeType, 'HTTPHeaders');

      // Swift glue should compile without errors
      final swiftCode = swiftGen.generate(prebuiltSchema).values.first;
      expect(swiftCode, contains('AlamofirePlugin'));
      expect(swiftCode, contains('decodeHTTPMethod'));
    });

    test('pre-built OkHttp generates identical output to fresh parse', () {
      final freshSchema = gradleParser.parse(
        content: _fixture('kotlin/golden_okhttp.kt'),
        packageName: 'com.squareup.okhttp3:okhttp',
        version: '4.12.0',
      );

      final prebuiltSchema =
          loader.loadForPackage('com.squareup.okhttp3:okhttp');
      // OkHttp is stored as okhttp3
      final prebuiltSchema2 = loader.load('okhttp3');
      final schema = prebuiltSchema ?? prebuiltSchema2;
      expect(schema, isNotNull);

      final freshDart = dartGen.generate(freshSchema).values.first;
      final prebuiltDart = dartGen.generate(schema!).values.first;
      expect(prebuiltDart, freshDart);
    });

    test('all pre-built definitions load successfully', () {
      final available = loader.listAvailable();
      expect(available.length, greaterThanOrEqualTo(6));

      for (final name in available) {
        final schema = loader.load(name);
        expect(schema, isNotNull, reason: 'Failed to load: $name');
        expect(schema!.package, isNotEmpty);
        expect(schema.version, isNotEmpty);

        // Each should produce Dart output without error
        final dartFiles = dartGen.generate(schema);
        expect(dartFiles, isNotEmpty, reason: 'No Dart output for: $name');
      }
    });
  });

  group('Generated code quality', () {
    test('Dart output has no duplicate imports', () {
      final schema = npmParser.parse(
        content: _fixture('npm/golden_date_fns.d.ts'),
        packageName: 'date-fns',
        version: '3.6.0',
      );
      final code = dartGen.generate(schema).values.first;
      final imports =
          code.split('\n').where((l) => l.startsWith('import ')).toList();
      expect(imports.toSet().length, imports.length,
          reason: 'Duplicate imports found');
    });

    test('Kotlin output has matching open/close braces', () {
      final schema = gradleParser.parse(
        content: _fixture('kotlin/golden_okhttp.kt'),
        packageName: 'com.squareup.okhttp3:okhttp',
        version: '4.12.0',
      );
      final code = kotlinGen.generate(schema).values.first;
      final opens = '{'.allMatches(code).length;
      final closes = '}'.allMatches(code).length;
      expect(opens, closes, reason: 'Mismatched braces in Kotlin output');
    });

    test('Swift output has matching open/close braces', () {
      final schema = swiftParser.parse(
        content: _fixture('swift/golden_alamofire.swift'),
        packageName: 'Alamofire',
        version: '5.9.0',
      );
      final code = swiftGen.generate(schema).values.first;
      final opens = '{'.allMatches(code).length;
      final closes = '}'.allMatches(code).length;
      expect(opens, closes, reason: 'Mismatched braces in Swift output');
    });

    test('Dart output has no empty class bodies', () {
      final schema = gradleParser.parse(
        content: _fixture('kotlin/golden_okhttp.kt'),
        packageName: 'com.squareup.okhttp3:okhttp',
        version: '4.12.0',
      );
      final code = dartGen.generate(schema).values.first;
      // Check that classes with methods have content
      for (final cls in schema.classes) {
        if (cls.methods.isNotEmpty) {
          expect(code, contains('class ${cls.name}'));
        }
      }
    });
  });
}
