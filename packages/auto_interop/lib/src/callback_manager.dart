import 'package:flutter/services.dart';

/// Manages Dart-to-native callbacks for auto_interop.
///
/// When a Dart function is passed as a callback parameter to a native method,
/// the [CallbackManager] assigns it a unique ID and stores it. The native side
/// can then invoke the callback by sending a method call with that ID back
/// through the callback channel.
class CallbackManager {
  static CallbackManager? _instance;

  /// The singleton callback manager.
  static CallbackManager get instance {
    _instance ??= CallbackManager._();
    return _instance!;
  }

  /// Replaces the singleton instance (for testing).
  static set instance(CallbackManager value) {
    _instance = value;
  }

  final MethodChannel _callbackChannel;
  final Map<String, Function> _callbacks = {};
  int _nextId = 0;

  CallbackManager._()
      : _callbackChannel =
            const MethodChannel('auto_interop/callbacks') {
    _callbackChannel.setMethodCallHandler(_handleCallback);
  }

  /// Creates a callback manager with a custom channel (for testing).
  CallbackManager.withChannel(this._callbackChannel) {
    _callbackChannel.setMethodCallHandler(_handleCallback);
  }

  /// Registers a callback and returns its unique ID.
  ///
  /// The returned ID is passed to the native side, which can use it to
  /// invoke the callback later via the callback channel.
  String register(Function callback) {
    final id = 'cb_${_nextId++}';
    _callbacks[id] = callback;
    return id;
  }

  /// Unregisters a callback by its ID.
  void unregister(String callbackId) {
    _callbacks.remove(callbackId);
  }

  /// Unregisters all callbacks.
  void clear() {
    _callbacks.clear();
  }

  /// Returns the number of registered callbacks.
  int get count => _callbacks.length;

  /// Whether a callback with the given [callbackId] is registered.
  bool isRegistered(String callbackId) => _callbacks.containsKey(callbackId);

  /// Handles incoming callback invocations from the native side.
  Future<dynamic> _handleCallback(MethodCall call) async {
    final callbackId = call.method;
    final callback = _callbacks[callbackId];
    if (callback == null) {
      throw PlatformException(
        code: 'CALLBACK_NOT_FOUND',
        message: 'No callback registered with ID: $callbackId',
      );
    }

    final args = call.arguments;
    if (args is List) {
      switch (args.length) {
        case 0:
          return Function.apply(callback, []);
        case 1:
          return Function.apply(callback, [args[0]]);
        case 2:
          return Function.apply(callback, [args[0], args[1]]);
        case 3:
          return Function.apply(callback, [args[0], args[1], args[2]]);
        default:
          return Function.apply(callback, args);
      }
    } else if (args == null) {
      return Function.apply(callback, []);
    } else {
      return Function.apply(callback, [args]);
    }
  }
}
