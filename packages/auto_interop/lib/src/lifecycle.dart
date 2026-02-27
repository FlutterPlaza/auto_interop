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
      : _lifecycleChannel = const MethodChannel('auto_interop/lifecycle');

  /// Creates a lifecycle manager with a custom channel (for testing).
  AutoInteropLifecycle.withChannel(this._lifecycleChannel);

  /// Whether the native bridge has been initialized.
  bool get isInitialized => _initialized;

  /// Initializes the native bridge runtime.
  ///
  /// This must be called before using any native bridge channels.
  /// It is safe to call multiple times — subsequent calls are no-ops.
  /// If no native lifecycle handler is registered, initialization
  /// succeeds silently — individual channels handle their own setup.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _lifecycleChannel.invokeMethod<void>('initialize');
    } on MissingPluginException {
      // No native lifecycle handler registered — this is fine.
      // Individual channels will handle their own setup.
    }
    _initialized = true;
  }

  /// Disposes all native bridge resources.
  Future<void> dispose() async {
    if (!_initialized) return;
    try {
      await _lifecycleChannel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // No native lifecycle handler registered.
    }
    _initialized = false;
  }

  /// Releases a native object handle.
  Future<void> releaseObject(String channelName, String handle) async {
    try {
      await _lifecycleChannel.invokeMethod<void>('releaseObject', {
        'channel': channelName,
        'handle': handle,
      });
    } on MissingPluginException {
      // No native lifecycle handler registered.
    }
  }
}
