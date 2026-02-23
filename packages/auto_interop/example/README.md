# auto_interop Runtime Example

A Flutter app demonstrating every runtime component of the `auto_interop` package.

## What's Showcased

| Feature | Runtime Component | Generated Pattern |
|---------|------------------|-------------------|
| **Platform Info** | `AutoInteropChannel` | `invoke<T>()`, `invokeMap()` for typed native calls |
| **Sensor Streams** | `AutoInteropEventChannel` | `receiveStream<T>()` for real-time native data |
| **Image Processing** | `NativeObject<T>` | Opaque handles with lifecycle (`dispose`, `ensureNotDisposed`) |
| **File Download** | `CallbackManager` | Dart functions invoked from native via callback IDs |
| **Error Handling** | `ErrorHandler` | `PlatformException` → `AutoInteropException` mapping |

Additional components used throughout:
- **`AutoInteropLifecycle`** — runtime initialization and disposal
- **`TypeConverter`** — automatic DateTime, List, Map serialization

## How Generated Bindings Work

The files in `lib/generated/` follow the exact patterns that `auto_interop_generator` produces:

```dart
// 1. Data classes use fromMap/toMap for channel serialization
class DeviceInfo {
  factory DeviceInfo.fromMap(Map<String, dynamic> map) { ... }
  Map<String, dynamic> toMap() => { ... };
}

// 2. Abstract interfaces enable dependency injection and mocking
abstract interface class PlatformInfoInterface {
  Future<DeviceInfo> getDeviceInfo();
}

// 3. Implementation classes use AutoInteropChannel for native calls
class PlatformInfo implements PlatformInfoInterface {
  static const _channel = AutoInteropChannel('platform_info');

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    final result = await _channel.invokeMap<String, dynamic>('getDeviceInfo');
    return DeviceInfo.fromMap(result);
  }
}
```

## Running

```bash
cd packages/auto_interop/example
flutter run
```

Note: Native method calls will throw `MissingPluginException` without the corresponding native platform code. This example demonstrates the Dart-side API patterns and architecture.
