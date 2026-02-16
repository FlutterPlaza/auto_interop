import 'package:flutter_test/flutter_test.dart';
import 'package:auto_interop/src/type_converter.dart';

void main() {
  group('TypeConverter', () {
    group('toPlatform', () {
      test('passes null through', () {
        expect(TypeConverter.toPlatform(null), isNull);
      });

      test('passes int through', () {
        expect(TypeConverter.toPlatform(42), 42);
      });

      test('passes double through', () {
        expect(TypeConverter.toPlatform(3.14), 3.14);
      });

      test('passes String through', () {
        expect(TypeConverter.toPlatform('hello'), 'hello');
      });

      test('passes bool through', () {
        expect(TypeConverter.toPlatform(true), true);
      });

      test('converts DateTime to ISO 8601 string', () {
        final dt = DateTime.utc(2024, 1, 15, 10, 30, 0);
        final result = TypeConverter.toPlatform(dt);
        expect(result, isA<String>());
        expect(result, '2024-01-15T10:30:00.000Z');
      });

      test('converts List recursively', () {
        final dt = DateTime.utc(2024, 1, 1);
        final result = TypeConverter.toPlatform([1, 'a', dt]);
        expect(result, isA<List>());
        final list = result as List;
        expect(list[0], 1);
        expect(list[1], 'a');
        expect(list[2], isA<String>());
      });

      test('converts Map recursively', () {
        final dt = DateTime.utc(2024, 6, 1);
        final result = TypeConverter.toPlatform({'date': dt, 'count': 5});
        expect(result, isA<Map>());
        final map = result as Map;
        expect(map['date'], isA<String>());
        expect(map['count'], 5);
      });
    });

    group('fromPlatform', () {
      test('passes null through', () {
        expect(TypeConverter.fromPlatform(null), isNull);
      });

      test('passes primitives through', () {
        expect(TypeConverter.fromPlatform(42), 42);
        expect(TypeConverter.fromPlatform('hello'), 'hello');
        expect(TypeConverter.fromPlatform(true), true);
      });

      test('converts string to DateTime when dartType is DateTime', () {
        final result = TypeConverter.fromPlatform(
          '2024-01-15T10:30:00.000Z',
          dartType: 'DateTime',
        );
        expect(result, isA<DateTime>());
        final dt = result as DateTime;
        expect(dt.year, 2024);
        expect(dt.month, 1);
        expect(dt.day, 15);
      });

      test('passes string through when dartType is not DateTime', () {
        final result = TypeConverter.fromPlatform('hello', dartType: 'String');
        expect(result, 'hello');
      });
    });

    group('dateTimeToString / stringToDateTime', () {
      test('roundtrips DateTime', () {
        final original = DateTime.utc(2024, 3, 15, 12, 0, 0);
        final str = TypeConverter.dateTimeToString(original);
        final restored = TypeConverter.stringToDateTime(str);
        expect(restored, original);
      });
    });
  });
}
