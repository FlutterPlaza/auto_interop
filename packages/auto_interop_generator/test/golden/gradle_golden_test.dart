import 'dart:io';

import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/generators/kotlin_glue_generator.dart';
import 'package:auto_interop_generator/src/parsers/gradle_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

String _kotlinFixture(String name) {
  return File('test/fixtures/kotlin/$name').readAsStringSync();
}

String _javaFixture(String name) {
  return File('test/fixtures/java/$name').readAsStringSync();
}

String _golden(String path) {
  return File('test/golden/$path').readAsStringSync();
}

void main() {
  late GradleParser parser;
  late DartGenerator dartGen;
  late KotlinGlueGenerator kotlinGen;

  setUp(() {
    parser = GradleParser();
    dartGen = DartGenerator();
    kotlinGen = KotlinGlueGenerator();
  });

  group('Gradle golden tests', () {
    group('OkHttp (Kotlin)', () {
      test('Dart binding matches golden', () {
        final schema = parser.parse(
          content: _kotlinFixture('golden_okhttp.kt'),
          packageName: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );
        final files = dartGen.generate(schema);
        final dartCode =
            files['com_squareup_okhttp3_okhttp.dart']!;
        final golden =
            _golden('okhttp/com_squareup_okhttp3_okhttp.dart.golden');
        expect(dartCode, golden);
      });

      test('Kotlin glue matches golden', () {
        final schema = parser.parse(
          content: _kotlinFixture('golden_okhttp.kt'),
          packageName: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );
        final files = kotlinGen.generate(schema);
        final kotlinCode =
            files['ComSquareupOkhttp3OkhttpPlugin.kt']!;
        final golden =
            _golden('okhttp/ComSquareupOkhttp3OkhttpPlugin.kt.golden');
        expect(kotlinCode, golden);
      });

      test('parses expected types', () {
        final schema = parser.parse(
          content: _kotlinFixture('golden_okhttp.kt'),
          packageName: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );
        expect(schema.classes, hasLength(2)); // OkHttpClient, Call
        expect(schema.types, hasLength(2)); // Request, Response
        expect(schema.enums, hasLength(1)); // HttpMethod
      });

      test('parses sealed class correctly', () {
        final schema = parser.parse(
          content: _kotlinFixture('golden_okhttp.kt'),
          packageName: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );

        // HttpMethod enum
        final httpMethod =
            schema.enums.firstWhere((e) => e.name == 'HttpMethod');
        expect(httpMethod.values, hasLength(4));
        expect(httpMethod.values[0].name, 'get');
      });

      test('parses data classes with nullable fields', () {
        final schema = parser.parse(
          content: _kotlinFixture('golden_okhttp.kt'),
          packageName: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );

        final request =
            schema.types.firstWhere((t) => t.name == 'Request');
        final body = request.fields.firstWhere((f) => f.name == 'body');
        expect(body.nullable, true);
      });

      test('parses suspend functions as async', () {
        final schema = parser.parse(
          content: _kotlinFixture('golden_okhttp.kt'),
          packageName: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );

        final call =
            schema.classes.firstWhere((c) => c.name == 'Call');
        final execute =
            call.methods.firstWhere((m) => m.name == 'execute');
        expect(execute.isAsync, true);
      });
    });

    group('Gson (Java)', () {
      test('Dart binding matches golden', () {
        final schema = parser.parse(
          content: _javaFixture('golden_gson.java'),
          packageName: 'com.google.code.gson:gson',
          version: '2.10.1',
        );
        final files = dartGen.generate(schema);
        final dartCode =
            files['com_google_code_gson_gson.dart']!;
        final golden =
            _golden('gson/com_google_code_gson_gson.dart.golden');
        expect(dartCode, golden);
      });

      test('Kotlin glue matches golden', () {
        final schema = parser.parse(
          content: _javaFixture('golden_gson.java'),
          packageName: 'com.google.code.gson:gson',
          version: '2.10.1',
        );
        final files = kotlinGen.generate(schema);
        final kotlinCode =
            files['ComGoogleCodeGsonGsonPlugin.kt']!;
        final golden =
            _golden('gson/ComGoogleCodeGsonGsonPlugin.kt.golden');
        expect(kotlinCode, golden);
      });

      test('parses expected types', () {
        final schema = parser.parse(
          content: _javaFixture('golden_gson.java'),
          packageName: 'com.google.code.gson:gson',
          version: '2.10.1',
        );
        expect(schema.classes, hasLength(3)); // Gson, GsonBuilder, JsonElement
      });

      test('parses interface as abstract class', () {
        final schema = parser.parse(
          content: _javaFixture('golden_gson.java'),
          packageName: 'com.google.code.gson:gson',
          version: '2.10.1',
        );

        final jsonElement =
            schema.classes.firstWhere((c) => c.name == 'JsonElement');
        expect(jsonElement.kind, UtsClassKind.abstractClass);
        expect(jsonElement.methods, hasLength(3));
      });

      test('preserves documentation', () {
        final schema = parser.parse(
          content: _javaFixture('golden_gson.java'),
          packageName: 'com.google.code.gson:gson',
          version: '2.10.1',
        );
        final files = dartGen.generate(schema);
        final code = files['com_google_code_gson_gson.dart']!;
        expect(code,
            contains('Main class for JSON serialization and deserialization.'));
        expect(code,
            contains('Deserializes a JSON string into an object.'));
      });
    });

    group('pipeline determinism', () {
      test('same Kotlin input produces same output', () {
        final content = _kotlinFixture('golden_okhttp.kt');

        final s1 = parser.parse(
          content: content,
          packageName: 'okhttp',
          version: '4.12.0',
        );
        final s2 = parser.parse(
          content: content,
          packageName: 'okhttp',
          version: '4.12.0',
        );

        expect(
          dartGen.generate(s1).values.first,
          dartGen.generate(s2).values.first,
        );
        expect(
          kotlinGen.generate(s1).values.first,
          kotlinGen.generate(s2).values.first,
        );
      });

      test('same Java input produces same output', () {
        final content = _javaFixture('golden_gson.java');

        final s1 = parser.parse(
          content: content,
          packageName: 'gson',
          version: '2.10.1',
        );
        final s2 = parser.parse(
          content: content,
          packageName: 'gson',
          version: '2.10.1',
        );

        expect(
          dartGen.generate(s1).values.first,
          dartGen.generate(s2).values.first,
        );
      });
    });
  });
}
