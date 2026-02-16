#native_bridge — Universal Native Package Binding Generator

## Vision

A `build_runner`-based tool that lets Flutter developers consume **any** native package (npm, CocoaPods/Swift Package Manager, Kotlin/Gradle) by auto-generating type-safe Dart bindings.

```yaml
# pubspec.yaml
dependencies:
  native_bridge: ^1.0.0

dev_dependencies:
  native_bridge_generator: ^1.0.0
  build_runner: ^2.4.0

# native_bridge.yaml (new config file)
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
    imports:
      - "format"
      - "addDays"
      - "differenceInDays"

  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"
    imports:
      - "AF.request"
      - "AF.download"

  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
    imports:
      - "OkHttpClient"
      - "Request"
      - "Response"
```

Then run:

```bash
dart run build_runner build
# or
flutter pub run native_bridge:generate
```

And get:

```dart
// GENERATED — do not edit
import 'package:native_bridge/native_bridge.dart';

class DateFns {
  static Future<String> format(DateTime date, String formatStr) async { ... }
  static Future<DateTime> addDays(DateTime date, int amount) async { ... }
  static Future<int> differenceInDays(DateTime left, DateTime right) async { ... }
}
```

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        native_bridge.yaml                         │
│              (declares which native packages to bind)              │
└───────────────────────────┬──────────────────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │  build_runner   │
                    │  entry point    │
                    └───────┬────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │  NPM Parser  │ │  Pod Parser  │ │ Gradle Parser│
    │  (JS/TS)     │ │  (Swift/ObjC)│ │ (Kotlin/Java)│
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           ▼                ▼                ▼
    ┌──────────────────────────────────────────────┐
    │          Unified Type Schema (UTS)            │
    │  (intermediate representation of all APIs)    │
    └──────────────────────┬───────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │ Dart Binding │ │ Platform    │ │ Platform    │
    │ Generator    │ │ Channel Gen │ │ Installer   │
    │ (.dart)      │ │ (Kotlin/    │ │ (adds deps  │
    │              │ │  Swift glue)│ │  to native  │
    │              │ │             │ │  projects)  │
    └─────────────┘ └─────────────┘ └─────────────┘
