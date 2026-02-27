import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../swift_parser.dart';
import 'ast_parser_base.dart';
import 'toolchain_detector.dart';

/// AST-based Swift parser.
///
/// Compiles and invokes a swift-syntax-based helper binary to parse Swift
/// source files. The binary is compiled once via SPM and cached at
/// `~/.auto_interop/tools/swift_ast_helper`.
///
/// Falls back to [SwiftParser] if Swift is unavailable or compilation fails.
class AstSwiftParser extends AstParserBase {
  String? _binaryPath;
  String? _helperProjectPath;

  AstSwiftParser({
    super.toolchainDetector,
    super.processRunner,
    super.timeout = const Duration(seconds: 60),
  }) : super(fallbackParser: SwiftParser());

  @override
  Future<bool> isToolchainAvailable() =>
      toolchainDetector.hasSwift();

  @override
  Future<void> prepare() async {
    _helperProjectPath ??= await _resolveHelperProjectPath();
    _binaryPath = toolchainDetector.cachedSwiftBinary();
    if (_binaryPath != null && _isUpToDate(_binaryPath!)) return;
    await _ensureCompiled();
  }

  @override
  List<String> helperCommand({
    required List<String> filePaths,
    required String packageName,
    required String version,
  }) {
    final binary = _binaryPath;
    if (binary == null) return [];
    return [
      binary,
      '--package',
      packageName,
      '--version',
      version,
      ...filePaths,
    ];
  }

  /// Compiles the Swift AST helper via SPM and caches the binary.
  ///
  /// Streams filtered SPM output to stderr so the user sees real-time
  /// progress during the first-time compilation (~30-60s).
  Future<void> _ensureCompiled() async {
    _helperProjectPath ??= await _resolveHelperProjectPath();
    final projectPath = _helperProjectPath;
    if (projectPath == null) {
      throw StateError('Could not resolve swift_ast_helper project path');
    }

    final home = ToolchainDetector.homeDirectory();
    if (home == null) throw StateError('HOME environment variable not set');

    final toolsDir = '$home/.auto_interop/tools';
    Directory(toolsDir).createSync(recursive: true);

    final targetBinary = '$toolsDir/swift_ast_helper';

    stderr.writeln('');
    stderr.writeln(
        '  Swift AST helper \u2014 one-time setup (~30-60s)');

    final stopwatch = Stopwatch()..start();
    final process = await Process.start(
      'swift',
      ['build', '-c', 'release'],
      workingDirectory: projectPath,
    );

    // Stream filtered build output for progress visibility
    final stderrLines = <String>[];
    int lastShownStep = 0;

    final stderrSub = process.stderr
        .transform(const SystemEncoding().decoder)
        .transform(LineSplitter())
        .listen((line) {
      stderrLines.add(line);
      _showBuildProgress(line, lastShownStep, (step) => lastShownStep = step);
    });

    final stdoutSub = process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(LineSplitter())
        .listen((line) {
      _showBuildProgress(line, lastShownStep, (step) => lastShownStep = step);
    });

    final exitCode = await process.exitCode;
    await stderrSub.cancel();
    await stdoutSub.cancel();
    stopwatch.stop();

    if (exitCode != 0) {
      final errorOutput = stderrLines.join('\n');
      throw StateError(
          'Swift AST helper compilation failed (exit $exitCode):\n$errorOutput');
    }

    // Copy binary to cache location
    final builtBinary = '$projectPath/.build/release/swift_ast_helper';
    if (!File(builtBinary).existsSync()) {
      throw StateError('Compiled binary not found at $builtBinary');
    }

    File(builtBinary).copySync(targetBinary);

    toolchainDetector.invalidateSwiftBinaryCache();
    _binaryPath = targetBinary;

    final elapsed = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);
    stderr.writeln(
        '  \u2713 Compiled and cached (${elapsed}s)');
    stderr.writeln(
        '    $targetBinary');
    stderr.writeln('');
  }

  /// Shows filtered SPM build progress on stderr.
  ///
  /// Displays: fetch/resolve messages, every ~10% of compilation steps,
  /// linking, and build-complete lines. Avoids flooding with hundreds
  /// of individual compilation lines.
  void _showBuildProgress(
      String line, int lastShownStep, void Function(int) updateStep) {
    final trimmed = line.trim();

    // Always show these milestone lines
    if (trimmed.startsWith('Fetching') ||
        trimmed.startsWith('Fetched') ||
        trimmed.startsWith('Computing') ||
        trimmed.startsWith('Computed') ||
        trimmed.startsWith('Creating working copy') ||
        trimmed.startsWith('Working copy') ||
        trimmed.startsWith('Resolving') ||
        trimmed.startsWith('Building for') ||
        trimmed.startsWith('Build complete') ||
        trimmed.contains('Linking')) {
      stderr.writeln('  \u2502 $trimmed');
      return;
    }

    // Show compilation progress at intervals (every ~10% of total steps)
    final progressMatch =
        RegExp(r'\[(\d+)/(\d+)\]').firstMatch(trimmed);
    if (progressMatch != null) {
      final current = int.parse(progressMatch.group(1)!);
      final total = int.parse(progressMatch.group(2)!);
      // Show first, last, and every ~10%
      final interval = (total / 10).ceil().clamp(1, total);
      if (current == 1 ||
          current == total ||
          current - lastShownStep >= interval) {
        stderr.writeln('  \u2502 $trimmed');
        updateStep(current);
      }
    }
  }

  /// Checks if the cached binary is up to date with the source files.
  ///
  /// Compares the modification time of the cached binary against the source
  /// files (`Package.swift`, `Sources/main.swift`). If any source file is
  /// newer, the binary is stale and needs recompilation.
  bool _isUpToDate(String binaryPath) {
    final binaryFile = File(binaryPath);
    if (!binaryFile.existsSync()) return false;

    final projectPath = _helperProjectPath;
    if (projectPath == null) return false;

    final binaryMtime = binaryFile.lastModifiedSync();

    for (final relativePath in ['Package.swift', 'Sources/main.swift']) {
      final source = File('$projectPath/$relativePath');
      if (source.existsSync() &&
          source.lastModifiedSync().isAfter(binaryMtime)) {
        return false;
      }
    }
    return true;
  }

  /// Resolves the path to `swift_ast_helper/` directory within this package.
  static Future<String?> _resolveHelperProjectPath() async {
    final packageUri = Uri.parse(
        'package:auto_interop_generator/src/parsers/ast/helpers/swift_ast_helper/Package.swift');
    final resolved = await Isolate.resolvePackageUri(packageUri);
    if (resolved != null) {
      // Return the directory containing Package.swift
      return resolved.resolve('.').toFilePath();
    }
    // Fallback for development
    final fallback = 'lib/src/parsers/ast/helpers/swift_ast_helper';
    if (Directory(fallback).existsSync()) return fallback;
    return null;
  }
}
