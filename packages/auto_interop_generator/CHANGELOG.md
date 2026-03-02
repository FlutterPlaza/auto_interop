## 0.2.1

- Version bump to accompany `auto_interop` 0.2.1 (no generator changes).

## 0.2.0

### AST-Based Parsing (Near-100% Reliability)

- **AST parsers as default** — All three parsers now use real compiler APIs for accurate parsing, with automatic regex fallback on failure:
  - **Swift**: SwiftSyntax via compiled helper binary
  - **Kotlin**: Kotlin PSI via `kotlinc -script` with compiler-embeddable
  - **TypeScript**: TypeScript Compiler API via Node.js
- **Backward-compatible SwiftSyntax** — Conditional compilation (`#if compiler(>=6.0)`) selects SwiftSyntax 600+ on Swift 6.x, 510 on Swift 5.x. Supports SwiftSyntax 602 API changes via `#if compiler(>=6.2)`.
- **Kotlin extension function folding** — Extension functions (`fun String.isValidEmail()`) are folded into matching classes or emitted as top-level functions with the receiver as the first parameter.
- **Kotlin overload deduplication** — When multiple overloads exist for the same function name, only the first is kept (Dart doesn't support overloading).
- **Swift `throws` propagation** — Throwing functions are marked `isAsync: true` in the schema so Dart generators wrap them in `Future` with error handling. Supports typed throws (`throws(NetworkError)`).
- **Mixed Kotlin/Java handling** — Packages with both `.kt` and `.java` files are parsed in parallel: Kotlin via AST, Java via regex. Results are merged into a single schema.
- **TypeScript default export handling** — `export default class/interface/type/enum` declarations are now correctly parsed.

### Cache & Toolchain Improvements

- **Mtime-based Swift cache invalidation** — The compiled Swift helper binary is automatically recompiled when `Package.swift` or `Sources/main.swift` change (similar to `make`).
- **Content-comparison Kotlin cache invalidation** — The version-matched Kotlin script is rewritten only when its patched content differs from the cached version.
- **Warm stamp auto-write** — The "first use" Maven dependency warning now writes a warm stamp immediately, preventing repeated warnings across invocations.
- **`setup` command** — `dart run auto_interop_generator:generate setup` pre-warms all AST helper caches (downloads Maven deps, compiles Swift binary).

### Bug Fixes

- Removed unused `dart:async` imports from AST parser files.
- Fixed Kotlin warm stamp being overly aggressive (no longer deleted on script logic changes, only on kotlinc version changes).

## 0.1.0

- Initial release.
- Parsers for npm (TypeScript `.d.ts`), CocoaPods/SPM (Swift), and Gradle (Kotlin).
- Unified Type Schema (UTS) intermediate representation.
- Dart binding generator with full type mapping.
- Kotlin glue generator (Android FlutterPlugin).
- Swift glue generator (iOS FlutterPlugin).
- JS interop generator (web `dart:js_interop`).
- Platform installers: npm, CocoaPods (Podfile), SPM (Package.swift), Gradle.
- Pre-built type definitions for date-fns, lodash, uuid, OkHttp, Alamofire, SDWebImage.
- `TypeDefinitionLoader` for loading/saving UTS JSON definitions.
- CLI tool with `generate`, `list`, and `add` commands.
- `build_runner` integration via `AutoInteropBuilder`.
- Callback, stream, and native object lifecycle support in all generators.
