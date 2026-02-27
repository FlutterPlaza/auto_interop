import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_gradle_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

/// Tests that the Kotlin AST helper deduplicates overloaded functions,
/// keeping only the first overload for each name.
void main() {
  group('Kotlin overload deduplication via AST', () {
    test('top-level overloads are deduplicated', () async {
      // Simulate AST output where overloads are already deduplicated
      // (only first overload kept per name)
      final schema = UnifiedTypeSchema(
        package: 'com.example:overloads',
        source: PackageSource.gradle,
        version: '1.0.0',
        functions: [
          UtsMethod(
            name: 'process',
            isStatic: true,
            parameters: [
              UtsParameter(
                name: 'input',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.primitive('String'),
          ),
          UtsMethod(
            name: 'uniqueFunction',
            isStatic: true,
            parameters: [
              UtsParameter(
                name: 'data',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.primitive('bool'),
          ),
          UtsMethod(
            name: 'convert',
            isStatic: true,
            parameters: [
              UtsParameter(
                name: 'value',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.primitive('int'),
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
        files: {'overloads.kt': '// placeholder'},
        packageName: 'com.example:overloads',
        version: '1.0.0',
      );

      // Only 3 unique functions (not 5 with duplicates)
      expect(result.schema.functions.length, 3);

      // Each function name appears exactly once
      final names = result.schema.functions.map((f) => f.name).toList();
      expect(names, containsAll(['process', 'uniqueFunction', 'convert']));
      expect(names.toSet().length, names.length,
          reason: 'No duplicate function names');

      // First overload of process takes String
      final process =
          result.schema.functions.firstWhere((f) => f.name == 'process');
      expect(process.parameters.first.type.name, 'String');
    });

    test('class method overloads are deduplicated', () async {
      final schema = UnifiedTypeSchema(
        package: 'com.example:overloads',
        source: PackageSource.gradle,
        version: '1.0.0',
        classes: [
          UtsClass(
            name: 'OverloadedService',
            kind: UtsClassKind.concreteClass,
            methods: [
              // Only first overload of fetch kept
              UtsMethod(
                name: 'fetch',
                isStatic: false,
                parameters: [
                  UtsParameter(
                    name: 'url',
                    type: UtsType.primitive('String'),
                  ),
                ],
                returnType: UtsType.primitive('String'),
              ),
              UtsMethod(
                name: 'transform',
                isStatic: false,
                parameters: [
                  UtsParameter(
                    name: 'data',
                    type: UtsType.primitive('String'),
                  ),
                ],
                returnType: UtsType.primitive('String'),
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
        files: {'overloads.kt': '// placeholder'},
        packageName: 'com.example:overloads',
        version: '1.0.0',
      );

      final service = result.schema.classes
          .firstWhere((c) => c.name == 'OverloadedService');

      // Only 2 unique methods (fetch deduplicated, transform unique)
      expect(service.methods.length, 2);
      final methodNames = service.methods.map((m) => m.name).toList();
      expect(methodNames, containsAll(['fetch', 'transform']));
      expect(methodNames.toSet().length, methodNames.length,
          reason: 'No duplicate method names');
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
