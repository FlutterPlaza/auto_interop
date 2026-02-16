import 'dart:convert';

import 'package:auto_interop_generator/src/installers/npm_installer.dart';
import 'package:test/test.dart';

void main() {
  late NpmInstaller installer;

  setUp(() {
    installer = NpmInstaller();
  });

  group('NpmInstaller', () {
    group('addDependency', () {
      test('adds dependency to empty package.json', () {
        const input = '{"name": "my-app", "version": "1.0.0"}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
          version: '^3.0.0',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['dependencies']['date-fns'], '^3.0.0');
      });

      test('adds dependency alongside existing ones', () {
        const input =
            '{"name": "app", "version": "1.0.0", "dependencies": {"lodash": "^4.0.0"}}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
          version: '^3.0.0',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['dependencies']['lodash'], '^4.0.0');
        expect(json['dependencies']['date-fns'], '^3.0.0');
      });

      test('updates existing dependency version', () {
        const input =
            '{"name": "app", "version": "1.0.0", "dependencies": {"date-fns": "^2.0.0"}}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
          version: '^3.0.0',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['dependencies']['date-fns'], '^3.0.0');
      });

      test('adds devDependency when isDev is true', () {
        const input = '{"name": "app", "version": "1.0.0"}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'jest',
          version: '^29.0.0',
          isDev: true,
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['devDependencies']['jest'], '^29.0.0');
        expect(json.containsKey('dependencies'), false);
      });

      test('preserves other fields', () {
        const input =
            '{"name": "app", "version": "1.0.0", "description": "My app", "scripts": {"test": "jest"}}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
          version: '^3.0.0',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['name'], 'app');
        expect(json['description'], 'My app');
        expect(json['scripts']['test'], 'jest');
      });

      test('does not duplicate when same version exists', () {
        const input =
            '{"name": "app", "version": "1.0.0", "dependencies": {"date-fns": "^3.0.0"}}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
          version: '^3.0.0',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        final deps = json['dependencies'] as Map<String, dynamic>;
        expect(deps.keys.where((k) => k == 'date-fns').length, 1);
      });
    });

    group('removeDependency', () {
      test('removes from dependencies', () {
        const input =
            '{"name": "app", "dependencies": {"date-fns": "^3.0.0", "lodash": "^4.0.0"}}';
        final result = installer.removeDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['dependencies'].containsKey('date-fns'), false);
        expect(json['dependencies']['lodash'], '^4.0.0');
      });

      test('removes from devDependencies', () {
        const input =
            '{"name": "app", "devDependencies": {"jest": "^29.0.0"}}';
        final result = installer.removeDependency(
          packageJsonContent: input,
          packageName: 'jest',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['devDependencies'].containsKey('jest'), false);
      });

      test('returns unchanged if dependency not found', () {
        const input =
            '{"name": "app", "dependencies": {"lodash": "^4.0.0"}}';
        final result = installer.removeDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['dependencies']['lodash'], '^4.0.0');
      });
    });

    group('hasDependency', () {
      test('returns true when in dependencies', () {
        const input =
            '{"name": "app", "dependencies": {"date-fns": "^3.0.0"}}';
        expect(
          installer.hasDependency(
            packageJsonContent: input,
            packageName: 'date-fns',
          ),
          true,
        );
      });

      test('returns true when in devDependencies', () {
        const input =
            '{"name": "app", "devDependencies": {"jest": "^29.0.0"}}';
        expect(
          installer.hasDependency(
            packageJsonContent: input,
            packageName: 'jest',
          ),
          true,
        );
      });

      test('returns false when not present', () {
        const input =
            '{"name": "app", "dependencies": {"lodash": "^4.0.0"}}';
        expect(
          installer.hasDependency(
            packageJsonContent: input,
            packageName: 'date-fns',
          ),
          false,
        );
      });

      test('returns false when no dependencies section', () {
        const input = '{"name": "app", "version": "1.0.0"}';
        expect(
          installer.hasDependency(
            packageJsonContent: input,
            packageName: 'date-fns',
          ),
          false,
        );
      });
    });

    group('getDependencyVersion', () {
      test('returns version from dependencies', () {
        const input =
            '{"name": "app", "dependencies": {"date-fns": "^3.0.0"}}';
        expect(
          installer.getDependencyVersion(
            packageJsonContent: input,
            packageName: 'date-fns',
          ),
          '^3.0.0',
        );
      });

      test('returns version from devDependencies', () {
        const input =
            '{"name": "app", "devDependencies": {"jest": "^29.0.0"}}';
        expect(
          installer.getDependencyVersion(
            packageJsonContent: input,
            packageName: 'jest',
          ),
          '^29.0.0',
        );
      });

      test('returns null when not present', () {
        const input = '{"name": "app"}';
        expect(
          installer.getDependencyVersion(
            packageJsonContent: input,
            packageName: 'date-fns',
          ),
          null,
        );
      });
    });

    group('createPackageJson', () {
      test('creates minimal package.json', () {
        final result = installer.createPackageJson(name: 'my-app');
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['name'], 'my-app');
        expect(json['version'], '1.0.0');
        expect(json['private'], true);
      });

      test('creates package.json with dependencies', () {
        final result = installer.createPackageJson(
          name: 'my-app',
          dependencies: {'date-fns': '^3.0.0', 'lodash': '^4.0.0'},
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['dependencies']['date-fns'], '^3.0.0');
        expect(json['dependencies']['lodash'], '^4.0.0');
      });

      test('creates package.json with devDependencies', () {
        final result = installer.createPackageJson(
          name: 'my-app',
          devDependencies: {'jest': '^29.0.0'},
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['devDependencies']['jest'], '^29.0.0');
      });

      test('omits empty dependency sections', () {
        final result = installer.createPackageJson(name: 'my-app');
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json.containsKey('dependencies'), false);
        expect(json.containsKey('devDependencies'), false);
      });

      test('uses custom version', () {
        final result = installer.createPackageJson(
          name: 'my-app',
          version: '2.0.0',
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['version'], '2.0.0');
      });
    });

    group('addDependencies (batch)', () {
      test('adds multiple dependencies at once', () {
        const input = '{"name": "app", "version": "1.0.0"}';
        final result = installer.addDependencies(
          packageJsonContent: input,
          packages: {
            'date-fns': '^3.0.0',
            'lodash': '^4.0.0',
            'uuid': '^9.0.0',
          },
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['dependencies']['date-fns'], '^3.0.0');
        expect(json['dependencies']['lodash'], '^4.0.0');
        expect(json['dependencies']['uuid'], '^9.0.0');
      });

      test('adds multiple devDependencies', () {
        const input = '{"name": "app", "version": "1.0.0"}';
        final result = installer.addDependencies(
          packageJsonContent: input,
          packages: {'jest': '^29.0.0', 'eslint': '^8.0.0'},
          isDev: true,
        );
        final json = jsonDecode(result) as Map<String, dynamic>;
        expect(json['devDependencies']['jest'], '^29.0.0');
        expect(json['devDependencies']['eslint'], '^8.0.0');
      });
    });

    group('error handling', () {
      test('throws on invalid JSON', () {
        expect(
          () => installer.addDependency(
            packageJsonContent: 'not json',
            packageName: 'date-fns',
            version: '^3.0.0',
          ),
          throwsA(isA<NpmInstallerException>()),
        );
      });

      test('throws on empty input', () {
        expect(
          () => installer.addDependency(
            packageJsonContent: '',
            packageName: 'date-fns',
            version: '^3.0.0',
          ),
          throwsA(isA<NpmInstallerException>()),
        );
      });
    });

    group('output format', () {
      test('produces pretty-printed JSON with 2-space indent', () {
        const input = '{"name": "app", "version": "1.0.0"}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'date-fns',
          version: '^3.0.0',
        );
        expect(result, contains('  "dependencies"'));
        expect(result, contains('    "date-fns"'));
      });

      test('ends with newline', () {
        const input = '{"name": "app"}';
        final result = installer.addDependency(
          packageJsonContent: input,
          packageName: 'x',
          version: '1.0.0',
        );
        expect(result.endsWith('\n'), true);
      });
    });
  });
}
