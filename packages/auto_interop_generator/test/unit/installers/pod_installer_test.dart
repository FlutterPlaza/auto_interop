import 'package:auto_interop_generator/src/installers/pod_installer.dart';
import 'package:test/test.dart';

void main() {
  late PodInstaller installer;

  setUp(() {
    installer = PodInstaller();
  });

  group('PodInstaller', () {
    group('addDependency', () {
      test('adds pod to target block', () {
        final podfile = '''
platform :ios, '13.0'

target 'Runner' do
  use_frameworks!
end
''';
        final result = installer.addDependency(
          podfileContent: podfile,
          podName: 'Alamofire',
          version: '~> 5.9',
        );
        expect(result, contains("pod 'Alamofire', '~> 5.9'"));
      });

      test('adds pod to specific target', () {
        final podfile = '''
target 'App' do
  use_frameworks!
end

target 'Tests' do
end
''';
        final result = installer.addDependency(
          podfileContent: podfile,
          podName: 'Alamofire',
          version: '~> 5.9',
          target: 'App',
        );
        expect(result, contains("pod 'Alamofire', '~> 5.9'"));
        // Pod should be in the App target area
        final lines = result.split('\n');
        final alamofireIdx =
            lines.indexWhere((l) => l.contains('Alamofire'));
        final appIdx =
            lines.indexWhere((l) => l.contains("target 'App'"));
        final testsIdx =
            lines.indexWhere((l) => l.contains("target 'Tests'"));
        expect(alamofireIdx, greaterThan(appIdx));
        expect(alamofireIdx, lessThan(testsIdx));
      });

      test('updates existing pod version', () {
        final podfile = '''
target 'Runner' do
  pod 'Alamofire', '~> 5.0'
end
''';
        final result = installer.addDependency(
          podfileContent: podfile,
          podName: 'Alamofire',
          version: '~> 5.9',
        );
        expect(result, contains("pod 'Alamofire', '~> 5.9'"));
        expect(result, isNot(contains("'~> 5.0'")));
      });

      test('does not duplicate pod', () {
        final podfile = '''
target 'Runner' do
  pod 'Alamofire', '~> 5.0'
end
''';
        final result = installer.addDependency(
          podfileContent: podfile,
          podName: 'Alamofire',
          version: '~> 5.9',
        );
        final count =
            RegExp("pod 'Alamofire'").allMatches(result).length;
        expect(count, 1);
      });

      test('appends when no target block', () {
        final podfile = "platform :ios, '13.0'\n";
        final result = installer.addDependency(
          podfileContent: podfile,
          podName: 'Alamofire',
          version: '~> 5.9',
        );
        expect(result, contains("pod 'Alamofire', '~> 5.9'"));
      });
    });

    group('removeDependency', () {
      test('removes pod from podfile', () {
        final podfile = '''
target 'Runner' do
  pod 'Alamofire', '~> 5.9'
  pod 'SDWebImage', '~> 5.0'
end
''';
        final result = installer.removeDependency(
          podfileContent: podfile,
          podName: 'Alamofire',
        );
        expect(result, isNot(contains('Alamofire')));
        expect(result, contains('SDWebImage'));
      });

      test('preserves other content', () {
        final podfile = '''
platform :ios, '13.0'

target 'Runner' do
  use_frameworks!
  pod 'Alamofire', '~> 5.9'
end
''';
        final result = installer.removeDependency(
          podfileContent: podfile,
          podName: 'Alamofire',
        );
        expect(result, contains('platform'));
        expect(result, contains('use_frameworks!'));
        expect(result, contains('end'));
      });
    });

    group('hasDependency', () {
      test('returns true for existing pod', () {
        final podfile = "  pod 'Alamofire', '~> 5.9'\n";
        expect(
          installer.hasDependency(
              podfileContent: podfile, podName: 'Alamofire'),
          true,
        );
      });

      test('returns false for missing pod', () {
        final podfile = "  pod 'SDWebImage', '~> 5.0'\n";
        expect(
          installer.hasDependency(
              podfileContent: podfile, podName: 'Alamofire'),
          false,
        );
      });
    });

    group('getDependencyVersion', () {
      test('returns version for existing pod', () {
        final podfile = "  pod 'Alamofire', '~> 5.9'\n";
        expect(
          installer.getDependencyVersion(
              podfileContent: podfile, podName: 'Alamofire'),
          '~> 5.9',
        );
      });

      test('returns null for missing pod', () {
        expect(
          installer.getDependencyVersion(
              podfileContent: '', podName: 'Alamofire'),
          null,
        );
      });
    });

    group('addDependencies batch', () {
      test('adds multiple pods at once', () {
        final podfile = '''
target 'Runner' do
  use_frameworks!
end
''';
        final result = installer.addDependencies(
          podfileContent: podfile,
          dependencies: [
            PodDependency(name: 'Alamofire', version: '~> 5.9'),
            PodDependency(name: 'SDWebImage', version: '~> 5.19'),
          ],
        );
        expect(result, contains("pod 'Alamofire', '~> 5.9'"));
        expect(result, contains("pod 'SDWebImage', '~> 5.19'"));
      });
    });

    group('createPodfile', () {
      test('creates minimal Podfile', () {
        final result = installer.createPodfile(
          platform: 'ios',
          platformVersion: '13.0',
          target: 'Runner',
        );
        expect(result, contains("platform :ios, '13.0'"));
        expect(result, contains("target 'Runner' do"));
        expect(result, contains('use_frameworks!'));
        expect(result, contains('end'));
      });

      test('creates Podfile with pods', () {
        final result = installer.createPodfile(
          platform: 'ios',
          platformVersion: '14.0',
          target: 'MyApp',
          pods: [
            PodDependency(name: 'Alamofire', version: '~> 5.9'),
            PodDependency(name: 'SDWebImage', version: '~> 5.19'),
          ],
        );
        expect(result, contains("pod 'Alamofire', '~> 5.9'"));
        expect(result, contains("pod 'SDWebImage', '~> 5.19'"));
      });
    });
  });
}
