# auto_interop_generator

[![pub package](https://img.shields.io/pub/v/auto_interop_generator.svg)](https://pub.dev/packages/auto_interop_generator)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](https://github.com/FlutterPlaza/auto_interop/blob/main/LICENSE)

Code generator for the [auto_interop](https://github.com/FlutterPlaza/auto_interop) framework. Parses native package APIs (TypeScript, Swift, Kotlin, Java) and auto-generates type-safe Dart bindings, platform glue code, and JS interop layers.

This package is the **code generation engine**. It reads a `auto_interop.yaml` config, parses native source files, builds a Unified Type Schema (UTS), and emits Dart, Kotlin, Swift, and JavaScript code. The companion package [`auto_interop`](https://pub.dev/packages/auto_interop) provides the runtime.

## Table of Contents

- [Installation](#installation)
- [Getting Started](#getting-started)
  - [1. Configure native packages](#1-configure-native-packages)
  - [2. Generate bindings](#2-generate-bindings)
  - [3. Use the bindings](#3-use-the-bindings)
- [CLI Reference](#cli-reference)
  - [generate](#generate)
  - [list](#list)
  - [add](#add)
  - [help / version](#help--version)
- [build_runner Integration](#build_runner-integration)
- [Configuration](#configuration)
  - [auto_interop.yaml](#auto_interopyaml)
  - [Package Sources](#package-sources)
  - [Selective Imports](#selective-imports)
- [Architecture](#architecture)
  - [Pipeline Overview](#pipeline-overview)
  - [Unified Type Schema (UTS)](#unified-type-schema-uts)
  - [Parsers](#parsers)
  - [Generators](#generators)
  - [Type Mappers](#type-mappers)
  - [Installers](#installers)
  - [Type Definition Loader](#type-definition-loader)
- [Parser Details](#parser-details)
  - [npm Parser (TypeScript)](#npm-parser-typescript)
  - [Gradle Parser (Kotlin/Java)](#gradle-parser-kotlinjava)
  - [Swift Parser (CocoaPods/SPM)](#swift-parser-cocoapodsspm)
- [Generator Details](#generator-details)
  - [Dart Generator](#dart-generator)
  - [Kotlin Glue Generator](#kotlin-glue-generator)
  - [Swift Glue Generator](#swift-glue-generator)
  - [JS Glue Generator](#js-glue-generator)
- [Type Mapping](#type-mapping)
  - [TypeScript to Dart](#typescript-to-dart)
  - [Kotlin to Dart](#kotlin-to-dart)
  - [Swift to Dart](#swift-to-dart)
  - [Java to Dart](#java-to-dart)
  - [Channel Encoding](#channel-encoding)
- [Pre-built Type Definitions](#pre-built-type-definitions)
- [Extending the Generator](#extending-the-generator)
  - [Adding a Custom Parser](#adding-a-custom-parser)
  - [Adding a Custom Generator](#adding-a-custom-generator)
- [API Reference](#api-reference)
- [License](#license)

## Installation

```yaml
dev_dependencies:
  auto_interop_generator: ^0.1.0
  build_runner: ^2.4.0
```

You also need the runtime as a regular dependency:

```yaml
dependencies:
  auto_interop: ^0.1.0
```

## Getting Started

### 1. Configure native packages

Create a `auto_interop.yaml` in your project root:

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

  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
```

### 2. Generate bindings

```bash
# Using the CLI
dart run auto_interop_generator:generate

# Or using build_runner
dart run build_runner build
```

### 3. Use the bindings

```dart
import 'package:auto_interop/auto_interop.dart';
import 'generated/date_fns.dart';

void main() async {
  await AutoInteropLifecycle.instance.initialize();
  final formatted = await DateFns.format(DateTime.now(), 'yyyy-MM-dd');
  print(formatted); // 2024-01-15
}
```

## CLI Reference

The CLI is invoked via:

```bash
dart run auto_interop_generator:generate [command] [options]
```

If no command is given, `generate` is the default.

### generate

Generates Dart bindings and platform glue code from `auto_interop.yaml`.

```bash
# Default: reads auto_interop.yaml, outputs to lib/generated/
dart run auto_interop_generator:generate

# Custom config file and output directory
dart run auto_interop_generator:generate generate --config my_config.yaml --output lib/src/generated
```

**Options:**

| Flag | Default | Description |
|------|---------|-------------|
| `--config <path>` | `auto_interop.yaml` | Path to the configuration file |
| `--output <dir>` | `lib/generated` | Output directory for generated files |

**What it produces** (per package):

| File | Purpose |
|------|---------|
| `<package>.dart` | Dart bindings with typed classes, methods, enums, data classes |
| `<Package>Plugin.kt` | Kotlin FlutterPlugin for Android (Gradle sources) |
| `<Package>Plugin.swift` | Swift FlutterPlugin for iOS (CocoaPods/SPM sources) |
| `<package>_web.dart` | JS interop bindings for web (npm sources) |

### list

Lists all available pre-built type definitions.

```bash
dart run auto_interop_generator:generate list
```

Example output:

```
Available pre-built type definitions:
  alamofire — Alamofire@5.9.0 (cocoapods)
  date_fns — date-fns@3.6.0 (npm)
  lodash — lodash@4.17.21 (npm)
  okhttp3 — com.squareup.okhttp3:okhttp@4.12.0 (gradle)
  sdwebimage — SDWebImage@5.19.0 (cocoapods)
  uuid — uuid@9.0.0 (npm)
```

### add

Adds a native package entry to `auto_interop.yaml`. Creates the file if it doesn't exist.

```bash
dart run auto_interop_generator:generate add <source> <package> <version>
```

Examples:

```bash
dart run auto_interop_generator:generate add npm date-fns ^3.0.0
dart run auto_interop_generator:generate add cocoapods Alamofire "~> 5.9"
dart run auto_interop_generator:generate add gradle com.squareup.okhttp3:okhttp 4.12.0
dart run auto_interop_generator:generate add spm Alamofire "~> 5.9"
```

### help / version

```bash
dart run auto_interop_generator:generate help
dart run auto_interop_generator:generate version
```

## build_runner Integration

The generator includes a `Builder` for [`build_runner`](https://pub.dev/packages/build_runner). Add the builder to your `build.yaml`:

```yaml
targets:
  $default:
    builders:
      auto_interop_generator|auto_interop:
        enabled: true
```

Then run:

```bash
dart run build_runner build
```

The builder reads `auto_interop.yaml` and outputs a single combined file at `lib/generated/auto_interop_bindings.dart` containing all bindings.

**Note:** The build_runner integration uses pre-built type definitions only. For full parsing (downloading and analyzing native packages), use the CLI.

## Configuration

### auto_interop.yaml

The configuration file declares which native packages to generate bindings for. Each entry requires three fields:

```yaml
native_packages:
  - source: npm           # required: npm, cocoapods, gradle, spm
    package: "date-fns"   # required: the package name
    version: "^3.6.0"     # required: version constraint
    imports:              # optional: specific symbols to import
      - "format"
      - "addDays"
```

### Package Sources

| Source | Language | Platform | Package Registry |
|--------|----------|----------|-----------------|
| `npm` | TypeScript/JS | Web | npm registry |
| `cocoapods` | Swift | iOS | CocoaPods trunk |
| `spm` | Swift | iOS | Swift Package Manager |
| `gradle` | Kotlin/Java | Android | Maven Central |

### Selective Imports

The optional `imports` list lets you generate bindings for only specific functions or classes. If omitted, all public APIs are included.

```yaml
native_packages:
  - source: npm
    package: "lodash"
    version: "^4.17.21"
    imports:
      - "debounce"
      - "throttle"
      - "cloneDeep"
```

## Architecture

### Pipeline Overview

```
auto_interop.yaml     Source Parsers          Unified Type Schema
   (config)        -->  (TS/Swift/Kotlin)  -->    (intermediate)
                                                      |
                        Code Generators   <-----------+
                    (Dart/Kotlin/Swift/JS)
                            |
                    Generated Source Files
                  (what you import and use)
```

The pipeline has four stages:

1. **Config Parser** reads `auto_interop.yaml` into `AutoInteropConfig` with a list of `PackageSpec` entries
2. **Source Parsers** parse native API declarations into the **Unified Type Schema (UTS)**
3. **Code Generators** consume the UTS and emit platform-specific source code
4. **Installers** manage native dependency files (Podfile, build.gradle, package.json)

### Unified Type Schema (UTS)

The UTS is the intermediate representation at the center of the pipeline. Every parser outputs a `UnifiedTypeSchema` and every generator consumes one. This decouples parsing from generation and makes it easy to add new source languages or output targets.

```dart
class UnifiedTypeSchema {
  final String package;           // "date-fns"
  final PackageSource source;     // PackageSource.npm
  final String version;           // "3.6.0"
  final List<UtsClass> classes;   // classes with methods
  final List<UtsMethod> functions;// top-level functions
  final List<UtsClass> types;     // data classes / option objects
  final List<UtsEnum> enums;      // enum definitions
}
```

The schema is JSON-serializable (via `json_annotation`) so it can be saved to `.uts.json` files as pre-built type definitions.

**Key UTS types:**

| Class | Represents |
|-------|-----------|
| `UtsClass` | A class, struct, interface, data class, or sealed class |
| `UtsMethod` | A method or function with parameters and return type |
| `UtsParameter` | A method parameter (positional or named, optional or required) |
| `UtsField` | A class field/property with type, nullability, and read-only flag |
| `UtsEnum` | An enum with named values and optional raw values |
| `UtsEnumValue` | A single enum case |
| `UtsType` | A type reference (primitive, object, list, map, callback, stream, future, nativeObject, enum, void, dynamic) |

**`UtsType` kinds:**

| Kind | Dart Representation | Example |
|------|-------------------|---------|
| `primitive` | `String`, `int`, `double`, `bool`, `DateTime`, `Uint8List` | `UtsType.primitive('String')` |
| `object` | Named class reference | `UtsType.object('FormatOptions')` |
| `list` | `List<T>` | `UtsType.list(UtsType.primitive('String'))` |
| `map` | `Map<K, V>` | `UtsType.map(stringType, intType)` |
| `future` | `Future<T>` | `UtsType.future(UtsType.primitive('String'))` |
| `stream` | `Stream<T>` | `UtsType.stream(UtsType.primitive('int'))` |
| `callback` | `R Function(P1, P2)` | `UtsType.callback(parameterTypes: [...], returnType: ...)` |
| `nativeObject` | `NativeObject<T>` | `UtsType.nativeObject('OkHttpClient')` |
| `enumType` | Named enum reference | `UtsType.enumType('HttpMethod')` |
| `voidType` | `void` | `UtsType.voidType()` |
| `dynamic` | `dynamic` | `UtsType.dynamicType()` |

**`UtsClassKind` values:**

| Kind | Source Construct | Generated As |
|------|-----------------|-------------|
| `concreteClass` | TS class, Kotlin class, Swift class | Dart class with methods |
| `abstractClass` | TS interface (with methods), Kotlin interface, Swift protocol | `abstract class` |
| `dataClass` | TS interface (fields only), Kotlin data class, Swift struct | class with `fromMap`/`toMap` |
| `sealedClass` | Kotlin sealed class, Swift enum with associated values | `sealed class` |

### Parsers

All parsers extend `ParserBase` and implement a single method:

```dart
abstract class ParserBase {
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  });

  PackageSource get source;
}
```

`ParserBase` also provides `parseFiles()` for multi-file parsing and `mergeSchemas()` for combining multiple schemas (deduplicates by name).

| Parser | Source | Handles |
|--------|--------|---------|
| `NpmParser` | `.d.ts` TypeScript declaration files | Functions, classes, interfaces, type aliases, enums, generics, JSDoc |
| `GradleParser` | `.kt` Kotlin and `.java` Java files | Classes, data classes, sealed classes, enum classes, interfaces, suspend/Flow, KDoc/JavaDoc |
| `SwiftParser` | `.swift` / `.swiftinterface` files | Classes, structs, protocols, enums (simple + associated values), extensions, async/throws, closures, `///` docs |

### Generators

All generators extend `GeneratorBase`:

```dart
abstract class GeneratorBase {
  Map<String, String> generate(UnifiedTypeSchema schema);
}
```

The return value maps file names to generated source code.

| Generator | Output | Used For |
|-----------|--------|----------|
| `DartGenerator` | `<package>.dart` | Dart bindings (all platforms) |
| `KotlinGlueGenerator` | `<Package>Plugin.kt` | Android FlutterPlugin |
| `SwiftGlueGenerator` | `<Package>Plugin.swift` | iOS FlutterPlugin |
| `JsGlueGenerator` | `<package>_web.dart` | Web `dart:js_interop` bindings |

### Type Mappers

Language-specific mappers convert native type names to `UtsType`:

| Mapper | Source Language | Example |
|--------|---------------|---------|
| `JsToDartMapper` | TypeScript/JS | `string` -> `String`, `Promise<T>` -> `Future<T>` |
| `KotlinToDartMapper` | Kotlin | `Int` -> `int`, `suspend` -> `Future<T>` |
| `SwiftToDartMapper` | Swift | `Bool` -> `bool`, `[T]` -> `List<T>` |
| `JavaToDartMapper` | Java | `boolean` -> `bool`, `ArrayList<T>` -> `List<T>` |

The `TypeMapper` registry stores `TypeMapping` entries that pair source types with Dart types and their `ChannelEncoding` strategy.

### Installers

Installers manage native dependency files — they add, remove, and query dependencies without corrupting existing file content.

| Installer | Manages | Key Methods |
|-----------|---------|-------------|
| `NpmInstaller` | `package.json` | `addDependency`, `removeDependency`, `hasDependency`, `createPackageJson` |
| `PodInstaller` | `Podfile` | `addDependency`, `removeDependency`, `hasDependency`, `createPodfile` |
| `GradleInstaller` | `build.gradle` / `build.gradle.kts` | `addDependency`, `removeDependency`, `hasDependency` |
| `SpmInstaller` | `Package.swift` | SPM dependency management |

Example — adding an npm dependency:

```dart
final installer = NpmInstaller();
final updated = installer.addDependency(
  packageJsonContent: existingJson,
  packageName: 'date-fns',
  version: '^3.6.0',
);
```

### Type Definition Loader

`TypeDefinitionLoader` manages pre-built UTS JSON files, enabling instant code generation without re-parsing native sources.

```dart
final loader = TypeDefinitionLoader(
  definitionsDir: 'lib/src/type_definitions',
);

// List available definitions
final available = loader.listAvailable(); // ['alamofire', 'date_fns', ...]

// Load by name
final schema = loader.load('date_fns');

// Load by package name (tries exact, snake_case, and lowercase)
final schema2 = loader.loadForPackage('date-fns');

// Save a new definition
loader.save('my_package', mySchema);
```

## Parser Details

### npm Parser (TypeScript)

`NpmParser` reads `.d.ts` TypeScript declaration files. It handles:

- **Exported functions:** `export declare function format(date: Date, pattern: string): string;`
- **Classes:** `export class Interval { start: Date; end: Date; }` with methods, properties, constructors
- **Interfaces:** `export interface FormatOptions { locale?: Locale; }` (mapped to data classes if field-only, concrete classes if they have methods)
- **Type aliases:** `export type DateArg = Date | number | string;` (object type aliases with `{ ... }` bodies are parsed)
- **Enums:** `export enum RoundingMethod { ceil = "ceil", floor = "floor" }` (string and numeric)
- **Generics:** `Array<T>`, `Promise<T>`, `Map<K, V>`
- **Optional parameters:** `name?: type` (mapped to named Dart parameters)
- **Callback types:** `(value: string) => void` (mapped to `UtsType.callback`)
- **Async types:** `Promise<T>` -> `Future<T>`, `ReadableStream` -> `Stream<T>`
- **JSDoc:** `/** ... */` comments preserved as documentation
- **Privacy:** Underscore-prefixed names are filtered out

### Gradle Parser (Kotlin/Java)

`GradleParser` auto-detects whether a file is Kotlin or Java and dispatches to the appropriate parser.

**Kotlin features:**
- **Classes:** `class`, `open class`, `abstract class` with methods, fields, companion objects
- **Data classes:** `data class Config(val host: String, val port: Int)` (mapped to `UtsClassKind.dataClass`)
- **Sealed classes:** `sealed class Result { data class Success(...); object Loading; }` (mapped to `UtsClassKind.sealedClass` with subclass types)
- **Enum classes:** `enum class HttpMethod { GET, POST, PUT }` (values converted to camelCase)
- **Interfaces:** `interface Callback { fun onResult(data: String) }`
- **Suspend functions:** `suspend fun fetch(): Response` (mapped to `Future<Response>`)
- **Flow:** Kotlin Flow return types mapped to `Stream<T>`
- **Nullable types:** `String?` (mapped to nullable `UtsType`)
- **Default values:** `port: Int = 8080` (mapped to optional named parameters)
- **KDoc:** `/** ... */` comments preserved
- **Access control:** `private`/`internal` members are filtered out

**Java features:**
- **Classes:** `public class`, `public abstract class` with methods
- **Interfaces:** `public interface` with method declarations
- **Enums:** `public enum` with constants
- **Static methods:** `public static ReturnType method(...)` (mapped to `isStatic: true`)
- **Annotations:** `@Nullable` on parameters sets nullability
- **JavaDoc:** `/** ... */` comments preserved

### Swift Parser (CocoaPods/SPM)

`SwiftParser` reads Swift source files and `.swiftinterface` files.

- **Classes:** `public class`, `open class` with methods, properties
- **Structs:** `public struct Config { let host: String }` (mapped to `UtsClassKind.dataClass`)
- **Protocols:** `public protocol Delegate { func didComplete() }` (mapped to `UtsClassKind.abstractClass`) with `var name: Type { get set }` protocol property requirements
- **Enums (simple):** `enum Direction { case up, down, left, right }` (mapped to `UtsEnum`)
- **Enums (associated values):** `enum Result { case success(data: Data); case failure(error: Error) }` (mapped to `UtsClassKind.sealedClass` with data class subclasses)
- **Extensions:** `extension MyClass { func added() {} }` (methods folded into the base class)
- **Async/await:** `func fetch() async -> Data` (mapped to `Future<Data>`)
- **Throws:** Recognized but not represented in UTS (async + throws both produce `Future`)
- **Closures:** `completion: (String) -> Void` (mapped to `UtsType.callback`)
- **Optionals:** `String?` (mapped to nullable `UtsType`)
- **Default values:** `port: Int = 8080`
- **Static/class methods:** `static func`, `class func` (mapped to `isStatic: true`)
- **Documentation:** Both `///` doc comments and `/** ... */` blocks preserved
- **Access control:** `private`, `fileprivate`, and `internal` declarations are filtered out

## Generator Details

### Dart Generator

`DartGenerator` produces the primary Dart bindings that developers import. For each schema it generates:

**For enums:**
```dart
enum HttpMethod {
  get,
  post,
  put;
}
```

**For data classes (types):**
```dart
class FormatOptions {
  final String? locale;
  final int? weekStartsOn;

  FormatOptions({this.locale, this.weekStartsOn});

  factory FormatOptions.fromMap(Map<String, dynamic> map) {
    return FormatOptions(
      locale: map['locale'] as String?,
      weekStartsOn: map['weekStartsOn'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (locale != null) 'locale': locale,
    if (weekStartsOn != null) 'weekStartsOn': weekStartsOn,
  };
}
```

**For classes with methods:**
```dart
class DateFns {
  static final _channel = AutoInteropChannel('date_fns');

  static Future<String> format(DateTime date, String formatStr) async {
    final result = await _channel.invoke<String>('format', {
      'date': date.toIso8601String(),
      'formatStr': formatStr,
    });
    return result;
  }
}
```

**Special serialization:**

| Parameter Type | Serialized As |
|---------------|--------------|
| `DateTime` | `.toIso8601String()` |
| Object type | `.toMap()` |
| Enum type | `.name` |
| Callback | `CallbackManager.instance.register(callback)` |
| Primitive | Pass-through |

**Stream methods** use `AutoInteropEventChannel` instead of `AutoInteropChannel`:

```dart
static Stream<double> observe(String sensor) {
  return _eventChannel.receiveStream<double>(
    method: 'observe',
    arguments: { 'sensor': sensor },
  );
}
```

### Kotlin Glue Generator

`KotlinGlueGenerator` produces an Android `FlutterPlugin` class with:

- `MethodChannel` registration in `onAttachedToEngine`
- `when (call.method)` dispatch in `onMethodCall`
- `EventChannel` + `StreamHandler` if any methods return `Stream<T>`
- Argument extraction with `call.argument<Type>("name")`
- Type conversion for `DateTime` (ISO 8601 via `SimpleDateFormat`)
- Error handling with `result.error()`
- Instance registry for object handle management
- Real native library calls with proper import, construction, and method dispatch
- Coroutine support for `suspend` methods via `CoroutineScope`
- Data class encode/decode helpers for structured types
- Enum string↔value conversion

### Swift Glue Generator

`SwiftGlueGenerator` produces an iOS `FlutterPlugin` class with:

- `FlutterMethodChannel` registration in `register(with:)`
- `switch call.method` dispatch in `handle(_:result:)`
- `FlutterEventChannel` + `FlutterStreamHandler` if any methods return `Stream<T>`
- Argument extraction with `args["name"] as! Type`
- Type conversion for `DateTime` (ISO 8601 via `ISO8601DateFormatter`)
- Error handling with `FlutterError`
- Instance registry for object handle management
- Real native library calls with proper import, construction, and method dispatch
- `Task { }` wrapping for `async` methods with `DispatchQueue.main.async` result delivery
- Struct encode/decode helpers for structured types
- Enum string↔value conversion

### JS Glue Generator

`JsGlueGenerator` produces web bindings using `dart:js_interop`:

- **JS interop layer:** `@JS()` extension types for external declarations
- **Dart API layer:** Wrapper classes with type-safe Dart signatures
- Automatic `toJS`/`toDart` conversions between Dart and JS types
- `JSPromise` → `Future` await conversion for async methods
- Data class `fromJs`/`toJs` factories

## Type Mapping

### TypeScript to Dart

| TypeScript | Dart | Notes |
|-----------|------|-------|
| `string` | `String` | |
| `number` | `double` | Can also map to `int` based on context |
| `boolean` | `bool` | |
| `Date` | `DateTime` | Serialized as ISO 8601 |
| `Array<T>` / `T[]` | `List<T>` | |
| `Map<K, V>` / `Record<K, V>` | `Map<K, V>` | |
| `Promise<T>` | `Future<T>` | |
| `ReadableStream` | `Stream<T>` | |
| `Buffer` | `Uint8List` | |
| `(x: T) => R` | `R Function(T)` | Callback type |
| `void` | `void` | |
| `any` / `unknown` | `dynamic` | |
| `null` / `undefined` | `null` (nullable) | |

### Kotlin to Dart

| Kotlin | Dart | Notes |
|--------|------|-------|
| `String` | `String` | |
| `Int` / `Long` | `int` | |
| `Float` / `Double` | `double` | |
| `Boolean` | `bool` | |
| `List<T>` / `MutableList<T>` | `List<T>` | |
| `Map<K, V>` | `Map<K, V>` | |
| `ByteArray` | `Uint8List` | |
| `Unit` | `void` | |
| `suspend fun` | `Future<T>` | Wrapped automatically |
| `Flow<T>` | `Stream<T>` | |
| `T?` | `T?` | Nullable |
| `(T) -> R` lambda | `R Function(T)` | |

### Swift to Dart

| Swift | Dart | Notes |
|-------|------|-------|
| `String` | `String` | |
| `Int` | `int` | |
| `Float` / `Double` | `double` | |
| `Bool` | `bool` | |
| `[T]` / `Array<T>` | `List<T>` | |
| `[K: V]` / `Dictionary<K, V>` | `Map<K, V>` | |
| `Data` | `Uint8List` | |
| `Void` | `void` | |
| `async func` | `Future<T>` | Wrapped automatically |
| `AsyncSequence` / `AsyncStream` | `Stream<T>` | |
| `T?` | `T?` | Optional/nullable |
| `(T) -> R` closure | `R Function(T)` | |

### Java to Dart

| Java | Dart | Notes |
|------|------|-------|
| `String` | `String` | |
| `int` / `Integer` | `int` | |
| `float` / `Float` / `double` / `Double` | `double` | |
| `boolean` / `Boolean` | `bool` | |
| `List<T>` / `ArrayList<T>` | `List<T>` | |
| `Map<K, V>` / `HashMap<K, V>` | `Map<K, V>` | |
| `byte[]` | `Uint8List` | |
| `void` | `void` | |
| `@Nullable` annotation | nullable | |

### Channel Encoding

Each type has a `ChannelEncoding` strategy that determines how it crosses the platform channel:

| Encoding | Used For | Wire Format |
|----------|----------|-------------|
| `standard` | Primitives (`String`, `int`, `double`, `bool`) | Direct pass-through |
| `iso8601String` | `DateTime` | ISO 8601 UTC string |
| `jsonMap` | Data classes, object types | `Map<String, dynamic>` |
| `byteArray` | `Uint8List` | Raw bytes |
| `asyncChannel` | `Future<T>` | Async method channel response |
| `eventChannel` | `Stream<T>` | `EventChannel` broadcast stream |
| `callbackChannel` | Callback functions | String ID via `CallbackManager` |
| `opaqueHandle` | `NativeObject<T>` | Integer handle ID |
| `taggedUnion` | Sealed classes | Discriminated map |
| `stringName` | Enums | `.name` string |

## Pre-built Type Definitions

The generator ships with pre-built `.uts.json` files for popular packages, enabling instant code generation without parsing:

| Package | Source | Version | File |
|---------|--------|---------|------|
| date-fns | npm | 3.6.0 | `date_fns.uts.json` |
| lodash | npm | 4.17.21 | `lodash.uts.json` |
| uuid | npm | 9.0.0 | `uuid.uts.json` |
| OkHttp | Gradle | 4.12.0 | `okhttp3.uts.json` |
| Alamofire | CocoaPods | 5.9.0 | `alamofire.uts.json` |
| SDWebImage | CocoaPods | 5.19.0 | `sdwebimage.uts.json` |

Pre-built definitions are stored in `lib/src/type_definitions/` as JSON-serialized `UnifiedTypeSchema` objects. The `TypeDefinitionLoader` resolves package names using multiple naming conventions (exact, snake_case, lowercase).

To regenerate pre-built definitions from golden fixtures:

```bash
dart run tool/generate_type_definitions.dart
```

## Extending the Generator

### Adding a Custom Parser

1. Create a class that extends `ParserBase`:

```dart
import 'package:auto_interop_generator/auto_interop_generator.dart';

class MyParser extends ParserBase {
  @override
  PackageSource get source => PackageSource.npm; // or your custom source

  @override
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  }) {
    // Parse content into UTS classes, methods, types, enums
    return UnifiedTypeSchema(
      package: packageName,
      source: source,
      version: version,
      classes: [...],
      functions: [...],
      types: [...],
      enums: [...],
    );
  }
}
```

2. `ParserBase` gives you `parseFiles()` for multi-file parsing and `mergeSchemas()` for combining results with deduplication.

### Adding a Custom Generator

1. Create a class that extends `GeneratorBase`:

```dart
import 'package:auto_interop_generator/auto_interop_generator.dart';

class MyGenerator extends GeneratorBase {
  @override
  Map<String, String> generate(UnifiedTypeSchema schema) {
    final buffer = StringBuffer();
    // Generate your code using schema.classes, schema.functions, etc.
    return {'my_output.txt': buffer.toString()};
  }
}
```

2. Use `UtsType.toDartType()` to get Dart type strings, or inspect `UtsType.kind` for custom type mapping.

## API Reference

### Config

| Class | Purpose |
|-------|---------|
| `AutoInteropConfig` | Parsed configuration with a list of `PackageSpec` entries |
| `ConfigParser` | Parses `auto_interop.yaml` (string or file) into `AutoInteropConfig` |
| `ConfigParseException` | Thrown on invalid YAML or missing fields |
| `PackageSpec` | A single package entry: source, package name, version, optional imports |

### Schema (UTS)

| Class | Purpose |
|-------|---------|
| `UnifiedTypeSchema` | Top-level schema with classes, functions, types, enums |
| `UtsClass` | Class/struct/interface/sealed definition |
| `UtsMethod` | Method/function with parameters and return type |
| `UtsParameter` | Method parameter (positional/named, optional/required) |
| `UtsField` | Class field/property |
| `UtsEnum` | Enum definition with values |
| `UtsEnumValue` | Single enum case with optional raw value |
| `UtsType` | Type reference with kind, name, nullability, generics |

### Parsers

| Class | Purpose |
|-------|---------|
| `ParserBase` | Abstract base with `parse()`, `parseFiles()`, `mergeSchemas()` |
| `NpmParser` | Parses TypeScript `.d.ts` files |
| `GradleParser` | Parses Kotlin `.kt` and Java `.java` files |
| `SwiftParser` | Parses Swift `.swift` / `.swiftinterface` files |

### Generators

| Class | Purpose |
|-------|---------|
| `GeneratorBase` | Abstract base with `generate()` returning `Map<String, String>` |
| `DartGenerator` | Generates Dart binding classes |
| `KotlinGlueGenerator` | Generates Kotlin FlutterPlugin |
| `SwiftGlueGenerator` | Generates Swift FlutterPlugin |
| `JsGlueGenerator` | Generates `dart:js_interop` web bindings |

### Type Mapping

| Class | Purpose |
|-------|---------|
| `TypeMapper` | Master registry for source-to-Dart type mappings |
| `TypeMapping` | Single mapping entry (source type, Dart type, encoding) |
| `JsToDartMapper` | TypeScript/JS type mapper |
| `KotlinToDartMapper` | Kotlin type mapper |
| `SwiftToDartMapper` | Swift type mapper |
| `JavaToDartMapper` | Java type mapper |
| `ChannelEncoding` | Enum of encoding strategies for platform channels |

### CLI & build_runner

| Class | Purpose |
|-------|---------|
| `CliRunner` | CLI entry point with `run(args)` returning exit code |
| `AutoInteropBuilder` | `build_runner` Builder implementation |
| `TypeDefinitionLoader` | Loads/saves/lists pre-built `.uts.json` definitions |

### Installers

| Class | Purpose |
|-------|---------|
| `NpmInstaller` | Manages `package.json` dependencies |
| `PodInstaller` | Manages `Podfile` pod declarations |
| `GradleInstaller` | Manages `build.gradle` / `build.gradle.kts` dependencies |

## License

BSD 3-Clause License. See [LICENSE](https://github.com/FlutterPlaza/auto_interop/blob/main/LICENSE).
