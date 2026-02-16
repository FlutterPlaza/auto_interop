import 'package:flutter/services.dart';

/// Manages the lifecycle of native bridge resources.
///
/// Handles initialization, disposal, and native object release for
/// the entire native_bridge runtime.
class NativeBridgeLifecycle {
  static NativeBridgeLifecycle? _instance;

  /// The singleton lifecycle manager.
  static NativeBridgeLifecycle get instance {
    _instance ??= NativeBridgeLifecycle._();
    return _instance!;
  }

  /// Replaces the singleton instance (for testing).
  static set instance(NativeBridgeLifecycle value) {
    _instance = value;
  }

  final MethodChannel _lifecycleChannel;
  bool _initialized = false;

  NativeBridgeLifecycle._()
      : _lifecycleChannel =
            const MethodChannel('native_bridge/lifecycle');

  /// Creates a lifecycle manager with a custom channel (for testing).
  NativeBridgeLifecycle.withChannel(this._lifecycleChannel);

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
