import 'dart:convert';
import 'dart:io';

import '../config/package_spec.dart';
import '../schema/unified_type_schema.dart' show PackageSource;

/// Result of locating native source files for a package.
class SourceLocationResult {
  /// Map of file path → file content.
  final Map<String, String> files;

  /// Human-readable description of where sources were found.
  final String? location;

  /// Warning message if sources could not be found.
  final String? warning;

  const SourceLocationResult({
    this.files = const {},
    this.location,
    this.warning,
  });

  /// Whether any source files were found.
  bool get found => files.isNotEmpty;
}

/// Finds native source files on disk for a given [PackageSpec].
///
/// Auto-detects source locations based on the package source type
/// (CocoaPods, SPM, npm, Gradle). If [PackageSpec.sourcePath] is set,
/// uses that path directly instead of auto-detecting.
class NativeSourceLocator {
  /// Locates native source files for the given [spec].
  SourceLocationResult locate(PackageSpec spec) {
    // If sourcePath is explicitly set, use it directly
    if (spec.sourcePath != null) {
      return _locateFromPath(spec.sourcePath!, spec);
    }

    // Auto-detect based on source type
    switch (spec.source) {
      case PackageSource.cocoapods:
        return _locateCocoapods(spec);
      case PackageSource.spm:
        return _locateSpm(spec);
      case PackageSource.npm:
        return _locateNpm(spec);
      case PackageSource.gradle:
        return _locateGradle(spec);
    }
  }

  /// Locates files from an explicit path.
  SourceLocationResult _locateFromPath(String path, PackageSpec spec) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return SourceLocationResult(
        warning: 'Source path not found: $path',
      );
    }

    final extensions = _extensionsForSource(spec.source);
    final files = _collectFiles(dir, extensions);

    if (files.isEmpty) {
      return SourceLocationResult(
        warning: 'No source files (${extensions.join(', ')}) found in: $path',
      );
    }

    return SourceLocationResult(
      files: files,
      location: path,
    );
  }

  SourceLocationResult _locateCocoapods(PackageSpec spec) {
    final name = spec.package;
    final candidates = [
      'Pods/$name/',
      'ios/Pods/$name/',
      'macos/Pods/$name/',
      'build/auto_interop/ios_pod/Pods/$name/',
    ];
    final extensions = ['.swift', '.swiftinterface'];

    for (final candidate in candidates) {
      final dir = Directory(candidate);
      if (dir.existsSync()) {
        final files = _collectFiles(dir, extensions);
        if (files.isNotEmpty) {
          return SourceLocationResult(
            files: files,
            location: candidate,
          );
        }
      }
    }

    return SourceLocationResult(
      warning: 'Could not find CocoaPods sources for "$name". '
          'Tried: ${candidates.join(', ')}. '
          'Use source_path in auto_interop.yaml to specify the location.',
    );
  }

  SourceLocationResult _locateSpm(PackageSpec spec) {
    final name = spec.package;
    final candidates = [
      '.build/checkouts/$name/Sources/',
      '.build/checkouts/${name.toLowerCase()}/Sources/',
      'build/auto_interop/spm/.build/checkouts/$name/',
      'build/auto_interop/spm/.build/checkouts/${name.toLowerCase()}/',
      'build/auto_interop/spm/$name/',
    ];
    final extensions = ['.swift', '.swiftinterface'];

    for (final candidate in candidates) {
      final dir = Directory(candidate);
      if (dir.existsSync()) {
        final files = _collectFiles(dir, extensions);
        if (files.isNotEmpty) {
          return SourceLocationResult(
            files: files,
            location: candidate,
          );
        }
      }
    }

    return SourceLocationResult(
      warning: 'Could not find SPM sources for "$name". '
          'Tried: ${candidates.join(', ')}. '
          'Use source_path in auto_interop.yaml to specify the location.',
    );
  }

  SourceLocationResult _locateNpm(PackageSpec spec) {
    final name = spec.package;

    // Check multiple candidate locations
    for (final modulePath in [
      'node_modules/$name',
      'build/auto_interop/node_modules/$name',
    ]) {
      final moduleDir = Directory(modulePath);
      if (moduleDir.existsSync()) {
        return _locateNpmFromDir(modulePath, name);
      }
    }

    return SourceLocationResult(
      warning: 'Could not find npm package "$name" in node_modules/. '
          'Run "npm install" first, or use source_path to specify the location.',
    );
  }

  SourceLocationResult _locateNpmFromDir(String modulePath, String name) {
    final moduleDir = Directory(modulePath);

    // Check package.json for types/typings field
    final packageJsonFile = File('$modulePath/package.json');
    if (packageJsonFile.existsSync()) {
      try {
        final packageJson = jsonDecode(packageJsonFile.readAsStringSync())
            as Map<String, dynamic>;
        final typesPath =
            (packageJson['types'] ?? packageJson['typings']) as String?;
        if (typesPath != null) {
          final typesFile = File('$modulePath/$typesPath');
          if (typesFile.existsSync()) {
            return SourceLocationResult(
              files: {typesFile.path: typesFile.readAsStringSync()},
              location: '$modulePath/$typesPath',
            );
          }
        }
      } catch (_) {
        // Fall through to scanning
      }
    }

    // Fallback: scan for .d.ts files
    final files = _collectFiles(moduleDir, ['.d.ts']);
    if (files.isNotEmpty) {
      return SourceLocationResult(
        files: files,
        location: modulePath,
      );
    }

    return SourceLocationResult(
      warning: 'No TypeScript declaration files (.d.ts) found in $modulePath. '
          'Use source_path in auto_interop.yaml to specify the location.',
    );
  }

  SourceLocationResult _locateGradle(PackageSpec spec) {
    // Check build/auto_interop/gradle/ for downloaded sources
    final downloadedPath = 'build/auto_interop/gradle/${spec.package}';
    final downloadedDir = Directory(downloadedPath);
    if (downloadedDir.existsSync()) {
      final extensions = ['.kt', '.java'];
      final files = _collectFiles(downloadedDir, extensions);
      if (files.isNotEmpty) {
        return SourceLocationResult(
          files: files,
          location: downloadedPath,
        );
      }
    }

    return SourceLocationResult(
      warning: 'Could not find Gradle sources for "${spec.package}". '
          'Use source_path in auto_interop.yaml to specify the source location.',
    );
  }

  /// Returns the file extensions to look for based on source type.
  List<String> _extensionsForSource(PackageSource source) {
    switch (source) {
      case PackageSource.cocoapods:
      case PackageSource.spm:
        return ['.swift', '.swiftinterface'];
      case PackageSource.npm:
        return ['.d.ts'];
      case PackageSource.gradle:
        return ['.kt', '.java'];
    }
  }

  /// Recursively collects files matching [extensions] from [dir].
  Map<String, String> _collectFiles(Directory dir, List<String> extensions) {
    final files = <String, String>{};
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          final path = entity.path;
          if (extensions.any((ext) => path.endsWith(ext))) {
            try {
              files[path] = entity.readAsStringSync();
            } catch (_) {
              // Skip unreadable files
            }
          }
        }
      }
    } catch (_) {
      // Permission or other IO errors
    }
    return files;
  }
}
