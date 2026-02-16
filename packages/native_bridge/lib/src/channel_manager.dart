import 'package:flutter/services.dart';

import 'error_handler.dart';
import 'type_converter.dart';

/// Manages platform method channels for native bridge bindings.
///
/// Each native package gets its own [NativeBridgeChannel] identified by
/// a unique channel name. The channel provides typed method invocation
/// with automatic type conversion and error handling.
class NativeBridgeChannel {
  /// The underlying Flutter method channel.
  final MethodChannel _channel;

  /// The channel name (typically the snake_case package name).
  final String name;

  /// Creates a new channel with the given [name].
  ///
  /// The channel name should match the registration name on the
  /// native platform side.
  NativeBridgeChannel(this.name)
      : _channel = MethodChannel('native_bridge/$name');

  /// Creates a channel with a custom [MethodChannel] (for testing).
  NativeBridgeChannel.withChannel(this.name, this._channel);

  /// Invokes a method on the native side and returns the result.
  ///
  /// Arguments are automatically converted for platform channel transport.
  /// The result is cast to [T].
  Future<T> invoke<T>(String method, [Map<String, dynamic>? arguments]) {
    return ErrorHandler.guard(() async {
      final convertedArgs = arguments != null
          ? TypeConverter.toPlatform(arguments) as Map<Object?, Object?>?
          : null;
      final result = await _channel.invokeMethod<T>(method, convertedArgs);
      return result as T;
    });
  }

  /// Invokes a method that returns a List.
  Future<List<T>> invokeList<T>(String method,
      [Map<String, dynamic>? arguments]) {
    return ErrorHandler.guard(() async {
      final convertedArgs = arguments != null
          ? TypeConverter.toPlatform(arguments) as Map<Object?, Object?>?
          : null;
      final result =
          await _channel.invokeListMethod<T>(method, convertedArgs);
      return result ?? <T>[];
    });
  }

  /// Invokes a method that returns a Map.
  Future<Map<K, V>> invokeMap<K, V>(String method,
      [Map<String, dynamic>? arguments]) {
    return ErrorHandler.guard(() async {
      final convertedArgs = arguments != null
          ? TypeConverter.toPlatform(arguments) as Map<Object?, Object?>?
          : null;
      final result =
          await _channel.invokeMapMethod<K, V>(method, convertedArgs);
      return result ?? <K, V>{};
    });
  }
}
