import 'package:auto_interop_generator/src/config/config_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart'
    show PackageSource;
import 'package:test/test.dart';

void main() {
  late ConfigParser parser;

  setUp(() {
    parser = ConfigParser();
  });

  group('ConfigParser', () {
    group('valid configs', () {
      test('parses valid auto_interop.yaml with all sources', () {
        final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
    imports:
      - "format"
      - "addDays"
  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"
    imports:
      - "AF.request"
  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
    imports:
      - "OkHttpClient"
  - source: spm
    package: "Vapor"
    version: "4.0.0"
''');

        expect(config.packages, hasLength(4));
      });

      test('parses npm package correctly', () {
        final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
    imports:
      - "format"
      - "addDays"
      - "differenceInDays"
''');

        final pkg = config.packages[0];
        expect(pkg.source, PackageSource.npm);
        expect(pkg.package, 'date-fns');
        expect(pkg.version, '^3.0.0');
        expect(pkg.imports, ['format', 'addDays', 'differenceInDays']);
        expect(pkg.isSelectiveImport, true);
      });

      test('parses cocoapods package correctly', () {
        final config = parser.parseYaml('''
native_packages:
  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"
    imports:
      - "AF.request"
      - "AF.download"
''');

        final pkg = config.packages[0];
        expect(pkg.source, PackageSource.cocoapods);
        expect(pkg.package, 'Alamofire');
        expect(pkg.version, '~> 5.9');
      });

      test('parses gradle package correctly', () {
        final config = parser.parseYaml('''
native_packages:
  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
    imports:
      - "OkHttpClient"
      - "Request"
      - "Response"
''');

        final pkg = config.packages[0];
        expect(pkg.source, PackageSource.gradle);
        expect(pkg.package, 'com.squareup.okhttp3:okhttp');
        expect(pkg.version, '4.12.0');
      });

      test('handles wildcard imports (no imports field)', () {
        final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "lodash"
    version: "^4.0.0"
''');

        final pkg = config.packages[0];
        expect(pkg.imports, isEmpty);
        expect(pkg.isSelectiveImport, false);
      });

      test('supports numeric version constraints', () {
        final config = parser.parseYaml('''
native_packages:
  - source: gradle
    package: "com.google.code.gson:gson"
    version: "2.10"
''');

        final pkg = config.packages[0];
        expect(pkg.version, '2.10');
      });
    });

    group('validation errors', () {
      test('rejects non-map root', () {
        expect(
          () => parser.parseYaml('just a string'),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains('must be a YAML map'),
          )),
        );
      });

      test('rejects missing native_packages', () {
        expect(
          () => parser.parseYaml('something_else: true'),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains("Missing required field 'native_packages'"),
          )),
        );
      });

      test('rejects native_packages as non-list', () {
        expect(
          () => parser.parseYaml('native_packages: "not a list"'),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains("must be a list"),
          )),
        );
      });

      test('rejects missing source field', () {
        expect(
          () => parser.parseYaml('''
native_packages:
  - package: "date-fns"
    version: "^3.0.0"
'''),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains("Missing required field 'source'"),
          )),
        );
      });

      test('rejects unsupported source type', () {
        expect(
          () => parser.parseYaml('''
native_packages:
  - source: cargo
    package: "serde"
    version: "1.0.0"
'''),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains("Unsupported source 'cargo'"),
          )),
        );
      });

      test('rejects missing package field', () {
        expect(
          () => parser.parseYaml('''
native_packages:
  - source: npm
    version: "^3.0.0"
'''),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains("Missing required field 'package'"),
          )),
        );
      });

      test('rejects missing version field', () {
        expect(
          () => parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
'''),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains("Missing required field 'version'"),
          )),
        );
      });

      test('rejects imports as non-list', () {
        expect(
          () => parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
    imports: "format"
'''),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains("'imports' must be a list"),
          )),
        );
      });

      test('rejects non-string import entries', () {
        expect(
          () => parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
    imports:
      - 123
'''),
          throwsA(isA<ConfigParseException>().having(
            (e) => e.message,
            'message',
            contains('All imports must be strings'),
          )),
        );
      });
    });
  });

  group('source_path', () {
    test('parses source_path when present', () {
      final config = parser.parseYaml('''
native_packages:
  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"
    source_path: "ios/Pods/Alamofire/Source"
''');
      expect(config.packages[0].sourcePath, 'ios/Pods/Alamofire/Source');
    });

    test('source_path is null when not specified', () {
      final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
''');
      expect(config.packages[0].sourcePath, isNull);
    });
  });

  group('custom_types', () {
    test('parses custom_types when present', () {
      final config = parser.parseYaml('''
native_packages:
  - source: cocoapods
    package: "Alamofire"
    version: "~> 5.9"
    custom_types:
      URLRequest: "lib/types/networking.dart"
      HTTPHeaders: "lib/types/networking.dart"
''');
      expect(config.packages[0].customTypes, {
        'URLRequest': 'lib/types/networking.dart',
        'HTTPHeaders': 'lib/types/networking.dart',
      });
    });

    test('custom_types defaults to empty map', () {
      final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
''');
      expect(config.packages[0].customTypes, isEmpty);
    });

    test('rejects custom_types as non-map', () {
      expect(
        () => parser.parseYaml('''
native_packages:
  - source: npm
    package: "test"
    version: "1.0.0"
    custom_types: "not a map"
'''),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains("'custom_types' must be a map"),
        )),
      );
    });
  });

  group('maven_repositories', () {
    test('parses maven_repositories when present', () {
      final config = parser.parseYaml('''
native_packages:
  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
    maven_repositories:
      - "https://repo1.maven.org/maven2"
      - "https://jitpack.io"
''');
      expect(config.packages[0].mavenRepositories, [
        'https://repo1.maven.org/maven2',
        'https://jitpack.io',
      ]);
    });

    test('defaults to standard repos when not specified', () {
      final config = parser.parseYaml('''
native_packages:
  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
''');
      expect(config.packages[0].mavenRepositories, [
        'https://repo1.maven.org/maven2',
        'https://dl.google.com/dl/android/maven2',
      ]);
    });

    test('rejects maven_repositories as non-list', () {
      expect(
        () => parser.parseYaml('''
native_packages:
  - source: gradle
    package: "com.squareup.okhttp3:okhttp"
    version: "4.12.0"
    maven_repositories: "not a list"
'''),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains("'maven_repositories' must be a list"),
        )),
      );
    });
  });

  group('overrides_dir', () {
    test('parses overrides_dir when present', () {
      final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
overrides_dir: my_overrides
''');
      expect(config.overridesDir, 'my_overrides');
    });

    test('overrides_dir is null when not specified', () {
      final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
''');
      expect(config.overridesDir, isNull);
    });

    test('rejects overrides_dir as non-string', () {
      expect(
        () => parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
overrides_dir: 123
'''),
        throwsA(isA<ConfigParseException>().having(
          (e) => e.message,
          'message',
          contains("'overrides_dir' must be a string"),
        )),
      );
    });
  });

  group('PackageSpec', () {
    test('isSelectiveImport is true when imports are specified', () {
      final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
    imports:
      - "format"
''');
      expect(config.packages[0].isSelectiveImport, true);
    });

    test('isSelectiveImport is false when no imports', () {
      final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
''');
      expect(config.packages[0].isSelectiveImport, false);
    });

    test('toString contains useful info', () {
      final config = parser.parseYaml('''
native_packages:
  - source: npm
    package: "date-fns"
    version: "^3.0.0"
''');
      final str = config.packages[0].toString();
      expect(str, contains('npm'));
      expect(str, contains('date-fns'));
    });
  });
}
