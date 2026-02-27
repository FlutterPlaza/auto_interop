import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_swift_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

/// Tests that the Swift AST helper propagates `throws` as `isAsync: true`
/// so the Dart generator can wrap throwing calls appropriately.
void main() {
  group('Swift throws propagation via AST', () {
    test('throwing functions are marked isAsync with Future return', () async {
      // Simulate AST helper output where throws → isAsync + Future-wrapped
      final schema = UnifiedTypeSchema(
        package: 'NetworkLib',
        source: PackageSource.cocoapods,
        version: '1.0.0',
        classes: [
          UtsClass(
            name: 'NetworkService',
            kind: UtsClassKind.concreteClass,
            methods: [
              // throws → isAsync: true, returnType wrapped in Future
              UtsMethod(
                name: 'fetchData',
                isStatic: false,
                isAsync: true,
                parameters: [
                  UtsParameter(
                    name: 'url',
                    type: UtsType.primitive('String'),
                  ),
                ],
                returnType: UtsType.future(UtsType.primitive('String')),
              ),
              // async throws → isAsync: true
              UtsMethod(
                name: 'uploadData',
                isStatic: false,
                isAsync: true,
                parameters: [
                  UtsParameter(
                    name: 'data',
                    type: UtsType.primitive('Uint8List'),
                  ),
                  UtsParameter(
                    name: 'url',
                    type: UtsType.primitive('String'),
                  ),
                ],
                returnType: UtsType.future(UtsType.primitive('bool')),
              ),
              // Non-throwing, non-async → isAsync: false
              UtsMethod(
                name: 'syncMethod',
                isStatic: false,
                isAsync: false,
                parameters: [
                  UtsParameter(
                    name: 'value',
                    type: UtsType.primitive('int'),
                  ),
                ],
                returnType: UtsType.primitive('int'),
              ),
            ],
          ),
        ],
        functions: [
          // Top-level throwing function
          UtsMethod(
            name: 'riskyOperation',
            isStatic: true,
            isAsync: true,
            parameters: [
              UtsParameter(
                name: 'input',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.future(UtsType.primitive('String')),
          ),
          // Non-throwing top-level function
          UtsMethod(
            name: 'safeOperation',
            isStatic: true,
            isAsync: false,
            parameters: [
              UtsParameter(
                name: 'input',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.primitive('String'),
          ),
          // async throws top-level function
          UtsMethod(
            name: 'asyncAndThrowing',
            isStatic: true,
            isAsync: true,
            parameters: [
              UtsParameter(
                name: 'data',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.future(UtsType.primitive('bool')),
          ),
        ],
      );

      final jsonOutput = jsonEncode(schema.toJson());

      final parser = AstSwiftParser(
        toolchainDetector: _mockDetector(hasSwift: true),
        processRunner: (exec, args, {workingDirectory}) async {
          return _mockResult(0, stdout: jsonOutput);
        },
      );

      final result = await parser.parseFilesAsync(
        files: {'NetworkService.swift': '// placeholder'},
        packageName: 'NetworkLib',
        version: '1.0.0',
      );

      expect(result.schema.package, 'NetworkLib');

      // NetworkService class
      final service =
          result.schema.classes.firstWhere((c) => c.name == 'NetworkService');

      // fetchData: throws → isAsync: true, Future return
      final fetchData =
          service.methods.firstWhere((m) => m.name == 'fetchData');
      expect(fetchData.isAsync, isTrue);
      expect(fetchData.returnType.kind, UtsTypeKind.future);

      // uploadData: async throws → isAsync: true, Future return
      final uploadData =
          service.methods.firstWhere((m) => m.name == 'uploadData');
      expect(uploadData.isAsync, isTrue);
      expect(uploadData.returnType.kind, UtsTypeKind.future);

      // syncMethod: not throwing → isAsync: false
      final syncMethod =
          service.methods.firstWhere((m) => m.name == 'syncMethod');
      expect(syncMethod.isAsync, isFalse);
      expect(syncMethod.returnType.kind, isNot(UtsTypeKind.future));

      // Top-level throwing function
      final risky =
          result.schema.functions.firstWhere((f) => f.name == 'riskyOperation');
      expect(risky.isAsync, isTrue);
      expect(risky.returnType.kind, UtsTypeKind.future);

      // Top-level safe function
      final safe =
          result.schema.functions.firstWhere((f) => f.name == 'safeOperation');
      expect(safe.isAsync, isFalse);

      // Top-level async+throws function
      final asyncThrows = result.schema.functions
          .firstWhere((f) => f.name == 'asyncAndThrowing');
      expect(asyncThrows.isAsync, isTrue);
      expect(asyncThrows.returnType.kind, UtsTypeKind.future);
    });
  });
}

ToolchainDetector _mockDetector({
  required bool hasSwift,
}) {
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
