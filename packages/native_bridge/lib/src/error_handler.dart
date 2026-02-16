import 'package:flutter/services.dart';

/// Exception thrown when a native method call fails.
class NativeBridgeException implements Exception {
  /// The error code from the native side.
  final String code;

  /// The error message.
  final String? message;

  /// Additional error details.
  final dynamic details;

  const NativeBridgeException({
    required this.code,
    this.message,
    this.details,
  });

  /// Creates a [NativeBridgeException] from a Flutter [PlatformException].
  factory NativeBridgeException.fromPlatformException(
      PlatformException e) {
    return NativeBridgeException(
      code: e.code,
      message: e.message,
      details: e.details,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer('NativeBridgeException($code');
    if (message != null) sb.write(': $message');
    sb.write(')');
    return sb.toString();
  }
}

/// Handles errors from native method calls.
class ErrorHandler {
  /// Wraps a platform channel call, converting [PlatformException] to
  /// [NativeBridgeException].
  static Future<T> guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw NativeBridgeException.fromPlatformException(e);
    }
  }
}
