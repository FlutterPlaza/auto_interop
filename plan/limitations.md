# auto_interop — Known Limitations

## Fundamental Limits (Can Never Be Solved)

These are baked into Flutter's platform channel architecture itself.

### 1. Platform channels are async-only, string-dispatched RPC
Every native call is a `Future` — there is no way to make a synchronous call from Dart to native. This means real-time, tight-loop APIs (game engines, audio DSP, GPU compute) will always have unacceptable latency. Platform channels serialize everything through Flutter's `StandardMessageCodec`, which supports only: `null`, `bool`, `int`, `double`, `String`, `Uint8List`, `Int32List`, `Int64List`, `Float32List`, `Float64List`, `List`, `Map`. Any richer type must be manually serialized/deserialized.

### 2. No direct memory sharing
Native objects live in native memory; Dart holds only an opaque `String` handle. You cannot pass a pointer, share a buffer, or do zero-copy data transfer. A 10MB image from SDWebImage must be fully copied through the platform channel codec. FFI (`dart:ffi`) solves this, but auto_interop is built entirely on platform channels, not FFI.

### 3. No bidirectional object graph
Dart can call native and native can invoke Dart callbacks, but you can't pass a Dart object *into* native as a first-class native object. The bridge is always: Dart → (serialize) → native → (serialize) → Dart. Complex object graphs with circular references, inheritance hierarchies, or shared mutable state cannot be represented.

### 4. Hot restart invalidates all native handles
When Flutter hot-restarts, the Dart VM resets but native state persists (or vice versa). Any `NativeObject` handles from before the restart become stale. There is no protocol to re-synchronize.

### 5. One-shot method calls, no persistent connections
Each `invoke()` is independent — there's no connection state, session affinity, or request pipelining. Protocols that require stateful request/response sequences (WebSocket-like, transaction boundaries) must be entirely managed on the native side with the Dart side issuing individual RPCs.

---

## Very Hard to Solve (Major engineering effort)

These are architecturally possible but require significant redesign.

### 6. No generics on generated classes
The schema (`UtsClass`, `UtsMethod`) has no type parameter concept. `Gson.fromJson<T>(json)` becomes `fromJson(json) → dynamic`. Supporting generics would require: schema changes, all 4 generators updated, runtime type reification across the channel, and native-side reflection. *Effort: months of work across every layer.*

### 7. No inheritance / protocol conformance
Generated classes are flat — no `extends`, no `implements NativeProtocol`. A Swift library returning `URLSessionTask` (with subclasses `URLSessionDataTask`, `URLSessionDownloadTask`) collapses to a single handle type. Supporting polymorphism requires: discriminated handle types, native-side type introspection, schema inheritance modeling. *Effort: significant schema + all generators.*

### 8. Single EventChannel per package
Each generated native plugin has exactly one `eventSink`. If a library exposes multiple independent streams (e.g., accelerometer + gyroscope + magnetometer), they cannot run simultaneously. Fixing this requires per-method event channels with multiplexed dispatch. *Effort: all 3 native generators + runtime changes.*

### 9. No constructor overloads
Each class gets exactly one `_create` method. Libraries with multiple constructors (e.g., `OkHttpClient()` vs `OkHttpClient(connectionPool, dispatcher)`) can only expose one. Fixing requires: schema support for multiple named constructors, dispatch logic in all generators. *Effort: schema + 4 generators.*

### 10. Kotlin Builder pattern assumption
The Kotlin generator assumes parameterized construction uses the Java Builder pattern (`ClassName.Builder().setX(x).build()`). Modern Kotlin libraries use primary constructors or DSL builders, which produce broken generated code. *Effort: Kotlin generator rewrite for construction strategies.*

### 11. JS generator has no escape hatch
Unlike Swift/Kotlin generators which support `nativeBody` verbatim overrides, the JS generator ignores `nativeBody['js']` entirely. Complex JS patterns (prototype chains, `this`-bound callbacks, dynamic property access) have no workaround. *Effort: JS generator needs nativeBody support + callback/stream support.*

### 12. No cross-platform type unification
If Alamofire (iOS) and OkHttp (Android) both have an HTTP response type, they generate completely separate Dart classes. There's no mechanism to define a shared Dart interface that both platform-specific implementations fulfill. *Effort: new abstraction layer in schema + code generation.*

---

## Hard but Solvable (Weeks of effort)

