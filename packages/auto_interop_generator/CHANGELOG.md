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
