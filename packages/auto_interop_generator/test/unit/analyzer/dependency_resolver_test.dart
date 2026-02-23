import 'package:auto_interop_generator/src/analyzer/dependency_resolver.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  const resolver = DependencyResolver();

  group('DependencyResolver', () {
    test('resolves independent packages with no dependencies', () {
      final schemas = [
        UnifiedTypeSchema(
          package: 'pkg-a',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'greet',
              returnType: UtsType.primitive('String'),
            ),
          ],
        ),
        UnifiedTypeSchema(
          package: 'pkg-b',
          source: PackageSource.gradle,
          version: '2.0.0',
          functions: [
            UtsMethod(
              name: 'compute',
              returnType: UtsType.primitive('int'),
            ),
          ],
        ),
      ];
      final result = resolver.resolve(schemas);
      expect(result.dependencies, isEmpty);
      expect(result.buildOrder, hasLength(2));
      expect(result.hasConflicts, isFalse);
      expect(result.hasUnresolved, isFalse);
    });

    test('detects cross-package type references', () {
      final schemas = [
        UnifiedTypeSchema(
          package: 'models',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [UtsClass(name: 'UserModel')],
        ),
        UnifiedTypeSchema(
          package: 'api',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getUser',
              returnType: UtsType.object('UserModel'),
            ),
          ],
        ),
      ];
      final result = resolver.resolve(schemas);
      expect(result.dependencies['api'], contains('models'));
    });

    test('topological sort puts dependencies first', () {
      final schemas = [
        UnifiedTypeSchema(
          package: 'models',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [UtsClass(name: 'BaseModel')],
        ),
        UnifiedTypeSchema(
          package: 'api',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getModel',
              returnType: UtsType.object('BaseModel'),
            ),
          ],
        ),
      ];
      final result = resolver.resolve(schemas);
      final modelsIndex = result.buildOrder.indexOf('models');
      final apiIndex = result.buildOrder.indexOf('api');
      expect(modelsIndex, lessThan(apiIndex));
    });

    test('detects version conflicts', () {
      final schemas = [
        UnifiedTypeSchema(
          package: 'shared',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(name: 'fn', returnType: UtsType.voidType()),
          ],
        ),
        UnifiedTypeSchema(
          package: 'shared',
          source: PackageSource.npm,
          version: '2.0.0',
          functions: [
            UtsMethod(name: 'fn', returnType: UtsType.voidType()),
          ],
        ),
      ];
      final result = resolver.resolve(schemas);
      expect(result.hasConflicts, isTrue);
      expect(result.conflicts.first.package, 'shared');
      expect(result.conflicts.first.versions, containsAll(['1.0.0', '2.0.0']));
    });

    test('reports unresolved type references', () {
      final schemas = [
        UnifiedTypeSchema(
          package: 'api',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getExternal',
              returnType: UtsType.object('ExternalType'),
            ),
          ],
        ),
      ];
      final result = resolver.resolve(schemas);
      expect(result.hasUnresolved, isTrue);
      expect(
        result.unresolvedReferences.any((r) => r.typeName == 'ExternalType'),
        isTrue,
      );
    });

    test('does not report builtin types as unresolved', () {
      final schemas = [
        UnifiedTypeSchema(
          package: 'api',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getData',
              returnType: UtsType.list(UtsType.primitive('String')),
            ),
          ],
        ),
      ];
      final result = resolver.resolve(schemas);
      expect(result.hasUnresolved, isFalse);
    });
  });
}
