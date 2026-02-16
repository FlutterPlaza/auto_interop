import '../schema/unified_type_schema.dart';

/// Base class for native package API parsers.
///
/// Each parser reads source files from a specific platform (npm, cocoapods,
/// gradle) and produces a [UnifiedTypeSchema] as output.
abstract class ParserBase {
  /// Parses the given source content and returns a [UnifiedTypeSchema].
  ///
  /// [content] is the raw text content of the source file(s).
  /// [packageName] is the name of the native package.
  /// [version] is the package version.
  UnifiedTypeSchema parse({
    required String content,
    required String packageName,
    required String version,
  });

  /// Parses multiple source files and merges the results.
  ///
  /// [files] maps file paths to their content.
  UnifiedTypeSchema parseFiles({
    required Map<String, String> files,
    required String packageName,
    required String version,
  }) {
    final schemas = <UnifiedTypeSchema>[];
    for (final entry in files.entries) {
      schemas.add(parse(
        content: entry.value,
        packageName: packageName,
        version: version,
      ));
    }
    return mergeSchemas(schemas, packageName: packageName, version: version);
  }

  /// Merges multiple schemas into one.
  UnifiedTypeSchema mergeSchemas(
    List<UnifiedTypeSchema> schemas, {
    required String packageName,
    required String version,
  }) {
    if (schemas.isEmpty) {
      return UnifiedTypeSchema(
        package: packageName,
        source: source,
        version: version,
      );
    }
    if (schemas.length == 1) return schemas.first;

    final classes = <UtsClass>[];
    final functions = <UtsMethod>[];
    final types = <UtsClass>[];
    final enums = <UtsEnum>[];
    final seenNames = <String>{};

    for (final schema in schemas) {
      for (final cls in schema.classes) {
        if (seenNames.add(cls.name)) classes.add(cls);
      }
      for (final fn in schema.functions) {
        if (seenNames.add(fn.name)) functions.add(fn);
      }
      for (final type in schema.types) {
        if (seenNames.add(type.name)) types.add(type);
      }
      for (final e in schema.enums) {
        if (seenNames.add(e.name)) enums.add(e);
      }
    }

    return UnifiedTypeSchema(
      package: packageName,
      source: source,
      version: version,
      classes: classes,
      functions: functions,
      types: types,
      enums: enums,
    );
  }

  /// The source type this parser handles.
  PackageSource get source;
}