```

---

## Package Structure

```
native_bridge/                           # Mono-repo
├── packages/
│   ├── native_bridge/                   # Runtime package (included in apps)
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── channel_manager.dart        # Manages method/event channels
│   │   │   │   ├── type_converter.dart         # Dart ↔ native type conversion
│   │   │   │   ├── error_handler.dart          # Native error → Dart exception mapping
│   │   │   │   ├── lifecycle.dart              # Init/dispose native resources
│   │   │   │   ├── async_bridge.dart           # Future/Stream wrappers
│   │   │   │   └── native_object.dart          # Opaque handle for native objects
│   │   │   └── native_bridge.dart              # Public API
│   │   └── pubspec.yaml
│   │
│   ├── native_bridge_generator/         # build_runner codegen (dev dependency)
│   │   ├── lib/
│   │   │   ├── src/
│   │   │   │   ├── config/
│   │   │   │   │   ├── config_parser.dart      # Parse native_bridge.yaml
│   │   │   │   │   └── package_spec.dart       # Package declaration model
│   │   │   │   ├── parsers/
│   │   │   │   │   ├── npm_parser.dart         # Parse TS/JS type definitions
│   │   │   │   │   ├── cocoapod_parser.dart    # Parse Swift/ObjC headers
│   │   │   │   │   ├── gradle_parser.dart      # Parse Kotlin/Java class files
│   │   │   │   │   ├── swift_pm_parser.dart    # Parse Swift Package Manager
│   │   │   │   │   └── parser_base.dart        # Common parsing interface
│   │   │   │   ├── schema/
│   │   │   │   │   ├── unified_type_schema.dart # Intermediate API representation
│   │   │   │   │   ├── uts_type.dart           # Type system (primitives, objects, enums, callbacks)
│   │   │   │   │   ├── uts_method.dart         # Method signatures
│   │   │   │   │   ├── uts_class.dart          # Class/interface definitions
│   │   │   │   │   └── uts_enum.dart           # Enum definitions
│   │   │   │   ├── generators/
│   │   │   │   │   ├── dart_generator.dart     # Generate Dart binding classes
│   │   │   │   │   ├── kotlin_glue_generator.dart  # Generate Kotlin platform channel handler
│   │   │   │   │   ├── swift_glue_generator.dart   # Generate Swift platform channel handler
│   │   │   │   │   ├── js_glue_generator.dart      # Generate JS interop for web
│   │   │   │   │   └── generator_base.dart
│   │   │   │   ├── installers/
│   │   │   │   │   ├── npm_installer.dart      # Add to package.json (for web)
│   │   │   │   │   ├── pod_installer.dart      # Add to Podfile
│   │   │   │   │   ├── gradle_installer.dart   # Add to build.gradle
│   │   │   │   │   └── spm_installer.dart      # Add to Package.swift
│   │   │   │   ├── type_mapping/
│   │   │   │   │   ├── type_mapper.dart        # Master type mapping registry
│   │   │   │   │   ├── js_to_dart.dart         # JS/TS types → Dart types
│   │   │   │   │   ├── swift_to_dart.dart      # Swift types → Dart types
│   │   │   │   │   ├── kotlin_to_dart.dart     # Kotlin types → Dart types
│   │   │   │   │   └── java_to_dart.dart       # Java types → Dart types
│   │   │   │   └── analyzer/
│   │   │   │       ├── api_surface_analyzer.dart # Detect public API surface
│   │   │   │       ├── dependency_resolver.dart  # Resolve transitive deps
│   │   │   │       └── compatibility_checker.dart # Check platform support
│   │   │   └── builder.dart                    # build_runner entry point
│   │   ├── bin/
│   │   │   └── generate.dart                   # CLI: flutter pub run native_bridge:generate
│   │   └── pubspec.yaml
│   │
│   └── native_bridge_cli/               # Optional CLI tool
│       ├── bin/
│       │   └── nb.dart                         # `nb add npm:date-fns`, `nb generate`
│       └── pubspec.yaml
│
├── type_definitions/                    # Pre-built type mappings for popular packages
│   ├── npm/
│   │   ├── date-fns.uts.json
│   │   ├── lodash.uts.json
│   │   └── uuid.uts.json
│   ├── cocoapods/
│   │   ├── Alamofire.uts.json
│   │   └── SDWebImage.uts.json
│   └── gradle/
│       ├── okhttp3.uts.json
│       └── gson.uts.json
│
├── example/
├── docs/
└── README.md
```

---

## Unified Type Schema (UTS)

The intermediate representation that all parsers output and all generators consume:

```json
{
  "package": "date-fns",
  "source": "npm",
  "version": "3.6.0",
  "classes": [],
  "functions": [
    {
      "name": "format",
      "isStatic": true,
      "parameters": [
        { "name": "date", "type": { "kind": "primitive", "name": "DateTime" } },
        { "name": "formatStr", "type": { "kind": "primitive", "name": "String" } },
        { "name": "options", "type": { "kind": "object", "nullable": true, "ref": "FormatOptions" } }
      ],
      "returnType": { "kind": "primitive", "name": "String" },
      "isAsync": false
    },
    {
      "name": "addDays",
      "isStatic": true,
      "parameters": [
        { "name": "date", "type": { "kind": "primitive", "name": "DateTime" } },
        { "name": "amount", "type": { "kind": "primitive", "name": "int" } }
      ],
      "returnType": { "kind": "primitive", "name": "DateTime" },
      "isAsync": false
    }
  ],
  "types": [
    {
      "name": "FormatOptions",
      "kind": "object",
      "fields": [
        { "name": "locale", "type": { "kind": "primitive", "name": "String" }, "nullable": true },
        { "name": "weekStartsOn", "type": { "kind": "primitive", "name": "int" }, "nullable": true }
      ]
    }
  ],
  "enums": []
}
```

### Type Mapping Table

| Source Type | Dart Type | Platform Channel Encoding |
|---|---|---|
| JS `number` / Kotlin `Int` / Swift `Int` | `int` | Standard |
| JS `number` (float) / Kotlin `Double` / Swift `Double` | `double` | Standard |
| JS `string` / Kotlin `String` / Swift `String` | `String` | Standard |
| JS `boolean` / Kotlin `Boolean` / Swift `Bool` | `bool` | Standard |
| JS `Date` / Kotlin `Date` / Swift `Date` | `DateTime` | ISO8601 String |
| JS `null` / Kotlin `null` / Swift `nil` | `null` | Null |
| JS `Array<T>` / Kotlin `List<T>` / Swift `[T]` | `List<T>` | List |
| JS `Map` / Kotlin `Map<K,V>` / Swift `[K:V]` | `Map<K,V>` | Map |
| JS `Promise<T>` / Kotlin `suspend` / Swift `async` | `Future<T>` | Async channel |
| JS `ReadableStream` / Kotlin `Flow` / Swift `AsyncSequence` | `Stream<T>` | Event channel |
| JS `Buffer` / Kotlin `ByteArray` / Swift `Data` | `Uint8List` | Byte array |
| JS callback / Kotlin lambda / Swift closure | `Function` | Callback channel |
| JS class instance / Kotlin object / Swift class | `NativeObject<T>` | Opaque handle (int64 ID) |
| Kotlin `sealed class` / Swift `enum` (associated) | Dart sealed class | Tagged union JSON |
| Kotlin `enum class` / Swift `enum` (simple) | Dart `enum` | String name |

---

## How Parsing Works per Source

### NPM Packages (JS/TS)
1. Download the package via `npm pack` (or read from node_modules)
2. Look for TypeScript declarations (`.d.ts` files) — these are the primary source
3. If no `.d.ts`, fall back to JSDoc parsing in `.js` files
4. Parse with a TS AST parser (use `ts_morph` or similar logic)
5. Extract: exported functions, classes, interfaces, types, enums
6. Map TS types → UTS types

### CocoaPods / Swift Package Manager
1. Download the podspec / SPM package
2. Look for Swift interface files (`.swiftinterface`) or header files (`.h` for ObjC)
3. Parse with a Swift AST parser (or use `sourcekitten` / `swift-syntax` output)
4. Extract: public classes, structs, protocols, functions, enums
5. Map Swift types → UTS types
6. Handle: optionals, generics, closures, async/await, Combine publishers

### Gradle / Maven (Kotlin/Java)
1. Download the AAR/JAR from Maven Central / Google Maven
2. For Kotlin: read `.kotlin_metadata` or decompile to Kotlin stubs
3. For Java: parse `.class` files or source JARs for public API
4. Extract: public classes, interfaces, methods, fields, enums
5. Map Kotlin/Java types → UTS types
6. Handle: suspend functions, Flow, coroutines, companion objects, sealed classes

---

## Generated Output per Platform

For a binding like `date-fns.format()`:

### 1. Dart Binding (what the developer uses)

```dart
// GENERATED — lib/generated/date_fns.dart
import 'package:native_bridge/native_bridge.dart';

