# auto_interop Example

This example demonstrates using `auto_interop` to generate type-safe Dart bindings for three native packages across all platforms:

| Package | Source | Platform |
|---------|--------|----------|
| [date-fns](https://date-fns.org/) | npm | Web |
| [Alamofire](https://github.com/Alamofire/Alamofire) | CocoaPods | iOS |
| [OkHttp](https://square.github.io/okhttp/) | Gradle | Android |

## Setup

1. Define your native packages in `auto_interop.yaml`:

```yaml
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.6.0"
    imports:
      - "format"
      - "addDays"
      - "differenceInDays"

  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"

  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
```

2. Generate bindings:

```bash
dart run auto_interop_generator:generate
```

3. Use the generated bindings in your Dart code:

```dart
import 'package:auto_interop/auto_interop.dart';
import 'generated/date_fns.dart';

void main() async {
  await AutoInteropLifecycle.instance.initialize();

  // Use the singleton instance
  final formatted = await DateFns.instance.format(
    DateTime.now(),
    'yyyy-MM-dd',
  );
  print('Today: $formatted');

  // Or use interfaces for dependency injection
  final DateFnsInterface dateFns = DateFns.instance;
  final tomorrow = await dateFns.addDays(DateTime.now(), 1);
  print('Tomorrow: $tomorrow');
}
```

## Project Structure

```
example/
  lib/
    main.dart                                # Example Flutter app
    generated/
      date_fns.dart                          # Generated: date-fns bindings
      alamofire.dart                         # Generated: Alamofire bindings
      com_squareup_okhttp3_okhttp.dart       # Generated: OkHttp bindings
  auto_interop.yaml                         # Package configuration
  pubspec.yaml                               # Flutter project config
```
