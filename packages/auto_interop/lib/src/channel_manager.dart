import 'dart:async';

import 'package:flutter/services.dart';

import 'error_handler.dart';
import 'type_converter.dart';

/// Manages platform method channels for native bridge bindings.
///
/// Each native package gets its own [AutoInteropChannel] identified by
/// a unique channel name. The channel provides typed method invocation
/// with automatic type conversion and error handling.
class AutoInteropChannel {
  /// The underlying Flutter method channel.
  final MethodChannel _channel;

  /// The channel name (typically the snake_case package name).
  final String name;

  /// Creates a new channel with the given [name].
  ///
  /// The channel name should match the registration name on the
  /// native platform side.
  AutoInteropChannel(this.name)
      : _channel = MethodChannel('auto_interop/$name');

  /// Creates a channel with a custom [MethodChannel] (for testing).
  AutoInteropChannel.withChannel(this.name, this._channel);

  /// Invokes a method on the native side and returns the result.
  ///
  /// Arguments are automatically converted for platform channel transport.
  /// The result is cast to [T]. Platform maps are automatically deep-cast
  /// to `Map<String, dynamic>` when needed.
  ///
  /// When [timeout] is provided, the call will throw a
  /// [AutoInteropException] with code `'TIMEOUT'` if the native side does
  /// not respond within the specified duration.
  Future<T> invoke<T>(String method, [Map<String, dynamic>? arguments, Duration? timeout]) {
    return ErrorHandler.guard(() async {
      final convertedArgs = arguments != null
          ? TypeConverter.toPlatform(arguments) as Map<Object?, Object?>?
          : null;
      Future<Object?> call = _channel.invokeMethod<Object?>(method, convertedArgs);
      if (timeout != null) {
        call = call.timeout(timeout);
      }
      final result = await call;
      if (result == null) return null as T;
      return TypeConverter.fromPlatform(result) as T;
    });
  }

  /// Invokes a method that returns a List.
  ///
  /// When [timeout] is provided, the call will throw a
  /// [AutoInteropException] with code `'TIMEOUT'` if the native side does
  /// not respond within the specified duration.
  Future<List<T>> invokeList<T>(String method,
      [Map<String, dynamic>? arguments, Duration? timeout]) {
    return ErrorHandler.guard(() async {
      final convertedArgs = arguments != null
          ? TypeConverter.toPlatform(arguments) as Map<Object?, Object?>?
          : null;
      Future<List<T>?> call =
          _channel.invokeListMethod<T>(method, convertedArgs);
      if (timeout != null) {
        call = call.timeout(timeout);
      }
      final result = await call;
      return result ?? <T>[];
    });
  }

  /// Invokes a method that returns a Map.
  ///
  /// When [timeout] is provided, the call will throw a
  /// [AutoInteropException] with code `'TIMEOUT'` if the native side does
  /// not respond within the specified duration.
  Future<Map<K, V>> invokeMap<K, V>(String method,
      [Map<String, dynamic>? arguments, Duration? timeout]) {
    return ErrorHandler.guard(() async {
      final convertedArgs = arguments != null
          ? TypeConverter.toPlatform(arguments) as Map<Object?, Object?>?
          : null;
      Future<Map<K, V>?> call =
          _channel.invokeMapMethod<K, V>(method, convertedArgs);
      if (timeout != null) {
        call = call.timeout(timeout);
      }
      final result = await call;
      return result ?? <K, V>{};
    });
  }

  /// Invokes multiple methods in a single platform channel call.
  ///
  /// Each call in [calls] is a [BatchCall] specifying the method name and
  /// optional arguments. The native side processes all calls sequentially
  /// and returns a list of results (or error maps).
  ///
  /// This reduces round-trip overhead when many independent calls are
  /// needed — N calls in 1 round-trip instead of N round-trips.
  ///
  /// Returns a list of [BatchResult]s in the same order as [calls].
  Future<List<BatchResult>> batchInvoke(List<BatchCall> calls,
      {Duration? timeout}) {
    return ErrorHandler.guard(() async {
      final payload = calls
          .map((c) => <String, dynamic>{
                'method': c.method,
                if (c.arguments != null)
                  'arguments': TypeConverter.toPlatform(c.arguments!),
              })
          .toList();

      Future<Object?> call = _channel.invokeMethod<Object?>(
          '_batch', <String, dynamic>{'calls': payload});
      if (timeout != null) {
        call = call.timeout(timeout);
      }

      final rawResults = await call;
      if (rawResults is! List) {
        return calls
            .map((_) => BatchResult.error('INVALID_RESPONSE',
                'Batch response was not a list'))
            .toList();
      }

      return rawResults.map((raw) {
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          if (map.containsKey('error')) {
            final error = Map<String, dynamic>.from(map['error'] as Map);
            return BatchResult.error(
              error['code'] as String? ?? 'UNKNOWN',
              error['message'] as String?,
            );
          }
          return BatchResult.success(
              TypeConverter.fromPlatform(map['result']));
        }
        return BatchResult.success(TypeConverter.fromPlatform(raw));
      }).toList();
    });
  }
}

/// A single call in a [AutoInteropChannel.batchInvoke] request.
class BatchCall {
  /// The method name to invoke.
  final String method;

  /// Optional arguments for the method call.
  final Map<String, dynamic>? arguments;

  const BatchCall(this.method, [this.arguments]);
}

/// The result of a single call within a batch.
class BatchResult {
  /// The result value, or `null` if the call failed.
  final dynamic value;

  /// The error code if the call failed, or `null` on success.
  final String? errorCode;

  /// The error message if the call failed, or `null` on success.
  final String? errorMessage;

  const BatchResult._(this.value, this.errorCode, this.errorMessage);

  /// Creates a successful result.
  const BatchResult.success(this.value)
      : errorCode = null,
        errorMessage = null;

  /// Creates an error result.
  const BatchResult.error(this.errorCode, [this.errorMessage]) : value = null;

  /// Whether this result represents a successful call.
  bool get isSuccess => errorCode == null;

  /// Whether this result represents a failed call.
  bool get isError => errorCode != null;
}