class DateFns {
  static const _channel = NativeBridgeChannel('date_fns');
  
  /// Formats a date according to the given format string.
  static Future<String> format(
    DateTime date,
    String formatStr, {
    FormatOptions? options,
  }) async {
    return await _channel.invoke<String>('format', {
      'date': date.toIso8601String(),
      'formatStr': formatStr,
      if (options != null) 'options': options.toMap(),
    });
  }
  
  /// Adds the specified number of days to the given date.
  static Future<DateTime> addDays(DateTime date, int amount) async {
    final result = await _channel.invoke<String>('addDays', {
      'date': date.toIso8601String(),
      'amount': amount,
    });
    return DateTime.parse(result);
  }
}

class FormatOptions {
  final String? locale;
  final int? weekStartsOn;
  
  FormatOptions({this.locale, this.weekStartsOn});
  
  Map<String, dynamic> toMap() => {
    if (locale != null) 'locale': locale,
    if (weekStartsOn != null) 'weekStartsOn': weekStartsOn,
  };
}
```

### 2. Kotlin Glue (Android platform channel handler)

```kotlin
// GENERATED — android/src/main/.../DateFnsPlugin.kt
class DateFnsPlugin : MethodCallHandler {
    private val dateFns = DateFns()  // imported from npm via dukat or direct

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "format" -> {
                val date = parseIso8601(call.argument("date")!!)
                val formatStr = call.argument<String>("formatStr")!!
                val options = call.argument<Map<String, Any?>>("options")
                result.success(dateFns.format(date, formatStr, options))
            }
            "addDays" -> {
                val date = parseIso8601(call.argument("date")!!)
                val amount = call.argument<Int>("amount")!!
                result.success(dateFns.addDays(date, amount).toIso8601())
            }
            else -> result.notImplemented()
        }
    }
}
```

### 3. Swift Glue (iOS platform channel handler)

```swift
// GENERATED — ios/Classes/DateFnsPlugin.swift
class DateFnsPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "date_fns", binaryMessenger: registrar.messenger())
        let instance = DateFnsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "ARGS", message: "Invalid arguments", details: nil))
            return
        }
        
        switch call.method {
        case "format":
            let date = ISO8601DateFormatter().date(from: args["date"] as! String)!
            let formatStr = args["formatStr"] as! String
            result(DateFns.format(date, formatStr))
        case "addDays":
            let date = ISO8601DateFormatter().date(from: args["date"] as! String)!
            let amount = args["amount"] as! Int
            result(DateFns.addDays(date, amount).iso8601)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
```

---

## native_bridge Test Plan

```
test/
├── unit/
│   ├── config/
│   │   ├── config_parser_test.dart           # Parse native_bridge.yaml correctly
│   │   └── package_spec_test.dart            # Package spec validation
│   ├── parsers/
│   │   ├── npm_parser_test.dart              # Parse .d.ts files → UTS
│   │   ├── cocoapod_parser_test.dart         # Parse .swiftinterface → UTS
│   │   ├── gradle_parser_test.dart           # Parse Kotlin metadata → UTS
│   │   └── parser_edge_cases_test.dart       # Generics, optionals, callbacks, nested types
│   ├── schema/
│   │   ├── unified_type_schema_test.dart     # UTS creation and validation
│   │   └── type_compatibility_test.dart      # Cross-platform type compatibility
│   ├── type_mapping/
│   │   ├── js_to_dart_test.dart              # Every JS type → Dart mapping
│   │   ├── swift_to_dart_test.dart           # Every Swift type → Dart mapping
│   │   ├── kotlin_to_dart_test.dart          # Every Kotlin type → Dart mapping
│   │   └── edge_cases_test.dart             # Generics, wildcards, variance
│   ├── generators/
│   │   ├── dart_generator_test.dart          # Generated Dart code is valid
│   │   ├── kotlin_glue_generator_test.dart   # Generated Kotlin code compiles
│   │   ├── swift_glue_generator_test.dart    # Generated Swift code compiles
│   │   └── js_glue_generator_test.dart       # Generated JS code is valid
│   └── installers/
│       ├── pod_installer_test.dart           # Correctly modifies Podfile
│       ├── gradle_installer_test.dart        # Correctly modifies build.gradle
│       └── npm_installer_test.dart           # Correctly modifies package.json
│
├── integration/
│   ├── npm_roundtrip_test.dart               # npm package → parse → generate → invoke
│   ├── cocoapod_roundtrip_test.dart
│   ├── gradle_roundtrip_test.dart
│   ├── multi_package_test.dart               # Multiple packages in one project
│   └── incremental_rebuild_test.dart         # Only regenerate changed packages
│
├── golden/
│   ├── date_fns/                             # Expected outputs for date-fns
│   │   ├── date_fns.dart.golden
│   │   ├── DateFnsPlugin.kt.golden
│   │   └── DateFnsPlugin.swift.golden
│   └── alamofire/                            # Expected outputs for Alamofire
│       ├── alamofire.dart.golden
│       └── AlamofirePlugin.swift.golden
│
└── fixtures/
    ├── npm/                                  # Sample .d.ts files
    ├── swift/                                # Sample .swiftinterface files
    ├── kotlin/                               # Sample .kotlin_metadata files
    └── configs/                              # Sample native_bridge.yaml files
```

### Key Test Cases for native_bridge

```
group('Config Parsing'):
  ✓ parses valid native_bridge.yaml
  ✓ rejects missing source field
  ✓ rejects unsupported source type
  ✓ handles selective imports (only specific functions/classes)
  ✓ handles wildcard imports (entire package)
  ✓ supports version constraints

group('NPM Parser'):
  ✓ parses simple function declaration from .d.ts
  ✓ parses class with methods and properties
  ✓ parses interface and maps to Dart class
  ✓ parses generic types (Array<T>, Map<K,V>, Promise<T>)
  ✓ parses union types (string | number → dynamic with docs)
  ✓ parses optional parameters
  ✓ parses default exports
  ✓ parses named exports
  ✓ handles re-exports from other modules
  ✓ parses enum (string enum, numeric enum)
  ✓ parses callback/function types
  ✓ handles overloaded function signatures
  ✓ skips internal/private APIs (underscore prefix)

group('Swift Parser'):
  ✓ parses public class with methods
  ✓ parses struct
  ✓ parses protocol (→ Dart abstract class)
  ✓ parses Swift optionals (→ nullable Dart types)
  ✓ parses async/await methods (→ Future)
  ✓ parses Combine publishers (→ Stream)
  ✓ parses closures (→ Function types)
  ✓ parses generic constraints
  ✓ parses Swift enums with associated values (→ sealed class)
  ✓ parses extensions (folds into base class)
  ✓ handles @objc annotations
  ✓ handles availability annotations (@available)

group('Kotlin/Java Parser'):
  ✓ parses Kotlin data class (→ Dart class with copyWith)
  ✓ parses suspend function (→ Future)
  ✓ parses Kotlin Flow (→ Stream)
  ✓ parses sealed class (→ Dart sealed class)
  ✓ parses companion object methods (→ static methods)
  ✓ parses enum class
  ✓ parses Java interface (→ Dart abstract class)
  ✓ parses Java annotations (processes @Nullable, etc.)
  ✓ handles Kotlin null safety (? → nullable)
  ✓ handles Java Optional (→ nullable)
  ✓ handles Kotlin default parameters

group('Type Mapping Correctness'):
  ✓ all primitive types map correctly per table
  ✓ nullable types map to Dart nullable
  ✓ collections map recursively (List<List<String>>)
  ✓ maps/dictionaries map recursively
  ✓ callbacks map to Dart Function with correct signature
  ✓ async types map to Future/Stream
  ✓ native objects get opaque handles
  ✓ enums map to Dart enums
  ✓ complex objects map to Dart classes with serialization

group('Dart Code Generation'):
  ✓ generated code is valid Dart (passes analyzer)
  ✓ generated code has dartdoc comments from source docs
  ✓ generated methods use correct channel invocation
  ✓ generated classes have proper toMap/fromMap
  ✓ generated enums have proper serialization
  ✓ generated code handles errors with typed exceptions
  ✓ generated code is deterministic (same input → same output)

group('Platform Glue Generation'):
  ✓ Kotlin glue compiles successfully
  ✓ Swift glue compiles successfully
  ✓ glue correctly dispatches method calls
  ✓ glue correctly serializes/deserializes types
  ✓ glue handles errors and returns FlutterError

group('Installers'):
  ✓ adds pod to Podfile without duplicates
  ✓ adds dependency to build.gradle without duplicates
  ✓ adds package to package.json without duplicates
  ✓ respects version constraints
  ✓ handles existing dependencies (version upgrade)
  ✓ does not corrupt existing file content
```

---

## native_bridge Implementation Phases

### Phase 1: Core Framework (Weeks 1-3)
- [ ] Config parser (native_bridge.yaml)
- [ ] Unified Type Schema (UTS) data model
- [ ] Type mapping registry (all primitives)
- [ ] Dart binding generator (methods, classes)
- [ ] Platform channel manager (runtime)
- **Tests first**

### Phase 2: NPM Parser (Weeks 4-6)
- [ ] TypeScript .d.ts parser
- [ ] Handle all TS types → UTS
- [ ] JS glue generator (web platform)
- [ ] npm installer (package.json)
- [ ] Golden tests for popular packages (date-fns, lodash, uuid)
- **Tests first**

### Phase 3: Kotlin/Gradle Parser (Weeks 7-9)
- [ ] Kotlin metadata parser
- [ ] Java class file parser
- [ ] Handle suspend, Flow, sealed classes
- [ ] Kotlin glue generator
- [ ] Gradle installer
- [ ] Golden tests (OkHttp, Gson)
- **Tests first**

### Phase 4: Swift Parser (Weeks 10-12)
- [ ] Swift interface parser
- [ ] Handle async/await, Combine, closures
- [ ] Swift glue generator
- [ ] CocoaPods + SPM installer
- [ ] Golden tests (Alamofire, SDWebImage)
- **Tests first**

### Phase 5: Advanced Features (Weeks 13-15)
- [ ] Callback support (Dart → native callbacks)
- [ ] Stream/event channel support
- [ ] Native object lifecycle management (opaque handles)
- [ ] Incremental rebuild (only regen changed packages)
- [ ] Pre-built type definitions for popular packages
- [ ] CLI tool (`nb add`, `nb generate`, `nb list`)

### Phase 6: Polish & Launch (Weeks 16-18)
- [ ] Integration tests (end-to-end roundtrip)
- [ ] Documentation site
- [ ] Example project (3 native packages, all platforms)
- [ ] pub.dev publish

---

## Open Questions & Risks

### flutter_data
1. **Drift dependency**: Tightly coupling to Drift is powerful but limiting. Should we abstract storage?
   - *Recommendation*: Drift as default, abstract interface for alternatives.
2. **Code generation overhead**: Adding another codegen step to projects. Can we use macros when they stabilize?
   - *Recommendation*: Start with build_runner, migrate to macros when available.
3. **Backend adapter testing**: Each backend adapter needs a real backend for integration tests.
   - *Recommendation*: Mock adapters for unit tests, Docker-based backends for CI.

### native_bridge
1. **Parsing reliability**: Native package APIs are complex. Parsers will have gaps.
   - *Recommendation*: Support manual UTS overrides for when parsing fails.
2. **Runtime performance**: Platform channels add overhead per call.
   - *Recommendation*: Batch calls, cache results, use FFI for hot paths.
3. **Web support**: npm packages on web don't need platform channels — they need JS interop.
   - *Recommendation*: Generate `dart:js_interop` bindings for web, platform channels for mobile.
4. **Maintenance burden**: Native packages update → bindings need regeneration.
   - *Recommendation*: Version-lock bindings, CI check for updates.
