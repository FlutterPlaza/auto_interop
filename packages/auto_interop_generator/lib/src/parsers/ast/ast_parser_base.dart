import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../schema/unified_type_schema.dart';
import '../parser_base.dart';
import 'toolchain_detector.dart';

/// Abstract base for AST-based parsers that invoke native helper scripts.
///
/// Subclasses implement [helperCommand] to provide the subprocess command
/// and [isToolchainAvailable] to check if the required toolchain is present.
///
/// The synchronous [parse] always delegates to the regex fallback.
/// [parseAsync] tries the AST subprocess first and falls back on any failure.
abstract class AstParserBase extends ParserBase {
  /// The regex-based parser used as fallback.
  final ParserBase fallbackParser;

  /// Toolchain detector (shared, caches results).
  final ToolchainDetector toolchainDetector;

  /// Process runner for subprocess invocation.
  final ProcessRunner _runProcess;

  /// Subprocess timeout.
  final Duration timeout;

  AstParserBase({
    required this.fallbackParser,
    ToolchainDetector? toolchainDetector,
    ProcessRunner? processRunner,
    this.timeout = const Duration(seconds: 30),
  })  : toolchainDetector = toolchainDetector ?? ToolchainDetector(),
        _runProcess = processRunner ?? _defaultProcessRunner;

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(executable, arguments,
        workingDirectory: workingDirectory);
  }

  @override
  PackageSource get source => fallbackParser.source;

  /// Synchronous parse always uses the regex fallback.
  @override
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  }) {
    return fallbackParser.parse(
      content: content,
      packageName: packageName,
      version: version,
    );
  }

  /// Asynchronously parses files using the AST helper subprocess.
  ///
  /// Falls back to the regex parser if:
  /// - The toolchain is not available
  /// - The subprocess exits non-zero
  /// - The subprocess times out
  /// - The output is not valid UTS JSON
  Future<ParseResult> parseFilesAsync({
    required Map<String, String> files,
    required String packageName,
    required String version,
  }) async {
    // Check toolchain availability
    if (!await isToolchainAvailable()) {
      return fallbackParser.parseFilesWithValidation(
        files: files,
        packageName: packageName,
        version: version,
      );
    }

    // Prepare for AST parsing (e.g. compile Swift binary)
    try {
      await prepare();
    } catch (e) {
      stderr.writeln(
          'Warning: AST parser preparation failed for $packageName: $e');
      stderr.writeln('  Falling back to regex parser.');
      return fallbackParser.parseFilesWithValidation(
        files: files,
        packageName: packageName,
        version: version,
      );
    }

    // Build and run the subprocess command
    try {
      final command = helperCommand(
        filePaths: files.keys.toList(),
        packageName: packageName,
        version: version,
      );

      if (command.isEmpty) {
        return fallbackParser.parseFilesWithValidation(
          files: files,
          packageName: packageName,
          version: version,
        );
      }

      final executable = command.first;
      final arguments = command.sublist(1);

      final result = await _runProcess(
        executable,
        arguments,
      ).timeout(timeout);

      if (result.exitCode != 0) {
        final errorOutput = (result.stderr as String).trim();
        if (errorOutput.isNotEmpty) {
          stderr.writeln(
              'Warning: AST parser failed for $packageName (exit ${result.exitCode}):');
          stderr.writeln('  $errorOutput');
        }
        stderr.writeln('  Falling back to regex parser.');
        return fallbackParser.parseFilesWithValidation(
          files: files,
          packageName: packageName,
          version: version,
        );
      }

      // Parse the JSON output
      final jsonOutput = (result.stdout as String).trim();
      if (jsonOutput.isEmpty) {
        stderr.writeln(
            'Warning: AST parser produced empty output for $packageName.');
        stderr.writeln('  Falling back to regex parser.');
        return fallbackParser.parseFilesWithValidation(
          files: files,
          packageName: packageName,
          version: version,
        );
      }

      final json = jsonDecode(jsonOutput) as Map<String, dynamic>;
      final schema = UnifiedTypeSchema.fromJson(json);
      return validateResult(schema);
    } on TimeoutException {
      stderr.writeln(
          'Warning: AST parser timed out for $packageName (${timeout.inSeconds}s).');
      stderr.writeln('  Falling back to regex parser.');
      return fallbackParser.parseFilesWithValidation(
        files: files,
        packageName: packageName,
        version: version,
      );
    } catch (e) {
      stderr.writeln('Warning: AST parser error for $packageName: $e');
      stderr.writeln('  Falling back to regex parser.');
      return fallbackParser.parseFilesWithValidation(
        files: files,
        packageName: packageName,
        version: version,
      );
    }
  }

  /// Whether the required toolchain is available for this parser.
  Future<bool> isToolchainAvailable();

  /// Optional preparation step (e.g. compiling Swift binary).
  Future<void> prepare() async {}

  /// Returns the command to invoke the helper script.
  ///
  /// [filePaths] are the source file paths to parse.
  /// Returns `[executable, arg1, arg2, ...]`.
  List<String> helperCommand({
    required List<String> filePaths,
    required String packageName,
    required String version,
  });
}
