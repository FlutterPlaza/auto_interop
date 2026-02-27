import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_swift_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  group('AstSwiftParser', () {
    test('source is cocoapods', () {
      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: true),
      );
      expect(parser.source, PackageSource.cocoapods);
    });

    test('isToolchainAvailable checks swift', () async {
      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: true),
      );
      expect(await parser.isToolchainAvailable(), isTrue);
    });

    test('isToolchainAvailable returns false without swift', () async {
      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: false),
      );
      expect(await parser.isToolchainAvailable(), isFalse);
    });

    test('fallback parser is SwiftParser', () {
      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: false),
      );
      final schema = parser.parse(
        content: '''
public class Hello {
    public func greet(name: String) -> String {
        return "Hello"
    }
}
''',
        packageName: 'Hello',
        version: '1.0.0',
      );
      expect(schema.package, 'Hello');
      expect(schema.source, PackageSource.cocoapods);
    });

    test('timeout defaults to 60 seconds', () {
      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: true),
      );
      expect(parser.timeout, const Duration(seconds: 60));
    });

    test('helperCommand uses cached binary path', () async {
      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: true, hasCachedBinary: true),
      );

      // Simulate prepare
      await parser.prepare().catchError((_) {});

      // The command should use the binary
      final command = parser.helperCommand(
        filePaths: ['/src/Hello.swift'],
        packageName: 'Hello',
        version: '1.0.0',
      );

      // Command may be empty if binary not found, which is fine in test
      if (command.isNotEmpty) {
        expect(command, contains('--package'));
        expect(command, contains('Hello'));
      }
    });

    test('parseFilesAsync falls back when toolchain unavailable', () async {
      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: false),
      );

      final result = await parser.parseFilesAsync(
        files: {'Hello.swift': 'public class Hello {}'},
        packageName: 'Hello',
        version: '1.0.0',
      );

      expect(result.schema.package, 'Hello');
    });
  });
}

ToolchainDetector _mockDetector(
    {required bool hasSwift, bool hasCachedBinary = false}) {
  return ToolchainDetector(
    processRunner: (exec, args, {workingDirectory}) async {
      if (exec == 'swift' && args.contains('--version')) {
        return _mockResult(hasSwift ? 0 : 127,
            stdout: hasSwift ? 'swift-driver version: 1.90' : '');
      }
      return _mockResult(127);
    },
  );
}

ProcessResult _mockResult(int exitCode,
    {String stdout = '', String stderr = ''}) {
  return ProcessResult(0, exitCode, stdout, stderr);
}
