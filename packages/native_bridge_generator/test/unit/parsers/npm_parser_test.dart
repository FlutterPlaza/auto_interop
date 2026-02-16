import 'dart:io';

import 'package:native_bridge_generator/src/parsers/npm_parser.dart';
import 'package:native_bridge_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

String _fixture(String name) {
  final file = File('test/fixtures/npm/$name');
  return file.readAsStringSync();
}

void main() {
  late NpmParser parser;

  setUp(() {
    parser = NpmParser();
  });

  group('NpmParser', () {
    test('source is npm', () {
      expect(parser.source, PackageSource.npm);
    });

    group('simple function declarations', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('simple_functions.d.ts'),
          packageName: 'date-fns',
          version: '3.6.0',
        );
      });

      test('parses all exported functions', () {
        expect(schema.functions, hasLength(3));
      });

      test('parses function names', () {
        expect(schema.functions[0].name, 'format');
        expect(schema.functions[1].name, 'addDays');
        expect(schema.functions[2].name, 'differenceInDays');
      });

      test('parses Date parameter as DateTime', () {
        final format = schema.functions[0];
        expect(format.parameters[0].name, 'date');
        expect(format.parameters[0].type.toDartType(), 'DateTime');
      });

      test('parses string parameter', () {
        final format = schema.functions[0];
        expect(format.parameters[1].name, 'formatStr');
        expect(format.parameters[1].type.toDartType(), 'String');
      });

      test('parses string return type', () {
        expect(schema.functions[0].returnType.toDartType(), 'String');
      });

      test('parses Date return type as DateTime', () {
        expect(schema.functions[1].returnType.toDartType(), 'DateTime');
      });

      test('parses number return type as double', () {
        expect(schema.functions[2].returnType.toDartType(), 'double');
      });

      test('parses JSDoc documentation', () {
        expect(schema.functions[0].documentation,
            'Formats a date according to the given format string.');
      });

      test('all functions are marked static', () {
        for (final fn in schema.functions) {
          expect(fn.isStatic, true);
        }
      });

      test('stores package metadata', () {
        expect(schema.package, 'date-fns');
        expect(schema.version, '3.6.0');
        expect(schema.source, PackageSource.npm);
      });
    });

    group('class with methods', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('class_with_methods.d.ts'),
          packageName: 'http-lib',
          version: '1.0.0',
        );
      });

      test('parses exported class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'HttpClient');
      });

      test('parses class methods', () {
        final cls = schema.classes[0];
        expect(cls.methods, hasLength(3));
        expect(cls.methods[0].name, 'get');
        expect(cls.methods[1].name, 'post');
        expect(cls.methods[2].name, 'close');
      });

      test('parses async method return type', () {
        final get = schema.classes[0].methods[0];
        expect(get.returnType.kind, UtsTypeKind.future);
        expect(get.isAsync, true);
      });

      test('parses void return type', () {
        final close = schema.classes[0].methods[2];
        expect(close.returnType.toDartType(), 'void');
      });

      test('parses class documentation', () {
        expect(schema.classes[0].documentation,
            'HTTP client for making requests.');
      });

      test('parses method documentation', () {
        expect(schema.classes[0].methods[0].documentation,
            'Sends a GET request.');
      });

      test('parses interface as type', () {
        expect(schema.types, hasLength(1));
        expect(schema.types[0].name, 'Response');
      });

      test('parses interface fields', () {
        final response = schema.types[0];
        expect(response.fields, hasLength(3));
        expect(response.fields[0].name, 'status');
        expect(response.fields[0].type.toDartType(), 'double');
        expect(response.fields[1].name, 'body');
        expect(response.fields[1].type.toDartType(), 'String');
      });
    });

    group('interfaces and types', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('interfaces_and_types.d.ts'),
          packageName: 'test',
          version: '1.0.0',
        );
      });

      test('parses interfaces as data classes', () {
        expect(schema.types.length, greaterThanOrEqualTo(2));
      });

      test('parses FormatOptions with optional fields', () {
        final options = schema.types.firstWhere(
            (t) => t.name == 'FormatOptions');
        expect(options.fields.length, greaterThanOrEqualTo(2));

        final locale = options.fields.firstWhere((f) => f.name == 'locale');
        expect(locale.nullable, true);
        expect(locale.type.toDartType(), 'String');
      });

      test('parses DateRange with required fields', () {
        final range = schema.types.firstWhere(
            (t) => t.name == 'DateRange');
        final start = range.fields.firstWhere((f) => f.name == 'start');
        expect(start.nullable, false);
        expect(start.type.toDartType(), 'DateTime');
      });

      test('parses type alias with object body', () {
        final locale = schema.types.where((t) => t.name == 'Locale');
        expect(locale, isNotEmpty);
      });
    });

    group('enums', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('enums.d.ts'),
          packageName: 'test',
          version: '1.0.0',
        );
      });

      test('parses all enums', () {
        expect(schema.enums, hasLength(3));
      });

      test('parses string enum', () {
        final direction = schema.enums.firstWhere(
            (e) => e.name == 'Direction');
        expect(direction.values, hasLength(4));
        expect(direction.values[0].rawValue, 'UP');
        expect(direction.values[1].rawValue, 'DOWN');
      });

      test('parses numeric enum', () {
        final status = schema.enums.firstWhere(
            (e) => e.name == 'HttpStatus');
        expect(status.values, hasLength(3));

        final ok = status.values.firstWhere((v) => v.name == 'ok');
        expect(ok.rawValue, 200);
      });

      test('converts enum value names to camelCase', () {
        final direction = schema.enums.firstWhere(
            (e) => e.name == 'Direction');
        // "Up" → "up", "Down" → "down"
        expect(direction.values[0].name, 'up');
        expect(direction.values[1].name, 'down');
      });
    });

    group('optional parameters', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('optional_params.d.ts'),
          packageName: 'test',
          version: '1.0.0',
        );
      });

      test('parses optional string parameter', () {
        final greet = schema.functions.firstWhere(
            (f) => f.name == 'greet');
        expect(greet.parameters, hasLength(2));
        expect(greet.parameters[0].isOptional, false);
        expect(greet.parameters[1].isOptional, true);
        expect(greet.parameters[1].isNamed, true);
      });

      test('parses function with optional object parameter', () {
        final fetch = schema.functions.firstWhere(
            (f) => f.name == 'fetch');
        expect(fetch.parameters, hasLength(2));
        expect(fetch.parameters[1].isOptional, true);
      });
    });

    group('async and streams', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('async_and_streams.d.ts'),
          packageName: 'test',
          version: '1.0.0',
        );
      });

      test('parses Promise<string> as Future<String>', () {
        final fetchData = schema.functions.firstWhere(
            (f) => f.name == 'fetchData');
        expect(fetchData.returnType.kind, UtsTypeKind.future);
        expect(fetchData.returnType.toDartType(), 'Future<String>');
        expect(fetchData.isAsync, true);
      });

      test('parses Promise<Buffer> as Future<Uint8List>', () {
        final download = schema.functions.firstWhere(
            (f) => f.name == 'downloadFile');
        expect(download.returnType.toDartType(), 'Future<Uint8List>');
      });

      test('parses ReadableStream<string> as Stream<String>', () {
        final watch = schema.functions.firstWhere(
            (f) => f.name == 'watchChanges');
        expect(watch.returnType.kind, UtsTypeKind.stream);
        expect(watch.returnType.toDartType(), 'Stream<String>');
      });
    });

    group('callbacks', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('callbacks.d.ts'),
          packageName: 'test',
          version: '1.0.0',
        );
      });

      test('parses function with callback parameter', () {
        final addEventListener = schema.functions.firstWhere(
            (f) => f.name == 'addEventListener');
        expect(addEventListener.parameters, hasLength(2));

        final handler = addEventListener.parameters[1];
        expect(handler.type.kind, UtsTypeKind.callback);
      });

      test('parses timer callback (no params)', () {
        final timer = schema.functions.firstWhere(
            (f) => f.name == 'createTimer');
        expect(timer.parameters[1].type.kind, UtsTypeKind.callback);
      });
    });

    group('private API filtering', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('private_apis.d.ts'),
          packageName: 'test',
          version: '1.0.0',
        );
      });

      test('includes public functions', () {
        final names = schema.functions.map((f) => f.name).toList();
        expect(names, contains('publicFunction'));
        expect(names, contains('anotherPublic'));
      });

      test('excludes underscore-prefixed functions', () {
        final names = schema.functions.map((f) => f.name).toList();
        expect(names, isNot(contains('_privateHelper')));
        expect(names, isNot(contains('__internalFunction')));
      });

      test('includes public class but excludes private methods', () {
        expect(schema.classes, hasLength(1));
        final cls = schema.classes[0];
        expect(cls.name, 'PublicClass');
        final methodNames = cls.methods.map((m) => m.name).toList();
        expect(methodNames, contains('publicMethod'));
        expect(methodNames, isNot(contains('_privateMethod')));
      });
    });

    group('parseFiles (multi-file)', () {
      test('merges multiple files into single schema', () {
        final schema = parser.parseFiles(
          files: {
            'funcs.d.ts': _fixture('simple_functions.d.ts'),
            'enums.d.ts': _fixture('enums.d.ts'),
          },
          packageName: 'multi',
          version: '1.0.0',
        );

        expect(schema.functions.length, greaterThan(0));
        expect(schema.enums.length, greaterThan(0));
        expect(schema.package, 'multi');
      });

      test('deduplicates by name when merging', () {
        final schema = parser.parseFiles(
          files: {
            'a.d.ts': _fixture('simple_functions.d.ts'),
            'b.d.ts': _fixture('simple_functions.d.ts'),
          },
          packageName: 'dedup',
          version: '1.0.0',
        );

        expect(schema.functions, hasLength(3));
      });
    });
  });
}
