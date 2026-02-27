import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_gradle_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

/// Tests that the AstGradleParser correctly handles Kotlin extension functions
/// when the AST helper subprocess returns them.
void main() {
  group('Kotlin extension functions via AST', () {
    test('extension methods folded into matching class', () async {
      // Simulate AST helper output where extension methods on StringUtils
      // are folded into the class
      final schema = UnifiedTypeSchema(
        package: 'com.example:extensions',
        source: PackageSource.gradle,
        version: '1.0.0',
        classes: [
          UtsClass(
            name: 'StringUtils',
            kind: UtsClassKind.concreteClass,
            methods: [
              UtsMethod(
                name: 'isEmpty',
                isStatic: false,
                parameters: [
                  UtsParameter(
                    name: 'value',
                    type: UtsType.primitive('String'),
                  ),
                ],
                returnType: UtsType.primitive('bool'),
              ),
              // Extension method folded into the class
              UtsMethod(
                name: 'reverse',
                isStatic: false,
                parameters: [
                  UtsParameter(
                    name: 'input',
                    type: UtsType.primitive('String'),
                  ),
                ],
                returnType: UtsType.primitive('String'),
              ),
            ],
          ),
        ],
        functions: [
          // Extensions on types without matching class → top-level functions
          UtsMethod(
            name: 'trimWhitespace',
            isStatic: true,
            parameters: [
              UtsParameter(
                name: 'self',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.primitive('String'),
          ),
          UtsMethod(
            name: 'isEven',
            isStatic: true,
            parameters: [
              UtsParameter(
                name: 'self',
                type: UtsType.primitive('int'),
              ),
            ],
            returnType: UtsType.primitive('bool'),
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
        files: {'Client.kt': '// placeholder'},
        packageName: 'com.example:extensions',
        version: '1.0.0',
      );

      expect(result.schema.package, 'com.example:extensions');

      // StringUtils should have both isEmpty and the folded reverse extension
      final stringUtils =
          result.schema.classes.firstWhere((c) => c.name == 'StringUtils');
      expect(stringUtils.methods.length, 2);
      expect(stringUtils.methods.map((m) => m.name),
          containsAll(['isEmpty', 'reverse']));

      // Extensions on primitive types become top-level functions
      expect(result.schema.functions.length, 2);
      expect(result.schema.functions.map((f) => f.name),
          containsAll(['trimWhitespace', 'isEven']));

      // Top-level extension functions should have 'self' as first param
      final trimFn =
          result.schema.functions.firstWhere((f) => f.name == 'trimWhitespace');
      expect(trimFn.parameters.first.name, 'self');
      expect(trimFn.parameters.first.type.name, 'String');
    });

    test('extensions without matching class become top-level functions',
        () async {
      final schema = UnifiedTypeSchema(
        package: 'com.example:ext',
        source: PackageSource.gradle,
        version: '1.0.0',
        functions: [
          UtsMethod(
            name: 'isEven',
            isStatic: true,
            parameters: [
              UtsParameter(
                name: 'self',
                type: UtsType.primitive('int'),
              ),
            ],
            returnType: UtsType.primitive('bool'),
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
        files: {'ext.kt': '// placeholder'},
        packageName: 'com.example:ext',
        version: '1.0.0',
      );

      expect(result.schema.functions, hasLength(1));
      expect(result.schema.functions.first.name, 'isEven');
      expect(result.schema.functions.first.isStatic, isTrue);
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
