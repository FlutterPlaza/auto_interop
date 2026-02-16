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