### 13. Parsers are fragile line-by-line regex
- Swift parser: multi-line method signatures silently corrupt the parse. `init` methods are skipped. `internal` access modifier is not filtered.
- Gradle parser: `[^)]*` regex breaks on nested generics in parameter types. Method overloads produce duplicate Dart methods.
- npm parser: rest params (`...args`) silently dropped. `export default` ignored. Union types beyond `T | null` not handled.

*Fix: proper AST-based parsing (e.g., use `swift-syntax` output, Kotlin compiler plugin, TypeScript compiler API). Significant but well-understood work.*

### 14. Shallow container serialization
`TypeConverter` and `DartGenerator` only serialize/deserialize the outermost container level. `List<Request>` works, but `List<List<Request>>` or `Map<String, List<Request>>` silently passes through raw maps without reconstruction. *Fix: recursive codegen-aware serialization in dart_generator.*

### 15. No per-call timeout or cancellation
`AutoInteropChannel.invoke()` hangs forever if native doesn't respond. No timeout, no cancellation token. *Fix: add `timeout` parameter, use `Future.timeout()` wrapper, add cancellation token protocol.*

### 16. Callbacks with non-void return are silently ignored
The `CallbackManager` only supports fire-and-forget callbacks. A native API expecting a return value from a Dart callback (e.g., `shouldContinue() → Bool`) will get `nil`. *Fix: two-way callback channel protocol.*

### 17. No `Map` with non-String keys
`TypeConverter.fromPlatform()` always converts map keys to `String` via `.toString()`. `Map<int, String>` silently becomes `Map<String, String>`. *Fix: key-type-aware conversion in TypeConverter + generators.*

### 18. `Duration` and `Uri` not handled in containers
Top-level `Duration` and `Uri` are mapped to primitives, but inside a `List<Duration>` or as a field type, there's no serialization logic. *Fix: extend TypeConverter + generator serialization for these types.*

### 19. Gradle source download is Maven Central only
Hardcoded to `repo1.maven.org`. Libraries on Google Maven, JitPack, or private registries fail silently. *Fix: configurable repository URLs in `auto_interop.yaml`.*

### 20. No macOS platform in compatibility checker
CocoaPods maps to `{ios}` only, despite the Swift generator emitting `#if os(macOS)` code. macOS support exists in the generated code but isn't tracked. *Fix: add macOS to the platform enum and compatibility mapping.*

---

## Moderate Effort (Days of work) — ALL FIXED

### 21. ~~`UtsType` equality doesn't compare type arguments~~ FIXED
`UtsType` equality now compares `typeArguments`, `parameterTypes`, and `returnType`. `List<String> != List<int>`.

### 22. ~~No `--dry-run` or `--verbose` CLI flags~~ FIXED
Added `--dry-run` (previews what would be generated without writing files) and `--verbose` (shows checksums, cache state, file lists).

### 23. ~~Cache doesn't invalidate on config/nativeBody changes~~ FIXED
Per-package input checksum now includes `customTypes` and `imports` from PackageSpec, not just the schema JSON.

### 24. ~~No object equality across handles~~ FIXED
`NativeObject` now overrides `==` and `hashCode` using `handle` and `channelName`.

### 25. ~~Error codes are unstable native class names~~ FIXED
Both Kotlin and Swift glue generators now emit `normalizeErrorCode()` helper that maps common exceptions to stable codes (`IO_ERROR`, `NETWORK_ERROR`, `TIMEOUT`, `PERMISSION_DENIED`, `CANCELLED`, `INVALID_ARGUMENT`, `NOT_FOUND`, etc.). `AutoInteropException` has convenience getters (`isTimeout`, `isNetworkError`, etc.).

### 26. ~~No batching / request pipelining~~ FIXED
Added `batchInvoke(List<BatchCall>)` to `AutoInteropChannel`. Sends N calls in 1 round-trip via `_batch` method. Returns `List<BatchResult>` with per-call success/error.

---

## Summary

| Category | Count | Status |
|----------|-------|--------|
| **Never solvable** (Flutter arch) | 5 | Inherent to platform channels |
| **Very hard** (months) | 7 | Future work |
| **Hard** (weeks) | 8 | ALL FIXED (L13-L20) |
| **Moderate** (days) | 6 | ALL FIXED (L21-L26) |

The "never solvable" items are inherent to Flutter platform channels. The only way around them is to use `dart:ffi` (C interop) or Dart's `NativePort` — which would be a fundamentally different package.
