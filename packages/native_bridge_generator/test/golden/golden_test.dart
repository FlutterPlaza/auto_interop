import 'dart:io';

import 'package:native_bridge_generator/src/generators/dart_generator.dart';
import 'package:native_bridge_generator/src/generators/js_glue_generator.dart';
import 'package:native_bridge_generator/src/parsers/npm_parser.dart';
import 'package:test/test.dart';

String _fixture(String name) {
  return File('test/fixtures/npm/$name').readAsStringSync();
}

String _golden(String path) {
  return File('test/golden/$path').readAsStringSync();
}

void main() {
  late NpmParser parser;
  late DartGenerator dartGen;
  late JsGlueGenerator jsGen;

  setUp(() {
    parser = NpmParser();
    dartGen = DartGenerator();
    jsGen = JsGlueGenerator();
  });

  group('Golden tests', () {
    group('date-fns', () {
      test('Dart binding matches golden', () {
        final schema = parser.parse(
          content: _fixture('golden_date_fns.d.ts'),
          packageName: 'date-fns',
          version: '3.6.0',
        );
        final files = dartGen.generate(schema);
        final dartCode = files['date_fns.dart']!;
        final golden = _golden('date_fns/date_fns.dart.golden');
        expect(dartCode, golden);
      });

      test('JS web binding matches golden', () {
        final schema = parser.parse(
          content: _fixture('golden_date_fns.d.ts'),
          packageName: 'date-fns',
          version: '3.6.0',
        );
        final files = jsGen.generate(schema);
        final jsCode = files['date_fns_web.dart']!;
        final golden = _golden('date_fns/date_fns_web.dart.golden');
        expect(jsCode, golden);
      });

      test('parses expected number of functions', () {
        final schema = parser.parse(
          content: _fixture('golden_date_fns.d.ts'),
          packageName: 'date-fns',
          version: '3.6.0',
        );
        expect(schema.functions, hasLength(3));
        expect(schema.types, hasLength(1));
      });

      test('preserves JSDoc documentation', () {
        final schema = parser.parse(
          content: _fixture('golden_date_fns.d.ts'),
          packageName: 'date-fns',
          version: '3.6.0',
        );
        final files = dartGen.generate(schema);
        final code = files['date_fns.dart']!;
        expect(code,
            contains('Formats a date according to the given format string.'));
        expect(code, contains(
            'Returns the number of calendar days between two dates.'));
      });
    });

    group('lodash', () {
      test('Dart binding matches golden', () {
        final schema = parser.parse(
          content: _fixture('golden_lodash.d.ts'),
          packageName: 'lodash',
          version: '4.17.21',
        );
        final files = dartGen.generate(schema);
        final dartCode = files['lodash.dart']!;
        final golden = _golden('lodash/lodash.dart.golden');
        expect(dartCode, golden);
      });

      test('JS web binding matches golden', () {
        final schema = parser.parse(
          content: _fixture('golden_lodash.d.ts'),
          packageName: 'lodash',
          version: '4.17.21',
        );
        final files = jsGen.generate(schema);
        final jsCode = files['lodash_web.dart']!;
        final golden = _golden('lodash/lodash_web.dart.golden');
        expect(jsCode, golden);
      });

      test('parses expected number of functions', () {
        final schema = parser.parse(
          content: _fixture('golden_lodash.d.ts'),
          packageName: 'lodash',
          version: '4.17.21',
        );
        expect(schema.functions, hasLength(5));
      });

      test('handles optional parameters', () {
        final schema = parser.parse(
          content: _fixture('golden_lodash.d.ts'),
          packageName: 'lodash',
          version: '4.17.21',
        );
        final chunk =
            schema.functions.firstWhere((f) => f.name == 'chunk');
        expect(chunk.parameters[1].isOptional, true);
      });
    });

    group('uuid', () {
      test('Dart binding matches golden', () {
        final schema = parser.parse(
          content: _fixture('golden_uuid.d.ts'),
          packageName: 'uuid',
          version: '9.0.0',
        );
        final files = dartGen.generate(schema);
        final dartCode = files['uuid.dart']!;
        final golden = _golden('uuid/uuid.dart.golden');
        expect(dartCode, golden);
      });

      test('JS web binding matches golden', () {
        final schema = parser.parse(
          content: _fixture('golden_uuid.d.ts'),
          packageName: 'uuid',
          version: '9.0.0',
        );
        final files = jsGen.generate(schema);
        final jsCode = files['uuid_web.dart']!;
        final golden = _golden('uuid/uuid_web.dart.golden');
        expect(jsCode, golden);
      });

      test('parses expected number of functions', () {
        final schema = parser.parse(
          content: _fixture('golden_uuid.d.ts'),
          packageName: 'uuid',
          version: '9.0.0',
        );
        expect(schema.functions, hasLength(4));
      });

      test('all functions have documentation', () {
        final schema = parser.parse(
          content: _fixture('golden_uuid.d.ts'),
          packageName: 'uuid',
          version: '9.0.0',
        );
        for (final fn in schema.functions) {
          expect(fn.documentation, isNotNull,
              reason: '${fn.name} should have documentation');
        }
      });
    });

    group('pipeline determinism', () {
      test('same input produces same output across runs', () {
        final content = _fixture('golden_date_fns.d.ts');

        final schema1 = parser.parse(
          content: content,
          packageName: 'date-fns',
          version: '3.6.0',
        );
        final schema2 = parser.parse(
          content: content,
          packageName: 'date-fns',
          version: '3.6.0',
        );

        final dart1 = dartGen.generate(schema1);
        final dart2 = dartGen.generate(schema2);
        expect(dart1['date_fns.dart'], dart2['date_fns.dart']);

        final js1 = jsGen.generate(schema1);
        final js2 = jsGen.generate(schema2);
        expect(js1['date_fns_web.dart'], js2['date_fns_web.dart']);
      });
    });
  });
}
