import 'package:auto_interop_generator/src/schema/uts_type.dart';
import 'package:auto_interop_generator/src/type_mapping/swift_to_dart.dart';
import 'package:test/test.dart';

void main() {
  late SwiftToDartMapper mapper;

  setUp(() {
    mapper = SwiftToDartMapper();
  });

  group('SwiftToDartMapper', () {
    group('primitive types', () {
      test('maps Int to int', () {
        expect(mapper.mapType('Int').toDartType(), 'int');
      });

      test('maps Int32 to int', () {
        expect(mapper.mapType('Int32').toDartType(), 'int');
      });

      test('maps Int64 to int', () {
        expect(mapper.mapType('Int64').toDartType(), 'int');
      });

      test('maps UInt to int', () {
        expect(mapper.mapType('UInt').toDartType(), 'int');
      });

      test('maps Double to double', () {
        expect(mapper.mapType('Double').toDartType(), 'double');
      });

      test('maps Float to double', () {
        expect(mapper.mapType('Float').toDartType(), 'double');
      });

      test('maps CGFloat to double', () {
        expect(mapper.mapType('CGFloat').toDartType(), 'double');
      });

      test('maps String to String', () {
        expect(mapper.mapType('String').toDartType(), 'String');
      });

      test('maps Bool to bool', () {
        expect(mapper.mapType('Bool').toDartType(), 'bool');
      });

      test('maps Date to DateTime', () {
        expect(mapper.mapType('Date').toDartType(), 'DateTime');
      });

      test('maps Data to Uint8List', () {
        expect(mapper.mapType('Data').toDartType(), 'Uint8List');
      });

      test('maps Void to void', () {
        expect(mapper.mapType('Void').toDartType(), 'void');
      });

      test('maps Any to dynamic', () {
        expect(mapper.mapType('Any').toDartType(), 'dynamic');
      });

      test('maps AnyObject to dynamic', () {
        expect(mapper.mapType('AnyObject').toDartType(), 'dynamic');
      });
    });

    group('optional types', () {
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

      test('maps Optional<String> to String?', () {
        final result = mapper.mapType('Optional<String>');
        expect(result.nullable, true);
        expect(result.toDartType(), 'String?');
      });
    });

    group('collection types', () {
      test('maps [String] to List<String>', () {
        final result = mapper.mapType('[String]');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<String>');
      });

      test('maps Array<Int> to List<int>', () {
        final result = mapper.mapType('Array<Int>');
        expect(result.kind, UtsTypeKind.list);
        expect(result.toDartType(), 'List<int>');
      });

      test('maps [String: Int] to Map<String, int>', () {
        final result = mapper.mapType('[String: Int]');
        expect(result.kind, UtsTypeKind.map);
        expect(result.toDartType(), 'Map<String, int>');
      });

      test('maps Dictionary<String, Bool> to Map<String, bool>', () {
        final result = mapper.mapType('Dictionary<String, Bool>');
        expect(result.kind, UtsTypeKind.map);
        expect(result.toDartType(), 'Map<String, bool>');
      });

      test('maps [String]? to nullable List<String>', () {
        final result = mapper.mapType('[String]?');
        expect(result.nullable, true);
        expect(result.toDartType(), 'List<String>?');
      });
    });

    group('async types', () {
      test('maps AsyncStream<String> to Stream<String>', () {
        final result = mapper.mapType('AsyncStream<String>');
        expect(result.kind, UtsTypeKind.stream);
        expect(result.toDartType(), 'Stream<String>');
      });
    });

    group('object types', () {
      test('maps unknown type to object', () {
        final result = mapper.mapType('URLRequest');
        expect(result.kind, UtsTypeKind.object);
        expect(result.name, 'URLRequest');
      });
    });
  });
}
