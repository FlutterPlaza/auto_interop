import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_gradle_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  group('AstGradleParser', () {
    test('source is gradle', () {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true),
      );
      expect(parser.source, PackageSource.gradle);
    });

    test('isToolchainAvailable checks kotlinc', () async {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true),
      );
      expect(await parser.isToolchainAvailable(), isTrue);
    });

    test('isToolchainAvailable returns false without kotlinc', () async {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: false),
      );
      expect(await parser.isToolchainAvailable(), isFalse);
    });

    test('helperCommand uses kotlinc -script', () async {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true),
      );

      await parser.prepare();

      final command = parser.helperCommand(
        filePaths: ['/src/Client.kt'],
        packageName: 'com.example:client',
        version: '1.0.0',
      );

      expect(command.first, 'kotlinc');
      expect(command[1], '-script');
      // The script path should end with .main.kts
      expect(command[2], endsWith('.main.kts'));
      // args after -- separator
      expect(command, contains('--'));
      expect(command, contains('--package'));
      expect(command, contains('com.example:client'));
      expect(command, contains('--version'));
      expect(command, contains('1.0.0'));
      expect(command, contains('/src/Client.kt'));
    });

    test('prepare creates version-matched script', () async {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true, version: '2.3.10'),
      );

      await parser.prepare();

      final command = parser.helperCommand(
        filePaths: ['/src/Test.kt'],
        packageName: 'test',
        version: '1.0.0',
      );

      // Script path should contain the kotlinc version
      final scriptPath = command[2];
      expect(scriptPath, contains('2.3.10'));

      // Verify the script content has the correct version
      if (File(scriptPath).existsSync()) {
        final content = File(scriptPath).readAsStringSync();
        expect(content, contains('kotlin-compiler-embeddable:2.3.10'));
      }
    });

    test('fallback parser is GradleParser', () {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: false),
      );
      final schema = parser.parse(
        content: '''
class OkHttpClient {
    fun newCall(request: Request): Call { }
}
''',
        packageName: 'com.squareup.okhttp3:okhttp',
        version: '4.12.0',
      );
      expect(schema.package, 'com.squareup.okhttp3:okhttp');
      expect(schema.source, PackageSource.gradle);
    });

    test('timeout defaults to 180 seconds', () {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true),
      );
      expect(parser.timeout, const Duration(seconds: 180));
    });

    test('parseFilesAsync falls back when toolchain unavailable', () async {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: false),
      );

      final result = await parser.parseFilesAsync(
        files: {
          'Client.kt': '''
class Client {
    fun call(): String {
        return ""
    }
}
''',
        },
        packageName: 'test',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test');
    });
  });
}

ToolchainDetector _mockDetector({
  required bool hasKotlinc,
  String version = '1.9.22',
}) {
  return ToolchainDetector(
    processRunner: (exec, args, {workingDirectory}) async {
      if (exec == 'kotlinc' && args.contains('-version')) {
        return _mockResult(hasKotlinc ? 0 : 127,
            stdout: hasKotlinc ? 'info: kotlinc-jvm $version' : '',
            stderr: hasKotlinc ? 'info: kotlinc-jvm $version' : '');
      }
      return _mockResult(127);
    },
  );
}

ProcessResult _mockResult(int exitCode,
    {String stdout = '', String stderr = ''}) {
  return ProcessResult(0, exitCode, stdout, stderr);
}
