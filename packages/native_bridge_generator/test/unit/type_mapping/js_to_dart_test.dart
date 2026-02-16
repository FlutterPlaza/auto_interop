import 'package:native_bridge_generator/src/schema/uts_type.dart';
import 'package:native_bridge_generator/src/type_mapping/js_to_dart.dart';
import 'package:native_bridge_generator/src/type_mapping/type_mapper.dart';
import 'package:test/test.dart';

void main() {
  late JsToDartMapper mapper;
  late TypeMapper registry;

  setUp(() {
    mapper = JsToDartMapper();
    registry = TypeMapper();
    mapper.registerAll(registry);
  });

  group('JsToDartMapper', () {
    group('primitive types', () {
      test('maps number to double', () {
        final result = mapper.mapType('number');
        expect(result.toDartType(), 'double');
      });

      test('maps string to String', () {
        final result = mapper.mapType('string');
        expect(result.toDartType(), 'String');
      });

      test('maps boolean to bool', () {
        final result = mapper.mapType('boolean');
        expect(result.toDartType(), 'bool');
      });

      test('maps Date to DateTime', () {
        final result = mapper.mapType('Date');
        expect(result.toDartType(), 'DateTime');
      });

      test('maps void to void', () {
        final result = mapper.mapType('void');
        expect(result.toDartType(), 'void');
      });

      test('maps null to void', () {
        final result = mapper.mapType('null');
        expect(result.toDartType(), 'void');
      });

      test('maps undefined to void', () {
        final result = mapper.mapType('undefined');
        expect(result.toDartType(), 'void');
      });

      test('maps any to dynamic', () {
        final result = mapper.mapType('any');
        expect(result.toDartType(), 'dynamic');
      });

      test('maps unknown to dynamic', () {
        final result = mapper.mapType('unknown');
        expect(result.toDartType(), 'dynamic');
      });
    });

    group('binary types', () {
      test('maps Buffer to Uint8List', () {
        final result = mapper.mapType('Buffer');
        expect(result.toDartType(), 'Uint8List');
      });

      test('maps ArrayBuffer to Uint8List', () {
        final result = mapper.mapType('ArrayBuffer');
        expect(result.toDartType(), 'Uint8List');
      });

      test('maps Uint8Array to Uint8List', () {
        final result = mapper.mapType('Uint8Array');
        expect(result.toDartType(), 'Uint8List');
      });
    });

    group('nullable types', () {
      test('maps nullable string', () {
        final result = mapper.mapType('string', nullable: true);
        expect(result.toDartType(), 'String?');
        expect(result.nullable, true);
      });

      test('parses union with null', () {
        final result = mapper.mapType('string | null');
        expect(result.nullable, true);
        expect(result.toDartType(), 'String?');
      });

      test('parses union with undefined', () {
        final result = mapper.mapType('number | undefined');
        expect(result.nullable, true);
        expect(result.toDartType(), 'double?');
      });
    });

    group('collection types', () {
      test('maps Array<string> to List<String>', () {
        final result = mapper.mapType('Array<string>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps string[] to List<String>', () {
        final result = mapper.mapType('string[]');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps Array<Array<number>> to List<List<double>>', () {
        final result = mapper.mapType('Array<Array<number>>');
        expect(result.toDartType(), 'List<List<double>>');
      });

      test('maps Map<string, number> to Map<String, double>', () {
        final result = mapper.mapType('Map<string, number>');
        expect(result.kind, UtsTypeKind.map);
        expect(result.toDartType(), 'Map<String, double>');
      });

      test('maps Record<string, any> to Map<String, dynamic>', () {
        final result = mapper.mapType('Record<string, any>');
        expect(result.kind, UtsTypeKind.map);
        expect(result.toDartType(), 'Map<String, dynamic>');
      });
    });

    group('async types', () {
      test('maps Promise<string> to Future<String>', () {
        final result = mapper.mapType('Promise<string>');
        expect(result.kind, UtsTypeKind.future);
        expect(result.toDartType(), 'Future<String>');
      });

      test('maps Promise<void> to Future<void>', () {
        final result = mapper.mapType('Promise<void>');
        expect(result.toDartType(), 'Future<void>');
      });

      test('maps ReadableStream<string> to Stream<String>', () {
        final result = mapper.mapType('ReadableStream<string>');
        expect(result.kind, UtsTypeKind.stream);
        expect(result.toDartType(), 'Stream<String>');
      });
    });

    group('object types', () {
      test('maps unknown type name to object', () {
        final result = mapper.mapType('MyCustomClass');
        expect(result.kind, UtsTypeKind.object);
        expect(result.name, 'MyCustomClass');
        expect(result.toDartType(), 'MyCustomClass');
      });

      test('maps unknown nullable type name to nullable object', () {
        final result = mapper.mapType('MyCustomClass', nullable: true);
        expect(result.toDartType(), 'MyCustomClass?');
      });
    });

    group('registry integration', () {
      test('registers all standard types', () {
        expect(registry.lookup('number'), isNotNull);
        expect(registry.lookup('string'), isNotNull);
        expect(registry.lookup('boolean'), isNotNull);
        expect(registry.lookup('Date'), isNotNull);
        expect(registry.lookup('void'), isNotNull);
        expect(registry.lookup('any'), isNotNull);
        expect(registry.lookup('Buffer'), isNotNull);
      });

      test('registry lookup returns correct encoding', () {
        final dateMapping = registry.lookup('Date');
        expect(dateMapping!.encoding, ChannelEncoding.iso8601String);

        final bufferMapping = registry.lookup('Buffer');
        expect(bufferMapping!.encoding, ChannelEncoding.byteArray);
      });
    });
  });
}
