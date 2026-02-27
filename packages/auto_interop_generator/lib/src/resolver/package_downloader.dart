import 'dart:convert';
import 'dart:io';

import '../config/package_spec.dart';
import '../schema/unified_type_schema.dart' show PackageSource;

/// Result of a download operation.
class DownloadResult {
  /// The local path where sources were downloaded.
  final String? path;

  /// Error message if the download failed.
  final String? error;

  const DownloadResult({this.path, this.error});

  bool get success => path != null;
}

/// Function type for running external processes. Allows test mocking.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// Downloads native package sources for code generation.
///
/// Uses official package managers as the primary mechanism:
/// - **npm**: `npm install`
/// - **CocoaPods**: `pod install` with a stub Xcode project
/// - **Gradle**: Maven Central sources JAR download
/// - **SPM**: `swift package resolve`
///
/// Falls back to `git clone` from `source_url` only when the package
/// manager fails and the user has explicitly provided a URL.
class PackageDownloader {
  final String _buildDir;
  final ProcessRunner _runProcess;

  PackageDownloader({
    required String buildDir,
    ProcessRunner? processRunner,
  })  : _buildDir = buildDir,
        _runProcess = processRunner ?? _defaultProcessRunner;

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(executable, arguments,
        workingDirectory: workingDirectory);
  }

  /// Downloads sources for the given [spec].
  Future<DownloadResult> download(PackageSpec spec) async {
    switch (spec.source) {
      case PackageSource.npm:
        return _downloadNpm(spec);
      case PackageSource.cocoapods:
        return _downloadCocoapods(spec);
      case PackageSource.spm:
        return _downloadSpm(spec);
      case PackageSource.gradle:
        return _downloadGradle(spec);
    }
  }

  // ---------------------------------------------------------------------------
  // npm — uses `npm install`
  // ---------------------------------------------------------------------------

  Future<DownloadResult> _downloadNpm(PackageSpec spec) async {
    final npmDir = _buildDir;

    // Create package.json if missing
    final packageJsonFile = File('$npmDir/package.json');
    if (!packageJsonFile.existsSync()) {
      Directory(npmDir).createSync(recursive: true);
      packageJsonFile.writeAsStringSync(jsonEncode({
        'name': 'auto_interop_sources',
        'version': '0.0.0',
        'private': true,
      }));
    }

    final installTarget = '${spec.package}@${spec.version}';

    final result = await _runProcess(
      'npm',
      ['install', installTarget, '--prefix', npmDir],
    );

    if (result.exitCode != 0) {
      return DownloadResult(
        error: 'npm install failed for ${spec.package}: ${result.stderr}',
      );
    }

    final downloadedPath = '$npmDir/node_modules/${spec.package}';
    if (!Directory(downloadedPath).existsSync()) {
      return DownloadResult(
        error: 'npm install succeeded but package not found at $downloadedPath',
      );
    }

    return DownloadResult(path: downloadedPath);
  }

  // ---------------------------------------------------------------------------
  // CocoaPods — uses `pod install` with a stub Xcode project
  // ---------------------------------------------------------------------------

  Future<DownloadResult> _downloadCocoapods(PackageSpec spec) async {
    final podDir = '$_buildDir/ios_pod';
    final podsPath = '$podDir/Pods/${spec.package}';

    // Already downloaded
    if (Directory(podsPath).existsSync()) {
      return DownloadResult(path: podsPath);
    }

    Directory(podDir).createSync(recursive: true);

    // Create stub Xcode project so `pod install` has a target to reference
    _ensureStubXcodeProject(podDir);

    // Write/update Podfile
    _ensurePodfile(podDir, spec);

    // Run pod install (downloads into Pods/)
    final result = await _runProcess(
      'pod',
      ['install'],
      workingDirectory: podDir,
    );

    if (result.exitCode == 0 && Directory(podsPath).existsSync()) {
      return DownloadResult(path: podsPath);
    }

    // Fallback: git clone from source_url if user provided one
    if (spec.sourceUrl != null) {
      return _gitClone(
        url: spec.sourceUrl!,
        version: spec.version,
        targetDir: podsPath,
        packageName: spec.package,
      );
    }

    return DownloadResult(
      error: 'pod install failed for "${spec.package}": ${result.stderr}\n'
          'Set source_url in auto_interop.yaml as a fallback.',
    );
  }

  /// Creates a minimal stub `.xcodeproj` so `pod install` can find a target.
  void _ensureStubXcodeProject(String podDir) {
    final projDir = '$podDir/AutoInterop.xcodeproj';
    final pbxFile = File('$projDir/project.pbxproj');
    if (pbxFile.existsSync()) return;

    Directory(projDir).createSync(recursive: true);
    pbxFile.writeAsStringSync(_stubPbxproj);
  }

  /// Creates or appends to a Podfile in [podDir] for [spec].
  void _ensurePodfile(String podDir, PackageSpec spec) {
    final podfile = File('$podDir/Podfile');
    if (podfile.existsSync()) {
      var content = podfile.readAsStringSync();
      if (!content.contains("pod '${spec.package}'")) {
        content = content.replaceFirst(
          '\nend',
          "\n  pod '${spec.package}', '${spec.version}'\nend",
        );
        podfile.writeAsStringSync(content);
      }
    } else {
      podfile.writeAsStringSync(
        "platform :ios, '13.0'\n"
        "project 'AutoInterop.xcodeproj'\n"
        "target 'AutoInterop' do\n"
        "  use_frameworks!\n"
        "  pod '${spec.package}', '${spec.version}'\n"
        "end\n",
      );
    }
  }

  /// Minimal pbxproj that defines one target named 'AutoInterop'.
  /// CocoaPods only needs the target to exist; it doesn't need real sources.
  static const _stubPbxproj = '''
// !!\$*UTF8*\$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXGroup section */
		00000000000000000000001 /* Source */ = {
			isa = PBXGroup;
			children = (
			);
			path = Source;
			sourceTree = "<group>";
		};
		00000000000000000000002 /* Main */ = {
			isa = PBXGroup;
			children = (
				00000000000000000000001 /* Source */,
			);
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		00000000000000000000010 /* AutoInterop */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 00000000000000000000030 /* Build configuration list for PBXNativeTarget "AutoInterop" */;
			buildPhases = (
			);
			buildRules = (
			);
			dependencies = (
			);
			name = AutoInterop;
			productName = AutoInterop;
			productReference = 00000000000000000000011 /* AutoInterop.framework */;
			productType = "com.apple.product-type.framework";
		};
/* End PBXNativeTarget section */

/* Begin PBXFileReference section */
		00000000000000000000011 /* AutoInterop.framework */ = {
			isa = PBXFileReference;
			explicitFileType = wrapper.framework;
			includeInIndex = 0;
			path = AutoInterop.framework;
			sourceTree = BUILT_PRODUCTS_DIR;
		};
/* End PBXFileReference section */

/* Begin PBXProject section */
		00000000000000000000020 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastUpgradeCheck = 1500;
			};
			buildConfigurationList = 00000000000000000000031 /* Build configuration list for PBXProject "AutoInterop" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = 00000000000000000000002 /* Main */;
			productRefGroup = 00000000000000000000002 /* Main */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				00000000000000000000010 /* AutoInterop */,
			);
		};
/* End PBXProject section */

/* Begin XCBuildConfiguration section */
		00000000000000000000040 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
			};
			name = Debug;
		};
		00000000000000000000041 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
			};
			name = Release;
		};
		00000000000000000000042 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
			};
			name = Debug;
		};
		00000000000000000000043 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		00000000000000000000030 /* Build configuration list for PBXNativeTarget "AutoInterop" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				00000000000000000000040 /* Debug */,
				00000000000000000000041 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		00000000000000000000031 /* Build configuration list for PBXProject "AutoInterop" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				00000000000000000000042 /* Debug */,
				00000000000000000000043 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = 00000000000000000000020 /* Project object */;
}
''';

  // ---------------------------------------------------------------------------
  // SPM — uses `swift package resolve`
  // ---------------------------------------------------------------------------

  Future<DownloadResult> _downloadSpm(PackageSpec spec) async {
    if (spec.sourceUrl == null) {
      return DownloadResult(
        error: 'SPM packages require source_url in auto_interop.yaml '
            '(the git repository URL).',
      );
    }

    final spmDir = '$_buildDir/spm';
    final cleanVersion = spec.version.replaceAll(RegExp(r'^[~^>=<\s]+'), '');

    // Check if already resolved
    final checkoutCandidates = [
      '$spmDir/.build/checkouts/${spec.package}',
      '$spmDir/.build/checkouts/${spec.package.toLowerCase()}',
    ];
    for (final candidate in checkoutCandidates) {
      if (Directory(candidate).existsSync()) {
        return DownloadResult(path: candidate);
      }
    }

    Directory(spmDir).createSync(recursive: true);

    // Create Package.swift
    File('$spmDir/Package.swift').writeAsStringSync(
      '// swift-tools-version:5.7\n'
      'import PackageDescription\n'
      'let package = Package(\n'
      '    name: "AutoInteropSources",\n'
      '    dependencies: [\n'
      '        .package(url: "${spec.sourceUrl}", from: "$cleanVersion"),\n'
      '    ]\n'
      ')\n',
    );

    final result = await _runProcess(
      'swift',
      ['package', 'resolve'],
      workingDirectory: spmDir,
    );

    if (result.exitCode == 0) {
      for (final candidate in checkoutCandidates) {
        if (Directory(candidate).existsSync()) {
          return DownloadResult(path: candidate);
        }
      }
    }

    // Fallback: direct git clone
    final targetDir = '$spmDir/${spec.package}';
    return _gitClone(
      url: spec.sourceUrl!,
      version: spec.version,
      targetDir: targetDir,
      packageName: spec.package,
    );
  }

  // ---------------------------------------------------------------------------
  // Gradle — downloads sources JAR from Maven Central
  // ---------------------------------------------------------------------------

  Future<DownloadResult> _downloadGradle(PackageSpec spec) async {
    // Parse Maven coordinates: com.squareup.okhttp3:okhttp → group/artifact
    final parts = spec.package.split(':');
    if (parts.length != 2) {
      return DownloadResult(
        error: 'Invalid Maven coordinates "${spec.package}". '
            'Expected format: group:artifact (e.g., com.squareup.okhttp3:okhttp)',
      );
    }

    final group = parts[0].replaceAll('.', '/');
    final artifact = parts[1];
    final cleanVersion = spec.version.replaceAll(RegExp(r'^[~^>=<\s]+'), '');
    final targetDir = '$_buildDir/gradle/${spec.package}';

    // If already extracted, skip
    if (Directory(targetDir).existsSync()) {
      return DownloadResult(path: targetDir);
    }

    Directory(targetDir).createSync(recursive: true);

    // Try each Maven repository in order
    final jarPath = '$targetDir/$artifact-$cleanVersion-sources.jar';
    ProcessResult? lastCurlResult;

    for (final repoUrl in spec.mavenRepositories) {
      final baseUrl = repoUrl.endsWith('/')
          ? repoUrl.substring(0, repoUrl.length - 1)
          : repoUrl;
      final jarUrl =
          '$baseUrl/$group/$artifact/$cleanVersion/$artifact-$cleanVersion-sources.jar';

      lastCurlResult = await _runProcess(
        'curl',
        ['-fSL', '-o', jarPath, jarUrl],
      );

      if (lastCurlResult.exitCode == 0) break;
    }

    if (lastCurlResult == null || lastCurlResult.exitCode != 0) {
      // Clean up empty dir on failure
      try {
        Directory(targetDir).deleteSync(recursive: true);
      } catch (_) {}
      return DownloadResult(
        error:
            'Failed to download sources JAR for ${spec.package}:$cleanVersion '
            'from any repository: ${lastCurlResult?.stderr}',
      );
    }

    // Extract only .kt and .java files
    final unzipResult = await _runProcess(
      'unzip',
      ['-o', jarPath, '*.kt', '*.java', '-d', targetDir],
    );

    if (unzipResult.exitCode != 0) {
      // unzip returns 11 when no matching files found — that's ok for
      // packages with only one language
      if (unzipResult.exitCode != 11) {
        return DownloadResult(
          error: 'Failed to extract sources JAR for ${spec.package}: '
              '${unzipResult.stderr}',
        );
      }
    }

    // Clean up JAR file
    try {
      File(jarPath).deleteSync();
    } catch (_) {}

    return DownloadResult(path: targetDir);
  }

  // ---------------------------------------------------------------------------
  // Git clone fallback — only used when user specifies source_url
  // ---------------------------------------------------------------------------

  Future<DownloadResult> _gitClone({
    required String url,
    required String version,
    required String targetDir,
    required String packageName,
  }) async {
    if (Directory(targetDir).existsSync()) {
      return DownloadResult(path: targetDir);
    }

    Directory(targetDir).parent.createSync(recursive: true);

    final tag = version.replaceAll(RegExp(r'^[~^>=<\s]+'), '');
    final cloneArgs = ['clone', '--depth', '1'];
    if (tag.isNotEmpty) {
      cloneArgs.addAll(['--branch', tag]);
    }
    cloneArgs.addAll([url, targetDir]);

    final result = await _runProcess('git', cloneArgs);

    if (result.exitCode != 0) {
      return DownloadResult(
        error: 'git clone failed for $packageName: ${result.stderr}',
      );
    }

    return DownloadResult(path: targetDir);
  }
}
