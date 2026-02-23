import '../schema/unified_type_schema.dart';

/// Base class for code generators.
///
/// Generators consume a [UnifiedTypeSchema] and produce source code strings
/// for a specific platform/language.
abstract class GeneratorBase {
  /// Generates source code from the given [schema].
  ///
  /// Returns a map of file paths (relative) to their generated contents.
  /// [customTypes] maps native type names to user-provided Dart file paths
  /// (only used by DartGenerator).
  Map<String, String> generate(UnifiedTypeSchema schema,
      {Map<String, String> customTypes = const {}});
}
