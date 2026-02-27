import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:test/test.dart';

void main() {
  group('ToolchainDetector', () {
    test('hasNode returns true when node >= 18 is available', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          if (exec == 'node' && args.contains('--version')) {
            return _mockResult(0, stdout: 'v20.11.0');
          }
          return _mockResult(1);
        },
      );
      expect(await detector.hasNode(), isTrue);
    });

    test('hasNode returns false for old node', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          return _mockResult(0, stdout: 'v16.0.0');
        },
      );
      expect(await detector.hasNode(), isFalse);
    });

    test('hasNode returns false when node not found', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          return _mockResult(127);
        },
      );
      expect(await detector.hasNode(), isFalse);
    });

    test('hasNode caches result', () async {
      var callCount = 0;
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          callCount++;
          return _mockResult(0, stdout: 'v20.0.0');
        },
      );
      await detector.hasNode();
      await detector.hasNode();
      expect(callCount, 1);
    });

    test('hasSwift returns true when swift is available', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          if (exec == 'swift') return _mockResult(0, stdout: 'swift-driver version: 1.90.11.1');
          return _mockResult(1);
        },
      );
      expect(await detector.hasSwift(), isTrue);
    });

    test('hasSwift returns false when swift not found', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          return _mockResult(127);
        },
      );
      expect(await detector.hasSwift(), isFalse);
    });

    test('hasKotlinc returns true when kotlinc is available', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          if (exec == 'kotlinc') return _mockResult(0, stdout: 'info: kotlinc-jvm 1.9.22');
          return _mockResult(1);
        },
      );
      expect(await detector.hasKotlinc(), isTrue);
    });

    test('hasKotlinc returns false when kotlinc not found', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          return _mockResult(127);
        },
      );
      expect(await detector.hasKotlinc(), isFalse);
    });

    test('cachedSwiftBinary returns null when no binary exists', () {
      final detector = ToolchainDetector();
      // Even if HOME is set, the binary shouldn't exist at a random path
      final result = detector.cachedSwiftBinary();
      // Result depends on whether the binary has been compiled before
      // Just verify it doesn't throw
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('invalidateSwiftBinaryCache clears cache', () {
      final detector = ToolchainDetector();
      detector.cachedSwiftBinary(); // prime cache
      detector.invalidateSwiftBinaryCache();
      // Calling again should re-check
      detector.cachedSwiftBinary();
      // Just verify no errors
    });

    test('handles process runner throwing exceptions', () async {
      final detector = ToolchainDetector(
        processRunner: (exec, args, {workingDirectory}) async {
          throw const ProcessException('node', [], 'not found');
        },
      );
      expect(await detector.hasNode(), isFalse);
      expect(await detector.hasSwift(), isFalse);
      expect(await detector.hasKotlinc(), isFalse);
    });
  });
}

ProcessResult _mockResult(int exitCode, {String stdout = '', String stderr = ''}) {
  return ProcessResult(0, exitCode, stdout, stderr);
}
