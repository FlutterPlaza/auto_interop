import 'package:flutter/services.dart';

/// Manages the lifecycle of native bridge resources.
///
/// Handles initialization, disposal, and native object release for
/// the entire auto_interop runtime.
class AutoInteropLifecycle {
  static AutoInteropLifecycle? _instance;

  /// The singleton lifecycle manager.
  static AutoInteropLifecycle get instance {
    _instance ??= AutoInteropLifecycle._();
    return _instance!;
  }

  /// Replaces the singleton instance (for testing).
  static set instance(AutoInteropLifecycle value) {
    _instance = value;
  }

  final MethodChannel _lifecycleChannel;
  bool _initialized = false;

  AutoInteropLifecycle._()
      : _lifecycleChannel =
            const MethodChannel('auto_interop/lifecycle');

  /// Creates a lifecycle manager with a custom channel (for testing).
  AutoInteropLifecycle.withChannel(this._lifecycleChannel);

  /// Whether the native bridge has been initialized.
  bool get isInitialized => _initialized;

  /// Initializes the native bridge runtime.
  ///
  /// This must be called before using any native bridge channels.
  /// It is safe to call multiple times — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_initialized) return;
    await _lifecycleChannel.invokeMethod<void>('initialize');
    _initialized = true;
  }

  /// Disposes all native bridge resources.
  Future<void> dispose() async {
    if (!_initialized) return;
    await _lifecycleChannel.invokeMethod<void>('dispose');
    _initialized = false;
  }

  /// Releases a native object handle.
  Future<void> releaseObject(String channelName, int handle) async {
    await _lifecycleChannel.invokeMethod<void>('releaseObject', {
      'channel': channelName,
      'handle': handle,
    });
  }
}
