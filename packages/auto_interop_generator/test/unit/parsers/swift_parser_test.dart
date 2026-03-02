import 'dart:io';

import 'package:auto_interop_generator/src/parsers/swift_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

String _fixture(String name) {
  return File('test/fixtures/swift/$name').readAsStringSync();
}

void main() {
  late SwiftParser parser;

  setUp(() {
    parser = SwiftParser();
  });

  group('SwiftParser', () {
    test('source is cocoapods', () {
      expect(parser.source, PackageSource.cocoapods);
    });

    group('simple class', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('simple_class.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses class name', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'NetworkClient');
      });

      test('parses class kind', () {
        expect(schema.classes[0].kind, UtsClassKind.concreteClass);
      });

      test('parses methods', () {
        expect(schema.classes[0].methods, hasLength(3));
        expect(schema.classes[0].methods[0].name, 'get');
        expect(schema.classes[0].methods[1].name, 'post');
        expect(schema.classes[0].methods[2].name, 'close');
      });

      test('parses method parameters', () {
        final postMethod = schema.classes[0].methods[1];
        expect(postMethod.parameters, hasLength(2));
        expect(postMethod.parameters[0].name, 'url');
        expect(postMethod.parameters[0].type.toDartType(), 'String');
        expect(postMethod.parameters[1].name, 'body');
        expect(postMethod.parameters[1].type.toDartType(), 'String');
      });

      test('parses return types', () {
        expect(schema.classes[0].methods[0].returnType.toDartType(), 'String');
        expect(schema.classes[0].methods[2].returnType.toDartType(), 'void');
      });

      test('parses documentation', () {
        expect(schema.classes[0].documentation,
            'A network client for making HTTP requests.');
        expect(schema.classes[0].methods[0].documentation,
            'Sends a GET request to the given URL.');
      });

      test('metadata is correct', () {
        expect(schema.package, 'TestPackage');
        expect(schema.version, '1.0.0');
        expect(schema.source, PackageSource.cocoapods);
      });
    });

    group('struct', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('struct.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses structs as data classes', () {
        expect(schema.types, hasLength(2));
        expect(schema.types[0].name, 'Coordinate');
        expect(schema.types[0].kind, UtsClassKind.dataClass);
        expect(schema.types[1].name, 'RequestConfig');
      });

      test('parses struct fields', () {
        final coord = schema.types[0];
        expect(coord.fields, hasLength(3));
        expect(coord.fields[0].name, 'latitude');
        expect(coord.fields[0].type.toDartType(), 'double');
        expect(coord.fields[0].isReadOnly, true);
        expect(coord.fields[1].name, 'longitude');
        expect(coord.fields[1].type.toDartType(), 'double');
      });

      test('parses nullable fields', () {
        final coord = schema.types[0];
        final label = coord.fields.firstWhere((f) => f.name == 'label');
        expect(label.nullable, true);
      });

      test('parses collection type fields', () {
        final config = schema.types[1];
        final headers = config.fields.firstWhere((f) => f.name == 'headers');
        expect(headers.type.toDartType(), 'Map<String, String>');
      });

      test('parses read-only vs mutable', () {
        final config = schema.types[1];
        expect(config.fields[0].isReadOnly, true); // let url
        expect(config.fields[2].isReadOnly, false); // var timeout
      });

      test('parses field documentation', () {
        final coord = schema.types[0];
        expect(coord.fields[0].documentation, 'The latitude value.');
      });
    });

    group('protocol', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('protocol.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses protocols as abstract classes', () {
        expect(schema.classes, hasLength(2));
        expect(schema.classes[0].name, 'JSONSerializable');
        expect(schema.classes[0].kind, UtsClassKind.abstractClass);
      });

      test('parses protocol methods', () {
        final proto = schema.classes[0];
        expect(proto.methods, hasLength(2));
        expect(proto.methods[0].name, 'toJSON');
        expect(proto.methods[0].returnType.toDartType(), 'String');
        expect(proto.methods[1].name, 'fromJSON');
      });

      test('parses protocol properties', () {
        final proto = schema.classes[0];
        expect(proto.fields, hasLength(1));
        expect(proto.fields[0].name, 'contentType');
        expect(proto.fields[0].isReadOnly, true);
      });

      test('parses second protocol', () {
        final cacheable = schema.classes[1];
        expect(cacheable.name, 'Cacheable');
        expect(cacheable.fields, hasLength(1));
        expect(cacheable.methods, hasLength(1));
      });

      test('parses documentation', () {
        expect(schema.classes[0].documentation,
            'A protocol for objects that can be serialized to JSON.');
      });
    });

    group('simple enum', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('enum.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses simple enums', () {
        expect(schema.enums, hasLength(2));
        expect(schema.enums[0].name, 'HTTPMethod');
        expect(schema.enums[1].name, 'LogLevel');
      });

      test('parses enum values', () {
        final httpMethod = schema.enums[0];
        expect(httpMethod.values, hasLength(5));
        expect(httpMethod.values[0].name, 'get');
        expect(httpMethod.values[1].name, 'post');
        expect(httpMethod.values[4].name, 'patch');
      });

      test('parses enum with raw values', () {
        final logLevel = schema.enums[1];
        expect(logLevel.values, hasLength(4));
        expect(logLevel.values[0].name, 'debug');
        expect(logLevel.values[0].rawValue, 'DEBUG');
        expect(logLevel.values[3].name, 'error');
        expect(logLevel.values[3].rawValue, 'ERROR');
      });

      test('parses documentation', () {
        expect(schema.enums[0].documentation,
            'HTTP methods for network requests.');
      });
    });

    group('enum with associated values', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('enum_associated.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses as sealed class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'NetworkResult');
        expect(schema.classes[0].kind, UtsClassKind.sealedClass);
      });

      test('parses sealed subclass names', () {
        expect(schema.classes[0].sealedSubclasses, hasLength(3));
        expect(schema.classes[0].sealedSubclasses,
            ['success', 'failure', 'loading']);
      });

      test('parses subclass data types', () {
        expect(schema.types, hasLength(3));

        final success = schema.types.firstWhere((t) => t.name == 'success');
        expect(success.kind, UtsClassKind.dataClass);
        expect(success.fields, hasLength(2));
        expect(success.fields[0].name, 'data');
        expect(success.fields[0].type.toDartType(), 'Uint8List');
        expect(success.fields[1].name, 'statusCode');
        expect(success.fields[1].type.toDartType(), 'int');

        final failure = schema.types.firstWhere((t) => t.name == 'failure');
        expect(failure.fields, hasLength(1));
        expect(failure.fields[0].name, 'message');
      });

      test('parses subclass without associated values', () {
        final loading = schema.types.firstWhere((t) => t.name == 'loading');
        expect(loading.kind, UtsClassKind.concreteClass);
        expect(loading.fields, isEmpty);
      });

      test('subclasses reference parent', () {
        for (final sub in schema.types) {
          expect(sub.superclass, 'NetworkResult');
        }
      });
    });

    group('async methods', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('async_methods.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses async methods as Future', () {
        final fetcher = schema.classes[0];
        final fetchData =
            fetcher.methods.firstWhere((m) => m.name == 'fetchData');
        expect(fetchData.isAsync, true);
        expect(fetchData.returnType.kind, UtsTypeKind.future);
      });

      test('parses async throws methods', () {
        final fetcher = schema.classes[0];
        final fetchString =
            fetcher.methods.firstWhere((m) => m.name == 'fetchString');
        expect(fetchString.isAsync, true);
        expect(fetchString.returnType.kind, UtsTypeKind.future);
      });

      test('parses AsyncStream as Stream', () {
        final fetcher = schema.classes[0];
        final streamMethod =
            fetcher.methods.firstWhere((m) => m.name == 'stream');
        expect(streamMethod.isAsync, true);
        expect(streamMethod.returnType.kind, UtsTypeKind.stream);
      });

      test('parses method with multiple params', () {
        final fetcher = schema.classes[0];
        final upload = fetcher.methods.firstWhere((m) => m.name == 'upload');
        expect(upload.parameters, hasLength(2));
        expect(upload.parameters[0].name, 'data');
        expect(upload.parameters[1].name, 'url');
      });
    });

    group('closures', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('closures.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses closure parameters', () {
        final handler = schema.classes[0];
        expect(handler.methods, hasLength(3));
      });

      test('parses simple callback', () {
        final handler = schema.classes[0];
        final onEvent = handler.methods.firstWhere((m) => m.name == 'onEvent');
        expect(onEvent.parameters, hasLength(1));
        final callback = onEvent.parameters[0];
        expect(callback.name, 'callback');
        expect(callback.type.kind, UtsTypeKind.callback);
      });

      test('parses callback with return type', () {
        final handler = schema.classes[0];
        final transform =
            handler.methods.firstWhere((m) => m.name == 'transform');
        final mapper = transform.parameters[0];
        expect(mapper.type.kind, UtsTypeKind.callback);
        expect(mapper.type.returnType?.toDartType(), 'int');
      });

      test('parses optional closure', () {
        final handler = schema.classes[0];
        final fetch =
            handler.methods.firstWhere((m) => m.name == 'fetchWithCompletion');
        expect(fetch.parameters, hasLength(2));
        final completion = fetch.parameters[1];
        expect(completion.name, 'completion');
        expect(completion.type.nullable, true);
        expect(completion.isOptional, true);
      });
    });

    group('extensions', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('extensions.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('folds extension methods into base class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'ImageLoader');
      });

      test('base class has all methods', () {
        final loader = schema.classes[0];
        // 1 from base class + 2 from extension
        expect(loader.methods, hasLength(3));
        expect(loader.methods[0].name, 'load');
        expect(loader.methods[1].name, 'loadResized');
        expect(loader.methods[2].name, 'clearCache');
      });

      test('extension method params are preserved', () {
        final loader = schema.classes[0];
        final loadResized =
            loader.methods.firstWhere((m) => m.name == 'loadResized');
        expect(loadResized.parameters, hasLength(3));
        expect(loadResized.parameters[0].name, 'url');
        expect(loadResized.parameters[1].name, 'width');
        expect(loadResized.parameters[2].name, 'height');
      });
    });

    group('private members', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('private_members.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('skips private methods', () {
        final cls = schema.classes[0];
        final methodNames = cls.methods.map((m) => m.name).toList();
        expect(methodNames, contains('publicMethod'));
        expect(methodNames, contains('anotherPublic'));
        expect(methodNames, isNot(contains('_helper')));
        expect(methodNames, isNot(contains('_internalHelper')));
      });

      test('includes public fields only', () {
        final cls = schema.classes[0];
        final fieldNames = cls.fields.map((f) => f.name).toList();
        expect(fieldNames, contains('publicValue'));
        expect(fieldNames, isNot(contains('_secretValue')));
      });
    });

    group('static methods', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('static_methods.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses static methods', () {
        final cls = schema.classes[0];
        final add = cls.methods.firstWhere((m) => m.name == 'add');
        expect(add.isStatic, true);
      });

      test('parses class methods as static', () {
        final cls = schema.classes[0];
        final format = cls.methods.firstWhere((m) => m.name == 'format');
        expect(format.isStatic, true);
      });

      test('non-static method is not static', () {
        final cls = schema.classes[0];
        final instance =
            cls.methods.firstWhere((m) => m.name == 'instanceMethod');
        expect(instance.isStatic, false);
      });

      test('parses static method parameters', () {
        final cls = schema.classes[0];
        final add = cls.methods.firstWhere((m) => m.name == 'add');
        expect(add.parameters, hasLength(2));
        expect(add.parameters[0].type.toDartType(), 'int');
      });
    });

    group('multi-file parsing', () {
      test('merges schemas from multiple files', () {
        final schema = parser.parseFiles(
          files: {
            'class.swift': _fixture('simple_class.swift'),
            'struct.swift': _fixture('struct.swift'),
          },
          packageName: 'TestPackage',
          version: '1.0.0',
        );

        expect(schema.classes, hasLength(1)); // NetworkClient
        expect(schema.types, hasLength(2)); // Coordinate, RequestConfig
      });
    });

    group('multi-line signatures', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('multiline_signature.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses class with multi-line methods', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'MultilineClient');
      });

      test('parses multi-line method parameters', () {
        final fetchData =
            schema.classes[0].methods.firstWhere((m) => m.name == 'fetchData');
        expect(fetchData.parameters, hasLength(3));
        expect(fetchData.parameters[0].name, 'url');
        expect(fetchData.parameters[1].name, 'method');
        expect(fetchData.parameters[2].name, 'timeout');
      });

      test('parses multi-line async method', () {
        final upload =
            schema.classes[0].methods.firstWhere((m) => m.name == 'upload');
        expect(upload.isAsync, true);
        expect(upload.parameters, hasLength(2));
      });

      test('still parses single-line methods', () {
        final simple =
            schema.classes[0].methods.firstWhere((m) => m.name == 'simple');
        expect(simple.parameters, hasLength(1));
        expect(simple.returnType.toDartType(), 'int');
      });

      test('parses all methods', () {
        expect(schema.classes[0].methods, hasLength(3));
      });
    });

    group('init constructors', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('init_constructor.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses class constructor parameters', () {
        final cls = schema.classes[0];
        expect(cls.name, 'NetworkSession');
        expect(cls.constructorParameters, isNotNull);
        expect(cls.constructorParameters, hasLength(2));
        expect(cls.constructorParameters![0].name, 'baseURL');
        expect(cls.constructorParameters![0].type.toDartType(), 'String');
        expect(cls.constructorParameters![1].name, 'timeout');
        expect(cls.constructorParameters![1].type.toDartType(), 'int');
      });

      test('class still has methods and fields', () {
        final cls = schema.classes[0];
        expect(cls.methods, hasLength(1));
        expect(cls.methods[0].name, 'request');
        expect(cls.fields, hasLength(1));
        expect(cls.fields[0].name, 'baseURL');
      });

      test('parses struct constructor parameters', () {
        final config = schema.types[0];
        expect(config.name, 'Config');
        expect(config.constructorParameters, isNotNull);
        expect(config.constructorParameters, hasLength(2));
        expect(config.constructorParameters![0].name, 'host');
        expect(config.constructorParameters![1].name, 'port');
        expect(config.constructorParameters![1].isOptional, true);
      });
    });

    group('internal filter', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('internal_filter.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('includes public class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'PublicService');
      });

      test('filters internal functions', () {
        expect(schema.functions, isEmpty);
      });
    });

    group('string-aware block finding', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('string_in_body.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses class despite braces in strings', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'Formatter');
      });

      test('parses all methods despite braces in strings and comments', () {
        expect(schema.classes[0].methods, hasLength(2));
        expect(schema.classes[0].methods[0].name, 'format');
        expect(schema.classes[0].methods[1].name, 'render');
      });
    });

    group('edge cases', () {
      test('handles empty content', () {
        final schema = parser.parse(
          content: '',
          packageName: 'empty',
          version: '1.0.0',
        );
        expect(schema.classes, isEmpty);
        expect(schema.functions, isEmpty);
        expect(schema.types, isEmpty);
        expect(schema.enums, isEmpty);
      });

      test('handles import-only content', () {
        final schema = parser.parse(
          content: 'import Foundation\nimport UIKit\n',
          packageName: 'imports',
          version: '1.0.0',
        );
        expect(schema.classes, isEmpty);
      });

      test('handles nullable return type', () {
        final schema = parser.parse(
          content: '''
public class Finder {
    public func find(key: String) -> String? {
        return nil
    }
}
''',
          packageName: 'test',
          version: '1.0.0',
        );

        final method = schema.classes[0].methods[0];
        expect(method.returnType.nullable, true);
        expect(method.returnType.toDartType(), 'String?');
      });
    });

    // ========== Phase 6A: Swift attribute stripping ==========

    group('attribute stripping', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _fixture('attributes.swift'),
          packageName: 'TestPackage',
          version: '1.0.0',
        );
      });

      test('parses class with attributed methods', () {
        final cls =
            schema.classes.firstWhere((c) => c.name == 'AttributedService');
        final names = cls.methods.map((m) => m.name).toList();
        expect(names, contains('process'));
        expect(names, contains('modernMethod'));
        expect(names, contains('bridgedMethod'));
        expect(names, contains('normalMethod'));
        expect(cls.methods, hasLength(4));
      });

      test('parses struct with attributed method', () {
        final s = schema.types.firstWhere((t) => t.name == 'AttributedStruct');
        final names = s.methods.map((m) => m.name).toList();
        expect(names, contains('compute'));
        expect(s.fields, hasLength(1));
        expect(s.fields[0].name, 'name');
      });

      test('parses protocol with attributed method', () {
        final p =
            schema.classes.firstWhere((c) => c.name == 'AttributedProtocol');
        expect(p.methods, hasLength(1));
        expect(p.methods[0].name, 'validate');
      });

      test('parses attributed top-level function', () {
        final fn =
            schema.functions.firstWhere((f) => f.name == 'attributedTopLevel');
        expect(fn.parameters, hasLength(1));
        expect(fn.parameters[0].name, 'data');
        expect(fn.returnType.toDartType(), 'String');
      });
    });
  });
}
