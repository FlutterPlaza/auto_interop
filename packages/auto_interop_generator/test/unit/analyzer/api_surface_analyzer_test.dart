import 'package:auto_interop_generator/src/analyzer/api_surface_analyzer.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  const analyzer = ApiSurfaceAnalyzer();

  group('ApiSurfaceAnalyzer', () {
    group('empty surface', () {
      test('warns on empty API surface', () {
        final schema = UnifiedTypeSchema(
          package: 'empty-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
        );
        final result = analyzer.analyze(schema);
        expect(result.warnings, hasLength(1));
        expect(result.warnings.first.message, contains('Empty API surface'));
      });
    });

    group('missing type references', () {
      test('warns on unresolved object type reference', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'doSomething',
              returnType: UtsType.object('UnknownType'),
            ),
          ],
        );
        final result = analyzer.analyze(schema);
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any(
          (d) => d.message.contains('Unresolved type reference "UnknownType"'),
        ), isTrue);
      });

      test('does not warn on defined types', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(name: 'MyOptions'),
          ],
          functions: [
            UtsMethod(
              name: 'configure',
              returnType: UtsType.object('MyOptions'),
            ),
          ],
        );
        final result = analyzer.analyze(schema);
        final unresolvedWarnings = result.warnings.where(
          (d) => d.message.contains('Unresolved type reference'),
        );
        expect(unresolvedWarnings, isEmpty);
      });

      test('does not warn on primitive types', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'greet',
              returnType: UtsType.primitive('String'),
            ),
          ],
        );
        final result = analyzer.analyze(schema);
        final unresolvedWarnings = result.warnings.where(
          (d) => d.message.contains('Unresolved type reference'),
        );
        expect(unresolvedWarnings, isEmpty);
      });
    });

    group('circular dependencies', () {
      test('detects circular type references', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'TypeA',
              fields: [
                UtsField(
                  name: 'b',
                  type: UtsType.object('TypeB'),
                ),
              ],
            ),
            UtsClass(
              name: 'TypeB',
              fields: [
                UtsField(
                  name: 'a',
                  type: UtsType.object('TypeA'),
                ),
              ],
            ),
          ],
        );
        final result = analyzer.analyze(schema);
        expect(result.hasErrors, isTrue);
        expect(result.errors.any(
          (d) => d.message.contains('Circular type dependency'),
        ), isTrue);
      });

      test('no circular dependency for non-cycles', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'TypeA',
              fields: [
                UtsField(
                  name: 'b',
                  type: UtsType.object('TypeB'),
                ),
              ],
            ),
            UtsClass(name: 'TypeB'),
          ],
        );
        final result = analyzer.analyze(schema);
        final circularErrors = result.errors.where(
          (d) => d.message.contains('Circular type dependency'),
        );
        expect(circularErrors, isEmpty);
      });
    });

    group('unsupported type combinations', () {
      test('warns on Map with non-primitive key', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(name: 'MyKey'),
          ],
          functions: [
            UtsMethod(
              name: 'getMap',
              returnType: UtsType.map(
                UtsType.object('MyKey'),
                UtsType.primitive('String'),
              ),
            ),
          ],
        );
        final result = analyzer.analyze(schema);
        expect(result.hasErrors, isFalse);
        expect(result.warnings.any(
          (d) => d.message.contains('Map with non-primitive key type'),
        ), isTrue);
      });

      test('allows Map with enum key', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(name: 'Color', values: [
              UtsEnumValue(name: 'red'),
              UtsEnumValue(name: 'blue'),
            ]),
          ],
          functions: [
            UtsMethod(
              name: 'getMap',
              returnType: UtsType.map(
                UtsType.enumType('Color'),
                UtsType.primitive('String'),
              ),
            ),
          ],
        );
        final result = analyzer.analyze(schema);
        final mapErrors = result.errors.where(
          (d) => d.message.contains('Map with non-primitive key type'),
        );
        expect(mapErrors, isEmpty);
      });
    });

    group('naming conflicts', () {
      test('detects duplicate names across classes and types', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [UtsClass(name: 'Foo')],
          types: [UtsClass(name: 'Foo')],
        );
        final result = analyzer.analyze(schema);
        expect(result.hasErrors, isTrue);
        expect(result.errors.any(
          (d) => d.message.contains('Naming conflict'),
        ), isTrue);
      });

      test('warns on Dart reserved word collision', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [UtsClass(name: 'class')],
        );
        final result = analyzer.analyze(schema);
        expect(result.warnings.any(
          (d) => d.message.contains('Dart reserved word'),
        ), isTrue);
      });

      test('no conflict for unique names', () {
        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [UtsClass(name: 'ClassA')],
          types: [UtsClass(name: 'TypeB')],
          enums: [UtsEnum(name: 'EnumC')],
        );
        final result = analyzer.analyze(schema);
        final namingErrors = result.errors.where(
          (d) => d.message.contains('Naming conflict'),
        );
        expect(namingErrors, isEmpty);
      });
    });

    group('clean schema', () {
      test('no diagnostics for well-formed schema', () {
        final schema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '3.6.0',
          functions: [
            UtsMethod(
              name: 'format',
              parameters: [
                UtsParameter(
                  name: 'date',
                  type: UtsType.primitive('DateTime'),
                ),
                UtsParameter(
                  name: 'formatStr',
                  type: UtsType.primitive('String'),
                ),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        );
        final result = analyzer.analyze(schema);
        expect(result.diagnostics, isEmpty);
      });
    });
  });
}
