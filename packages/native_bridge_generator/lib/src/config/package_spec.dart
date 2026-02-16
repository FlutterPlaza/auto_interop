import '../schema/unified_type_schema.dart' show PackageSource;

/// Specifies a native package to generate bindings for.
///
/// This is the parsed representation of a single entry in the
/// `native_packages` list in `native_bridge.yaml`.
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

  const PackageSpec({
    required this.source,
    required this.package,
    required this.version,
    this.imports = const [],
  });

  /// Whether this spec imports specific symbols or the entire package.
  bool get isSelectiveImport => imports.isNotEmpty;

  @override
  String toString() => 'PackageSpec($source:$package@$version)';
}
