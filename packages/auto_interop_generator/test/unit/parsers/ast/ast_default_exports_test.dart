import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/parsers/ast/ast_npm_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

/// Tests that the AstNpmParser correctly handles TypeScript default exports
/// when the AST helper subprocess returns them.
void main() {
  group('TypeScript default exports via AST', () {
    test('export default interface is extracted as dataClass', () async {
      final schema = UnifiedTypeSchema(
        package: 'test-defaults',
        source: PackageSource.npm,
        version: '1.0.0',
        types: [
          UtsClass(
            name: 'Config',
            kind: UtsClassKind.dataClass,
            fields: [
              UtsField(
                name: 'host',
                type: UtsType.primitive('String'),
              ),
              UtsField(
                name: 'port',
                type: UtsType.primitive('double'),
              ),
              UtsField(
                name: 'debug',
                type: UtsType.primitive('bool', nullable: true),
                nullable: true,
              ),
            ],
          ),
          UtsClass(
            name: 'Options',
            kind: UtsClassKind.dataClass,
            fields: [
              UtsField(
                name: 'timeout',
                type: UtsType.primitive('double'),
              ),
              UtsField(
                name: 'retries',
                type: UtsType.primitive('double'),
              ),
            ],
          ),
        ],
        classes: [
          UtsClass(
            name: 'Logger',
            kind: UtsClassKind.abstractClass,
            methods: [
              UtsMethod(
                name: 'log',
                isStatic: false,
                parameters: [
                  UtsParameter(
                    name: 'message',
                    type: UtsType.primitive('String'),
                  ),
                ],
                returnType: UtsType.voidType(),
              ),
              UtsMethod(
                name: 'error',
                isStatic: false,
                parameters: [
                  UtsParameter(
                    name: 'message',
                    type: UtsType.primitive('String'),
                  ),
                  UtsParameter(
                    name: 'code',
                    type: UtsType.primitive('double'),
                  ),
                ],
                returnType: UtsType.voidType(),
              ),
            ],
          ),
        ],
        enums: [
          UtsEnum(
            name: 'Status',
            values: [
              UtsEnumValue(name: 'Active', rawValue: 'active'),
              UtsEnumValue(name: 'Inactive', rawValue: 'inactive'),
              UtsEnumValue(name: 'Pending', rawValue: 'pending'),
            ],
          ),
        ],
      );

      final jsonOutput = jsonEncode(schema.toJson());

      final parser = AstNpmParser(
        toolchainDetector: _mockDetector(hasNode: true),
        processRunner: (exec, args, {workingDirectory}) async {
          return _mockResult(0, stdout: jsonOutput);
        },
      );

      final result = await parser.parseFilesAsync(
        files: {'index.d.ts': '// placeholder'},
        packageName: 'test-defaults',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test-defaults');

      // Default exported interface Config → dataClass
      expect(result.schema.types.length, 2);
      final config = result.schema.types.firstWhere((t) => t.name == 'Config');
      expect(config.kind, UtsClassKind.dataClass);
      expect(config.fields.length, 3);

      // Default exported type alias Options → dataClass
      final options =
          result.schema.types.firstWhere((t) => t.name == 'Options');
      expect(options.kind, UtsClassKind.dataClass);
      expect(options.fields.length, 2);

      // Declare-exported interface Logger → abstractClass
      final logger =
          result.schema.classes.firstWhere((c) => c.name == 'Logger');
      expect(logger.kind, UtsClassKind.abstractClass);
      expect(logger.methods.length, 2);

      // Default exported enum Status
      expect(result.schema.enums.length, 1);
      expect(result.schema.enums.first.name, 'Status');
      expect(result.schema.enums.first.values.length, 3);
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
