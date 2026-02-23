import '../schema/unified_type_schema.dart';

/// Supported platforms.
enum Platform { android, ios, macos, web }

/// Platform support details for a single API element.
class PlatformSupport {
  final String name;
  final Set<Platform> platforms;
  final String? note;

  const PlatformSupport({
    required this.name,
    required this.platforms,
    this.note,
  });

  bool get isAndroidOnly =>
      platforms.length == 1 && platforms.contains(Platform.android);
  bool get isIosOnly =>
      platforms.length == 1 && platforms.contains(Platform.ios);
  bool get isWebOnly =>
      platforms.length == 1 && platforms.contains(Platform.web);
  bool get isMacosOnly =>
      platforms.length == 1 && platforms.contains(Platform.macos);
}

/// Compatibility report for a schema.
class CompatibilityReport {
  /// The package name.
  final String package;

  /// Primary platform derived from the package source.
  final Set<Platform> primaryPlatforms;

  /// Per-class platform support.
  final List<PlatformSupport> classSupport;

  /// Per-method platform notes (only non-obvious ones).
  final List<PlatformSupport> methodNotes;

  const CompatibilityReport({
    required this.package,
    required this.primaryPlatforms,
    this.classSupport = const [],
    this.methodNotes = const [],
  });
}

/// Checks platform compatibility for schemas.
class CompatibilityChecker {
  const CompatibilityChecker();

  /// Determines primary platforms from [source].
  static Set<Platform> platformsForSource(PackageSource source) {
    switch (source) {
      case PackageSource.npm:
        return {Platform.web};
      case PackageSource.cocoapods:
      case PackageSource.spm:
        return {Platform.ios, Platform.macos};
      case PackageSource.gradle:
        return {Platform.android};
    }
  }

  /// Checks compatibility for a single [schema].
  CompatibilityReport check(UnifiedTypeSchema schema) {
    final primaryPlatforms = platformsForSource(schema.source);
    final classSupport = <PlatformSupport>[];
    final methodNotes = <PlatformSupport>[];

    for (final cls in schema.classes) {
      String? note;

      // Sealed classes are a Kotlin feature → Android-only
      if (cls.kind == UtsClassKind.sealedClass) {
        note = 'Sealed class (Kotlin-specific)';
        classSupport.add(PlatformSupport(
          name: cls.name,
          platforms: {Platform.android},
          note: note,
        ));
        continue;
      }

      classSupport.add(PlatformSupport(
        name: cls.name,
        platforms: primaryPlatforms,
      ));

      // Check methods for platform-specific patterns
      for (final method in cls.methods) {
        // Swift closures / async patterns → iOS-only
        if (_hasSwiftClosurePattern(method) &&
            schema.source == PackageSource.cocoapods) {
          methodNotes.add(PlatformSupport(
            name: '${cls.name}.${method.name}',
            platforms: {Platform.ios},
            note: 'Uses Swift closure pattern',
          ));
        }
      }
    }

    for (final cls in schema.types) {
      classSupport.add(PlatformSupport(
        name: cls.name,
        platforms: primaryPlatforms,
      ));
    }

    return CompatibilityReport(
      package: schema.package,
      primaryPlatforms: primaryPlatforms,
      classSupport: classSupport,
      methodNotes: methodNotes,
    );
  }

  bool _hasSwiftClosurePattern(UtsMethod method) {
    return method.parameters.any(
      (p) => p.type.kind == UtsTypeKind.callback,
    );
  }
}
