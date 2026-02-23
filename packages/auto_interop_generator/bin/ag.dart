#!/usr/bin/env dart
// Short alias for `dart run auto_interop_generator:generate`.
//
// Usage:
//   dart run ag [command] [options]
//
// Commands:
//   generate   Generate Dart bindings from auto_interop.yaml (default)
//   list       List available pre-built type definitions
//   add        Add a native package to auto_interop.yaml
import 'dart:io';

import 'package:auto_interop_generator/src/cli/cli_runner.dart';

Future<void> main(List<String> args) async {
  final runner = CliRunner();
  final exitCode = await runner.run(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
