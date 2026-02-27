import 'dart:async';

import 'package:flutter/services.dart';

/// Exception thrown when a native method call fails.
///
/// The [code] field contains the native exception type name
/// (e.g., `"IOException"`, `"SecurityException"`, `"NSURLError"`),
/// enabling programmatic error handling based on the original
/// native exception class.
class AutoInteropException implements Exception {
  /// The error code from the native side.
  ///
  /// This is the native exception class name (e.g., `"IOException"`),
  /// or `"MISSING_PLUGIN"` when the platform handler is not registered.
  final String code;

  /// The error message.
  final String? message;

  /// Additional error details (typically a stack trace string from
  /// the native side).
  final dynamic details;

  const AutoInteropException({
    required this.code,
    this.message,
    this.details,
  });

  /// The native exception type name.
  ///
  /// Alias for [code]. Returns the exception class name as reported
  /// by the native side (e.g., `"IOException"`, `"NSError"`).
  String get nativeExceptionType => code;

  /// Whether this exception originated from a missing plugin registration.
  bool get isMissingPlugin => code == 'MISSING_PLUGIN';

  /// Whether this is a timeout error.
  bool get isTimeout => code == 'TIMEOUT';

  /// Whether this is a network error.
  bool get isNetworkError => code == 'NETWORK_ERROR';

  /// Whether this is an I/O error.
  bool get isIoError => code == 'IO_ERROR';

  /// Whether this is a permission error.
  bool get isPermissionDenied => code == 'PERMISSION_DENIED';

  /// Whether this is a cancellation.
  bool get isCancelled => code == 'CANCELLED';

  /// Whether this is an invalid argument error.
  bool get isInvalidArgument => code == 'INVALID_ARGUMENT';

  /// Whether this is a not-found error.
  bool get isNotFound => code == 'NOT_FOUND';

  /// Creates a [AutoInteropException] from a Flutter [PlatformException].
  factory AutoInteropException.fromPlatformException(PlatformException e) {
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
  /// Wraps a platform channel call, converting [PlatformException] and
  /// [MissingPluginException] to [AutoInteropException].
  static Future<T> guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw AutoInteropException.fromPlatformException(e);
    } on MissingPluginException catch (e) {
      throw AutoInteropException(
        code: 'MISSING_PLUGIN',
        message: e.message,
      );
    } on TimeoutException catch (e) {
      throw AutoInteropException(
        code: 'TIMEOUT',
        message: 'Native method call timed out after ${e.duration}',
      );
    }
  }
}
