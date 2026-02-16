import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_bridge/src/lifecycle.dart';
import 'package:native_bridge/src/native_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeObject', () {
    late MethodChannel mockLifecycleChannel;

    setUp(() {
      mockLifecycleChannel =
          const MethodChannel('test_lifecycle');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              mockLifecycleChannel, (MethodCall call) async {
        return null;
      });
      NativeBridgeLifecycle.instance =
          NativeBridgeLifecycle.withChannel(mockLifecycleChannel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockLifecycleChannel, null);
    });

    test('stores handle and channel name', () {
      final obj = NativeObject<String>(
        handle: 42,
        channelName: 'test',
      );
      expect(obj.handle, 42);
      expect(obj.channelName, 'test');
      expect(obj.isDisposed, false);
    });

    test('dispose marks as disposed', () async {
      final obj = NativeObject<String>(
        handle: 1,
        channelName: 'test',
      );
      await obj.dispose();
      expect(obj.isDisposed, true);
    });

    test('dispose is idempotent', () async {
      final obj = NativeObject<String>(
        handle: 1,
        channelName: 'test',
      );
      await obj.dispose();
      await obj.dispose(); // Should not throw
      expect(obj.isDisposed, true);
    });

    test('ensureNotDisposed succeeds when not disposed', () {
      final obj = NativeObject<String>(
        handle: 1,
        channelName: 'test',
      );
      expect(() => obj.ensureNotDisposed(), returnsNormally);
    });

    test('ensureNotDisposed throws when disposed', () async {
      final obj = NativeObject<String>(
        handle: 1,
        channelName: 'test',
      );
      await obj.dispose();
      expect(() => obj.ensureNotDisposed(), throwsA(isA<StateError>()));
    });

    test('toString contains handle info', () {
      final obj = NativeObject<String>(
        handle: 42,
        channelName: 'test',
      );
      expect(obj.toString(), contains('42'));
      expect(obj.toString(), contains('String'));
    });
  });
}
