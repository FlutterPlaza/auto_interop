import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../analyzer/api_surface_analyzer.dart';
import '../analyzer/dependency_resolver.dart';
import '../cache/build_cache.dart';
import '../cache/checksum.dart';
import '../cache/dependency_graph.dart';
import '../cache/parse_cache.dart';
import '../config/config_parser.dart';
import '../config/package_spec.dart';
import '../generators/dart_generator.dart';
import '../generators/kotlin_glue_generator.dart';
import '../generators/swift_glue_generator.dart';
import '../generators/js_glue_generator.dart';
import '../schema/unified_type_schema.dart';
import '../parsers/ast/ast_gradle_parser.dart';
import '../parsers/ast/ast_npm_parser.dart';
import '../parsers/ast/ast_parser_base.dart';
import '../parsers/ast/ast_swift_parser.dart';
import '../parsers/ast/toolchain_detector.dart';
import '../parsers/swift_parser.dart';
import '../parsers/gradle_parser.dart';
import '../parsers/npm_parser.dart';
import '../parsers/parser_base.dart';
import '../resolver/build_manifest.dart';
import '../resolver/override_loader.dart';
import '../resolver/package_downloader.dart';
import '../resolver/registry_client.dart';
import '../resolver/schema_resolver.dart';
import 'pbxproj_patcher.dart';

/// Holds the generated output for a single package.
class _GenerationResult {
  final String package;
  final Map<String, String> dartFiles;
  final Map<String, String> glueFiles;
  final String inputChecksum;
  final Set<String> unresolvedTypes;

