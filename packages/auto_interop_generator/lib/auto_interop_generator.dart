/// Code generator for auto_interop.
///
/// Auto-generates type-safe Dart bindings from native package APIs.
/// Supports npm (TypeScript), CocoaPods/SPM (Swift), and Gradle (Kotlin).
library;

export 'src/analyzer/analyzer.dart';
export 'src/cache/build_cache.dart';
export 'src/cache/checksum.dart';
export 'src/cache/dependency_graph.dart';
export 'src/cache/parse_cache.dart';
export 'src/config/config_parser.dart';
export 'src/config/package_spec.dart';
export 'src/generators/dart_generator.dart';
export 'src/generators/generator_base.dart';
export 'src/generators/js_glue_generator.dart';
export 'src/generators/kotlin_glue_generator.dart';
export 'src/generators/swift_glue_generator.dart';
export 'src/parsers/parser_base.dart';
export 'src/parsers/gradle_parser.dart';
export 'src/parsers/npm_parser.dart';
export 'src/parsers/swift_parser.dart';
export 'src/resolver/native_source_locator.dart';
export 'src/resolver/override_loader.dart';
export 'src/resolver/registry_client.dart';
export 'src/resolver/schema_resolver.dart';
export 'src/schema/unified_type_schema.dart';
export 'src/type_definitions/type_definition_loader.dart';
