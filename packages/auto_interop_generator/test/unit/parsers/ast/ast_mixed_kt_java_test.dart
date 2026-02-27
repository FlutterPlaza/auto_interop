import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_gradle_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

/// Tests that AstGradleParser correctly splits mixed .kt and .java files,
/// routing Kotlin to the AST subprocess and Java to the regex fallback,
/// then merging results.
void main() {
  group('Mixed Kotlin/Java file handling', () {
    test('routes .kt to AST and .java to regex, merges results', () async {
      // AST subprocess output for Kotlin files only
      final ktSchema = UnifiedTypeSchema(
        package: 'com.example:mixed',
        source: PackageSource.gradle,
        version: '1.0.0',
        classes: [
          UtsClass(
            name: 'KotlinClient',
            kind: UtsClassKind.concreteClass,
            methods: [
              UtsMethod(
                name: 'connect',
                isStatic: false,
                parameters: [
                  UtsParameter(
                    name: 'host',
                    type: UtsType.primitive('String'),
                  ),
                  UtsParameter(
                    name: 'port',
                    type: UtsType.primitive('int'),
                  ),
                ],
                returnType: UtsType.primitive('bool'),
              ),
              UtsMethod(
                name: 'disconnect',
                isStatic: false,
                returnType: UtsType.voidType(),
              ),
            ],
          ),
        ],
      );

      final ktJson = jsonEncode(ktSchema.toJson());

      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true),
        processRunner: (exec, args, {workingDirectory}) async {
          // The AST subprocess should only receive .kt files
          if (exec == 'kotlinc') {
            final fileArgs = args
                .where((a) => a.endsWith('.kt') || a.endsWith('.java'))
                .toList();
            expect(fileArgs.every((f) => f.endsWith('.kt')), isTrue,
                reason: 'Java files should not be sent to kotlinc');
            expect(fileArgs, isNot(contains(endsWith('.java'))));
            return _mockResult(0, stdout: ktJson);
          }
          return _mockResult(127);
        },
      );

      final result = await parser.parseFilesAsync(
        files: {
          'Client.kt': '''
class KotlinClient {
    fun connect(host: String, port: Int): Boolean { return true }
    fun disconnect(): Unit {}
}
''',
          'Helper.java': '''
public class JavaHelper {
    public String format(String input) { return input; }
    public int compute(int value) { return value; }
}
''',
        },
        packageName: 'com.example:mixed',
        version: '1.0.0',
      );

      expect(result.schema.package, 'com.example:mixed');

      // KotlinClient from AST
      final ktClient =
          result.schema.classes.where((c) => c.name == 'KotlinClient').toList();
      expect(ktClient, hasLength(1));
      expect(ktClient.first.methods.length, 2);

      // JavaHelper from regex fallback
      final javaHelper =
          result.schema.classes.where((c) => c.name == 'JavaHelper').toList();
      expect(javaHelper, hasLength(1));
      expect(javaHelper.first.methods.length, greaterThanOrEqualTo(1));
    });

    test('only .kt files delegates entirely to AST', () async {
      final schema = UnifiedTypeSchema(
        package: 'test',
        source: PackageSource.gradle,
        version: '1.0.0',
        classes: [
          UtsClass(
            name: 'MyClass',
            kind: UtsClassKind.concreteClass,
            methods: [
              UtsMethod(
                name: 'doWork',
                isStatic: false,
                returnType: UtsType.voidType(),
              ),
            ],
          ),
        ],
      );

      final jsonOutput = jsonEncode(schema.toJson());

      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true),
        processRunner: (exec, args, {workingDirectory}) async {
          return _mockResult(0, stdout: jsonOutput);
        },
      );

      final result = await parser.parseFilesAsync(
        files: {'MyClass.kt': 'class MyClass { fun doWork() {} }'},
        packageName: 'test',
        version: '1.0.0',
      );

      expect(result.schema.classes, hasLength(1));
      expect(result.schema.classes.first.name, 'MyClass');
    });

    test('only .java files delegates entirely to regex', () async {
      final parser = AstGradleParser(
        toolchainDetector: _mockDetector(hasKotlinc: true),
      );

      final result = await parser.parseFilesAsync(
        files: {
          'Helper.java': '''
public class Helper {
    public String help(String input) { return input; }
}
''',
        },
        packageName: 'test',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test');
      // Regex parser should find the Helper class
      expect(result.schema.classes.length, greaterThanOrEqualTo(1));
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
