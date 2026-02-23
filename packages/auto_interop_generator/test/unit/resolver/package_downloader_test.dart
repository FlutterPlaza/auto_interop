import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/config/package_spec.dart';
import 'package:auto_interop_generator/src/resolver/package_downloader.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart'
    show PackageSource;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String buildDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('downloader_test_');
    buildDir = '${tempDir.path}/build/auto_interop';
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('PackageDownloader', () {
    group('npm', () {
      test('creates package.json and runs npm install', () async {
        final commands = <List<String>>[];
        final targetPath = '$buildDir/node_modules/date-fns';
        // Pre-create the target directory to simulate successful npm install
        Directory(targetPath).createSync(recursive: true);

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          commands.add([executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'date-fns',
          version: '^3.0.0',
        );

        final result = await downloader.download(spec);
        expect(result.success, isTrue);
        expect(result.path, targetPath);

        // Verify npm install was called
        expect(commands, hasLength(1));
        expect(commands[0][0], 'npm');
        expect(commands[0], contains('install'));
        expect(commands[0], contains('date-fns@^3.0.0'));

        // Verify package.json was created
        final packageJson = File('$buildDir/package.json');
        expect(packageJson.existsSync(), isTrue);
        final content =
            jsonDecode(packageJson.readAsStringSync()) as Map<String, dynamic>;
        expect(content['private'], isTrue);
      });

      test('returns error on npm install failure', () async {
        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          return ProcessResult(0, 1, '', 'npm ERR! package not found');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'nonexistent-pkg',
          version: '1.0.0',
        );

        final result = await downloader.download(spec);
        expect(result.success, isFalse);
        expect(result.error, contains('npm install failed'));
      });
    });

    group('cocoapods', () {
      test('creates stub xcodeproj and runs pod install', () async {
        final commands = <List<String>>[];
        final podDir = '$buildDir/ios_pod';
        final podsPath = '$podDir/Pods/Alamofire';

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          commands.add([executable, ...arguments]);
          if (executable == 'pod') {
            // Simulate pod install creating the Pods directory
            Directory(podsPath).createSync(recursive: true);
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Alamofire',
          version: '~> 5.9',
        );

        final result = await downloader.download(spec);
        expect(result.success, isTrue);
        expect(result.path, podsPath);

        // Verify pod install was called
        expect(commands, hasLength(1));
        expect(commands[0][0], 'pod');
        expect(commands[0], contains('install'));

        // Verify stub xcodeproj was created
        final pbxFile = File('$podDir/AutoInterop.xcodeproj/project.pbxproj');
        expect(pbxFile.existsSync(), isTrue);
        expect(pbxFile.readAsStringSync(), contains('AutoInterop'));

        // Verify Podfile was created with correct content
        final podfile = File('$podDir/Podfile');
        expect(podfile.existsSync(), isTrue);
        final podfileContent = podfile.readAsStringSync();
        expect(podfileContent, contains("pod 'Alamofire', '~> 5.9'"));
        expect(podfileContent, contains("use_frameworks!"));
        expect(podfileContent, contains("project 'AutoInterop.xcodeproj'"));
      });

      test('accumulates pods in shared Podfile', () async {
        final podDir = '$buildDir/ios_pod';
        var callCount = 0;

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          if (executable == 'pod') {
            callCount++;
            if (callCount == 1) {
              Directory('$podDir/Pods/Alamofire').createSync(recursive: true);
            } else {
              Directory('$podDir/Pods/SDWebImage').createSync(recursive: true);
            }
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        await downloader.download(PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Alamofire',
          version: '~> 5.9',
        ));

        await downloader.download(PackageSpec(
          source: PackageSource.cocoapods,
          package: 'SDWebImage',
          version: '~> 5.0',
        ));

        final podfileContent = File('$podDir/Podfile').readAsStringSync();
        expect(podfileContent, contains("pod 'Alamofire', '~> 5.9'"));
        expect(podfileContent, contains("pod 'SDWebImage', '~> 5.0'"));
      });

      test('falls back to git clone from source_url when pod install fails',
          () async {
        final commands = <List<String>>[];
        final podsPath = '$buildDir/ios_pod/Pods/MyPod';

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          commands.add([executable, ...arguments]);
          if (executable == 'pod') {
            return ProcessResult(0, 1, '', 'pod install failed');
          }
          if (executable == 'git') {
            Directory(podsPath).createSync(recursive: true);
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'MyPod',
          version: '1.2.0',
          sourceUrl: 'https://github.com/example/MyPod.git',
        );

        final result = await downloader.download(spec);
        expect(result.success, isTrue);

        // Verify pod install was tried first
        expect(commands[0][0], 'pod');

        // Then git clone as fallback
        final gitCmd = commands.firstWhere((c) => c[0] == 'git');
        expect(gitCmd, contains('clone'));
        expect(gitCmd, contains('https://github.com/example/MyPod.git'));
      });

      test('returns error when pod install fails and no source_url', () async {
        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          return ProcessResult(0, 1, '', 'pod not found');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Unknown',
          version: '1.0.0',
        );

        final result = await downloader.download(spec);
        expect(result.success, isFalse);
        expect(result.error, contains('pod install failed'));
        expect(result.error, contains('source_url'));
      });
    });

    group('spm', () {
      test('uses swift package resolve with Package.swift', () async {
        final commands = <List<String>>[];
        final spmDir = '$buildDir/spm';
        final checkoutPath = '$spmDir/.build/checkouts/SwiftyJSON';

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          commands.add([executable, ...arguments]);
          if (executable == 'swift') {
            // Simulate swift package resolve creating checkouts
            Directory(checkoutPath).createSync(recursive: true);
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.spm,
          package: 'SwiftyJSON',
          version: '5.0.0',
          sourceUrl: 'https://github.com/SwiftyJSON/SwiftyJSON.git',
        );

        final result = await downloader.download(spec);
        expect(result.success, isTrue);
        expect(result.path, checkoutPath);

        // Verify swift package resolve was called
        expect(commands[0][0], 'swift');
        expect(commands[0], contains('package'));
        expect(commands[0], contains('resolve'));

        // Verify Package.swift was created
        final packageSwift = File('$spmDir/Package.swift');
        expect(packageSwift.existsSync(), isTrue);
        final content = packageSwift.readAsStringSync();
        expect(content, contains('SwiftyJSON.git'));
        expect(content, contains('from: "5.0.0"'));
      });

      test('requires source_url', () async {
        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: (_, __, {workingDirectory}) async =>
              ProcessResult(0, 0, '', ''),
        );

        final spec = PackageSpec(
          source: PackageSource.spm,
          package: 'NoPkg',
          version: '1.0.0',
        );

        final result = await downloader.download(spec);
        expect(result.success, isFalse);
        expect(result.error, contains('source_url'));
      });

      test('falls back to git clone when swift package resolve fails',
          () async {
        final commands = <List<String>>[];
        final targetDir = '$buildDir/spm/FailPkg';

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          commands.add([executable, ...arguments]);
          if (executable == 'swift') {
            return ProcessResult(0, 1, '', 'resolve failed');
          }
          if (executable == 'git') {
            Directory(targetDir).createSync(recursive: true);
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.spm,
          package: 'FailPkg',
          version: '2.0.0',
          sourceUrl: 'https://github.com/example/FailPkg.git',
        );

        final result = await downloader.download(spec);
        expect(result.success, isTrue);

        // swift was tried first
        expect(commands[0][0], 'swift');
        // then git clone fallback
        final gitCmd = commands.firstWhere((c) => c[0] == 'git');
        expect(gitCmd, contains('clone'));
      });
    });

    group('gradle', () {
      test('downloads and extracts sources JAR', () async {
        final commands = <List<String>>[];
        final targetPath =
            '$buildDir/gradle/com.squareup.okhttp3:okhttp';

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          commands.add([executable, ...arguments]);
          if (executable == 'curl') {
            // Simulate download by creating the jar file
            final jarPath = arguments.firstWhere(
                (a) => a.endsWith('-sources.jar'),
                orElse: () => arguments[arguments.indexOf('-o') + 1]);
            File(jarPath)
              ..createSync(recursive: true)
              ..writeAsStringSync('fake jar');
            return ProcessResult(0, 0, '', '');
          }
          if (executable == 'unzip') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.gradle,
          package: 'com.squareup.okhttp3:okhttp',
          version: '4.12.0',
        );

        final result = await downloader.download(spec);
        expect(result.success, isTrue);
        expect(result.path, targetPath);

        // Verify curl was called with Maven Central URL
        final curlCmd = commands.firstWhere((c) => c[0] == 'curl');
        expect(
            curlCmd.any((a) => a.contains('repo1.maven.org')), isTrue);
        expect(
            curlCmd.any((a) => a.contains('okhttp-4.12.0-sources.jar')),
            isTrue);

        // Verify unzip was called
        final unzipCmd = commands.firstWhere((c) => c[0] == 'unzip');
        expect(unzipCmd, contains('*.kt'));
        expect(unzipCmd, contains('*.java'));
      });

      test('tries multiple maven repositories on failure', () async {
        final commands = <List<String>>[];
        final targetPath =
            '$buildDir/gradle/com.google.firebase:firebase-core';
        var curlCallCount = 0;

        Future<ProcessResult> mockRunner(
          String executable,
          List<String> arguments, {
          String? workingDirectory,
        }) async {
          commands.add([executable, ...arguments]);
          if (executable == 'curl') {
            curlCallCount++;
            if (curlCallCount == 1) {
              // First repo fails
              return ProcessResult(0, 22, '', 'HTTP 404');
            }
            // Second repo succeeds
            final jarPath = arguments[arguments.indexOf('-o') + 1];
            File(jarPath)
              ..createSync(recursive: true)
              ..writeAsStringSync('fake jar');
            return ProcessResult(0, 0, '', '');
          }
          if (executable == 'unzip') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        }

        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: mockRunner,
        );

        final spec = PackageSpec(
          source: PackageSource.gradle,
          package: 'com.google.firebase:firebase-core',
          version: '21.0.0',
          mavenRepositories: [
            'https://repo1.maven.org/maven2',
            'https://dl.google.com/dl/android/maven2',
          ],
        );

        final result = await downloader.download(spec);
        expect(result.success, isTrue);
        expect(result.path, targetPath);

        // Verify both repos were tried
        final curlCmds = commands.where((c) => c[0] == 'curl').toList();
        expect(curlCmds, hasLength(2));
        expect(curlCmds[0].any((a) => a.contains('repo1.maven.org')), isTrue);
        expect(curlCmds[1].any((a) => a.contains('dl.google.com')), isTrue);
      });

      test('returns error for invalid Maven coordinates', () async {
        final downloader = PackageDownloader(
          buildDir: buildDir,
          processRunner: (_, __, {workingDirectory}) async =>
              ProcessResult(0, 0, '', ''),
        );

        final spec = PackageSpec(
          source: PackageSource.gradle,
          package: 'invalid-package-name',
          version: '1.0.0',
        );

        final result = await downloader.download(spec);
        expect(result.success, isFalse);
        expect(result.error, contains('Invalid Maven coordinates'));
      });
    });
  });
}
