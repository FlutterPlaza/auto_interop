# auto_interop

[![pub package](https://img.shields.io/pub/v/auto_interop.svg)](https://pub.dev/packages/auto_interop)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](https://github.com/FlutterPlaza/auto_interop/blob/main/LICENSE)

Use **any** native package in Flutter — npm, CocoaPods, SPM, or Gradle — with auto-generated type-safe Dart bindings.

```dart
// Generated from Alamofire (iOS) — no manual bridging code
final session = await Session.create();
final request = await session.request('https://api.example.com', HTTPMethod.get, null);
final response = await request.response();
print('Status: ${response.statusCode}');
```

## Quick Start

### 1. Install

```yaml
# pubspec.yaml
dependencies:
  auto_interop: ^0.2.0

dev_dependencies:
  auto_interop_generator: ^0.2.0
  build_runner: ^2.4.0
```

### 2. Declare native packages

Create `auto_interop.yaml` in your project root:

```yaml
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.6.0"
    imports:
      - "format"
      - "addDays"

  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"
    imports:
      - "Session"
      - "DataRequest"

  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
    imports:
      - "OkHttpClient"
      - "Request"
```

### 3. Generate bindings

```bash
dart run auto_interop_generator:generate
```

This produces Dart bindings, plus native glue code (Swift plugin for iOS, Kotlin plugin for Android, JS interop for web).

### 4. Use

```dart
import 'package:auto_interop/auto_interop.dart';
import 'generated/alamofire.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AutoInteropLifecycle.instance.initialize();

  final session = await Session.create();
  final request = await session.request(
    'https://httpbin.org/get',
    HTTPMethod.get,
    null,
  );
  final response = await request.response();
  print('Status: ${response.statusCode}');

  await request.dispose();
  await session.dispose();
}
```

## Supported Platforms

| Source | Platform | Native Glue |
|--------|----------|-------------|
| `npm` | Web | `dart:js_interop` bindings |
| `cocoapods` / `spm` | iOS | Swift FlutterPlugin |
| `gradle` | Android | Kotlin FlutterPlugin |

## What Gets Generated

For each native package, the generator produces:

- **Dart bindings** — classes, methods, enums, and data types with full type safety
- **Interfaces** — for dependency injection and testing (e.g. `SessionInterface`)
- **Native glue** — platform channel handlers that call the real native library
- **Data classes** — with `toMap()`/`fromMap()` for serialization

```dart
// Generated interface — use for DI and mocking
abstract interface class SessionInterface {
  Future<DataRequest> request(String url, HTTPMethod method, Map<String, String>? headers);
  Future<String> download(String url, String? destination);
}

// Generated implementation
class Session implements SessionInterface {
  static Future<Session> create() async { ... }

  @override
  Future<DataRequest> request(...) async { ... }
}
```

## Runtime API

The `auto_interop` package provides the runtime that generated code depends on. You rarely need to use these directly — generated bindings handle everything.

| Class | Purpose |
|-------|---------|
| `AutoInteropLifecycle` | Initialize/dispose the runtime. Call once at app start. |
| `AutoInteropChannel` | Method channel with typed invocations and error handling. |
| `AutoInteropEventChannel` | Stream support for native events (Kotlin Flow, Swift AsyncSequence). |
| `CallbackManager` | Passes Dart functions to native code via unique IDs. |
| `NativeObject<T>` | Opaque handle to a native-side object with dispose support. |
| `TypeConverter` | Dart ↔ platform type conversion (handles `DateTime`, collections, etc). |
| `ErrorHandler` | Wraps `PlatformException` into structured `AutoInteropException`. |

### Initialize at app start

```dart
await AutoInteropLifecycle.instance.initialize();
```

### Handle errors

```dart
try {
  final response = await request.response();
} on AutoInteropException catch (e) {
  print('${e.code}: ${e.message}');
}
```

### Dispose native objects

Handle-based objects (Session, OkHttpClient, etc.) hold native memory. Always dispose them when done:

```dart
final session = await Session.create();
// ... use session ...
await session.dispose();
```

## Testing

Generated classes expose interfaces for easy mocking. Runtime classes have `.withChannel()` constructors for test doubles:

```dart
// Mock via the generated interface
class MockSession implements SessionInterface {
  @override
  Future<DataRequest> request(...) async => mockRequest;
}

// Or replace the runtime singleton for integration tests
AutoInteropLifecycle.instance = AutoInteropLifecycle.withChannel(mockChannel);
```

## Type Mapping

| Native Type | Dart Type | Wire Format |
|-------------|-----------|-------------|
| `String` / `string` | `String` | Pass-through |
| `Int` / `number` / `int` | `int` / `double` | Pass-through |
| `Bool` / `boolean` | `bool` | Pass-through |
| `Date` / `Date` / `Date` | `DateTime` | ISO 8601 string |
| `[T]` / `Array<T>` / `List<T>` | `List<T>` | List |
| `[K:V]` / `Map<K,V>` | `Map<K,V>` | Map |
| `Data` / `ByteArray` / `Buffer` | `Uint8List` | Byte array |
| `async` / `suspend` / `Promise<T>` | `Future<T>` | Async channel |
| `AsyncSequence` / `Flow<T>` / `ReadableStream` | `Stream<T>` | Event channel |
| Closures / lambdas / callbacks | `Function` | Callback channel |
| Class instances | Handle-based proxy | Opaque handle |
| Enums | Dart `enum` | String name |
| Sealed/associated enums | `sealed class` | Tagged union |

## Related

- [Documentation](https://flutterplaza.github.io/auto_interop/) — full documentation with examples, architecture, and API reference
- [`auto_interop_generator`](https://pub.dev/packages/auto_interop_generator) — the code generation engine (config, parsers, generators, CLI)
- [Example app](https://github.com/FlutterPlaza/auto_interop/tree/main/packages/auto_interop/example) — full working demo with Alamofire, streams, callbacks, and error handling

## License

BSD 3-Clause. See [LICENSE](https://github.com/FlutterPlaza/auto_interop/blob/main/LICENSE).
