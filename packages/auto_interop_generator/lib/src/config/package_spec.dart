import '../schema/unified_type_schema.dart' show PackageSource;

/// Specifies a native package to generate bindings for.
///
/// This is the parsed representation of a single entry in the
/// `native_packages` list in `auto_interop.yaml`.
class PackageSpec {
  /// The source platform (npm, cocoapods, gradle, spm).
  final PackageSource source;

  /// The package name (e.g., "date-fns", "Alamofire", "com.squareup.okhttp3:okhttp").
  final String package;

  /// The version constraint (e.g., "^3.0.0", "~> 5.9", "4.12.0").
  final String version;

  /// Specific imports to generate bindings for.
  /// If empty, all public APIs are imported.
  final List<String> imports;

  /// Optional path to native source files.
  /// When set, the locator uses this path directly instead of auto-detecting.
  final String? sourcePath;

  /// Optional source URL for the package (e.g., git URL for CocoaPods/SPM).
  /// Used as fallback when `pod spec cat` fails.
  final String? sourceUrl;

  /// Custom type overrides: maps native type names to user-provided Dart file paths.
  /// When set, the generator emits an `import` for these types instead of auto-generating stubs.
  final Map<String, String> customTypes;

  /// Maven repository URLs for Gradle packages. Tried in order when downloading sources JARs.
  /// Defaults to Maven Central and Google Maven.
  final List<String> mavenRepositories;

  /// Default Maven repository URLs.
  static const defaultMavenRepositories = [
    'https://repo1.maven.org/maven2',
    'https://dl.google.com/dl/android/maven2',
  ];

  const PackageSpec({
    required this.source,
    required this.package,
    required this.version,
    this.imports = const [],
    this.sourcePath,
    this.sourceUrl,
    this.customTypes = const {},
    this.mavenRepositories = defaultMavenRepositories,
  });

  /// Whether this spec imports specific symbols or the entire package.
  bool get isSelectiveImport => imports.isNotEmpty;

  /// Returns a copy with the given fields replaced.
  PackageSpec copyWith(
      {String? sourcePath,
      String? sourceUrl,
      Map<String, String>? customTypes,
      List<String>? mavenRepositories}) {
    return PackageSpec(
      source: source,
      package: package,
      version: version,
      imports: imports,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      customTypes: customTypes ?? this.customTypes,
      mavenRepositories: mavenRepositories ?? this.mavenRepositories,
    );
  }

  @override
  String toString() => 'PackageSpec($source:$package@$version)';
}
