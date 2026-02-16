import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auto_interop/src/error_handler.dart';

void main() {
  group('AutoInteropException', () {
    test('creates with code only', () {
      const exception = AutoInteropException(code: 'ERROR');
      expect(exception.code, 'ERROR');
      expect(exception.message, isNull);
      expect(exception.details, isNull);
    });

    test('creates with all fields', () {
      const exception = AutoInteropException(
        code: 'NOT_FOUND',
        message: 'Resource not found',
        details: {'id': 123},
      );
      expect(exception.code, 'NOT_FOUND');
      expect(exception.message, 'Resource not found');
      expect(exception.details, {'id': 123});
    });

    test('creates from PlatformException', () {
      final platformEx = PlatformException(
        code: 'NETWORK',
        message: 'Connection failed',
        details: 'timeout',
      );
      final exception =
          AutoInteropException.fromPlatformException(platformEx);
      expect(exception.code, 'NETWORK');
      expect(exception.message, 'Connection failed');
      expect(exception.details, 'timeout');
    });

    test('toString contains code', () {
      const exception = AutoInteropException(code: 'ERROR');
      expect(exception.toString(), contains('ERROR'));
    });

    test('toString contains message when present', () {
      const exception = AutoInteropException(
        code: 'ERROR',
        message: 'Something went wrong',
      );
      expect(exception.toString(), contains('Something went wrong'));
    });
  });

  group('ErrorHandler', () {
    test('returns result on success', () async {
      final result = await ErrorHandler.guard(() async => 42);
      expect(result, 42);
    });

    test('converts PlatformException to AutoInteropException', () async {
      expect(
        () => ErrorHandler.guard(() async {
          throw PlatformException(code: 'TEST_ERROR');
        }),
        throwsA(isA<AutoInteropException>().having(
          (e) => e.code,
          'code',
          'TEST_ERROR',
        )),
      );
    });

    test('lets non-PlatformException propagate', () async {
      expect(
        () => ErrorHandler.guard(() async {
          throw StateError('test');
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
