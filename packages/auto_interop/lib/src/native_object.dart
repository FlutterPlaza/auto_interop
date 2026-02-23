import 'lifecycle.dart';

/// Token attached to a [NativeObject] for the [Finalizer] to release
/// the native-side resource if [dispose] is never called.
class _Release {
  final String channelName;
  final String handle;
  const _Release(this.channelName, this.handle);
}

/// An opaque handle to a native object living on the platform side.
///
/// Native objects are referenced by a string ID. The actual object lives
/// in the native runtime and is accessed via platform channel calls.
/// When the Dart-side handle is disposed, the native object is released.
///
/// A [Finalizer] is attached as a safety net: if the Dart-side handle is
/// garbage-collected without [dispose] being called, the native resource
/// is released asynchronously. However, you should still call [dispose]
/// explicitly for deterministic cleanup.
class NativeObject<T> {
  /// Weak-reference based finalizer that releases the native-side object
  /// if the Dart handle is garbage-collected without [dispose].
  static final Finalizer<_Release> _finalizer = Finalizer<_Release>((release) {
    // Fire-and-forget: the release completes asynchronously on the event loop.
    AutoInteropLifecycle.instance
        .releaseObject(release.channelName, release.handle);
  });

  /// The opaque handle ID used to reference this object on the native side.
  final String handle;

  /// The channel name this object belongs to.
  final String channelName;

  bool _disposed = false;

  NativeObject({required this.handle, required this.channelName}) {
    _finalizer.attach(this, _Release(channelName, handle), detach: this);
  }

  /// Whether this native object has been disposed.
  bool get isDisposed => _disposed;

  /// Disposes this native object, releasing the native-side resource.
  ///
  /// After disposal the [Finalizer] is detached so the release message
  /// is not sent twice.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeObject &&
          handle == other.handle &&
          channelName == other.channelName;

  @override
  int get hashCode => Object.hash(handle, channelName);

  @override
  String toString() =>
      'NativeObject<$T>(handle: $handle, disposed: $_disposed)';
}
