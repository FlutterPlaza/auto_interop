import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_npm_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  group('AstNpmParser', () {
    test('source is npm', () {
      final parser = AstNpmParser(
        toolchainDetector: _mockDetector(hasNode: true),
      );
      expect(parser.source, PackageSource.npm);
    });

    test('isToolchainAvailable checks node', () async {
      final parser = AstNpmParser(
        toolchainDetector: _mockDetector(hasNode: true),
      );
      expect(await parser.isToolchainAvailable(), isTrue);
    });

    test('isToolchainAvailable returns false without node', () async {
      final parser = AstNpmParser(
        toolchainDetector: _mockDetector(hasNode: false),
      );
      expect(await parser.isToolchainAvailable(), isFalse);
    });

    test('helperCommand includes node, package, version, and files', () async {
      String? capturedExec;
      List<String>? capturedArgs;

      final parser = AstNpmParser(
        toolchainDetector: _mockDetector(hasNode: true),
        processRunner: (exec, args, {workingDirectory}) async {
          capturedExec = exec;
          capturedArgs = args;
          return _mockResult(0, stdout: '{}');
        },
      );

      // Trigger prepare to resolve helper path
      await parser.prepare();

      final command = parser.helperCommand(
        filePaths: ['/src/index.d.ts', '/src/utils.d.ts'],
        packageName: 'date-fns',
        version: '3.6.0',
      );

      expect(command.first, 'node');
      expect(command, contains('--package'));
      expect(command, contains('date-fns'));
      expect(command, contains('--version'));
      expect(command, contains('3.6.0'));
      expect(command, contains('/src/index.d.ts'));
      expect(command, contains('/src/utils.d.ts'));
    });

    test('fallback parser is NpmParser', () {
      final parser = AstNpmParser(
        toolchainDetector: _mockDetector(hasNode: false),
      );
      // Sync parse should use fallback
      final schema = parser.parse(
        content: 'export function format(date: Date, fmt: string): string;',
        packageName: 'date-fns',
        version: '3.6.0',
      );
      expect(schema.package, 'date-fns');
      expect(schema.source, PackageSource.npm);
    });
  });
}

ToolchainDetector _mockDetector({required bool hasNode}) {
  return ToolchainDetector(
    processRunner: (exec, args, {workingDirectory}) async {
      if (exec == 'node' && args.contains('--version')) {
        return _mockResult(hasNode ? 0 : 127, stdout: hasNode ? 'v20.0.0' : '');
      }
      return _mockResult(127);
    },
  );
}

ProcessResult _mockResult(int exitCode,
    {String stdout = '', String stderr = ''}) {
  return ProcessResult(0, exitCode, stdout, stderr);
}
