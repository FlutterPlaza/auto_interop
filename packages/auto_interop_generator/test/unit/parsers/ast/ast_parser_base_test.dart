import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_parser_base.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/parsers/npm_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  group('AstParserBase', () {
    test('parse() synchronously delegates to fallback', () {
      final parser = _TestAstParser(toolchainAvailable: true);
      final schema = parser.parse(
        content: 'export function hello(): string;',
        packageName: 'test',
        version: '1.0.0',
      );
      // Should use the NpmParser fallback
      expect(schema.package, 'test');
    });

    test('parseFilesAsync with valid JSON returns parsed schema', () async {
      final schema = UnifiedTypeSchema(
        package: 'test-pkg',
        source: PackageSource.npm,
        version: '1.0.0',
        functions: [
          UtsMethod(
            name: 'hello',
            isStatic: true,
            returnType: UtsType.primitive('String'),
          ),
        ],
      );
      final jsonOutput = jsonEncode(schema.toJson());

      final parser = _TestAstParser(
        toolchainAvailable: true,
        processResult: _mockResult(0, stdout: jsonOutput),
      );

      final result = await parser.parseFilesAsync(
        files: {'test.d.ts': 'export function hello(): string;'},
        packageName: 'test-pkg',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test-pkg');
      expect(result.schema.functions, hasLength(1));
      expect(result.schema.functions.first.name, 'hello');
    });

    test('parseFilesAsync falls back on invalid JSON', () async {
      final parser = _TestAstParser(
        toolchainAvailable: true,
        processResult: _mockResult(0, stdout: 'not json at all'),
      );

      final result = await parser.parseFilesAsync(
        files: {'test.d.ts': 'export function hello(): string;'},
        packageName: 'test-pkg',
        version: '1.0.0',
      );

      // Should fallback to regex parser
      expect(result.schema.package, 'test-pkg');
    });

    test('parseFilesAsync falls back on non-zero exit', () async {
      final parser = _TestAstParser(
        toolchainAvailable: true,
        processResult: _mockResult(1, stderr: 'compilation failed'),
      );

      final result = await parser.parseFilesAsync(
        files: {'test.d.ts': 'export function hello(): string;'},
        packageName: 'test-pkg',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test-pkg');
    });

    test('parseFilesAsync falls back on timeout', () async {
      final parser = _TestAstParser(
        toolchainAvailable: true,
        processDelay: const Duration(seconds: 5),
        timeout: const Duration(milliseconds: 100),
      );

      final result = await parser.parseFilesAsync(
        files: {'test.d.ts': 'export function hello(): string;'},
        packageName: 'test-pkg',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test-pkg');
    });

    test('parseFilesAsync falls back when toolchain unavailable', () async {
      final parser = _TestAstParser(toolchainAvailable: false);

      final result = await parser.parseFilesAsync(
        files: {'test.d.ts': 'export function hello(): string;'},
        packageName: 'test-pkg',
        version: '1.0.0',
      );

      // Uses regex fallback
      expect(result.schema.package, 'test-pkg');
    });

    test('parseFilesAsync falls back on empty output', () async {
      final parser = _TestAstParser(
        toolchainAvailable: true,
        processResult: _mockResult(0, stdout: ''),
      );

      final result = await parser.parseFilesAsync(
        files: {'test.d.ts': 'export function hello(): string;'},
        packageName: 'test-pkg',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test-pkg');
    });

    test('parseFilesAsync falls back when prepare() throws', () async {
      final parser = _TestAstParser(
        toolchainAvailable: true,
        prepareError: StateError('compilation failed'),
      );

      final result = await parser.parseFilesAsync(
        files: {'test.d.ts': 'export function hello(): string;'},
        packageName: 'test-pkg',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test-pkg');
    });
  });
}

class _TestAstParser extends AstParserBase {
  final bool toolchainAvailable;
  final Duration? processDelay;
  final Object? prepareError;

  _TestAstParser({
    required this.toolchainAvailable,
    ProcessResult? processResult,
    this.processDelay,
    this.prepareError,
    Duration timeout = const Duration(seconds: 30),
  }) : super(
          fallbackParser: NpmParser(),
          toolchainDetector: ToolchainDetector(
            processRunner: (exec, args, {workingDirectory}) async {
              return _mockResult(toolchainAvailable ? 0 : 127,
                  stdout: toolchainAvailable ? 'v20.0.0' : '');
            },
          ),
          processRunner: (exec, args, {workingDirectory}) async {
            if (processDelay != null) {
              await Future.delayed(processDelay);
            }
            return processResult ?? _mockResult(0);
          },
          timeout: timeout,
        );

  @override
  Future<bool> isToolchainAvailable() async => toolchainAvailable;

  @override
  Future<void> prepare() async {
    if (prepareError != null) throw prepareError!;
  }

  @override
  List<String> helperCommand({
    required List<String> filePaths,
    required String packageName,
    required String version,
  }) {
    return ['test-helper', '--package', packageName, ...filePaths];
  }
}

ProcessResult _mockResult(int exitCode,
    {String stdout = '', String stderr = ''}) {
  return ProcessResult(0, exitCode, stdout, stderr);
}
