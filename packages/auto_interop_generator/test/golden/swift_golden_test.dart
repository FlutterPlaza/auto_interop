import 'dart:io';

import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/generators/swift_glue_generator.dart';
import 'package:auto_interop_generator/src/parsers/swift_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

String _swiftFixture(String name) {
  return File('test/fixtures/swift/$name').readAsStringSync();
}

String _golden(String path) {
  return File('test/golden/$path').readAsStringSync();
}

void main() {
  late SwiftParser parser;
  late DartGenerator dartGen;
  late SwiftGlueGenerator swiftGen;

  setUp(() {
    parser = SwiftParser();
    dartGen = DartGenerator();
    swiftGen = SwiftGlueGenerator();
  });

  group('Swift golden tests', () {
    group('Alamofire', () {
      test('Dart binding matches golden', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_alamofire.swift'),
          packageName: 'Alamofire',
          version: '5.9.0',
        );
        final files = dartGen.generate(schema);
        final dartCode = files['alamofire.dart']!;
        final golden = _golden('alamofire/alamofire.dart.golden');
        expect(dartCode, golden);
      });

      test('Swift glue matches golden', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_alamofire.swift'),
          packageName: 'Alamofire',
          version: '5.9.0',
        );
        final files = swiftGen.generate(schema);
        final swiftCode = files['AlamofirePlugin.swift']!;
        final golden = _golden('alamofire/AlamofirePlugin.swift.golden');
        expect(swiftCode, golden);
      });

      test('parses expected types', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_alamofire.swift'),
          packageName: 'Alamofire',
          version: '5.9.0',
        );
        expect(schema.classes, hasLength(2)); // Session, DataRequest
        expect(schema.types, hasLength(2)); // URLRequestConfig, DataResponse
        expect(schema.enums, hasLength(1)); // HTTPMethod
      });

      test('parses struct as data class', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_alamofire.swift'),
          packageName: 'Alamofire',
          version: '5.9.0',
        );

        final urlConfig =
            schema.types.firstWhere((t) => t.name == 'URLRequestConfig');
        expect(urlConfig.kind, UtsClassKind.dataClass);
        expect(urlConfig.fields, hasLength(5));
      });

      test('parses nullable fields in struct', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_alamofire.swift'),
          packageName: 'Alamofire',
          version: '5.9.0',
        );

        final urlConfig =
            schema.types.firstWhere((t) => t.name == 'URLRequestConfig');
        final headers =
            urlConfig.fields.firstWhere((f) => f.name == 'headers');
        expect(headers.nullable, true);
      });

      test('parses async methods', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_alamofire.swift'),
          packageName: 'Alamofire',
          version: '5.9.0',
        );

        final session =
            schema.classes.firstWhere((c) => c.name == 'Session');
        final download =
            session.methods.firstWhere((m) => m.name == 'download');
        expect(download.isAsync, true);
      });

      test('parses enum values', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_alamofire.swift'),
          packageName: 'Alamofire',
          version: '5.9.0',
        );

        final httpMethod =
            schema.enums.firstWhere((e) => e.name == 'HTTPMethod');
        expect(httpMethod.values, hasLength(7));
        expect(httpMethod.values[0].name, 'get');
      });
    });

    group('SDWebImage', () {
      test('Dart binding matches golden', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_sdwebimage.swift'),
          packageName: 'SDWebImage',
          version: '5.19.0',
        );
        final files = dartGen.generate(schema);
        final dartCode = files['sdwebimage.dart']!;
        final golden = _golden('sdwebimage/sdwebimage.dart.golden');
        expect(dartCode, golden);
      });

      test('Swift glue matches golden', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_sdwebimage.swift'),
          packageName: 'SDWebImage',
          version: '5.19.0',
        );
        final files = swiftGen.generate(schema);
        final swiftCode = files['SdwebimagePlugin.swift']!;
        final golden =
            _golden('sdwebimage/SdwebimagePlugin.swift.golden');
        expect(swiftCode, golden);
      });

      test('parses expected types', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_sdwebimage.swift'),
          packageName: 'SDWebImage',
          version: '5.19.0',
        );
        expect(schema.classes,
            hasLength(3)); // SDWebImageManager, SDImageCache, SDImageResult (sealed)
        expect(schema.enums, hasLength(1)); // SDImageContentMode
      });

      test('parses sealed enum', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_sdwebimage.swift'),
          packageName: 'SDWebImage',
          version: '5.19.0',
        );

        final imageResult =
            schema.classes.firstWhere((c) => c.name == 'SDImageResult');
        expect(imageResult.kind, UtsClassKind.sealedClass);
        expect(imageResult.sealedSubclasses, ['success', 'failure']);
      });

      test('preserves documentation', () {
        final schema = parser.parse(
          content: _swiftFixture('golden_sdwebimage.swift'),
          packageName: 'SDWebImage',
          version: '5.19.0',
        );
        final files = dartGen.generate(schema);
        final code = files['sdwebimage.dart']!;
        expect(code,
            contains('Manages image downloading and caching.'));
        expect(code,
            contains('Loads an image from a URL.'));
      });
    });

    group('pipeline determinism', () {
      test('same Alamofire input produces same output', () {
        final content = _swiftFixture('golden_alamofire.swift');

        final s1 = parser.parse(
          content: content,
          packageName: 'Alamofire',
          version: '5.9.0',
        );
        final s2 = parser.parse(
          content: content,
          packageName: 'Alamofire',
          version: '5.9.0',
        );

        expect(
          dartGen.generate(s1).values.first,
          dartGen.generate(s2).values.first,
        );
        expect(
          swiftGen.generate(s1).values.first,
          swiftGen.generate(s2).values.first,
        );
      });

      test('same SDWebImage input produces same output', () {
        final content = _swiftFixture('golden_sdwebimage.swift');

        final s1 = parser.parse(
          content: content,
          packageName: 'SDWebImage',
          version: '5.19.0',
        );
        final s2 = parser.parse(
          content: content,
          packageName: 'SDWebImage',
          version: '5.19.0',
        );

        expect(
          dartGen.generate(s1).values.first,
          dartGen.generate(s2).values.first,
        );
      });
    });
  });
}
