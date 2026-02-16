import 'package:flutter/services.dart';

import 'error_handler.dart';

/// Provides Stream support via Flutter's EventChannel.
///
/// Used by generated bindings for APIs that return streams
/// (e.g., Kotlin Flow, Swift AsyncSequence, JS ReadableStream).
class NativeBridgeEventChannel {
  /// The underlying Flutter event channel.
  final EventChannel _eventChannel;

  /// The channel name.
  final String name;

  /// Creates a new event channel with the given [name].
  NativeBridgeEventChannel(this.name)
      : _eventChannel = EventChannel('native_bridge/$name/events');

  /// Creates an event channel with a custom [EventChannel] (for testing).
  NativeBridgeEventChannel.withChannel(this.name, this._eventChannel);

  /// Returns a broadcast stream of events from the native side.
  ///
  /// The [method] identifies which native stream to subscribe to.
  /// [arguments] are passed to the native side when starting the stream.
  Stream<T> receiveStream<T>({
    String? method,
    Map<String, dynamic>? arguments,
  }) {
    final args = <String, dynamic>{};
    if (method != null) args['method'] = method;
    if (arguments != null) args.addAll(arguments);

    return _eventChannel
        .receiveBroadcastStream(args.isEmpty ? null : args)
        .map((event) => event as T)
        .handleError((Object error) {
      if (error is PlatformException) {
        throw NativeBridgeException.fromPlatformException(error);
      }
      throw error;
    });
  }
}
