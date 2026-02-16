import 'lifecycle.dart';

/// An opaque handle to a native object living on the platform side.
///
/// Native objects are referenced by an integer ID. The actual object lives
/// in the native runtime and is accessed via platform channel calls.
/// When the Dart-side handle is disposed, the native object is released.
class NativeObject<T> {
  /// The opaque handle ID used to reference this object on the native side.
  final int handle;

  /// The channel name this object belongs to.
  final String channelName;

  bool _disposed = false;

  NativeObject({required this.handle, required this.channelName});

  /// Whether this native object has been disposed.
  bool get isDisposed => _disposed;

  /// Disposes this native object, releasing the native-side resource.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await AutoInteropLifecycle.instance.releaseObject(channelName, handle);
  }

  /// Throws if this object has been disposed.
  void ensureNotDisposed() {
    if (_disposed) {
      throw StateError(
        'NativeObject<$T>(handle: $handle) has been disposed',
      );
    }
  }

  @override
  String toString() =>
      'NativeObject<$T>(handle: $handle, disposed: $_disposed)';
}
