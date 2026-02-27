import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auto_interop/src/channel_manager.dart';
import 'package:auto_interop/src/error_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoInteropChannel', () {
    late MethodChannel mockChannel;
    late AutoInteropChannel bridgeChannel;
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
            return (call.arguments['a'] as int) + (call.arguments['b'] as int);
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
      bridgeChannel = AutoInteropChannel.withChannel('test', mockChannel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, null);
    });

    test('has correct name', () {
      expect(bridgeChannel.name, 'test');
    });

    test('invoke calls method with arguments', () async {
      final result =
          await bridgeChannel.invoke<String>('greet', {'name': 'World'});
      expect(result, 'Hello, World!');
      expect(log.last.method, 'greet');
    });

    test('invoke calls method without arguments', () async {
      final result = await bridgeChannel.invoke<String>('noArgs');
      expect(result, 'ok');
    });

    test('invoke returns typed result', () async {
      final result = await bridgeChannel.invoke<int>('add', {'a': 3, 'b': 4});
      expect(result, 7);
    });

    test('invokeList returns list', () async {
      final result = await bridgeChannel.invokeList<String>('getList');
      expect(result, ['a', 'b', 'c']);
    });

    test('invokeMap returns map', () async {
      final result = await bridgeChannel.invokeMap<String, String>('getMap');
      expect(result, {'key': 'value'});
    });

    test('invoke wraps PlatformException', () async {
      expect(
        () => bridgeChannel.invoke<void>('fail'),
        throwsA(isA<AutoInteropException>().having(
          (e) => e.code,
          'code',
          'ERR',
        )),
      );
    });

    test('constructor creates channel with auto_interop prefix', () {
      final channel = AutoInteropChannel('my_package');
      expect(channel.name, 'my_package');
    });

    group('batchInvoke', () {
      late MethodChannel batchChannel;
      late AutoInteropChannel batchBridge;

      setUp(() {
        batchChannel = const MethodChannel('batch_channel');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(batchChannel, (MethodCall call) async {
          if (call.method == '_batch') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final calls = (args['calls'] as List).cast<Map>();
            final results = <Map<String, dynamic>>[];
            for (final c in calls) {
              final method = c['method'] as String;
              if (method == 'fail') {
                results.add({
                  'error': {'code': 'TEST_ERROR', 'message': 'failed'}
                });
              } else if (method == 'greet') {
                final callArgs =
                    Map<String, dynamic>.from(c['arguments'] as Map? ?? {});
                results.add({'result': 'Hello, ${callArgs['name']}!'});
              } else {
                results.add({'result': null});
              }
            }
            return results;
          }
          return null;
        });
        batchBridge = AutoInteropChannel.withChannel('batch', batchChannel);
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(batchChannel, null);
      });

      test('returns results for multiple calls', () async {
        final results = await batchBridge.batchInvoke([
          const BatchCall('greet', {'name': 'Alice'}),
          const BatchCall('greet', {'name': 'Bob'}),
        ]);
        expect(results, hasLength(2));
        expect(results[0].isSuccess, isTrue);
        expect(results[0].value, 'Hello, Alice!');
        expect(results[1].value, 'Hello, Bob!');
      });

      test('handles mixed success and error', () async {
        final results = await batchBridge.batchInvoke([
          const BatchCall('greet', {'name': 'Alice'}),
          const BatchCall('fail'),
        ]);
        expect(results, hasLength(2));
        expect(results[0].isSuccess, isTrue);
        expect(results[1].isError, isTrue);
        expect(results[1].errorCode, 'TEST_ERROR');
        expect(results[1].errorMessage, 'failed');
      });

      test('handles empty batch', () async {
        final results = await batchBridge.batchInvoke([]);
        expect(results, isEmpty);
      });
    });
  });
}