  _GenerationResult({
    required this.package,
    required this.dartFiles,
    required this.glueFiles,
    required this.inputChecksum,
    this.unresolvedTypes = const {},
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
      case 'parse':
        return _runParse(args.sublist(1));
      case 'list':
        return _runList();
      case 'add':
        return _runAdd(args.sublist(1));
      case 'registry':
        return _runRegistry(args.sublist(1));
      case 'setup':
        return _runSetup();
      case 'clean':
        return _runCleanup('clean', args.sublist(1));
      case 'delete':
        return _runCleanup('delete', args.sublist(1));
      case 'purge':
        return _runCleanup('purge', args.sublist(1));
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
    final force = args.contains('--force');
    final noAnalyze = args.contains('--no-analyze');
    final noDownload = args.contains('--no-download');
    final noRegistry = args.contains('--no-registry');
    final noAst = args.contains('--no-ast');
    final dryRun = args.contains('--dry-run');
    final verbose = args.contains('--verbose');
    final configPath = _findConfigPath(args);
    final overridePaths = _findOverrides(args);
    final configFile = File(configPath);

    if (!configFile.existsSync()) {
      stderr.writeln('Config file not found: $configPath');
      stderr.writeln(
          'Create a auto_interop.yaml file or specify one with --config');
      return 1;
    }

    final configContent = configFile.readAsStringSync();

    AutoInteropConfig config;
    try {
      config = _configParser.parseYaml(configContent);
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
      packages =
          packages.where((spec) => onlyFilter.contains(spec.package)).toList();
      if (packages.isEmpty) {
        stderr.writeln(
            'No matching packages for --only filter: ${onlyFilter.join(', ')}');
        return 1;
      }
    }

    // Auto-download packages that don't have sourcePath set
    if (!noDownload) {
      const buildDir = 'build/auto_interop';
      final manifest = BuildManifest.load(buildDir);
      final downloader = PackageDownloader(buildDir: buildDir);
      final updatedPackages = <PackageSpec>[];

      for (final spec in packages) {
        if (spec.sourcePath != null) {
          updatedPackages.add(spec);
          continue;
        }
        if (manifest.isUpToDate(spec.package, spec.version)) {
          final entry = manifest.entries[spec.package]!;
          updatedPackages.add(spec.copyWith(sourcePath: entry.path));
          continue;
        }

        stdout.writeln('  Downloading ${spec.package}@${spec.version}...');
        final result = await downloader.download(spec);
        if (result.success) {
          manifest.record(
              spec.package, spec.version, spec.source.name, result.path!);
          updatedPackages.add(spec.copyWith(sourcePath: result.path));
          stdout.writeln('  Downloaded ${spec.package} → ${result.path}');
        } else {
          stderr.writeln('  Warning: ${result.error}');
          updatedPackages.add(spec);
        }
      }

      manifest.save(buildDir);
      packages = updatedPackages;
    }

    final outputDir = _findOutputDir(args);
    if (!dryRun) {
      Directory(outputDir).createSync(recursive: true);
    }

    if (dryRun) {
      stdout.writeln('[dry-run] No files will be written.');
    }

    // Load build cache
    final cacheFile = File('.auto_interop_cache.json');
    final cache = BuildCache.load(cacheFile);
    final configChecksum = Checksum.of(configContent);
    final configChanged = cache.configChecksum != configChecksum;

    if (configChanged && !force) {
      stdout.writeln('Config changed, rebuilding all packages...');
    }
    if (verbose) {
      stdout.writeln('  Config checksum: $configChecksum');
      stdout.writeln('  Cached checksum: ${cache.configChecksum}');
      stdout.writeln('  Config changed: $configChanged');
    }

    // Build dependency graph from schemas
    final depGraph = DependencyGraph();
    final schemaMap = <String, UnifiedTypeSchema>{};

    // Set up override loader and registry client
    final overridesDir = config.overridesDir;
    final overrideLoader = OverrideLoader(
      projectDir: overridesDir ?? 'auto_interop_overrides',
    );
    final registryClient = noRegistry ? null : RegistryClient();
    final resolver = SchemaResolver(
      overrideLoader: overrideLoader,
      registryClient: registryClient,
      useRegistry: !noRegistry,
      useAst: !noAst,
    );

    for (final spec in packages) {
      // Find matching override file if provided via CLI --override
      final overrideFile = overridePaths
          .where((p) =>
              p.contains(spec.package) ||
              p.contains(_toSnakeCase(spec.package)))
          .firstOrNull;
      String? overrideContent;
      if (overrideFile != null) {
        try {
          overrideContent = File(overrideFile).readAsStringSync();
        } catch (e) {
          stderr
              .writeln('  Warning: Failed to read override $overrideFile: $e');
        }
      }

      final resolution =
          await resolver.resolve(spec, overrideSchema: overrideContent);
      if (resolution.schema != null) {
        schemaMap[spec.package] = resolution.schema!;
        stdout.writeln(
            '  ${spec.package}: resolved from ${resolution.source!.name}');
      } else {
        stderr.writeln(
            '  Warning: ${resolution.warning ?? 'No schema found for "${spec.package}"'}');
      }

      // Print parse warnings
      for (final w in resolution.parseWarnings) {
        stderr.writeln('  Warning: $w');
      }
    }

    // Apply selective imports filter
    for (final spec in packages) {
      if (spec.isSelectiveImport && schemaMap.containsKey(spec.package)) {
        schemaMap[spec.package] = SchemaResolver.filterByImports(
            schemaMap[spec.package]!, spec.imports);
      }
    }

    // Run analyzer on each schema
    if (!noAnalyze) {
      final analyzer = const ApiSurfaceAnalyzer();
      var hasErrors = false;
      for (final entry in schemaMap.entries) {
        final result = analyzer.analyze(entry.value);
        for (final d in result.diagnostics) {
          if (d.isError) {
            stderr.writeln('  ERROR [${entry.key}]: $d');
            hasErrors = true;
          } else {
            stdout.writeln('  ${d.severity.name} [${entry.key}]: $d');
          }
        }
      }
      if (hasErrors) {
        stderr.writeln('Analysis found errors. Aborting generation.');
        stderr.writeln('Use --no-analyze to skip analysis.');
        return 1;
      }

      // Run cross-package dependency resolution
      if (schemaMap.length > 1) {
        final resolver = const DependencyResolver();
        final resolution = resolver.resolve(schemaMap.values.toList());
        if (resolution.hasConflicts) {
          for (final conflict in resolution.conflicts) {
            stderr.writeln('  WARNING: Version conflict — $conflict');
          }
        }
      }
    }

    // Detect cross-package type references
    for (final entry in schemaMap.entries) {
      final schema = entry.value;
      final definedNames = schema.definedTypeNames;
      for (final otherEntry in schemaMap.entries) {
        if (otherEntry.key == entry.key) continue;
        final otherDefined = otherEntry.value.definedTypeNames;
        // If any type in `schema` references a name defined in `otherEntry`
        for (final name in _referencedTypeNames(schema)) {
          if (otherDefined.contains(name) && !definedNames.contains(name)) {
            depGraph.addDependency(entry.key, otherEntry.key);
            break;
          }
        }
      }
    }

    // Determine which packages need rebuilding
    final dirtyPackages = <String>{};
    for (final spec in packages) {
      final schema = schemaMap[spec.package];
      if (schema == null) continue;
      // Include customTypes and imports in the checksum so config-level
      // changes that affect generation (but not the schema itself) trigger
      // a rebuild even when the overall configChecksum hasn't changed.
      final specFingerprint =
          '${schema.toJson()}|${spec.customTypes}|${spec.imports}';
      final inputChecksum = Checksum.of(specFingerprint);
      final needsRebuild = force ||
          configChanged ||
          cache.needsRebuild(spec.package, inputChecksum);
      if (needsRebuild) {
        dirtyPackages.add(spec.package);
      }
      if (verbose) {
        stdout.writeln(
            '  ${spec.package}: checksum=$inputChecksum, needsRebuild=$needsRebuild');
      }
    }

    // Expand dirty set via dependency graph
    final fullDirtySet = depGraph.invalidationSet(dirtyPackages);
    final packagesToGenerate =
        packages.where((spec) => fullDirtySet.contains(spec.package)).toList();

    if (packagesToGenerate.isEmpty) {
      stdout.writeln('All packages up to date. Nothing to generate.');
      return 0;
    }

    stdout.writeln(
        'Generating bindings for ${packagesToGenerate.length} package(s)...');
    if (packagesToGenerate.length < packages.length) {
      final skipped = packages.length - packagesToGenerate.length;
      stdout.writeln('  ($skipped package(s) unchanged, skipped)');
    }

    // Generate dirty packages in parallel using isolates
    final results = await Future.wait(
      packagesToGenerate.map((spec) {
        final schema = schemaMap[spec.package];
        if (schema == null) return Future.value(null);
        final schemaJson = schema.toJson();
        final customTypes = Map<String, String>.from(spec.customTypes);
        return Isolate.run(() {
          return _generatePackageFromSchema(spec, schemaJson,
              customTypes: customTypes);
        });
      }),
    );

    // Write files sequentially and update cache
    var generated = 0;
    final allSwiftPlugins = <String>[];
    for (final result in results) {
      if (result == null) {
        stderr.writeln('  Warning: Could not resolve schema for a package');
        continue;
      }

      if (dryRun) {
        // Report what would be generated without writing
        for (final fileName in result.dartFiles.keys) {
          stdout.writeln('  [dry-run] Would write $outputDir/$fileName');
        }
        for (final fileName in result.glueFiles.keys) {
          stdout.writeln('  [dry-run] Would write glue file $fileName');
        }
        if (verbose) {
          stdout.writeln(
              '  [dry-run] Dart files: ${result.dartFiles.keys.join(', ')}');
          stdout.writeln(
              '  [dry-run] Glue files: ${result.glueFiles.keys.join(', ')}');
        }
        generated++;
        stdout.writeln(
            '  [dry-run] Would generate bindings for ${result.package}');
        continue;
      }

      final outputChecksums = <String, String>{};
      _writeFiles(result.dartFiles, outputDir, outputChecksums);

      // Route glue files to platform-specific directories
      _routeGlueFiles(
          result.glueFiles, outputDir, outputChecksums, allSwiftPlugins);

      cache.recordBuild(
        result.package,
        inputChecksum: result.inputChecksum,
        outputChecksums: outputChecksums,
      );
      generated++;
      stdout.writeln('  Generated bindings for ${result.package}');

      if (verbose) {
        stdout.writeln('    Dart files: ${result.dartFiles.keys.join(', ')}');
        stdout.writeln('    Glue files: ${result.glueFiles.keys.join(', ')}');
      }
    }

    if (!dryRun) {
      // Write _unresolved_types.yaml manifest
      _writeUnresolvedTypesManifest(results, outputDir);

      // Generate RegisterAutoInteropPlugins.swift if there are Swift plugins
      if (allSwiftPlugins.isNotEmpty) {
        _generateSwiftPluginRegistration(allSwiftPlugins);
        _patchPluginRegistration();
      }

      // Save cache
      cache.configChecksum = configChecksum;
      cache.save(cacheFile);

      // Post-generation: patch native dependency files
      _patchNativeDependencies(packages);
    }

    final prefix = dryRun ? '[dry-run] Would generate' : 'Done. Generated';
    stdout.writeln('$prefix $generated binding(s) in $outputDir');
    return 0;
  }

  int _runList() {
    final cache = ParseCache();
    final cached = cache.listCached();

    if (cached.isEmpty) {
      stdout.writeln('No cached type definitions found.');
      stdout.writeln('Run "generate" to auto-parse and cache native sources.');
      return 0;
    }

    stdout.writeln('Cached type definitions:');
    for (final name in cached) {
      stdout.writeln('  $name');
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

  Future<int> _runRegistry(List<String> args) async {
    if (args.isEmpty) {
      stderr.writeln('Usage: auto_interop registry <subcommand>');
      stderr.writeln('  list    List available packages in the registry');
      stderr.writeln('  fetch   Force-fetch a specific definition');
      return 1;
    }

    final client = RegistryClient();

    switch (args.first) {
      case 'list':
        final packages = await client.listPackages();
        if (packages.isEmpty) {
          stdout.writeln(
              'No packages found in registry (may be offline or empty).');
        } else {
          stdout.writeln('Available packages in registry:');
          for (final pkg in packages) {
            stdout.writeln('  $pkg');
          }
        }
        return 0;

      case 'fetch':
        if (args.length < 2) {
          stderr.writeln(
              'Usage: auto_interop registry fetch <source/package> [version]');
          stderr.writeln(
              '  Example: auto_interop registry fetch npm/date-fns 3.6.0');
          return 1;
        }
        final packageKey = args[1];
        final version = args.length > 2 ? args[2] : 'latest';
        stdout.writeln('Fetching $packageKey@$version from registry...');
        final result = await client.forceFetch(packageKey, version);
        if (result.schema != null) {
          stdout.writeln('  Fetched ${result.schema!.package} '
              '(${result.schema!.classes.length} classes, '
              '${result.schema!.functions.length} functions)');
        } else {
          stderr.writeln('  ${result.warning ?? "Failed to fetch"}');
          return 1;
        }
        return 0;

      default:
        stderr.writeln('Unknown registry subcommand: ${args.first}');
        return 1;
    }
  }

  Future<int> _runCleanup(String level, List<String> args) async {
    final allFlag = args.contains('--all');
    String? outputDir;
    String? packageName;

    // Parse args
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--all') continue;
      if (args[i] == '--output' && i + 1 < args.length) {
        outputDir = args[++i];
        continue;
      }
      if (!args[i].startsWith('-')) {
        packageName = args[i];
      }
    }

    outputDir ??= 'lib/generated';

    if (!allFlag && packageName == null) {
      stderr.writeln('Usage: auto_interop $level <package>');
      stderr.writeln('       auto_interop $level --all');
      stderr.writeln();
      stderr.writeln('Options:');
      stderr.writeln(
          '  --output <dir>  Output directory (default: lib/generated)');
      return 1;
    }

    final cacheFile = File('.auto_interop_cache.json');
    var removedCount = 0;

    final parseCache = ParseCache();

    if (allFlag) {
      // --all mode
      if (cacheFile.existsSync()) {
        cacheFile.deleteSync();
        stdout.writeln('  Removed .auto_interop_cache.json');
        removedCount++;
      }

      // Clear parse cache
      if (Directory(parseCache.cacheDir).existsSync()) {
        parseCache.clear();
        stdout.writeln('  Removed parse cache');
        removedCount++;
      }

      if (level == 'delete' || level == 'purge') {
        final outDir = Directory(outputDir);
        if (outDir.existsSync()) {
          final files = outDir.listSync().whereType<File>();
          for (final file in files) {
            file.deleteSync();
            stdout.writeln('  Removed ${file.path}');
            removedCount++;
          }
        }
      }

      if (level == 'delete' || level == 'purge') {
        // Remove downloaded sources
        final downloadDir = Directory('build/auto_interop');
        if (downloadDir.existsSync()) {
          downloadDir.deleteSync(recursive: true);
          stdout.writeln('  Removed build/auto_interop/');
          removedCount++;
        }
      }

      if (level == 'purge') {
        // Remove Swift plugin files
        final swiftDir = _findSwiftTargetDir();
        if (swiftDir != null) {
          final dir = Directory(swiftDir);
          if (dir.existsSync()) {
            for (final entity in dir.listSync().whereType<File>()) {
              final name = entity.uri.pathSegments.last;
              if (name.endsWith('Plugin.swift') ||
                  name == 'RegisterAutoInteropPlugins.swift') {
                entity.deleteSync();
                stdout.writeln('  Removed ${entity.path}');
                removedCount++;
              }
            }
          }
        }

        // Remove Kotlin plugin files
        final kotlinDir = _findKotlinTargetDir();
        if (kotlinDir != null) {
          final dir = Directory(kotlinDir);
          if (dir.existsSync()) {
            for (final entity in dir.listSync().whereType<File>()) {
              final name = entity.uri.pathSegments.last;
              if (name.endsWith('Plugin.kt')) {
                entity.deleteSync();
                stdout.writeln('  Removed ${entity.path}');
                removedCount++;
              }
            }
          }
        }
      }
    } else {
      // Per-package mode
      if (!cacheFile.existsSync()) {
        stderr.writeln('Warning: No cache file found. Nothing to clean.');
        return 0;
      }

      final cache = BuildCache.load(cacheFile);
      final entry = cache.packages[packageName];
      if (entry == null) {
        stderr.writeln(
            'Warning: Package "$packageName" not found in cache. Nothing to clean.');
        return 0;
      }

      final fileNames = entry.outputChecksums.keys.toList();

      // Always remove the package entry from build cache (clean level)
      cache.packages.remove(packageName);
      cache.save(cacheFile);
      stdout.writeln('  Removed "$packageName" from build cache');
      removedCount++;

      // Also remove from parse cache
      parseCache.remove(packageName!);
      stdout.writeln('  Removed "$packageName" from parse cache');
      removedCount++;

      if (level == 'delete' || level == 'purge') {
        // Remove .dart files from output dir
        for (final fileName in fileNames) {
          if (fileName.endsWith('.dart')) {
            if (_deleteFileIfExists('$outputDir/$fileName')) removedCount++;
          }
        }
      }

      if (level == 'purge') {
        // Remove .swift files from swift target dir
        final swiftDir = _findSwiftTargetDir();
        if (swiftDir != null) {
          for (final fileName in fileNames) {
            if (fileName.endsWith('.swift')) {
              if (_deleteFileIfExists('$swiftDir/$fileName')) removedCount++;
            }
          }
        }

        // Remove .kt files from kotlin target dir
        final kotlinDir = _findKotlinTargetDir();
        if (kotlinDir != null) {
          for (final fileName in fileNames) {
            if (fileName.endsWith('.kt')) {
              if (_deleteFileIfExists('$kotlinDir/$fileName')) removedCount++;
            }
          }
        }
      }
    }

    stdout.writeln('$level completed. $removedCount item(s) removed.');
    return 0;
  }

  bool _deleteFileIfExists(String path) {
    final file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
      stdout.writeln('  Removed $path');
      return true;
    }
    return false;
  }

  void _printUsage() {
    stdout.writeln(
        'auto_interop_generator — Generate Dart bindings from native packages');
    stdout.writeln();
    stdout.writeln(
        'Usage: dart run auto_interop_generator:generate [command] [options]');
    stdout.writeln();
    stdout.writeln('Commands:');
    stdout.writeln(
        '  generate   Generate Dart bindings from auto_interop.yaml (default)');
    stdout.writeln(
        '  parse      Parse native source files into a .uts.json type definition');
    stdout.writeln('  list       List cached parsed type definitions');
    stdout.writeln('  add        Add a native package to auto_interop.yaml');
    stdout.writeln(
        '  setup      Check toolchains and pre-compile AST helpers');
    stdout.writeln('  registry   Manage the cloud definition registry');
    stdout
        .writeln('  clean      Clear cache (forces rebuild on next generate)');
    stdout.writeln('  delete     Clean + remove generated Dart files');
    stdout
        .writeln('  purge      Delete + remove routed Swift/Kotlin glue files');
    stdout.writeln('  help       Show this help message');
    stdout.writeln('  version    Show version');
    stdout.writeln();
    stdout.writeln('Generate options:');
    stdout.writeln(
        '  --config <path>      Path to auto_interop.yaml (default: auto_interop.yaml)');
    stdout.writeln(
        '  --output <dir>       Output directory (default: lib/generated)');
    stdout.writeln(
        '  --only <packages>    Generate only specified packages (comma-separated)');
    stdout.writeln('  --force              Force regeneration of all packages');
    stdout.writeln(
        '  --dry-run            Preview what would be generated without writing files');
    stdout.writeln(
        '  --verbose            Show detailed output (checksums, cache state)');
    stdout.writeln('  --no-analyze         Skip API surface analysis');
    stdout.writeln(
        '  --no-download        Skip auto-downloading native packages');
    stdout.writeln('  --no-registry        Skip cloud registry lookup');
    stdout.writeln(
        '  --no-ast             Skip AST-based parsing (use regex parsers only)');
    stdout.writeln(
        '  --override <files>   Load user-provided .uts.json files (comma-separated)');
    stdout.writeln();
    stdout.writeln('Registry subcommands:');
    stdout
        .writeln('  registry list                    List available packages');
    stdout
        .writeln('  registry fetch <package> [ver]   Force-fetch a definition');
    stdout.writeln();
    stdout.writeln('Parse options:');
    stdout.writeln('  --package <name>     Package name (required)');
    stdout.writeln('  --version <ver>      Package version (default: 0.0.0)');
    stdout.writeln(
        '  --source <type>      Parser to use: cocoapods, spm, gradle, npm (auto-detected)');
    stdout.writeln(
        '  --output <path>      Write output to file instead of stdout');
    stdout.writeln('  --save               Save to parse cache');
    stdout.writeln('  --no-analyze         Skip API surface analysis');
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

  List<String> _findOverrides(List<String> args) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == '--override') {
        return args[i + 1].split(',').map((s) => s.trim()).toList();
      }
    }
    return const [];
  }

  static String _toSnakeCase(String input) {
    return input
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
  }

  static Map<String, dynamic>? _parseJson(String content) {
    try {
      return Map<String, dynamic>.from(
        (const JsonDecoder().convert(content)) as Map,
      );
    } catch (_) {
      return null;
    }
  }

  List<String>? _findOnlyFilter(List<String> args) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == '--only') {
        return args[i + 1].split(',').map((s) => s.trim()).toList();
      }
    }
    return null;
  }

  /// Collects all type names referenced (but not necessarily defined) in [schema].
  static Set<String> _referencedTypeNames(UnifiedTypeSchema schema) {
    final refs = <String>{};
    void walkType(UtsType type) {
      if (type.ref != null) refs.add(type.ref!);
      type.typeArguments?.forEach(walkType);
      type.parameterTypes?.forEach(walkType);
      if (type.returnType != null) walkType(type.returnType!);
    }

    for (final cls in [...schema.classes, ...schema.types]) {
      if (cls.superclass != null) refs.add(cls.superclass!);
      refs.addAll(cls.interfaces);
      refs.addAll(cls.sealedSubclasses);
      for (final field in cls.fields) {
        walkType(field.type);
      }
      for (final method in cls.methods) {
        walkType(method.returnType);
        for (final param in method.parameters) {
          walkType(param.type);
        }
      }
    }
    for (final func in schema.functions) {
      walkType(func.returnType);
      for (final param in func.parameters) {
        walkType(param.type);
      }
    }
    return refs;
  }

  /// Generates all output for a single package from a pre-resolved schema.
  /// Designed to run in an isolate.
  static _GenerationResult _generatePackageFromSchema(
      PackageSpec spec, Map<String, dynamic> schemaJson,
      {Map<String, String> customTypes = const {}}) {
    final schema = UnifiedTypeSchema.fromJson(schemaJson);
    final specFingerprint = '$schemaJson|$customTypes|${spec.imports}';
    final inputChecksum = Checksum.of(specFingerprint);
    final dartGen = DartGenerator();
    final dartFiles = dartGen.generate(schema, customTypes: customTypes);
    final unresolvedTypes =
        dartGen.collectUnresolvedTypes(schema, customTypes: customTypes);
    final glueFiles = _generateGlue(schema, spec.source);
    return _GenerationResult(
      package: spec.package,
      dartFiles: dartFiles,
      glueFiles: glueFiles,
      inputChecksum: inputChecksum,
      unresolvedTypes: unresolvedTypes,
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

  /// Routes glue files to platform-specific directories.
  ///
  /// - `.swift` files → `macos/Runner/` or `ios/Runner/` (whichever exists)
  /// - `.kt` files → `android/app/src/main/kotlin/`
  /// - Other files → default output directory
  void _routeGlueFiles(
    Map<String, String> glueFiles,
    String defaultOutputDir,
    Map<String, String> outputChecksums,
    List<String> allSwiftPlugins,
  ) {
    for (final entry in glueFiles.entries) {
      final fileName = entry.key;
      final content = entry.value;

      if (fileName.endsWith('.swift')) {
        // Extract plugin class name from filename (e.g. "AlamofirePlugin.swift" → "AlamofirePlugin")
        final pluginName = fileName.replaceAll('.swift', '');
        allSwiftPlugins.add(pluginName);

        // Route to macOS or iOS Runner directory
        final targetDir = _findSwiftTargetDir();
        if (targetDir != null) {
          final file = File('$targetDir/$fileName');
          outputChecksums[fileName] = Checksum.of(content);
          if (file.existsSync() && file.readAsStringSync() == content) {
            _patchXcodeProject(targetDir, fileName);
            continue;
          }
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(content);
          stdout.writeln('  Routed $fileName → $targetDir/');
          _patchXcodeProject(targetDir, fileName);
        } else {
          // Fallback to default output dir
          _writeSingleFile(
              fileName, content, defaultOutputDir, outputChecksums);
        }
      } else if (fileName.endsWith('.kt')) {
        final targetDir = _findKotlinTargetDir();
        if (targetDir != null) {
          final file = File('$targetDir/$fileName');
          outputChecksums[fileName] = Checksum.of(content);
          if (file.existsSync() && file.readAsStringSync() == content) {
            continue;
          }
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(content);
          stdout.writeln('  Routed $fileName → $targetDir/');
        } else {
          _writeSingleFile(
              fileName, content, defaultOutputDir, outputChecksums);
        }
      } else {
        _writeSingleFile(fileName, content, defaultOutputDir, outputChecksums);
      }
    }
  }

  /// Finds the Swift target directory (macOS or iOS Runner).
  String? _findSwiftTargetDir() {
    final candidates = [
      'macos/Runner',
      'ios/Runner',
    ];
    for (final dir in candidates) {
      if (Directory(dir).existsSync()) return dir;
    }
    return null;
  }

  /// Finds the Kotlin target directory for Android.
  String? _findKotlinTargetDir() {
    const dir = 'android/app/src/main/kotlin';
    if (Directory(dir).existsSync()) return dir;
    return null;
  }

  void _writeSingleFile(
    String fileName,
    String content,
    String outputDir,
    Map<String, String> outputChecksums,
  ) {
    final file = File('$outputDir/$fileName');
    outputChecksums[fileName] = Checksum.of(content);
    if (file.existsSync() && file.readAsStringSync() == content) {
      return;
    }
    file.writeAsStringSync(content);
  }

  /// Generates a `RegisterAutoInteropPlugins.swift` that registers all
  /// generated plugin classes with Flutter.
  ///
  /// Users add a single line to their AppDelegate:
  /// ```swift
  /// registerAutoInteropPlugins(with: self)
  /// ```
  void _generateSwiftPluginRegistration(List<String> pluginClassNames) {
    final targetDir = _findSwiftTargetDir();
    if (targetDir == null) return;

    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE — DO NOT EDIT');
    buffer.writeln('// Generated by auto_interop_generator');
    buffer.writeln('//');
    buffer.writeln(
        '// Call registerAutoInteropPlugins(with:) from MainFlutterWindow');
    buffer.writeln('// to register all generated native plugins.');
    buffer.writeln('//');
    buffer.writeln(
        '// In your MainFlutterWindow.swift (macOS), add after RegisterGeneratedPlugins:');
    buffer.writeln(
        '//   registerAutoInteropPlugins(with: flutterViewController.registrar(forPlugin: "AutoInteropPlugins"))');
    buffer.writeln('//');
    buffer.writeln(
        '// In your AppDelegate.swift (iOS), add in application(_:didFinishLaunchingWithOptions:):');
    buffer.writeln(
        '//   registerAutoInteropPlugins(with: self.registrar(forPlugin: "AutoInteropPlugins")!)');
    buffer.writeln();
    buffer.writeln('#if os(macOS)');
    buffer.writeln('import FlutterMacOS');
    buffer.writeln('#else');
    buffer.writeln('import Flutter');
    buffer.writeln('#endif');
    buffer.writeln();
    buffer.writeln(
        'public func registerAutoInteropPlugins(with registrar: FlutterPluginRegistrar) {');
    for (final cls in pluginClassNames) {
      buffer.writeln('    $cls.register(with: registrar)');
    }
    buffer.writeln('}');

    final file = File('$targetDir/RegisterAutoInteropPlugins.swift');
    final content = buffer.toString();
    if (file.existsSync() && file.readAsStringSync() == content) {
      return;
    }
    file.writeAsStringSync(content);
    stdout
        .writeln('  Generated RegisterAutoInteropPlugins.swift → $targetDir/');
    _patchXcodeProject(targetDir, 'RegisterAutoInteropPlugins.swift');
  }

  /// Writes an `_unresolved_types.yaml` manifest listing all auto-stubbed
  /// nativeObject types per package. Guides users to create custom types.
  void _writeUnresolvedTypesManifest(
      List<_GenerationResult?> results, String outputDir) {
    final buffer = StringBuffer();
    buffer.writeln('# Unresolved native types — auto-generated opaque stubs');
    buffer.writeln('# Override any of these by adding to auto_interop.yaml:');
    buffer.writeln('#   custom_types:');
    buffer.writeln('#     TypeName: "lib/your_file.dart"');
    buffer.writeln();

    var hasEntries = false;
    for (final result in results) {
      if (result == null || result.unresolvedTypes.isEmpty) continue;
      hasEntries = true;
      buffer.writeln('${result.package}:');
      final sorted = result.unresolvedTypes.toList()..sort();
      for (final typeName in sorted) {
        buffer.writeln('  - $typeName');
      }
      buffer.writeln();
    }

    if (!hasEntries) return;

    final file = File('$outputDir/_unresolved_types.yaml');
    file.writeAsStringSync(buffer.toString());
    stdout.writeln('  Generated _unresolved_types.yaml manifest');
  }

  void _writeFiles(
    Map<String, String> files,
    String outputDir,
    Map<String, String> outputChecksums,
  ) {
    for (final entry in files.entries) {
      final file = File('$outputDir/${entry.key}');
      outputChecksums[entry.key] = Checksum.of(entry.value);
      // Content-based skip: avoid rewriting unchanged files
      if (file.existsSync() && file.readAsStringSync() == entry.value) {
        continue;
      }
      file.writeAsStringSync(entry.value);
    }
  }

  // ---------------------------------------------------------------------------
  // parse command
  // ---------------------------------------------------------------------------

  Future<int> _runParse(List<String> args) async {
    String? packageName;
    String? version = '0.0.0';
    String? sourceOverride;
    String? outputPath;
    bool save = false;
    bool noAnalyze = false;
    bool noAst = false;
    final filePaths = <String>[];

    // Parse flags
    var i = 0;
    while (i < args.length) {
      switch (args[i]) {
        case '--package':
          if (i + 1 >= args.length) {
            stderr.writeln('--package requires a value');
            return 1;
          }
          packageName = args[++i];
        case '--version':
          if (i + 1 >= args.length) {
            stderr.writeln('--version requires a value');
            return 1;
          }
          version = args[++i];
        case '--source':
          if (i + 1 >= args.length) {
            stderr.writeln('--source requires a value');
            return 1;
          }
          sourceOverride = args[++i];
        case '--output':
          if (i + 1 >= args.length) {
            stderr.writeln('--output requires a value');
            return 1;
          }
          outputPath = args[++i];
        case '--save':
          save = true;
        case '--no-analyze':
          noAnalyze = true;
        case '--no-ast':
          noAst = true;
        default:
          if (args[i].startsWith('-')) {
            stderr.writeln('Unknown flag: ${args[i]}');
            return 1;
          }
          filePaths.add(args[i]);
      }
      i++;
    }

    // Validate
    if (packageName == null) {
      stderr.writeln('Error: --package is required');
      stderr.writeln(
          'Usage: dart run auto_interop_generator:generate parse <files...> --package <name>');
      return 1;
    }
    if (filePaths.isEmpty) {
      stderr.writeln('Error: At least one source file is required');
      return 1;
    }
    for (final path in filePaths) {
      if (!File(path).existsSync()) {
        stderr.writeln('Error: File not found: $path');
        return 1;
      }
    }

    // Determine parser
    ParserBase parser;
    if (sourceOverride != null) {
      parser = _parserForSource(sourceOverride);
    } else {
      final detectedParser = _detectParser(filePaths);
      if (detectedParser == null) {
        stderr.writeln(
            'Error: Could not auto-detect parser from file extensions. '
            'Use --source to specify (cocoapods, spm, gradle, npm).');
        return 1;
      }
      parser = detectedParser;
    }

    // Read files
    final files = <String, String>{};
    for (final path in filePaths) {
      files[path] = File(path).readAsStringSync();
    }

    // Parse (try AST parser first unless --no-ast)
    ParseResult result;
    if (!noAst) {
      final astParser = _astParserForSource(parser);
      if (astParser != null) {
        result = await astParser.parseFilesAsync(
          files: files,
          packageName: packageName,
          version: version!,
        );
      } else {
        result = parser.parseFilesWithValidation(
          files: files,
          packageName: packageName,
          version: version!,
        );
      }
    } else {
      result = parser.parseFilesWithValidation(
        files: files,
        packageName: packageName,
        version: version!,
      );
    }

    // Print warnings
    for (final w in result.warnings) {
      stderr.writeln('  Warning: $w');
    }

    final schema = result.schema;

    // Run analyzer
    if (!noAnalyze) {
      final analyzer = const ApiSurfaceAnalyzer();
      final analysisResult = analyzer.analyze(schema);
      for (final d in analysisResult.diagnostics) {
        if (d.isError) {
          stderr.writeln('  ERROR: $d');
        } else {
          stdout.writeln('  ${d.severity.name}: $d');
        }
      }
      if (analysisResult.hasErrors) {
        stderr.writeln('Analysis found errors. Use --no-analyze to skip.');
        return 1;
      }
    }

    // Output
    final jsonOutput =
        const JsonEncoder.withIndent('  ').convert(schema.toJson());

    if (save) {
      final cache = ParseCache();
      final checksum = Checksum.of(jsonOutput);
      cache.put(_toSnakeCase(packageName), checksum, schema);
      stdout.writeln('Saved type definition for $packageName to parse cache');
    } else if (outputPath != null) {
      File(outputPath).writeAsStringSync(jsonOutput);
      stdout.writeln('Wrote type definition to $outputPath');
    } else {
      stdout.writeln(jsonOutput);
    }

    return 0;
  }

  // ---------------------------------------------------------------------------
  // setup command
  // ---------------------------------------------------------------------------

  Future<int> _runSetup() async {
    stdout.writeln('Checking AST parser toolchains...');
    stdout.writeln('');

    final detector = ToolchainDetector();
    var allReady = true;

    // --- Node.js + TypeScript ---
    stdout.write('  Node.js (for TypeScript/npm parsing): ');
    if (await detector.hasNode()) {
      stdout.writeln('\u2713 available');
      // Check typescript module
      stdout.write('  typescript npm package:               ');
      final tsCheck = await Process.run(
          'node', ['--input-type=module', '-e', 'import("typescript")']);
      if (tsCheck.exitCode == 0) {
        stdout.writeln('\u2713 available');
      } else {
        stdout.writeln('\u2717 missing');
        stdout.writeln(
            '    Install with: npm install -g typescript');
        allReady = false;
      }
    } else {
      stdout.writeln('\u2717 not found (need Node.js >= 18)');
      allReady = false;
    }

    // --- Swift ---
    stdout.write('  Swift (for Swift/CocoaPods parsing):   ');
    if (await detector.hasSwift()) {
      stdout.writeln('\u2713 available');
      // Check if binary is already cached
      final cached = detector.cachedSwiftBinary();
      if (cached != null) {
        stdout.writeln('  Swift AST helper binary:              \u2713 cached');
        stdout.writeln('    $cached');
      } else {
        stdout.writeln('  Swift AST helper binary:              building...');
        try {
          final parser = AstSwiftParser(toolchainDetector: detector);
          await parser.prepare();
          stdout.writeln('  Swift AST helper binary:              \u2713 ready');
        } catch (e) {
          stdout.writeln('  Swift AST helper binary:              \u2717 failed');
          stdout.writeln('    $e');
          allReady = false;
        }
      }
    } else {
      stdout.writeln('\u2717 not found');
      if (Platform.isMacOS) {
        stdout.writeln(
            '    Install with: xcode-select --install');
      }
      allReady = false;
    }

    // --- kotlinc ---
    stdout.write('  kotlinc (for Kotlin/Gradle parsing):  ');
    if (await detector.hasKotlinc()) {
      final ktVersion = await detector.kotlincVersion();
      stdout.writeln('\u2713 available${ktVersion != null ? " ($ktVersion)" : ""}');
      // Pre-warm Maven dependencies
      stdout.writeln('  Kotlin dependencies:                  warming...');
      try {
        final parser = AstGradleParser(toolchainDetector: detector);
        await parser.warmMavenCache();
        stdout.writeln('  Kotlin dependencies:                  \u2713 ready');
      } catch (e) {
        stdout.writeln('  Kotlin dependencies:                  \u2717 failed');
        stdout.writeln('    $e');
        allReady = false;
      }
    } else {
      stdout.writeln('\u2717 not found');
      stdout.writeln(
          '    Install with: brew install kotlin (macOS) or sdkman');
      allReady = false;
    }

    stdout.writeln('');
    if (allReady) {
      stdout.writeln('All AST toolchains ready. Parsing will use AST mode.');
    } else {
      stdout.writeln(
          'Some toolchains missing. Parsing will fall back to regex for those.');
      stdout.writeln(
          'Regex parsing works but AST mode produces more accurate results.');
    }

    return 0;
  }

  ParserBase _parserForSource(String source) {
    switch (source) {
      case 'cocoapods':
      case 'spm':
        return SwiftParser();
      case 'gradle':
        return GradleParser();
      case 'npm':
        return NpmParser();
      default:
        return SwiftParser();
    }
  }

  ParserBase? _detectParser(List<String> filePaths) {
    ParserBase? detected;
    for (final path in filePaths) {
      final lower = path.toLowerCase();
      ParserBase? current;
      if (lower.endsWith('.swift') || lower.endsWith('.swiftinterface')) {
        current = SwiftParser();
      } else if (lower.endsWith('.kt') || lower.endsWith('.java')) {
        current = GradleParser();
      } else if (lower.endsWith('.d.ts') || lower.endsWith('.ts')) {
        current = NpmParser();
      }
      if (current == null) continue;
      if (detected != null && detected.source != current.source) {
        // Mixed file types — can't auto-detect
        return null;
      }
      detected = current;
    }
    return detected;
  }

  /// Returns an AST-based parser wrapping the given regex parser, or null.
  AstParserBase? _astParserForSource(ParserBase regexParser) {
    switch (regexParser.source) {
      case PackageSource.cocoapods:
      case PackageSource.spm:
        return AstSwiftParser();
      case PackageSource.gradle:
        return AstGradleParser();
      case PackageSource.npm:
        return AstNpmParser();
    }
  }

  // ---------------------------------------------------------------------------
  // Native dependency patching (Feature 2)
  // ---------------------------------------------------------------------------

  void _patchNativeDependencies(List<PackageSpec> packages) {
    final cocoapodsPkgs = <PackageSpec>[];
    final gradlePkgs = <PackageSpec>[];
    final npmPkgs = <PackageSpec>[];

    for (final spec in packages) {
      switch (spec.source) {
        case PackageSource.cocoapods:
        case PackageSource.spm:
          cocoapodsPkgs.add(spec);
        case PackageSource.gradle:
          gradlePkgs.add(spec);
        case PackageSource.npm:
          npmPkgs.add(spec);
      }
    }

    // CocoaPods: patch ios/Podfile and macos/Podfile
    if (cocoapodsPkgs.isNotEmpty) {
      _patchPodfile('ios/Podfile', cocoapodsPkgs);
      _patchPodfile('macos/Podfile', cocoapodsPkgs);
    }

    // Gradle: patch build.gradle.kts (or .gradle)
    if (gradlePkgs.isNotEmpty) {
      final gradlePath = File('android/app/build.gradle.kts').existsSync()
          ? 'android/app/build.gradle.kts'
          : 'android/app/build.gradle';
      _patchBuildGradle(gradlePath, gradlePkgs);
    }

    // npm: print instructions
    if (npmPkgs.isNotEmpty) {
      stdout.writeln();
      stdout.writeln('  npm dependencies (add manually):');
      for (final spec in npmPkgs) {
        stdout.writeln('    npm install ${spec.package}@${spec.version}');
      }
    }
  }

  void _patchPodfile(String podfilePath, List<PackageSpec> specs) {
    final file = File(podfilePath);
    if (!file.existsSync()) return;

    try {
      var content = file.readAsStringSync();
      final newPods = <String>[];

      for (final spec in specs) {
        // Extract pod name (strip version prefix chars)
        final podName = spec.package;
        if (content.contains("pod '$podName'")) continue;

        final cleanVersion =
            spec.version.replaceAll(RegExp(r'^[~^>=<\s]+'), '');
        newPods.add("  pod '$podName', '$cleanVersion'");
      }

      if (newPods.isEmpty) return;

      // Find insertion point: after flutter_install_all_*_pods line
      final platform = podfilePath.contains('macos') ? 'macos' : 'ios';
      final installPodsPattern =
          RegExp('flutter_install_all_${platform}_pods.*\n');
      final match = installPodsPattern.firstMatch(content);

      if (match != null) {
        final insertPos = match.end;
        final block = '\n  # auto_interop native dependencies\n'
            '${newPods.join('\n')}\n';
        content = content.substring(0, insertPos) +
            block +
            content.substring(insertPos);
        file.writeAsStringSync(content);
        stdout.writeln('  Patched $podfilePath with ${newPods.length} pod(s)');
      } else {
        // Can't find insertion point — print instructions
        stdout.writeln();
        stdout.writeln('  Add to $podfilePath:');
        for (final pod in newPods) {
          stdout.writeln('    $pod');
        }
      }
    } catch (e) {
      stderr.writeln('  Warning: Could not patch $podfilePath: $e');
      stdout.writeln('  Add pods manually to $podfilePath');
    }
  }

  void _patchBuildGradle(String gradlePath, List<PackageSpec> specs) {
    final file = File(gradlePath);
    if (!file.existsSync()) {
      stdout.writeln();
      stdout.writeln('  Gradle dependencies (add manually to $gradlePath):');
      for (final spec in specs) {
        stdout.writeln('    implementation("${spec.package}:${spec.version}")');
      }
      return;
    }

    try {
      var content = file.readAsStringSync();
      final newDeps = <String>[];

      for (final spec in specs) {
        // spec.package is "group:artifact", version separate
        final groupArtifact = spec.package;
        if (content.contains('implementation("$groupArtifact')) continue;

        final cleanVersion =
            spec.version.replaceAll(RegExp(r'^[~^>=<\s]+'), '');
        newDeps.add('    implementation("$groupArtifact:$cleanVersion")');
      }

      if (newDeps.isEmpty) return;

      // Look for existing dependencies block
      final depsBlockPattern = RegExp(r'dependencies\s*\{');
      final match = depsBlockPattern.firstMatch(content);

      if (match != null) {
        // Insert after the opening brace
        final insertPos = match.end;
        final block =
            '\n    // auto_interop native dependencies\n${newDeps.join('\n')}\n';
        content = content.substring(0, insertPos) +
            block +
            content.substring(insertPos);
      } else {
        // No dependencies block — add one before the final closing brace
        final lastBrace = content.lastIndexOf('}');
        if (lastBrace != -1) {
          final block =
              '\ndependencies {\n    // auto_interop native dependencies\n'
              '${newDeps.join('\n')}\n}\n';
          content = content.substring(0, lastBrace) +
              block +
              content.substring(lastBrace);
        }
      }

      file.writeAsStringSync(content);
      stdout.writeln(
          '  Patched $gradlePath with ${newDeps.length} dependency(ies)');
    } catch (e) {
      stderr.writeln('  Warning: Could not patch $gradlePath: $e');
      stdout.writeln('  Add dependencies manually to $gradlePath');
    }
  }

  // ---------------------------------------------------------------------------
  // Xcode pbxproj patching (Feature 3)
  // ---------------------------------------------------------------------------

  void _patchXcodeProject(String targetDir, String fileName) {
    try {
      // Determine pbxproj path from targetDir
      // targetDir is e.g. "ios/Runner" or "macos/Runner"
      final platformDir = targetDir.split('/').first; // "ios" or "macos"
      final pbxprojPath = '$platformDir/Runner.xcodeproj/project.pbxproj';
      final pbxprojFile = File(pbxprojPath);
      if (!pbxprojFile.existsSync()) return;

      const patcher = PbxprojPatcher();
      var content = pbxprojFile.readAsStringSync();

      if (patcher.hasFileReference(content, fileName)) return;

      content = patcher.addSwiftFile(content, fileName);
      pbxprojFile.writeAsStringSync(content);
      stdout.writeln('  Added $fileName to $pbxprojPath');
    } catch (e) {
      stderr.writeln(
          '  Warning: Could not patch Xcode project for $fileName: $e');
      stdout.writeln('  Add $fileName to your Xcode project manually');
    }
  }

  // ---------------------------------------------------------------------------
  // Plugin registration patching (Feature 4)
  // ---------------------------------------------------------------------------

  void _patchPluginRegistration() {
    // iOS: AppDelegate.swift
    _patchAppDelegate('ios/Runner/AppDelegate.swift');
    // macOS: MainFlutterWindow.swift
    _patchMainFlutterWindow('macos/Runner/MainFlutterWindow.swift');
  }

  void _patchAppDelegate(String path) {
    final file = File(path);
    if (!file.existsSync()) return;

    try {
      var content = file.readAsStringSync();
      if (content.contains('registerAutoInteropPlugins')) return;

      // Find GeneratedPluginRegistrant.register(with: self) line
      final pattern =
          RegExp(r'GeneratedPluginRegistrant\.register\(with:\s*self\)');
      final match = pattern.firstMatch(content);
      if (match == null) {
        stdout.writeln();
        stdout.writeln(
            '  Add to $path (after GeneratedPluginRegistrant.register):');
        stdout.writeln(
            '    registerAutoInteropPlugins(with: self.registrar(forPlugin: "AutoInteropPlugins")!)');
        return;
      }

      // Find end of that line
      final lineEnd = content.indexOf('\n', match.end);
      if (lineEnd == -1) return;

      final registration =
          '\n        registerAutoInteropPlugins(with: self.registrar(forPlugin: "AutoInteropPlugins")!)';
      content = content.substring(0, lineEnd) +
          registration +
          content.substring(lineEnd);
      file.writeAsStringSync(content);
      stdout.writeln('  Patched $path with plugin registration');
    } catch (e) {
      stderr.writeln('  Warning: Could not patch $path: $e');
      stdout.writeln('  Add registerAutoInteropPlugins call to $path manually');
    }
  }

  void _patchMainFlutterWindow(String path) {
    final file = File(path);
    if (!file.existsSync()) return;

    try {
      var content = file.readAsStringSync();
      if (content.contains('registerAutoInteropPlugins')) return;

      // Find RegisterGeneratedPlugins(registry:...) line
      final pattern = RegExp(r'RegisterGeneratedPlugins\(registry:[^)]*\)');
      final match = pattern.firstMatch(content);
      if (match == null) {
        stdout.writeln();
        stdout.writeln('  Add to $path (after RegisterGeneratedPlugins):');
        stdout.writeln(
            '    registerAutoInteropPlugins(with: flutterViewController.registrar(forPlugin: "AutoInteropPlugins"))');
        return;
      }

      final lineEnd = content.indexOf('\n', match.end);
      if (lineEnd == -1) return;

      final registration =
          '\n    registerAutoInteropPlugins(with: flutterViewController.registrar(forPlugin: "AutoInteropPlugins"))';
      content = content.substring(0, lineEnd) +
          registration +
          content.substring(lineEnd);
      file.writeAsStringSync(content);
      stdout.writeln('  Patched $path with plugin registration');
    } catch (e) {
      stderr.writeln('  Warning: Could not patch $path: $e');
      stdout.writeln('  Add registerAutoInteropPlugins call to $path manually');
    }
  }
}
