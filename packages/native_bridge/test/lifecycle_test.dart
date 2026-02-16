import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_bridge/src/lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeBridgeLifecycle', () {
    late MethodChannel mockChannel;
    late NativeBridgeLifecycle lifecycle;
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      mockChannel = const MethodChannel('test_lifecycle');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall call) async {
        log.add(call);
        return null;
      });
      lifecycle = NativeBridgeLifecycle.withChannel(mockChannel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, null);
    });

    test('starts uninitialized', () {
      expect(lifecycle.isInitialized, false);
    });

    test('initialize calls native initialize', () async {
      await lifecycle.initialize();
      expect(lifecycle.isInitialized, true);
      expect(log.last.method, 'initialize');
    });

    test('initialize is idempotent', () async {
      await lifecycle.initialize();
      await lifecycle.initialize();
      // Only called once
      expect(
          log.where((c) => c.method == 'initialize').length, 1);
    });

    test('dispose calls native dispose', () async {
      await lifecycle.initialize();
      await lifecycle.dispose();
      expect(lifecycle.isInitialized, false);
      expect(log.last.method, 'dispose');
    });

    test('dispose is no-op when not initialized', () async {
      await lifecycle.dispose();
      expect(log, isEmpty);
    });

    test('releaseObject calls native releaseObject', () async {
      await lifecycle.releaseObject('my_channel', 42);
      expect(log.last.method, 'releaseObject');
      expect(log.last.arguments, {
        'channel': 'my_channel',
        'handle': 42,
      });
    });
  });
}
