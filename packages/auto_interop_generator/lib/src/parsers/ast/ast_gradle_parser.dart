import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../schema/unified_type_schema.dart';
import '../gradle_parser.dart';
import '../parser_base.dart';
import 'ast_parser_base.dart';
import 'toolchain_detector.dart';

/// AST-based Gradle (Kotlin/Java) parser.
///
/// Invokes `kt_ast_helper.main.kts` via `kotlinc -script` to parse Kotlin
/// and Java source files using Kotlin PSI. Falls back to [GradleParser] if
/// `kotlinc` is unavailable or the subprocess fails.
///
/// On first use, the Kotlin script's `@file:DependsOn` triggers a Maven
/// dependency download (~30s). The version is matched to the installed kotlinc
/// to avoid API incompatibilities. Run `setup` to pre-warm the cache.
class AstGradleParser extends AstParserBase {
  String? _helperPath;
  String? _originalHelperPath;

  AstGradleParser({
    super.toolchainDetector,
    super.processRunner,
    // kotlinc -script can be slow on first run due to dependency resolution
    super.timeout = const Duration(seconds: 180),
  }) : super(fallbackParser: GradleParser());

  @override
  Future<bool> isToolchainAvailable() =>
      toolchainDetector.hasKotlinc();

  @override
  Future<void> prepare() async {
    _originalHelperPath ??= await _resolveOriginalHelperPath();
    _helperPath = await _prepareVersionMatchedScript();
  }

  @override
  List<String> helperCommand({
    required List<String> filePaths,
    required String packageName,
    required String version,
  }) {
    final path = _helperPath;
    if (path == null) return [];
    return [
      'kotlinc',
      '-script',
      path,
      '--',
      '--package',
      packageName,
      '--version',
      version,
      ...filePaths,
    ];
  }

  /// Splits files into Kotlin (AST) and Java (regex) and merges results.
  ///
  /// The Kotlin PSI cannot parse Java files, so `.java` files are routed
  /// through the regex [GradleParser] while `.kt` files use the AST
  /// subprocess. The two results are merged into a single schema.
  @override
  Future<ParseResult> parseFilesAsync({
    required Map<String, String> files,
    required String packageName,
    required String version,
  }) async {
    final ktFiles = <String, String>{};
    final javaFiles = <String, String>{};

    for (final entry in files.entries) {
      if (entry.key.endsWith('.java')) {
        javaFiles[entry.key] = entry.value;
      } else {
        ktFiles[entry.key] = entry.value;
      }
    }

    // If no Java files, delegate entirely to the base AST flow
    if (javaFiles.isEmpty) {
      return super.parseFilesAsync(
        files: files,
        packageName: packageName,
        version: version,
      );
    }

    // If no Kotlin files, delegate entirely to the regex fallback
    if (ktFiles.isEmpty) {
      return fallbackParser.parseFilesWithValidation(
        files: files,
        packageName: packageName,
        version: version,
      );
    }

    // Parse both in parallel
    final ktFuture = super.parseFilesAsync(
      files: ktFiles,
      packageName: packageName,
      version: version,
    );
    final javaResult = fallbackParser.parseFilesWithValidation(
      files: javaFiles,
      packageName: packageName,
      version: version,
    );

    final ktResult = await ktFuture;

    // Merge the two schemas
    final merged = fallbackParser.mergeSchemas(
      [ktResult.schema, javaResult.schema],
      packageName: packageName,
      version: version,
    );

    final warnings = [...ktResult.warnings, ...javaResult.warnings];
    return ParseResult(merged, warnings: warnings);
  }

