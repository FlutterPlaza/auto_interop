import 'package:auto_interop_generator/src/installers/spm_installer.dart';
import 'package:test/test.dart';

void main() {
  late SpmInstaller installer;

  setUp(() {
    installer = SpmInstaller();
  });

  group('SpmInstaller', () {
    group('addDependency', () {
      test('adds dependency to empty dependencies array', () {
        final content = '''
let package = Package(
    name: "MyApp",
    dependencies: [
    ],
    targets: []
)
''';
        final result = installer.addDependency(
          packageSwiftContent: content,
          packageUrl: 'https://github.com/Alamofire/Alamofire',
          version: '5.9.0',
        );
        expect(result, contains('.package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.0")'));
      });

      test('adds dependency to existing dependencies', () {
        final content = '''
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/SDWebImage/SDWebImage", from: "5.0.0")
    ],
    targets: []
)
''';
        final result = installer.addDependency(
          packageSwiftContent: content,
          packageUrl: 'https://github.com/Alamofire/Alamofire',
          version: '5.9.0',
        );
        expect(result, contains('Alamofire'));
        expect(result, contains('SDWebImage'));
      });

      test('updates existing dependency version', () {
        final content = '''
let package = Package(
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0")
    ]
)
''';
        final result = installer.addDependency(
          packageSwiftContent: content,
          packageUrl: 'https://github.com/Alamofire/Alamofire',
          version: '5.9.0',
        );
        expect(result, contains('from: "5.9.0"'));
        expect(result, isNot(contains('from: "5.0.0"')));
      });

      test('does not duplicate dependency', () {
        final content = '''
let package = Package(
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.0.0")
    ]
)
''';
        final result = installer.addDependency(
          packageSwiftContent: content,
          packageUrl: 'https://github.com/Alamofire/Alamofire',
          version: '5.9.0',
        );
        final count =
            RegExp('Alamofire/Alamofire').allMatches(result).length;
        expect(count, 1);
      });
    });

    group('removeDependency', () {
      test('removes dependency', () {
        final content = '''
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImage", from: "5.0.0")
    ]
''';
        final result = installer.removeDependency(
          packageSwiftContent: content,
          packageUrl: 'https://github.com/Alamofire/Alamofire',
        );
        expect(result, isNot(contains('Alamofire')));
        expect(result, contains('SDWebImage'));
      });
    });

    group('hasDependency', () {
      test('returns true for existing dependency', () {
        final content =
            '.package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.0")';
        expect(
          installer.hasDependency(
            packageSwiftContent: content,
            packageUrl: 'https://github.com/Alamofire/Alamofire',
          ),
          true,
        );
      });

      test('returns false for missing dependency', () {
        expect(
          installer.hasDependency(
            packageSwiftContent: '',
            packageUrl: 'https://github.com/Alamofire/Alamofire',
          ),
          false,
        );
      });
    });

    group('getDependencyVersion', () {
      test('returns from version', () {
        final content =
            '.package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.0")';
        expect(
          installer.getDependencyVersion(
            packageSwiftContent: content,
            packageUrl: 'https://github.com/Alamofire/Alamofire',
          ),
          '5.9.0',
        );
      });

      test('returns null for missing dependency', () {
        expect(
          installer.getDependencyVersion(
            packageSwiftContent: '',
            packageUrl: 'https://github.com/Alamofire/Alamofire',
          ),
          null,
        );
      });
    });

    group('addDependencies batch', () {
      test('adds multiple dependencies', () {
        final content = '''
let package = Package(
    dependencies: [
    ]
)
''';
        final result = installer.addDependencies(
          packageSwiftContent: content,
          dependencies: [
            SpmDependency(
                url: 'https://github.com/Alamofire/Alamofire',
                version: '5.9.0'),
            SpmDependency(
                url: 'https://github.com/SDWebImage/SDWebImage',
                version: '5.19.0'),
          ],
        );
        expect(result, contains('Alamofire'));
        expect(result, contains('SDWebImage'));
      });
    });
  });
}
