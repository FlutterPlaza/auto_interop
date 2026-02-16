import 'package:flutter/services.dart';

/// Exception thrown when a native method call fails.
class AutoInteropException implements Exception {
  /// The error code from the native side.
  final String code;

  /// The error message.
  final String? message;

  /// Additional error details.
  final dynamic details;

  const AutoInteropException({
    required this.code,
    this.message,
    this.details,
  });

  /// Creates a [AutoInteropException] from a Flutter [PlatformException].
  factory AutoInteropException.fromPlatformException(
      PlatformException e) {
    return AutoInteropException(
      code: e.code,
      message: e.message,
      details: e.details,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer('AutoInteropException($code');
    if (message != null) sb.write(': $message');
    sb.write(')');
    return sb.toString();
  }
}

/// Handles errors from native method calls.
class ErrorHandler {
  /// Wraps a platform channel call, converting [PlatformException] to
  /// [AutoInteropException].
  static Future<T> guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw AutoInteropException.fromPlatformException(e);
    }
  }
}
