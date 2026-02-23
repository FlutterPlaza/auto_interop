import 'package:auto_interop_generator/src/schema/uts_type.dart';
import 'package:auto_interop_generator/src/type_mapping/java_to_dart.dart';
import 'package:test/test.dart';

void main() {
  late JavaToDartMapper mapper;

  setUp(() {
    mapper = JavaToDartMapper();
  });

  group('JavaToDartMapper', () {
    group('primitive types', () {
      test('maps int to int', () {
        expect(mapper.mapType('int').toDartType(), 'int');
      });

      test('maps Integer to int', () {
        expect(mapper.mapType('Integer').toDartType(), 'int');
      });

      test('maps long to int', () {
        expect(mapper.mapType('long').toDartType(), 'int');
      });

      test('maps Long to int', () {
        expect(mapper.mapType('Long').toDartType(), 'int');
      });

      test('maps double to double', () {
        expect(mapper.mapType('double').toDartType(), 'double');
      });

      test('maps Double to double', () {
        expect(mapper.mapType('Double').toDartType(), 'double');
      });

      test('maps float to double', () {
        expect(mapper.mapType('float').toDartType(), 'double');
      });

      test('maps Float to double', () {
        expect(mapper.mapType('Float').toDartType(), 'double');
      });

      test('maps String to String', () {
        expect(mapper.mapType('String').toDartType(), 'String');
      });

      test('maps boolean to bool', () {
        expect(mapper.mapType('boolean').toDartType(), 'bool');
      });

      test('maps Boolean to bool', () {
        expect(mapper.mapType('Boolean').toDartType(), 'bool');
      });

      test('maps byte[] to Uint8List', () {
        expect(mapper.mapType('byte[]').toDartType(), 'Uint8List');
      });

      test('maps void to void', () {
        expect(mapper.mapType('void').toDartType(), 'void');
      });

      test('maps Void to void', () {
        expect(mapper.mapType('Void').toDartType(), 'void');
      });

      test('maps Object to dynamic', () {
        expect(mapper.mapType('Object').toDartType(), 'dynamic');
      });
    });

    group('nullable types', () {
      test('maps Integer with nullable flag', () {
        final result = mapper.mapType('Integer', nullable: true);
        expect(result.nullable, true);
        expect(result.toDartType(), 'int?');
      });

      test('maps Optional<String> to String?', () {
        final result = mapper.mapType('Optional<String>');
        expect(result.nullable, true);
        expect(result.toDartType(), 'String?');
      });
    });

    group('collection types', () {
      test('maps List<String> to List<String>', () {
        final result = mapper.mapType('List<String>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps ArrayList<Integer> to List<int>', () {
        final result = mapper.mapType('ArrayList<Integer>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<int>');
      });

      test('maps Map<String, Integer> to Map<String, int>', () {
        final result = mapper.mapType('Map<String, Integer>');
        expect(result.kind, UtsTypeKind.map);
        expect(result.toDartType(), 'Map<String, int>');
      });

      test('maps HashMap<String, Object> to Map<String, dynamic>', () {
        final result = mapper.mapType('HashMap<String, Object>');
        expect(result.kind, UtsTypeKind.map);
        expect(result.toDartType(), 'Map<String, dynamic>');
      });

      test('maps String[] to List<String>', () {
        final result = mapper.mapType('String[]');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps int[] to List<int>', () {
        final result = mapper.mapType('int[]');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<int>');
      });
    });

    group('SDK primitive types', () {
      test('maps URI to Uri', () {
        expect(mapper.mapType('URI').toDartType(), 'Uri');
      });

      test('maps URL to Uri', () {
        expect(mapper.mapType('URL').toDartType(), 'Uri');
      });

      test('maps java.net.URI to Uri', () {
        expect(mapper.mapType('java.net.URI').toDartType(), 'Uri');
      });

      test('maps java.net.URL to Uri', () {
        expect(mapper.mapType('java.net.URL').toDartType(), 'Uri');
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

      test('maps InputStream to nativeObject', () {
        final result = mapper.mapType('InputStream');
        expect(result.kind, UtsTypeKind.nativeObject);
      });
    });

    group('set types', () {
      test('maps Set<String> to List<String>', () {
        final result = mapper.mapType('Set<String>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps HashSet<Integer> to List<int>', () {
        final result = mapper.mapType('HashSet<Integer>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<int>');
      });
    });

    group('object types', () {
      test('maps unknown type to object', () {
        final result = mapper.mapType('Response');
        expect(result.kind, UtsTypeKind.object);
        expect(result.name, 'Response');
      });
    });
  });
}
