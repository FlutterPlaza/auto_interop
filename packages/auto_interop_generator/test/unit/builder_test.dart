import 'package:auto_interop_generator/builder.dart';
import 'package:build/build.dart';
import 'package:test/test.dart';

void main() {
  group('AutoInteropBuilder', () {
    test('factory function returns a Builder', () {
      final builder = autoInteropBuilder(BuilderOptions.empty);
      expect(builder, isA<Builder>());
    });

    test('buildExtensions maps yaml to dart', () {
      final builder = autoInteropBuilder(BuilderOptions.empty);
      expect(builder.buildExtensions, isNotEmpty);
      expect(
        builder.buildExtensions.keys.first,
        'auto_interop.yaml',
      );
    });

    test('output is a dart file', () {
      final builder = autoInteropBuilder(BuilderOptions.empty);
      final outputs = builder.buildExtensions.values.first;
      expect(outputs, hasLength(1));
      expect(outputs.first, endsWith('.dart'));
    });
  });
}
