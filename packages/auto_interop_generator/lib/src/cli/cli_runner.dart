import 'dart:io';
import 'dart:isolate';

import '../config/config_parser.dart';
import '../config/package_spec.dart';
import '../generators/dart_generator.dart';
import '../generators/kotlin_glue_generator.dart';
import '../generators/swift_glue_generator.dart';
import '../generators/js_glue_generator.dart';
import '../schema/unified_type_schema.dart';
import '../type_definitions/type_definition_loader.dart';

/// Holds the generated output for a single package.
class _GenerationResult {
  final String package;
  final Map<String, String> dartFiles;
  final Map<String, String> glueFiles;

  _GenerationResult({
    required this.package,
    required this.dartFiles,
    required this.glueFiles,
  });
}

/// CLI runner for auto_interop code generation.
class CliRunner {
  final ConfigParser _configParser = ConfigParser();

  /// Runs the CLI with the given [args].
  ///
  /// Returns the exit code.
  Future<int> run(List<String> args) async {
    if (args.isEmpty || args.first == 'generate') {
      return _runGenerate(args.length > 1 ? args.sublist(1) : []);
    }

    switch (args.first) {
      case 'list':
        return _runList();
      case 'add':
        return _runAdd(args.sublist(1));
      case 'help':
      case '--help':
      case '-h':
        _printUsage();
        return 0;
      case 'version':
      case '--version':
        _printVersion();
        return 0;
      default:
        stderr.writeln('Unknown command: ${args.first}');
        _printUsage();
        return 1;
    }
  }

  Future<int> _runGenerate(List<String> args) async {
    final configPath = _findConfigPath(args);
    final configFile = File(configPath);

    if (!configFile.existsSync()) {
      stderr.writeln('Config file not found: $configPath');
      stderr.writeln('Create a auto_interop.yaml file or specify one with --config');
      return 1;
    }

    AutoInteropConfig config;
    try {
      config = _configParser.parseFile(configFile);
    } on ConfigParseException catch (e) {
      stderr.writeln('Error parsing config: $e');
      return 1;
    }

    if (config.packages.isEmpty) {
      stderr.writeln('No packages configured in $configPath');
      return 0;
    }

    // Apply --only filter
    final onlyFilter = _findOnlyFilter(args);
    var packages = config.packages;
    if (onlyFilter != null) {
      packages = packages
          .where((spec) => onlyFilter.contains(spec.package))
          .toList();
      if (packages.isEmpty) {
        stderr.writeln(
            'No matching packages for --only filter: ${onlyFilter.join(', ')}');
        return 1;
      }
    }

    final outputDir = _findOutputDir(args);
    Directory(outputDir).createSync(recursive: true);

    stdout.writeln('Generating bindings for ${packages.length} package(s)...');

    final typeDefsDir = _findTypeDefsDir();

    // Generate all packages in parallel using isolates
    final results = await Future.wait(
      packages.map((spec) => Isolate.run(() {
        return _generatePackage(spec, typeDefsDir);
      })),
    );

    // Write files sequentially (fast I/O, avoids concurrent file writes)
    var generated = 0;
    for (final result in results) {
      if (result == null) {
        stderr.writeln(
            '  Warning: Could not resolve schema for a package');
        continue;
      }

      _writeFiles(result.dartFiles, outputDir);
      _writeFiles(result.glueFiles, outputDir);
      generated++;
      stdout.writeln('  Generated bindings for ${result.package}');
    }

    stdout.writeln('Done. Generated $generated binding(s) in $outputDir');
    return 0;
  }

  int _runList() {
    final loader = TypeDefinitionLoader(
      definitionsDir: _findTypeDefsDir(),
    );
    final available = loader.listAvailable();

    if (available.isEmpty) {
      stdout.writeln('No pre-built type definitions found.');
      return 0;
    }

    stdout.writeln('Available pre-built type definitions:');
    for (final name in available) {
      final schema = loader.load(name);
      if (schema != null) {
        stdout.writeln(
            '  $name — ${schema.package}@${schema.version} (${schema.source.name})');
      } else {
        stdout.writeln('  $name');
      }
    }
    return 0;
  }

