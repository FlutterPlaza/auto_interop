# auto_interop

[![pub package](https://img.shields.io/pub/v/auto_interop.svg)](https://pub.dev/packages/auto_interop)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](https://github.com/FlutterPlaza/auto_interop/blob/main/LICENSE)

Runtime library for the [auto_interop](https://github.com/FlutterPlaza/auto_interop) framework. Provides platform channel management, type conversion, callback handling, stream support, native object lifecycle, and structured error handling for auto-generated Dart bindings.

This package is the **runtime dependency** that generated code imports. The companion package [`auto_interop_generator`](https://pub.dev/packages/auto_interop_generator) handles code generation.

## Table of Contents

- [Installation](#installation)
- [Getting Started](#getting-started)
- [End-to-End Examples](#end-to-end-examples)
  - [Web: date-fns (npm)](#web-date-fns-npm)
  - [iOS: Alamofire (CocoaPods)](#ios-alamofire-cocoapods)
  - [Android: OkHttp (Gradle)](#android-okhttp-gradle)
- [Core Concepts](#core-concepts)
  - [Lifecycle Management](#lifecycle-management)
  - [Method Channels](#method-channels)
  - [Event Channels (Streams)](#event-channels-streams)
  - [Callbacks](#callbacks)
  - [Native Objects](#native-objects)
  - [Type Conversion](#type-conversion)
  - [Error Handling](#error-handling)
- [Channel Naming Convention](#channel-naming-convention)
- [Testing](#testing)
- [API Reference](#api-reference)
- [License](#license)

## Installation

```yaml
dependencies:
  auto_interop: ^0.1.0
```

In most projects you also add the generator as a dev dependency:

```yaml
dev_dependencies:
  auto_interop_generator: ^0.1.0
  build_runner: ^2.4.0
```

## Getting Started

Generated bindings take care of all the wiring for you. A typical app looks like this:

```dart
import 'package:flutter/material.dart';
import 'package:auto_interop/auto_interop.dart';
import 'generated/date_fns.dart';     // generated
import 'generated/alamofire.dart';    // generated

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize the runtime
  await AutoInteropLifecycle.instance.initialize();

  // 2. Call generated bindings via the singleton instance
  final formatted = await DateFns.instance.format(DateTime.now(), 'yyyy-MM-dd');
  print(formatted); // 2024-01-15

  // 3. Use interfaces for dependency injection / testability
  final DateFnsInterface dateFns = DateFns.instance;
  final tomorrow = await dateFns.addDays(DateTime.now(), 1);

  // 4. When your app is shutting down
  await AutoInteropLifecycle.instance.dispose();
}
```

Each generated package exposes:
- An **interface** (e.g. `DateFnsInterface`) for dependency injection and mocking
- A **concrete class** (e.g. `DateFns`) with a `.instance` singleton that implements the interface
- Instance methods marked with `@override`

You rarely need to touch the runtime classes directly. The sections below explain what each class does if you need lower-level control, want to write custom bindings, or are implementing the native side.

## End-to-End Examples

These examples show real native libraries — not available as Flutter plugins — and the Dart bindings + native glue code that `auto_interop_generator` produces for each platform.

### Web: date-fns (npm)

[date-fns](https://date-fns.org/) is a JavaScript date utility library with no Flutter equivalent. Here is the full flow from config to generated code.

**1. Config** (`auto_interop.yaml`)

```yaml
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.6.0"
    imports:
      - "format"
      - "addDays"
      - "differenceInDays"
```

**2. Generated Dart binding** (`lib/generated/date_fns.dart`)

The generator produces an interface for DI/testing, a concrete class with a `.instance` singleton, and data classes:

```dart
// GENERATED CODE — DO NOT EDIT
import 'package:auto_interop/auto_interop.dart';

class FormatOptions {
  final String? locale;
  final double? weekStartsOn;

  FormatOptions({this.locale, this.weekStartsOn});

  factory FormatOptions.fromMap(Map<String, dynamic> map) { /* ... */ }
  Map<String, dynamic> toMap() => { /* ... */ };
}

abstract interface class DateFnsInterface {
  Future<String> format(DateTime date, String formatStr);
  Future<DateTime> addDays(DateTime date, double amount);
  Future<double> differenceInDays(DateTime dateLeft, DateTime dateRight);
}

class DateFns implements DateFnsInterface {
  static const _channel = AutoInteropChannel('date_fns');

  static final DateFns instance = DateFns._();
  DateFns._();

  @override
  Future<String> format(DateTime date, String formatStr) async {
    final result = await _channel.invoke<String>('format', {
      'date': date.toIso8601String(),
      'formatStr': formatStr,
    });
    return result;
  }

  @override
  Future<DateTime> addDays(DateTime date, double amount) async {
    final result = await _channel.invoke<DateTime>('addDays', {
      'date': date.toIso8601String(),
      'amount': amount,
    });
    return result;
  }

  @override
  Future<double> differenceInDays(DateTime dateLeft, DateTime dateRight) async {
    final result = await _channel.invoke<double>('differenceInDays', {
      'dateLeft': dateLeft.toIso8601String(),
      'dateRight': dateRight.toIso8601String(),
    });
    return result;
  }
}
```

**3. Generated JS interop glue** (`lib/generated/date_fns_web.dart`)

On web, the generator produces `dart:js_interop` bindings that call the npm package directly — no platform channel needed:

```dart
// GENERATED CODE — DO NOT EDIT
import 'dart:js_interop';

@JS('dateFns.format')
external JSString _jsFormat(JSString date, JSString formatStr);
@JS('dateFns.addDays')
external JSString _jsAddDays(JSString date, JSNumber amount);
@JS('dateFns.differenceInDays')
external JSNumber _jsDifferenceInDays(JSString dateLeft, JSString dateRight);

class DateFns {
  static String format(DateTime date, String formatStr) {
    final jsResult = _jsFormat(date.toIso8601String().toJS, formatStr.toJS);
    return jsResult.toDart;
  }

  static DateTime addDays(DateTime date, double amount) {
    final jsResult = _jsAddDays(date.toIso8601String().toJS, amount.toJS);
    return DateTime.parse(jsResult.toDart);
  }

  static double differenceInDays(DateTime dateLeft, DateTime dateRight) {
    final jsResult = _jsDifferenceInDays(
      dateLeft.toIso8601String().toJS, dateRight.toIso8601String().toJS);
    return jsResult.toDartDouble;
  }
}
```

**4. Usage in Flutter**

```dart
import 'generated/date_fns.dart';

// Direct use
final formatted = await DateFns.instance.format(DateTime.now(), 'yyyy-MM-dd');

// Dependency injection via the interface
final DateFnsInterface dateFns = DateFns.instance;
final tomorrow = await dateFns.addDays(DateTime.now(), 1);
final daysBetween = await dateFns.differenceInDays(tomorrow, DateTime.now());
```

---

### iOS: Alamofire (CocoaPods)

[Alamofire](https://github.com/Alamofire/Alamofire) is Swift's most popular HTTP networking library. It provides session management, request chaining, and response validation that go beyond `dart:io`'s `HttpClient`.

**1. Config** (`auto_interop.yaml`)

```yaml
native_packages:
  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"
    imports:
      - "Session"
      - "DataRequest"
```

**2. Generated Dart binding** (`lib/generated/alamofire.dart`)

Each native class gets its own interface + concrete class. Data classes get `toMap`/`fromMap` for channel serialization:

```dart
// GENERATED CODE — DO NOT EDIT
import 'package:auto_interop/auto_interop.dart';

enum HTTPMethod { get, post, put, delete, patch, head, options; }

class DataResponse {
  final Uint8List? data;
  final int statusCode;
  final Map<String, String> headers;

  DataResponse({this.data, required this.statusCode, required this.headers});

  factory DataResponse.fromMap(Map<String, dynamic> map) { /* ... */ }
  Map<String, dynamic> toMap() => { /* ... */ };
}

abstract interface class SessionInterface {
  Future<DataRequest> request(String url, String method, Map<String, String>? headers);
  Future<Future<String>> download(String url, String? destination);
  Future<Future<String>> upload(Uint8List data, String url);
}

class Session implements SessionInterface {
  static const _channel = AutoInteropChannel('alamofire');

  @override
  Future<DataRequest> request(String url, String method, Map<String, String>? headers) async {
    final result = await _channel.invoke<DataRequest>('request', {
      'url': url, 'method': method, 'headers': headers,
    });
    return result;
  }
  // ... download(), upload() follow the same pattern
}

abstract interface class DataRequestInterface {
  Future<Future<DataResponse>> response();
  Future<void> cancel();
  Future<void> resume();
}

class DataRequest implements DataRequestInterface {
  static const _channel = AutoInteropChannel('alamofire');

  @override
  Future<void> cancel() async {
    await _channel.invoke<void>('cancel');
  }
  // ... response(), resume() follow the same pattern
}
```

**3. Generated Swift glue** (`AlamofirePlugin.swift`)

The generator produces a Flutter plugin that bridges method channel calls to the native Alamofire library:

```swift
// GENERATED CODE — DO NOT EDIT
import Flutter
import UIKit

public class AlamofirePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "alamofire", binaryMessenger: registrar.messenger())
        let instance = AlamofirePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "ARGS", message: "Invalid arguments", details: nil))
            return
        }

        switch call.method {
        case "Session.request":
            let url = args["url"] as! String
            let method = args["method"] as! String
            let headers = args["headers"] as? [String: Any]
            // TODO: Call Alamofire's Session.request(url, method:, headers:)
            result(nil)
        case "DataRequest.cancel":
            // TODO: Call DataRequest.cancel()
            result(nil)
        // ... other methods
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

**4. Usage in Flutter**

```dart
import 'generated/alamofire.dart';

// Create a session and make an HTTP request (iOS only)
final SessionInterface session = Session();
final request = await session.request('https://api.example.com/users', 'GET', null);

// Cancel a request
await request.cancel();
```

---

### Android: OkHttp (Gradle)

[OkHttp](https://square.github.io/okhttp/) is Android's most popular HTTP client, offering connection pooling, transparent GZIP, and HTTP/2 support beyond what `dart:io` provides.

**1. Config** (`auto_interop.yaml`)

```yaml
native_packages:
  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
    imports:
      - "OkHttpClient"
      - "Request"
      - "Response"
```

**2. Generated Dart binding** (`lib/generated/com_squareup_okhttp3_okhttp.dart`)

Abstract native classes become `abstract interface class` in Dart. Concrete classes get an interface + `implements`:

```dart
// GENERATED CODE — DO NOT EDIT
import 'package:auto_interop/auto_interop.dart';

enum HttpMethod { get, post, put, delete; }

class Request {
  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;

  Request({required this.url, required this.method, required this.headers, this.body});

  factory Request.fromMap(Map<String, dynamic> map) { /* ... */ }
  Map<String, dynamic> toMap() => { /* ... */ };
}

class Response {
  final int code;
  final String message;
  final String? body;
  final Map<String, String> headers;

  Response({required this.code, required this.message, this.body, required this.headers});

  factory Response.fromMap(Map<String, dynamic> map) { /* ... */ }
  Map<String, dynamic> toMap() => { /* ... */ };
}

abstract interface class OkHttpClientInterface {
  Future<Call> newCall(Request request);
  Future<void> close();
}

class OkHttpClient implements OkHttpClientInterface {
  static const _channel = AutoInteropChannel('com_squareup_okhttp3_okhttp');

  @override
  Future<Call> newCall(Request request) async {
    final result = await _channel.invoke<Call>('newCall', {
      'request': request.toMap(),
    });
    return result;
  }

  @override
  Future<void> close() async {
    await _channel.invoke<void>('close');
  }
}

// Abstract native class → abstract interface class in Dart
abstract interface class Call {
  Future<Future<Response>> execute();
  Future<void> cancel();
}
```

**3. Generated Kotlin glue** (`ComSquareupOkhttp3OkhttpPlugin.kt`)

The generator produces a Flutter plugin that bridges method channel calls to the native OkHttp library:

```kotlin
// GENERATED CODE — DO NOT EDIT
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class ComSquareupOkhttp3OkhttpPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com_squareup_okhttp3_okhttp")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "OkHttpClient.newCall" -> {
                val request = call.argument<Map<String, Any?>>("request")!!
                // TODO: Call OkHttpClient.newCall(Request)
                result.success(null)
            }
            "OkHttpClient.close" -> {
                // TODO: Call OkHttpClient.close()
                result.success(null)
            }
            "Call.execute" -> {
                // TODO: Call Call.execute()
                result.success(null)
            }
            "Call.cancel" -> {
                // TODO: Call Call.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
```

**4. Usage in Flutter**

```dart
import 'generated/com_squareup_okhttp3_okhttp.dart';

// Create a client and execute a request (Android only)
final OkHttpClientInterface client = OkHttpClient();
final request = Request(
  url: 'https://api.example.com/users',
  method: 'GET',
  headers: {'Accept': 'application/json'},
);
final call = await client.newCall(request);
await client.close();
```

---

### What the generator produces — summary

| Source | Dart binding | Native glue | Platform |
|--------|-------------|-------------|----------|
| npm | Interface + class via `AutoInteropChannel` | `dart:js_interop` external functions | Web |
| CocoaPods / SPM | Interface + class via `AutoInteropChannel` | Swift `FlutterPlugin` with method dispatch | iOS |
| Gradle | Interface + class via `AutoInteropChannel` | Kotlin `FlutterPlugin` with method dispatch | Android |

For every concrete class with instance methods, the generator creates:
1. An `abstract interface class` (e.g. `SessionInterface`) for DI and testing
2. A concrete `class` (e.g. `Session implements SessionInterface`) with `@override` methods
3. Data classes with `toMap()`/`fromMap()` for channel serialization
4. Enums mapped 1:1 from the native API

## Core Concepts

### Lifecycle Management

`AutoInteropLifecycle` is a singleton that bootstraps and tears down the native bridge runtime. It must be initialized before any channel calls are made.

```dart
final lifecycle = AutoInteropLifecycle.instance;

// Initialize once at app start (safe to call multiple times — subsequent calls are no-ops)
await lifecycle.initialize();

print(lifecycle.isInitialized); // true

// Dispose at app shutdown — releases all native resources
await lifecycle.dispose();
```

The lifecycle manager also handles releasing individual native objects:

```dart
// Called automatically by NativeObject.dispose(), but available if needed
await lifecycle.releaseObject('my_channel', objectHandle);
```

**Channel:** `auto_interop/lifecycle`
**Methods:** `initialize`, `dispose`, `releaseObject`

---

### Method Channels

`AutoInteropChannel` wraps Flutter's `MethodChannel` with typed invocations, automatic argument conversion, and structured error handling.

```dart
final channel = AutoInteropChannel('date_fns');

// Simple invocation
final result = await channel.invoke<String>('format', {
  'date': DateTime.now(),  // automatically converted to ISO 8601
  'pattern': 'yyyy-MM-dd',
});

// List result
final items = await channel.invokeList<String>('getCategories');

// Map result
final headers = await channel.invokeMap<String, String>('getHeaders');
```

All three methods (`invoke`, `invokeList`, `invokeMap`):
- Convert arguments through `TypeConverter.toPlatform()` before sending
- Wrap the call in `ErrorHandler.guard()` so `PlatformException` is translated to `AutoInteropException`
- Return typed results

**Channel:** `auto_interop/<name>` (e.g. `auto_interop/date_fns`)

---

### Event Channels (Streams)

`AutoInteropEventChannel` maps Flutter's `EventChannel` to Dart `Stream`s. Used by generated bindings for native APIs that produce continuous events (Kotlin `Flow`, Swift `AsyncSequence`, JS `ReadableStream`).

```dart
final eventChannel = AutoInteropEventChannel('sensor_data');

// Subscribe to a named stream
final stream = eventChannel.receiveStream<double>(
  method: 'accelerometer',
  arguments: {'interval': 100},
);

stream.listen(
  (value) => print('Acceleration: $value'),
  onError: (e) {
    if (e is AutoInteropException) {
      print('Native error: ${e.code} — ${e.message}');
    }
  },
);
```

Key behaviors:
- Returns a **broadcast stream** (multiple listeners allowed)
- Platform errors are automatically mapped to `AutoInteropException`
- The `method` parameter tells the native side which stream to open
- Additional `arguments` are merged and sent as the stream configuration

**Channel:** `auto_interop/<name>/events`

---

### Callbacks

`CallbackManager` enables passing Dart functions to native code. When a generated binding has a callback parameter, the manager assigns a unique string ID (`cb_0`, `cb_1`, ...) and stores the function. The native side invokes the callback by sending a method call on the callback channel with the ID as the method name.

```dart
final manager = CallbackManager.instance;

// Register a callback — returns its ID
final id = manager.register((String value) {
  print('Native called back with: $value');
});
print(id); // "cb_0"

// Pass `id` to native code via a channel call
await channel.invoke('setListener', {'callbackId': id});

// Cleanup when no longer needed
manager.unregister(id);

// Or clear all callbacks
manager.clear();

// Inspection
print(manager.count);               // number of active callbacks
print(manager.isRegistered(id));     // false (after unregister)
```

**How native invocation works:**

1. Native code sends a method call on the `auto_interop/callbacks` channel
2. The method name is the callback ID (e.g. `cb_0`)
3. Arguments are passed as a `List` (positional) or a single value
4. The callback's return value is sent back as the method call result

The manager supports callbacks with 0-3+ arguments:

```dart
manager.register(() => 'no args');
manager.register((a) => 'one arg: $a');
manager.register((a, b) => 'two args: $a, $b');
manager.register((a, b, c) => 'three args: $a, $b, $c');
```

**Channel:** `auto_interop/callbacks`

---

### Native Objects

`NativeObject<T>` is an opaque handle to an object that lives on the native side. The Dart side holds only an integer ID; the real object stays in native memory. When the Dart handle is disposed, the native object is released.

```dart
// Typically created by generated code from a channel call result
final client = NativeObject<OkHttpClient>(
  handle: 42,
  channelName: 'okhttp3',
);

print(client.handle);      // 42
print(client.isDisposed);  // false

// Use the handle in subsequent calls
await channel.invoke('execute', {
  'clientHandle': client.handle,
  'url': 'https://example.com',
});

// Ensure the object is still valid before use
client.ensureNotDisposed(); // throws StateError if disposed

// Release the native object when done
await client.dispose();
print(client.isDisposed);  // true

// Second dispose is a safe no-op
await client.dispose();

// Calling ensureNotDisposed after disposal throws
client.ensureNotDisposed(); // StateError: NativeObject<OkHttpClient>(handle: 42) has been disposed
```

The generic type parameter `T` is for documentation only — it helps generated code express which native class the handle refers to.

---

### Type Conversion

`TypeConverter` handles encoding/decoding between Dart types and Flutter's platform channel wire format. Platform channels natively support `int`, `double`, `String`, `bool`, `List`, and `Map` — but not `DateTime`.

```dart
// Dart → Platform (for sending)
TypeConverter.toPlatform(DateTime(2024, 1, 15));  // "2024-01-15T00:00:00.000Z"
TypeConverter.toPlatform('hello');                  // "hello" (pass-through)
TypeConverter.toPlatform(42);                       // 42 (pass-through)
TypeConverter.toPlatform(null);                     // null

// Recursively converts collections
TypeConverter.toPlatform({
  'date': DateTime(2024, 1, 15),
  'items': [DateTime(2024, 6, 1), DateTime(2024, 12, 25)],
});
// → {"date": "2024-01-15T00:00:00.000Z", "items": ["2024-06-01T...", "2024-12-25T..."]}

// Platform → Dart (for receiving)
TypeConverter.fromPlatform("2024-01-15T00:00:00.000Z", dartType: 'DateTime');
// → DateTime(2024, 1, 15)

// Convenience helpers
TypeConverter.dateTimeToString(DateTime(2024, 1, 15));  // ISO 8601 string
TypeConverter.stringToDateTime("2024-01-15T00:00:00.000Z");  // DateTime
```

Conversion rules:
| Dart Type | Wire Format | Notes |
|-----------|-------------|-------|
| `String` | `String` | Pass-through |
| `int` | `int` | Pass-through |
| `double` | `double` | Pass-through |
| `bool` | `bool` | Pass-through |
| `DateTime` | `String` | ISO 8601 UTC |
| `List<T>` | `List` | Elements recursively converted |
| `Map<K, V>` | `Map` | Keys and values recursively converted |
| `null` | `null` | Pass-through |

---

### Error Handling

All channel calls are wrapped in `ErrorHandler.guard()`, which catches `PlatformException` and rethrows as `AutoInteropException` with structured fields.

```dart
try {
  await channel.invoke<String>('riskyMethod');
} on AutoInteropException catch (e) {
  print(e.code);     // e.g. "NOT_FOUND"
  print(e.message);  // e.g. "Resource not found"
  print(e.details);  // any additional data from native side
}
```

You can also use `ErrorHandler.guard()` directly for custom channel calls:

```dart
final result = await ErrorHandler.guard(() async {
  return await myCustomChannel.invokeMethod<String>('method');
});
```

`AutoInteropException` fields:

| Field | Type | Description |
|-------|------|-------------|
| `code` | `String` | Machine-readable error code from native side |
| `message` | `String?` | Human-readable error description |
| `details` | `dynamic` | Additional error data (stack trace, context, etc.) |

---

## Channel Naming Convention

All platform channels follow a consistent naming scheme:

| Purpose | Channel Name | Example |
|---------|-------------|---------|
| Method calls | `auto_interop/<package>` | `auto_interop/date_fns` |
| Event streams | `auto_interop/<package>/events` | `auto_interop/date_fns/events` |
| Lifecycle | `auto_interop/lifecycle` | — |
| Callbacks | `auto_interop/callbacks` | — |

The `<package>` name is the snake_case form of the native package name (e.g., `date-fns` becomes `date_fns`, `OkHttp` becomes `okhttp3`).

## Testing

All runtime classes accept custom channels via `.withChannel()` constructors, making them easy to mock in tests:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auto_interop/auto_interop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AutoInteropChannel invokes method', () async {
    final channel = AutoInteropChannel.withChannel(
      'test',
      const MethodChannel('auto_interop/test'),
    );

    // Set up a mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('auto_interop/test'),
      (call) async {
        if (call.method == 'greet') return 'Hello!';
        return null;
      },
    );

    final result = await channel.invoke<String>('greet');
    expect(result, 'Hello!');
  });

  test('CallbackManager registers and invokes', () {
    final manager = CallbackManager.withChannel(
      const MethodChannel('auto_interop/callbacks'),
    );

    var received = '';
    final id = manager.register((String value) => received = value);

    expect(id, 'cb_0');
    expect(manager.isRegistered(id), isTrue);

    manager.unregister(id);
    expect(manager.isRegistered(id), isFalse);
  });

  test('NativeObject lifecycle', () async {
    final obj = NativeObject<String>(handle: 1, channelName: 'test');
    expect(obj.isDisposed, isFalse);

    obj.ensureNotDisposed(); // should not throw

    // Note: dispose() calls AutoInteropLifecycle.instance.releaseObject()
    // In tests, mock the lifecycle or test the disposed state directly
  });

  test('TypeConverter handles DateTime', () {
    final dt = DateTime.utc(2024, 1, 15);
    final encoded = TypeConverter.toPlatform(dt);
    expect(encoded, '2024-01-15T00:00:00.000Z');

    final decoded = TypeConverter.fromPlatform(encoded, dartType: 'DateTime');
    expect(decoded, dt);
  });
}
```

Testable constructors:

| Class | Test Constructor |
|-------|-----------------|
| `AutoInteropChannel` | `.withChannel(name, MethodChannel)` |
| `AutoInteropEventChannel` | `.withChannel(name, EventChannel)` |
| `AutoInteropLifecycle` | `.withChannel(MethodChannel)` |
| `CallbackManager` | `.withChannel(MethodChannel)` |

Singletons (`AutoInteropLifecycle.instance`, `CallbackManager.instance`) also expose setters, so you can replace them with test doubles:

```dart
AutoInteropLifecycle.instance = AutoInteropLifecycle.withChannel(mockChannel);
CallbackManager.instance = CallbackManager.withChannel(mockChannel);
```

## API Reference

| Class | Purpose |
|-------|---------|
| [`AutoInteropLifecycle`](#lifecycle-management) | Singleton that initializes/disposes the runtime and releases native objects |
| [`AutoInteropChannel`](#method-channels) | Typed method channel invocations with auto-conversion and error handling |
| [`AutoInteropEventChannel`](#event-channels-streams) | Stream support via Flutter EventChannels for continuous native events |
| [`CallbackManager`](#callbacks) | Registers Dart functions for invocation from native code via unique IDs |
| [`NativeObject<T>`](#native-objects) | Opaque handle to a native-side object with dispose/lifecycle support |
| [`TypeConverter`](#type-conversion) | Encodes/decodes Dart types (especially `DateTime`) for platform channel transport |
| [`ErrorHandler`](#error-handling) | Wraps channel calls, converting `PlatformException` to `AutoInteropException` |
| [`AutoInteropException`](#error-handling) | Structured exception with `code`, `message`, and `details` fields |

## License

BSD 3-Clause License. See [LICENSE](https://github.com/FlutterPlaza/auto_interop/blob/main/LICENSE).
