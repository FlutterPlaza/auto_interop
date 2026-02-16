import 'dart:io';

import 'package:auto_interop_generator/src/parsers/gradle_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

String _kotlinFixture(String name) {
  return File('test/fixtures/kotlin/$name').readAsStringSync();
}

String _javaFixture(String name) {
  return File('test/fixtures/java/$name').readAsStringSync();
}

void main() {
  late GradleParser parser;

  setUp(() {
    parser = GradleParser();
  });

  group('GradleParser', () {
    test('source is gradle', () {
      expect(parser.source, PackageSource.gradle);
    });

    // ========== Kotlin Tests ==========

    group('Kotlin: simple class', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('simple_class.kt'),
          packageName: 'com.example.lib',
          version: '1.0.0',
        );
      });

      test('parses class', () {
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

      test('parses method parameters', () {
        final get = schema.classes[0].methods[0];
        expect(get.parameters, hasLength(1));
        expect(get.parameters[0].name, 'url');
        expect(get.parameters[0].type.toDartType(), 'String');
      });

      test('parses return type as object reference', () {
        final get = schema.classes[0].methods[0];
        expect(get.returnType.toDartType(), 'Response');
      });

      test('parses void return type', () {
        final close = schema.classes[0].methods[2];
        expect(close.returnType.toDartType(), 'void');
      });

      test('parses class documentation', () {
        expect(schema.classes[0].documentation,
            'A simple HTTP client for making requests.');
      });

      test('parses method documentation', () {
        expect(schema.classes[0].methods[0].documentation,
            'Sends a GET request to the given URL.');
      });
    });

    group('Kotlin: data class', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('data_class.kt'),
          packageName: 'com.example.model',
          version: '1.0.0',
        );
      });

      test('parses data classes as types', () {
        expect(schema.types, hasLength(2));
      });

      test('parses Response data class fields', () {
        final response =
            schema.types.firstWhere((t) => t.name == 'Response');
        expect(response.fields, hasLength(4));
        expect(response.kind, UtsClassKind.dataClass);
      });

      test('parses field types', () {
        final response =
            schema.types.firstWhere((t) => t.name == 'Response');
        final code = response.fields.firstWhere((f) => f.name == 'code');
        expect(code.type.toDartType(), 'int');

        final message =
            response.fields.firstWhere((f) => f.name == 'message');
        expect(message.type.toDartType(), 'String');
      });

      test('parses nullable field', () {
        final response =
            schema.types.firstWhere((t) => t.name == 'Response');
        final body = response.fields.firstWhere((f) => f.name == 'body');
        expect(body.nullable, true);
      });

      test('parses Map field type', () {
        final response =
            schema.types.firstWhere((t) => t.name == 'Response');
        final headers =
            response.fields.firstWhere((f) => f.name == 'headers');
        expect(headers.type.toDartType(), 'Map<String, String>');
      });

      test('parses Request fields', () {
        final request =
            schema.types.firstWhere((t) => t.name == 'Request');
        expect(request.fields, hasLength(4));

        final body = request.fields.firstWhere((f) => f.name == 'body');
        expect(body.nullable, true);
        expect(body.type.toDartType(), 'Uint8List');
      });

      test('parses documentation', () {
        final response =
            schema.types.firstWhere((t) => t.name == 'Response');
        expect(response.documentation, 'Represents an HTTP response.');
      });

      test('marks val fields as read-only', () {
        final response =
            schema.types.firstWhere((t) => t.name == 'Response');
        for (final field in response.fields) {
          expect(field.isReadOnly, true);
        }
      });
    });

    group('Kotlin: sealed class', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('sealed_class.kt'),
          packageName: 'com.example.result',
          version: '1.0.0',
        );
      });

      test('parses sealed class', () {
        expect(schema.classes, hasLength(1));
        final result = schema.classes[0];
        expect(result.name, 'Result');
        expect(result.kind, UtsClassKind.sealedClass);
      });

      test('parses sealed subclass names', () {
        final result = schema.classes[0];
        expect(result.sealedSubclasses,
            containsAll(['Success', 'Failure', 'Loading']));
      });

      test('parses data subclasses as types', () {
        expect(schema.types.length, greaterThanOrEqualTo(2));

        final success =
            schema.types.firstWhere((t) => t.name == 'Success');
        expect(success.fields, hasLength(1));
        expect(success.fields[0].name, 'data');
        expect(success.superclass, 'Result');

        final failure =
            schema.types.firstWhere((t) => t.name == 'Failure');
        expect(failure.fields, hasLength(2));
      });

      test('parses object subclass', () {
        final loading =
            schema.types.firstWhere((t) => t.name == 'Loading');
        expect(loading.fields, isEmpty);
        expect(loading.superclass, 'Result');
      });

      test('parses documentation', () {
        expect(schema.classes[0].documentation,
            'Represents the result of an operation.');
      });
    });

    group('Kotlin: enum class', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('enum_class.kt'),
          packageName: 'com.example.enums',
          version: '1.0.0',
        );
      });

      test('parses all enums', () {
        expect(schema.enums, hasLength(2));
      });

      test('parses HttpMethod enum values', () {
        final httpMethod =
            schema.enums.firstWhere((e) => e.name == 'HttpMethod');
        expect(httpMethod.values, hasLength(5));
        expect(httpMethod.values[0].name, 'get');
        expect(httpMethod.values[0].rawValue, 'GET');
        expect(httpMethod.values[1].name, 'post');
      });

      test('parses LogLevel enum with documentation', () {
        final logLevel =
            schema.enums.firstWhere((e) => e.name == 'LogLevel');
        expect(logLevel.values, hasLength(4));
        expect(logLevel.documentation, 'Log severity levels.');
        expect(logLevel.values[0].documentation, 'Debug level logging.');
      });

      test('converts enum names to camelCase', () {
        final httpMethod =
            schema.enums.firstWhere((e) => e.name == 'HttpMethod');
        expect(httpMethod.values[0].name, 'get');
        expect(httpMethod.values[4].name, 'patch');
      });
    });

    group('Kotlin: suspend and Flow', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('suspend_and_flow.kt'),
          packageName: 'com.example.async',
          version: '1.0.0',
        );
      });

      test('parses suspend function as async', () {
        final fetchData =
            schema.functions.firstWhere((f) => f.name == 'fetchData');
        expect(fetchData.isAsync, true);
        expect(fetchData.returnType.kind, UtsTypeKind.future);
        expect(fetchData.returnType.toDartType(), 'Future<String>');
      });

      test('parses suspend with ByteArray return', () {
        final download =
            schema.functions.firstWhere((f) => f.name == 'downloadFile');
        expect(download.returnType.toDartType(), 'Future<Uint8List>');
      });

      test('parses Flow as Stream', () {
        final watch =
            schema.functions.firstWhere((f) => f.name == 'watchChanges');
        expect(watch.returnType.kind, UtsTypeKind.stream);
        expect(watch.returnType.toDartType(), 'Stream<String>');
      });

      test('parses Flow<Object> as Stream<Object>', () {
        final logs =
            schema.functions.firstWhere((f) => f.name == 'streamLogs');
        expect(logs.returnType.kind, UtsTypeKind.stream);
      });

      test('parses associated data class', () {
        final logEntry =
            schema.types.firstWhere((t) => t.name == 'LogEntry');
        expect(logEntry.fields, hasLength(3));
      });
    });

    group('Kotlin: companion object', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('companion_object.kt'),
          packageName: 'com.example.factory',
          version: '1.0.0',
        );
      });

      test('parses class with companion methods', () {
        expect(schema.classes, hasLength(1));
        final cls = schema.classes[0];
        expect(cls.name, 'RequestBody');
      });

      test('companion methods are marked static', () {
        final cls = schema.classes[0];
        expect(cls.methods, hasLength(3));
        for (final method in cls.methods) {
          expect(method.isStatic, true,
              reason: '${method.name} should be static');
        }
      });

      test('parses companion method names', () {
        final names = schema.classes[0].methods.map((m) => m.name).toList();
        expect(names, contains('fromString'));
        expect(names, contains('fromBytes'));
        expect(names, contains('empty'));
      });

      test('parses companion method documentation', () {
        final fromString = schema.classes[0].methods
            .firstWhere((m) => m.name == 'fromString');
        expect(fromString.documentation,
            'Creates a request body from a string.');
      });
    });

    group('Kotlin: interface', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('interface.kt'),
          packageName: 'com.example.contracts',
          version: '1.0.0',
        );
      });

      test('parses interfaces as abstract classes', () {
        expect(schema.classes, hasLength(2));
        for (final cls in schema.classes) {
          expect(cls.kind, UtsClassKind.abstractClass);
        }
      });

      test('parses Callback interface methods', () {
        final callback =
            schema.classes.firstWhere((c) => c.name == 'Callback');
        expect(callback.methods, hasLength(2));
        expect(callback.methods[0].name, 'onSuccess');
        expect(callback.methods[1].name, 'onError');
      });

      test('parses Repository with suspend methods', () {
        final repo =
            schema.classes.firstWhere((c) => c.name == 'Repository');
        expect(repo.methods, hasLength(3));

        final findById =
            repo.methods.firstWhere((m) => m.name == 'findById');
        expect(findById.isAsync, true);
        expect(findById.returnType.kind, UtsTypeKind.future);
      });

      test('parses interface documentation', () {
        final callback =
            schema.classes.firstWhere((c) => c.name == 'Callback');
        expect(callback.documentation,
            'Callback interface for asynchronous operations.');
      });
    });

    group('Kotlin: private member filtering', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _kotlinFixture('private_members.kt'),
          packageName: 'com.example.visibility',
          version: '1.0.0',
        );
      });

      test('includes public class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'PublicService');
      });

      test('excludes private class', () {
        final names = schema.classes.map((c) => c.name).toList();
        expect(names, isNot(contains('PrivateHelper')));
      });

      test('includes public methods in class', () {
        final methods =
            schema.classes[0].methods.map((m) => m.name).toList();
        expect(methods, contains('publicMethod'));
      });

      test('excludes private methods', () {
        final methods =
            schema.classes[0].methods.map((m) => m.name).toList();
        expect(methods, isNot(contains('_transform')));
      });

      test('excludes internal methods', () {
        final methods =
            schema.classes[0].methods.map((m) => m.name).toList();
        expect(methods, isNot(contains('internalHelper')));
      });

      test('includes public top-level function', () {
        final names = schema.functions.map((f) => f.name).toList();
        expect(names, contains('publicFunction'));
      });

      test('excludes private top-level function', () {
        final names = schema.functions.map((f) => f.name).toList();
        expect(names, isNot(contains('privateFunction')));
      });
    });

    // ========== Java Tests ==========

    group('Java: simple class', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _javaFixture('simple_class.java'),
          packageName: 'com.google.gson',
          version: '2.10.1',
        );
      });

      test('parses class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'Gson');
      });

      test('parses class methods', () {
        final cls = schema.classes[0];
        expect(cls.methods, hasLength(3));
        expect(cls.methods[0].name, 'fromJson');
        expect(cls.methods[1].name, 'toJson');
        expect(cls.methods[2].name, 'newBuilder');
      });

      test('parses method parameters', () {
        final fromJson = schema.classes[0].methods[0];
        expect(fromJson.parameters, hasLength(1));
        expect(fromJson.parameters[0].name, 'json');
        expect(fromJson.parameters[0].type.toDartType(), 'String');
      });

      test('parses return types', () {
        final fromJson = schema.classes[0].methods[0];
        expect(fromJson.returnType.toDartType(), 'String');

        final newBuilder = schema.classes[0].methods[2];
        expect(newBuilder.returnType.toDartType(), 'GsonBuilder');
      });

      test('parses documentation', () {
        expect(schema.classes[0].documentation,
            'Main class for JSON serialization and deserialization.');
      });

      test('parses method documentation', () {
        expect(schema.classes[0].methods[0].documentation,
            'Deserializes a JSON string into an object.');
      });
    });

    group('Java: interface', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _javaFixture('interface.java'),
          packageName: 'com.google.gson',
          version: '2.10.1',
        );
      });

      test('parses interface as abstract class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'JsonElement');
        expect(schema.classes[0].kind, UtsClassKind.abstractClass);
      });

      test('parses interface methods', () {
        final cls = schema.classes[0];
        expect(cls.methods, hasLength(5));
        expect(cls.methods[0].name, 'isJsonArray');
        expect(cls.methods[0].returnType.toDartType(), 'bool');
      });

      test('parses method return types', () {
        final cls = schema.classes[0];
        final getAsString =
            cls.methods.firstWhere((m) => m.name == 'getAsString');
        expect(getAsString.returnType.toDartType(), 'String');

        final getAsInt =
            cls.methods.firstWhere((m) => m.name == 'getAsInt');
        expect(getAsInt.returnType.toDartType(), 'int');

        final getAsDouble =
            cls.methods.firstWhere((m) => m.name == 'getAsDouble');
        expect(getAsDouble.returnType.toDartType(), 'double');
      });
    });

    group('Java: enum', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _javaFixture('enum.java'),
          packageName: 'com.example',
          version: '1.0.0',
        );
      });

      test('parses enum', () {
        expect(schema.enums, hasLength(1));
        expect(schema.enums[0].name, 'DateFormat');
      });

      test('parses enum values', () {
        final e = schema.enums[0];
        expect(e.values, hasLength(3));
        expect(e.values[0].rawValue, 'ISO_8601');
        expect(e.values[1].rawValue, 'RFC_2822');
        expect(e.values[2].rawValue, 'UNIX_TIMESTAMP');
      });

      test('converts enum names to camelCase', () {
        final e = schema.enums[0];
        expect(e.values[0].name, 'iso8601');
        expect(e.values[1].name, 'rfc2822');
        expect(e.values[2].name, 'unixTimestamp');
      });

      test('parses enum documentation', () {
        expect(schema.enums[0].documentation, 'Supported date formats.');
      });

      test('parses enum value documentation', () {
        expect(schema.enums[0].values[0].documentation, 'ISO 8601 format.');
      });
    });

    group('Java: static methods', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _javaFixture('static_methods.java'),
          packageName: 'com.example',
          version: '1.0.0',
        );
      });

      test('parses class with static methods', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'StringUtils');
      });

      test('marks methods as static', () {
        for (final method in schema.classes[0].methods) {
          expect(method.isStatic, true,
              reason: '${method.name} should be static');
        }
      });

      test('parses static method parameters', () {
        final isEmpty = schema.classes[0].methods
            .firstWhere((m) => m.name == 'isEmpty');
        expect(isEmpty.parameters, hasLength(1));
        expect(isEmpty.parameters[0].name, 'str');
        expect(isEmpty.parameters[0].type.toDartType(), 'String');
      });

      test('parses return types', () {
        final isEmpty = schema.classes[0].methods
            .firstWhere((m) => m.name == 'isEmpty');
        expect(isEmpty.returnType.toDartType(), 'bool');

        final reverse = schema.classes[0].methods
            .firstWhere((m) => m.name == 'reverse');
        expect(reverse.returnType.toDartType(), 'String');
      });
    });

    group('Java: builder pattern', () {
      late UnifiedTypeSchema schema;

      setUp(() {
        schema = parser.parse(
          content: _javaFixture('fields_and_methods.java'),
          packageName: 'com.example',
          version: '1.0.0',
        );
      });

      test('parses builder class', () {
        expect(schema.classes, hasLength(1));
        expect(schema.classes[0].name, 'GsonBuilder');
      });

      test('parses builder methods', () {
        final cls = schema.classes[0];
        expect(cls.methods, hasLength(4));
        expect(cls.methods.map((m) => m.name),
            containsAll(['setPrettyPrinting', 'setDateFormat',
                'serializeNulls', 'create']));
      });

      test('parses method with boolean parameter', () {
        final serialize = schema.classes[0].methods
            .firstWhere((m) => m.name == 'serializeNulls');
        expect(serialize.parameters, hasLength(1));
        expect(serialize.parameters[0].type.toDartType(), 'bool');
      });
    });

    // ========== Multi-file merging ==========

    group('parseFiles (multi-file)', () {
      test('merges Kotlin and Java files', () {
        final schema = parser.parseFiles(
          files: {
            'HttpClient.kt': _kotlinFixture('simple_class.kt'),
            'enum.java': _javaFixture('enum.java'),
          },
          packageName: 'multi',
          version: '1.0.0',
        );
        expect(schema.classes.length, greaterThan(0));
        expect(schema.enums.length, greaterThan(0));
      });

      test('deduplicates by name', () {
        final schema = parser.parseFiles(
          files: {
            'a.kt': _kotlinFixture('simple_class.kt'),
            'b.kt': _kotlinFixture('simple_class.kt'),
          },
          packageName: 'dedup',
          version: '1.0.0',
        );
        expect(schema.classes, hasLength(1));
      });
    });

    group('package metadata', () {
      test('stores package name and version', () {
        final schema = parser.parse(
          content: _kotlinFixture('simple_class.kt'),
          packageName: 'com.example',
          version: '2.0.0',
        );
        expect(schema.package, 'com.example');
        expect(schema.version, '2.0.0');
        expect(schema.source, PackageSource.gradle);
      });
    });
  });
}