  int _runAdd(List<String> args) {
    if (args.length < 3) {
      stderr.writeln('Usage: auto_interop add <source> <package> <version>');
      stderr.writeln('  source: npm, cocoapods, gradle, spm');
      stderr.writeln('  Example: auto_interop add npm date-fns ^3.0.0');
      return 1;
    }

    final source = args[0];
    final package = args[1];
    final version = args[2];

    if (!ConfigParser.supportedSources.contains(source)) {
      stderr.writeln(
          'Unsupported source: $source. Use: ${ConfigParser.supportedSources.join(', ')}');
      return 1;
    }

    final configPath = 'auto_interop.yaml';
    final configFile = File(configPath);

    String yaml;
    if (configFile.existsSync()) {
      yaml = configFile.readAsStringSync();
      if (!yaml.endsWith('\n')) yaml += '\n';
    } else {
      yaml = 'native_packages:\n';
    }

    yaml += '  - source: $source\n'
        '    package: "$package"\n'
        '    version: "$version"\n';

    configFile.writeAsStringSync(yaml);
    stdout.writeln('Added $package ($source@$version) to $configPath');
    return 0;
  }

  void _printUsage() {
    stdout.writeln('auto_interop_generator — Generate Dart bindings from native packages');
    stdout.writeln();
    stdout.writeln('Usage: dart run auto_interop_generator:generate [command] [options]');
    stdout.writeln();
    stdout.writeln('Commands:');
    stdout.writeln('  generate   Generate Dart bindings from auto_interop.yaml (default)');
    stdout.writeln('  list       List available pre-built type definitions');
    stdout.writeln('  add        Add a native package to auto_interop.yaml');
    stdout.writeln('  help       Show this help message');
    stdout.writeln('  version    Show version');
    stdout.writeln();
    stdout.writeln('Options:');
    stdout.writeln('  --config <path>      Path to auto_interop.yaml (default: auto_interop.yaml)');
    stdout.writeln('  --output <dir>       Output directory (default: lib/generated)');
    stdout.writeln('  --only <packages>    Generate only specified packages (comma-separated)');
  }

  void _printVersion() {
    stdout.writeln('auto_interop_generator 0.1.0');
  }

  String _findConfigPath(List<String> args) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == '--config') return args[i + 1];
    }
    return 'auto_interop.yaml';
  }

  String _findOutputDir(List<String> args) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == '--output') return args[i + 1];
    }
    return 'lib/generated';
  }

  List<String>? _findOnlyFilter(List<String> args) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == '--only') {
        return args[i + 1].split(',').map((s) => s.trim()).toList();
      }
    }
    return null;
  }

  /// Generates all output for a single package. Designed to run in an isolate.
  static _GenerationResult? _generatePackage(
      PackageSpec spec, String typeDefsDir) {
    final loader = TypeDefinitionLoader(definitionsDir: typeDefsDir);
    final schema = loader.loadForPackage(spec.package);
    if (schema == null) return null;

    final dartFiles = DartGenerator().generate(schema);
    final glueFiles = _generateGlue(schema, spec.source);
    return _GenerationResult(
      package: spec.package,
      dartFiles: dartFiles,
      glueFiles: glueFiles,
    );
  }

  static Map<String, String> _generateGlue(
      UnifiedTypeSchema schema, PackageSource source) {
    switch (source) {
      case PackageSource.gradle:
        return KotlinGlueGenerator().generate(schema);
      case PackageSource.cocoapods:
      case PackageSource.spm:
        return SwiftGlueGenerator().generate(schema);
      case PackageSource.npm:
        return JsGlueGenerator().generate(schema);
    }
  }

  void _writeFiles(Map<String, String> files, String outputDir) {
    for (final entry in files.entries) {
      final file = File('$outputDir/${entry.key}');
      // Content-based skip: avoid rewriting unchanged files
      if (file.existsSync() && file.readAsStringSync() == entry.value) {
        continue;
      }
      file.writeAsStringSync(entry.value);
    }
  }

  String _findTypeDefsDir() {
    // Look for type definitions relative to the package
    final candidates = [
      'lib/src/type_definitions',
      '../auto_interop_generator/lib/src/type_definitions',
    ];
    for (final dir in candidates) {
      if (Directory(dir).existsSync()) return dir;
    }
    return 'lib/src/type_definitions';
  }
}