  /// Prepares a version-matched copy of the helper script.
  ///
  /// Detects the installed kotlinc version and rewrites the `@file:DependsOn`
  /// line to match. Caches the result at `~/.auto_interop/tools/`.
  Future<String> _prepareVersionMatchedScript() async {
    final home = ToolchainDetector.homeDirectory();
    if (home == null) {
      // Can't cache; use original script as-is
      return _originalHelperPath!;
    }

    final toolsDir = '$home/.auto_interop/tools';

    try {
      Directory(toolsDir).createSync(recursive: true);
    } catch (_) {
      return _originalHelperPath!;
    }

    // Detect installed kotlinc version
    final kotlinVersion = await toolchainDetector.kotlincVersion();
    final version = kotlinVersion ?? '1.9.22'; // fallback

    final cachedScript = '$toolsDir/kt_ast_helper_$version.main.kts';
    final warmStamp = '$toolsDir/kt_ast_helper_$version.warm';

    // Read and patch the original source
    String patched;
    try {
      final original = File(_originalHelperPath!).readAsStringSync();
      patched = original.replaceFirst(
        RegExp(r'@file:DependsOn\("org\.jetbrains\.kotlin:kotlin-compiler-embeddable:[^"]+"\)'),
        '@file:DependsOn("org.jetbrains.kotlin:kotlin-compiler-embeddable:$version")',
      );
    } catch (_) {
      return _originalHelperPath!;
    }

    // Write if content changed or doesn't exist (auto-invalidates stale cache)
    final cachedFile = File(cachedScript);
    final needsUpdate = !cachedFile.existsSync() ||
        cachedFile.readAsStringSync() != patched;

    if (needsUpdate) {
      cachedFile.writeAsStringSync(patched);
      // Note: warm stamp is NOT deleted here. The stamp tracks Maven
      // dependency resolution which only depends on the @file:DependsOn
      // version — not on script logic. A new kotlinc version gets a new
      // filename pair (script + stamp) automatically, so stale stamps
      // are harmless.
    }

    // Warn user on first use (before Maven cache is warm)
    if (!File(warmStamp).existsSync()) {
      stderr.writeln(
          '  Kotlin AST: first use \u2014 dependency download may take ~30s');
      stderr.writeln(
          '  Run "setup" to pre-warm: dart run auto_interop_generator:generate setup');
      // Write stamp so message only shows once per kotlinc version
      try {
        File(warmStamp).writeAsStringSync(DateTime.now().toIso8601String());
      } catch (_) {}
    }

    return cachedScript;
  }

  /// Warms the Maven dependency cache with streaming output.
  ///
  /// Called from the CLI `setup` command. Runs the script with no files to
  /// trigger `@file:DependsOn` resolution without actually parsing anything.
  Future<void> warmMavenCache() async {
    final home = ToolchainDetector.homeDirectory();
    if (home == null) return;

    final kotlinVersion = await toolchainDetector.kotlincVersion();
    final version = kotlinVersion ?? '1.9.22';
    final toolsDir = '$home/.auto_interop/tools';
    final cachedScript = '$toolsDir/kt_ast_helper_$version.main.kts';
    final warmStamp = '$toolsDir/kt_ast_helper_$version.warm';

    // Ensure the version-matched script exists
    await prepare();

    if (File(warmStamp).existsSync()) return; // already warm

    stderr.writeln('');
    stderr.writeln(
        '  Kotlin AST helper \u2014 resolving dependencies...');

    final stopwatch = Stopwatch()..start();

    final process = await Process.start(
      'kotlinc',
      ['-script', cachedScript],
    );

    // Stream stderr for progress
    final stderrSub = process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('warning:') &&
          !trimmed.startsWith('OpenJDK')) {
        stderr.writeln('  \u2502 $trimmed');
      }
    });

    final stdoutSub = process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(LineSplitter())
        .listen((_) {});

    await process.exitCode;
    await stderrSub.cancel();
    await stdoutSub.cancel();
    stopwatch.stop();

    File(warmStamp).writeAsStringSync(DateTime.now().toIso8601String());

    final elapsed = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
    stderr.writeln('  \u2713 Dependencies cached (${elapsed}s)');
    stderr.writeln('');
  }

  /// Resolves the path to `kt_ast_helper.main.kts` within this package.
  static Future<String> _resolveOriginalHelperPath() async {
    final packageUri = Uri.parse(
        'package:auto_interop_generator/src/parsers/ast/helpers/kt_ast_helper.main.kts');
    final resolved = await Isolate.resolvePackageUri(packageUri);
    if (resolved != null) {
      return resolved.toFilePath();
    }
    // Fallback for development
    return 'lib/src/parsers/ast/helpers/kt_ast_helper.main.kts';
  }
}
