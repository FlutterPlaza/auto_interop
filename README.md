# auto_interop

[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

A `build_runner`-based tool that lets Flutter developers consume **any** native package (npm, CocoaPods/SPM, Gradle) by auto-generating type-safe Dart bindings.

## How It Works

```
auto_interop.yaml     Parsers (TS/Swift/Kotlin)     Unified Type Schema
   (config)        -->      (parse APIs)          -->     (intermediate)
                                                              |
                           Dart Bindings  <--  Code Generators (Dart/Kotlin/Swift/JS)
                         (what you use)
```

1. **Declare** which native packages you need in `auto_interop.yaml`
2. **Run** `dart run build_runner build` (or the CLI)
3. **Use** the generated type-safe Dart bindings

## Quick Start

### 1. Add dependencies

```yaml
# pubspec.yaml
dependencies:
  auto_interop: ^0.1.0

dev_dependencies:
  auto_interop_generator: ^0.1.0
  build_runner: ^2.4.0
```

### 2. Configure native packages

```yaml
# auto_interop.yaml
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

### 3. Generate bindings

```bash
dart run build_runner build
# or
dart run auto_interop_generator:generate
```

### 4. Use the bindings

```dart
import 'package:auto_interop/auto_interop.dart';
import 'generated/date_fns.dart';

void main() async {
  await AutoInteropLifecycle.instance.initialize();

  final formatted = await DateFns.format(DateTime.now(), 'yyyy-MM-dd');
  print(formatted); // 2024-01-15
}
```

## Supported Platforms

| Source | Language | Platform | Installer |
|--------|----------|----------|-----------|
| npm | TypeScript/JS | Web | `npm install` |
| CocoaPods | Swift | iOS | Podfile |
| SPM | Swift | iOS | Package.swift |
| Gradle | Kotlin | Android | build.gradle |

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      auto_interop.yaml                       │
│            (declares which native packages to bind)            │
└─────────────────────────┬────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
   │  NPM Parser  │ │  Pod Parser  │ │ Gradle Parser│
   │  (TS .d.ts)  │ │  (Swift)     │ │ (Kotlin)     │
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
   │ Dart Binding │ │ Kotlin/Swift│ │ JS Interop  │
   │ Generator    │ │ Glue Gen    │ │ Generator   │
   └─────────────┘ └─────────────┘ └─────────────┘
```

## CLI Commands

```bash
# Generate bindings from auto_interop.yaml
dart run auto_interop_generator:generate

# List available pre-built type definitions
dart run auto_interop_generator:generate list

# Add a package to auto_interop.yaml
dart run auto_interop_generator:generate add npm date-fns ^3.0.0
```

## Packages

| Package | Description |
|---------|-------------|
| [auto_interop](packages/auto_interop/) | Runtime library (platform channels, type conversion, error handling) |
| [auto_interop_generator](packages/auto_interop_generator/) | Code generator (parsers, generators, CLI, build_runner integration) |

## Pre-built Type Definitions

The generator ships with pre-built type definitions for popular packages, enabling instant code generation without parsing:

- **npm**: date-fns, lodash, uuid
- **CocoaPods**: Alamofire, SDWebImage
- **Gradle**: OkHttp

## License

BSD 3-Clause License. See [LICENSE](LICENSE) for details.
