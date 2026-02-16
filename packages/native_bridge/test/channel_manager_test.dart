import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_bridge/src/channel_manager.dart';
import 'package:native_bridge/src/error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeBridgeChannel', () {
    late MethodChannel mockChannel;
    late NativeBridgeChannel bridgeChannel;
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      mockChannel = const MethodChannel('test_channel');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (MethodCall call) async {
        log.add(call);
        switch (call.method) {
          case 'greet':
            return 'Hello, ${call.arguments['name']}!';
          case 'add':
            return (call.arguments['a'] as int) +
                (call.arguments['b'] as int);
          case 'getList':
            return ['a', 'b', 'c'];
          case 'getMap':
            return {'key': 'value'};
          case 'fail':
            throw PlatformException(code: 'ERR', message: 'failed');
          case 'noArgs':
            return 'ok';
          default:
            return null;
        }
      });
      bridgeChannel =
          NativeBridgeChannel.withChannel('test', mockChannel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, null);
    });

    test('has correct name', () {
      expect(bridgeChannel.name, 'test');
    });

    test('invoke calls method with arguments', () async {
      final result = await bridgeChannel.invoke<String>(
          'greet', {'name': 'World'});
      expect(result, 'Hello, World!');
      expect(log.last.method, 'greet');
    });

    test('invoke calls method without arguments', () async {
      final result = await bridgeChannel.invoke<String>('noArgs');
      expect(result, 'ok');
    });

    test('invoke returns typed result', () async {
      final result =
          await bridgeChannel.invoke<int>('add', {'a': 3, 'b': 4});
      expect(result, 7);
    });

    test('invokeList returns list', () async {
      final result = await bridgeChannel.invokeList<String>('getList');
      expect(result, ['a', 'b', 'c']);
    });

    test('invokeMap returns map', () async {
      final result =
          await bridgeChannel.invokeMap<String, String>('getMap');
      expect(result, {'key': 'value'});
    });

    test('invoke wraps PlatformException', () async {
      expect(
        () => bridgeChannel.invoke<void>('fail'),
        throwsA(isA<NativeBridgeException>().having(
          (e) => e.code,
          'code',
          'ERR',
        )),
      );
    });

    test('constructor creates channel with native_bridge prefix', () {
      final channel = NativeBridgeChannel('my_package');
      expect(channel.name, 'my_package');
    });
  });
}
