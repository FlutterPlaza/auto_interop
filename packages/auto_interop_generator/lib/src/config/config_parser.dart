import 'dart:io';

import 'package:yaml/yaml.dart';

import '../schema/unified_type_schema.dart' show PackageSource;
import 'package_spec.dart';

/// Configuration for auto_interop, parsed from `auto_interop.yaml`.
class AutoInteropConfig {
  /// The native packages to generate bindings for.
  final List<PackageSpec> packages;

  /// Optional custom path for the project-level overrides directory.
  /// Defaults to `auto_interop_overrides/` when null.
  final String? overridesDir;

  const AutoInteropConfig({required this.packages, this.overridesDir});
}

/// Parses `auto_interop.yaml` configuration files.
class ConfigParser {
  /// The supported source types.
  static const supportedSources = {'npm', 'cocoapods', 'gradle', 'spm'};

  /// Parses a YAML string into a [AutoInteropConfig].
  ///
  /// Throws [ConfigParseException] if the YAML is invalid or contains
  /// unsupported values.
  AutoInteropConfig parseYaml(String yamlContent) {
    final doc = loadYaml(yamlContent);
    if (doc is! YamlMap) {
      throw ConfigParseException('Config must be a YAML map');
    }

    final nativePackages = doc['native_packages'];
    if (nativePackages == null) {
      throw ConfigParseException("Missing required field 'native_packages'");
    }

    if (nativePackages is! YamlList) {
      throw ConfigParseException("'native_packages' must be a list");
    }

    final packages = <PackageSpec>[];
    for (var i = 0; i < nativePackages.length; i++) {
      final entry = nativePackages[i];
      if (entry is! YamlMap) {
        throw ConfigParseException('Package entry at index $i must be a map');
      }
      packages.add(_parsePackageEntry(entry, i));
    }

    // Parse optional overrides_dir
    final overridesDirRaw = doc['overrides_dir'];
    String? overridesDir;
    if (overridesDirRaw != null) {
      if (overridesDirRaw is! String) {
        throw ConfigParseException("'overrides_dir' must be a string");
      }
      overridesDir = overridesDirRaw;
    }

    return AutoInteropConfig(packages: packages, overridesDir: overridesDir);
  }

  /// Parses a YAML file into a [AutoInteropConfig].
  AutoInteropConfig parseFile(File file) {
    if (!file.existsSync()) {
      throw ConfigParseException('Config file not found: ${file.path}');
    }
    return parseYaml(file.readAsStringSync());
  }

  PackageSpec _parsePackageEntry(YamlMap entry, int index) {
    // Validate required 'source' field
    final sourceStr = entry['source'];
    if (sourceStr == null) {
      throw ConfigParseException(
          "Missing required field 'source' in package entry at index $index");
    }
    if (sourceStr is! String) {
      throw ConfigParseException(
          "'source' must be a string in package entry at index $index");
    }
    if (!supportedSources.contains(sourceStr)) {
      throw ConfigParseException(
          "Unsupported source '$sourceStr' in package entry at index $index. "
          "Supported sources: ${supportedSources.join(', ')}");
    }

    // Validate required 'package' field
    final packageName = entry['package'];
    if (packageName == null) {
      throw ConfigParseException(
          "Missing required field 'package' in package entry at index $index");
    }
    if (packageName is! String) {
      throw ConfigParseException(
          "'package' must be a string in package entry at index $index");
    }

    // Validate required 'version' field
    final version = entry['version'];
    if (version == null) {
      throw ConfigParseException(
          "Missing required field 'version' in package entry at index $index");
    }

    // Parse optional 'imports' field
    final importsRaw = entry['imports'];
    final imports = <String>[];
    if (importsRaw != null) {
      if (importsRaw is! YamlList) {
        throw ConfigParseException(
            "'imports' must be a list in package entry at index $index");
      }
      for (final item in importsRaw) {
        if (item is! String) {
          throw ConfigParseException(
              "All imports must be strings in package entry at index $index");
        }
        imports.add(item);
      }
    }

    // Parse optional 'source_path' field
    final sourcePath = entry['source_path'] as String?;

    // Parse optional 'source_url' field
    final sourceUrl = entry['source_url'] as String?;

    // Parse optional 'custom_types' field
    final customTypesRaw = entry['custom_types'];
    final customTypes = <String, String>{};
    if (customTypesRaw != null) {
      if (customTypesRaw is! YamlMap) {
        throw ConfigParseException(
            "'custom_types' must be a map in package entry at index $index");
      }
      for (final e in customTypesRaw.entries) {
        if (e.key is! String || e.value is! String) {
          throw ConfigParseException(
              "All custom_types entries must be string → string in package entry at index $index");
        }
        customTypes[e.key as String] = e.value as String;
      }
    }

    // Parse optional 'maven_repositories' field
    final mavenReposRaw = entry['maven_repositories'];
    final mavenRepositories = <String>[];
    if (mavenReposRaw != null) {
      if (mavenReposRaw is! YamlList) {
        throw ConfigParseException(
            "'maven_repositories' must be a list in package entry at index $index");
      }
      for (final item in mavenReposRaw) {
        if (item is! String) {
          throw ConfigParseException(
              "All maven_repositories entries must be strings in package entry at index $index");
        }
        mavenRepositories.add(item);
      }
    }

    return PackageSpec(
      source: _parseSource(sourceStr),
      package: packageName,
      version: version.toString(),
      imports: imports,
      sourcePath: sourcePath,
      sourceUrl: sourceUrl,
      customTypes: customTypes,
      mavenRepositories: mavenRepositories.isNotEmpty
          ? mavenRepositories
          : PackageSpec.defaultMavenRepositories,
    );
  }

  PackageSource _parseSource(String source) {
    switch (source) {
      case 'npm':
        return PackageSource.npm;
      case 'cocoapods':
        return PackageSource.cocoapods;
      case 'gradle':
        return PackageSource.gradle;
      case 'spm':
        return PackageSource.spm;
      default:
        throw ConfigParseException("Unknown source: $source");
    }
  }
}

/// Exception thrown when parsing a config file fails.
class ConfigParseException implements Exception {
  final String message;

  const ConfigParseException(this.message);

  @override
  String toString() => 'ConfigParseException: $message';
}
