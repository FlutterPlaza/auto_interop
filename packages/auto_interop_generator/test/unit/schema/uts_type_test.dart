import 'dart:convert';

import 'package:auto_interop_generator/src/schema/uts_type.dart';
import 'package:test/test.dart';

void main() {
  group('UtsType', () {
    group('primitive types', () {
      test('creates String type', () {
        final type = UtsType.primitive('String');
        expect(type.kind, UtsTypeKind.primitive);
        expect(type.name, 'String');
        expect(type.nullable, false);
        expect(type.toDartType(), 'String');
      });

      test('creates int type', () {
        final type = UtsType.primitive('int');
        expect(type.toDartType(), 'int');
      });

      test('creates double type', () {
        final type = UtsType.primitive('double');
        expect(type.toDartType(), 'double');
      });

      test('creates bool type', () {
        final type = UtsType.primitive('bool');
        expect(type.toDartType(), 'bool');
      });

      test('creates DateTime type', () {
        final type = UtsType.primitive('DateTime');
        expect(type.toDartType(), 'DateTime');
      });

      test('creates nullable primitive', () {
        final type = UtsType.primitive('String', nullable: true);
        expect(type.nullable, true);
        expect(type.toDartType(), 'String?');
      });
    });

    group('void and dynamic types', () {
      test('creates void type', () {
        final type = UtsType.voidType();
        expect(type.kind, UtsTypeKind.voidType);
        expect(type.toDartType(), 'void');
      });

      test('creates dynamic type', () {
        final type = UtsType.dynamicType();
        expect(type.kind, UtsTypeKind.dynamic);
        expect(type.toDartType(), 'dynamic');
      });
    });

    group('object types', () {
      test('creates object type', () {
        final type = UtsType.object('FormatOptions');
        expect(type.kind, UtsTypeKind.object);
        expect(type.name, 'FormatOptions');
        expect(type.ref, 'FormatOptions');
        expect(type.toDartType(), 'FormatOptions');
      });

      test('creates nullable object type', () {
        final type = UtsType.object('FormatOptions', nullable: true);
        expect(type.toDartType(), 'FormatOptions?');
      });
    });

    group('collection types', () {
      test('creates List<String>', () {
        final type = UtsType.list(UtsType.primitive('String'));
        expect(type.kind, UtsTypeKind.list);
        expect(type.toDartType(), 'List<String>');
      });

      test('creates nullable List<int>', () {
        final type =
            UtsType.list(UtsType.primitive('int'), nullable: true);
        expect(type.toDartType(), 'List<int>?');
      });

      test('creates nested List<List<String>>', () {
        final type =
            UtsType.list(UtsType.list(UtsType.primitive('String')));
        expect(type.toDartType(), 'List<List<String>>');
      });

      test('creates Map<String, int>', () {
        final type = UtsType.map(
          UtsType.primitive('String'),
          UtsType.primitive('int'),
        );
        expect(type.kind, UtsTypeKind.map);
        expect(type.toDartType(), 'Map<String, int>');
      });

      test('creates nullable Map', () {
        final type = UtsType.map(
          UtsType.primitive('String'),
          UtsType.primitive('dynamic'),
          nullable: true,
        );
        expect(type.toDartType(), 'Map<String, dynamic>?');
      });

      test('creates nested Map<String, List<int>>', () {
        final type = UtsType.map(
          UtsType.primitive('String'),
          UtsType.list(UtsType.primitive('int')),
        );
        expect(type.toDartType(), 'Map<String, List<int>>');
      });
    });

    group('async types', () {
      test('creates Future<String>', () {
        final type = UtsType.future(UtsType.primitive('String'));
        expect(type.kind, UtsTypeKind.future);
        expect(type.toDartType(), 'Future<String>');
      });

      test('creates Future<void>', () {
        final type = UtsType.future(UtsType.voidType());
        expect(type.toDartType(), 'Future<void>');
      });

      test('creates Stream<int>', () {
        final type = UtsType.stream(UtsType.primitive('int'));
        expect(type.kind, UtsTypeKind.stream);
        expect(type.toDartType(), 'Stream<int>');
      });
    });

    group('callback types', () {
      test('creates void Function(String)', () {
        final type = UtsType.callback(
          parameterTypes: [UtsType.primitive('String')],
          returnType: UtsType.voidType(),
        );
        expect(type.kind, UtsTypeKind.callback);
        expect(type.toDartType(), 'void Function(String)');
      });

      test('creates int Function(int, int)', () {
        final type = UtsType.callback(
          parameterTypes: [
            UtsType.primitive('int'),
            UtsType.primitive('int'),
          ],
          returnType: UtsType.primitive('int'),
        );
        expect(type.toDartType(), 'int Function(int, int)');
      });

      test('creates nullable callback', () {
        final type = UtsType.callback(
          parameterTypes: [],
          returnType: UtsType.voidType(),
          nullable: true,
        );
        expect(type.toDartType(), 'void Function()?');
      });
    });

    group('native object types', () {
      test('creates nativeObject type for OkHttpClient', () {
        final type = UtsType.nativeObject('OkHttpClient');
        expect(type.kind, UtsTypeKind.nativeObject);
        expect(type.toDartType(), 'OkHttpClient');
      });
    });

    group('enum types', () {
      test('creates enum reference', () {
        final type = UtsType.enumType('Weekday');
        expect(type.kind, UtsTypeKind.enumType);
        expect(type.ref, 'Weekday');
        expect(type.toDartType(), 'Weekday');
      });

      test('creates nullable enum', () {
        final type = UtsType.enumType('Weekday', nullable: true);
        expect(type.toDartType(), 'Weekday?');
      });
    });

    group('asNullable', () {
      test('returns nullable copy of non-nullable type', () {
        final type = UtsType.primitive('String');
        final nullableType = type.asNullable();
        expect(nullableType.nullable, true);
        expect(nullableType.kind, type.kind);
        expect(nullableType.name, type.name);
      });

      test('preserves type arguments when making nullable', () {
        final type = UtsType.list(UtsType.primitive('int'));
        final nullableType = type.asNullable();
        expect(nullableType.toDartType(), 'List<int>?');
      });
    });

    group('equality', () {
      test('same types are equal', () {
        final a = UtsType.primitive('String');
        final b = UtsType.primitive('String');
        expect(a, equals(b));
      });

      test('different names are not equal', () {
        final a = UtsType.primitive('String');
        final b = UtsType.primitive('int');
        expect(a, isNot(equals(b)));
      });

      test('nullable vs non-nullable are not equal', () {
        final a = UtsType.primitive('String');
        final b = UtsType.primitive('String', nullable: true);
        expect(a, isNot(equals(b)));
      });

      test('List<String> != List<int> (different type arguments)', () {
        final a = UtsType.list(UtsType.primitive('String'));
        final b = UtsType.list(UtsType.primitive('int'));
        expect(a, isNot(equals(b)));
      });

      test('List<String> == List<String> (same type arguments)', () {
        final a = UtsType.list(UtsType.primitive('String'));
        final b = UtsType.list(UtsType.primitive('String'));
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('Map<String, int> != Map<String, double>', () {
        final a = UtsType.map(
            UtsType.primitive('String'), UtsType.primitive('int'));
        final b = UtsType.map(
            UtsType.primitive('String'), UtsType.primitive('double'));
        expect(a, isNot(equals(b)));
      });

      test('Future<String> != Future<int>', () {
        final a = UtsType.future(UtsType.primitive('String'));
        final b = UtsType.future(UtsType.primitive('int'));
        expect(a, isNot(equals(b)));
      });

      test('callbacks with different signatures are not equal', () {
        final a = UtsType.callback(
          parameterTypes: [UtsType.primitive('String')],
          returnType: UtsType.voidType(),
        );
        final b = UtsType.callback(
          parameterTypes: [UtsType.primitive('int')],
          returnType: UtsType.voidType(),
        );
        expect(a, isNot(equals(b)));
      });

      test('callbacks with different return types are not equal', () {
        final a = UtsType.callback(
          parameterTypes: [UtsType.primitive('String')],
          returnType: UtsType.voidType(),
        );
        final b = UtsType.callback(
          parameterTypes: [UtsType.primitive('String')],
          returnType: UtsType.primitive('int'),
        );
        expect(a, isNot(equals(b)));
      });

      test('nested List<List<String>> == List<List<String>>', () {
        final a = UtsType.list(UtsType.list(UtsType.primitive('String')));
        final b = UtsType.list(UtsType.list(UtsType.primitive('String')));
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('JSON serialization', () {
      test('roundtrips primitive type', () {
        final type = UtsType.primitive('String', nullable: true);
        final json = type.toJson();
        final restored = UtsType.fromJson(json);
        expect(restored.kind, type.kind);
        expect(restored.name, type.name);
        expect(restored.nullable, type.nullable);
      });

      test('roundtrips list type', () {
        final type = UtsType.list(UtsType.primitive('int'));
        final json = type.toJson();
        final jsonStr = jsonEncode(json);
        final restored = UtsType.fromJson(jsonDecode(jsonStr));
        expect(restored.kind, UtsTypeKind.list);
        expect(restored.toDartType(), 'List<int>');
      });

      test('roundtrips callback type', () {
        final type = UtsType.callback(
          parameterTypes: [UtsType.primitive('String')],
          returnType: UtsType.primitive('int'),
        );
        final json = type.toJson();
        final restored = UtsType.fromJson(json);
        expect(restored.kind, UtsTypeKind.callback);
        expect(restored.parameterTypes, isNotNull);
        expect(restored.returnType, isNotNull);
      });
    });
  });
}
