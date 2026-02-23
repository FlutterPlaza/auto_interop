import 'package:auto_interop_generator/src/schema/uts_type.dart';
import 'package:auto_interop_generator/src/type_mapping/kotlin_to_dart.dart';
import 'package:test/test.dart';

void main() {
  late KotlinToDartMapper mapper;

  setUp(() {
    mapper = KotlinToDartMapper();
  });

  group('KotlinToDartMapper', () {
    group('primitive types', () {
      test('maps Int to int', () {
        expect(mapper.mapType('Int').toDartType(), 'int');
      });

      test('maps Long to int', () {
        expect(mapper.mapType('Long').toDartType(), 'int');
      });

      test('maps Short to int', () {
        expect(mapper.mapType('Short').toDartType(), 'int');
      });

      test('maps Byte to int', () {
        expect(mapper.mapType('Byte').toDartType(), 'int');
      });

      test('maps Double to double', () {
        expect(mapper.mapType('Double').toDartType(), 'double');
      });

      test('maps Float to double', () {
        expect(mapper.mapType('Float').toDartType(), 'double');
      });

      test('maps String to String', () {
        expect(mapper.mapType('String').toDartType(), 'String');
      });

      test('maps Boolean to bool', () {
        expect(mapper.mapType('Boolean').toDartType(), 'bool');
      });

      test('maps ByteArray to Uint8List', () {
        expect(mapper.mapType('ByteArray').toDartType(), 'Uint8List');
      });

      test('maps Unit to void', () {
        expect(mapper.mapType('Unit').toDartType(), 'void');
      });

      test('maps Nothing to void', () {
        expect(mapper.mapType('Nothing').toDartType(), 'void');
      });

      test('maps Any to dynamic', () {
        expect(mapper.mapType('Any').toDartType(), 'dynamic');
      });
    });

    group('nullable types', () {
      test('maps String? to String?', () {
        final result = mapper.mapType('String?');
        expect(result.nullable, true);
        expect(result.toDartType(), 'String?');
      });

      test('maps Int? to int?', () {
        final result = mapper.mapType('Int?');
        expect(result.nullable, true);
        expect(result.toDartType(), 'int?');
      });

      test('maps Any? to dynamic', () {
        final result = mapper.mapType('Any?');
        expect(result.nullable, true);
      });
    });

    group('collection types', () {
      test('maps List<String> to List<String>', () {
        final result = mapper.mapType('List<String>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps MutableList<Int> to List<int>', () {
        final result = mapper.mapType('MutableList<Int>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<int>');
      });

      test('maps Map<String, Int> to Map<String, int>', () {
        final result = mapper.mapType('Map<String, Int>');
        expect(result.kind, UtsTypeKind.map);
        expect(result.toDartType(), 'Map<String, int>');
      });

      test('maps nested List<List<String>> recursively', () {
        final result = mapper.mapType('List<List<String>>');
        expect(result.toDartType(), 'List<List<String>>');
      });
    });

    group('async types', () {
      test('maps Flow<String> to Stream<String>', () {
        final result = mapper.mapType('Flow<String>');
        expect(result.kind, UtsTypeKind.stream);
        expect(result.toDartType(), 'Stream<String>');
      });

      test('maps Deferred<Int> to Future<int>', () {
        final result = mapper.mapType('Deferred<Int>');
        expect(result.kind, UtsTypeKind.future);
        expect(result.toDartType(), 'Future<int>');
      });
    });

    group('SDK primitive types', () {
      test('maps URI to Uri', () {
        expect(mapper.mapType('URI').toDartType(), 'Uri');
      });

      test('maps URL to Uri', () {
        expect(mapper.mapType('URL').toDartType(), 'Uri');
      });

      test('maps Duration to Duration', () {
        expect(mapper.mapType('Duration').toDartType(), 'Duration');
      });

      test('maps BigDecimal to double', () {
        expect(mapper.mapType('BigDecimal').toDartType(), 'double');
      });

      test('maps BigInteger to int', () {
        expect(mapper.mapType('BigInteger').toDartType(), 'int');
      });

      test('maps UUID to String', () {
        expect(mapper.mapType('UUID').toDartType(), 'String');
      });

      test('maps CharSequence to String', () {
        expect(mapper.mapType('CharSequence').toDartType(), 'String');
      });
    });

    group('native object types', () {
      test('maps Exception to nativeObject', () {
        final result = mapper.mapType('Exception');
        expect(result.kind, UtsTypeKind.nativeObject);
        expect(result.name, 'Exception');
      });

      test('maps IOException to nativeObject', () {
        final result = mapper.mapType('IOException');
        expect(result.kind, UtsTypeKind.nativeObject);
      });

      test('maps Context to nativeObject', () {
        final result = mapper.mapType('Context');
        expect(result.kind, UtsTypeKind.nativeObject);
      });
    });

    group('set types', () {
      test('maps Set<String> to List<String>', () {
        final result = mapper.mapType('Set<String>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps MutableSet<Int> to List<int>', () {
        final result = mapper.mapType('MutableSet<Int>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<int>');
      });
    });

    group('object types', () {
      test('maps unknown type to object', () {
        final result = mapper.mapType('OkHttpClient');
        expect(result.kind, UtsTypeKind.object);
        expect(result.name, 'OkHttpClient');
      });
    });
  });
}
