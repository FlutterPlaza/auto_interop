/// Runtime library for native_bridge.
///
/// Provides the platform channel management, type conversion, and error
/// handling needed by generated native bindings.
library native_bridge;

export 'src/channel_manager.dart';
export 'src/type_converter.dart';
export 'src/error_handler.dart';
export 'src/lifecycle.dart';
export 'src/async_bridge.dart';
export 'src/native_object.dart';
