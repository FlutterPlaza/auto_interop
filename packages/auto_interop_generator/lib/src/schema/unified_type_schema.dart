import 'package:json_annotation/json_annotation.dart';

import 'uts_class.dart';
import 'uts_enum.dart';
import 'uts_method.dart';

export 'uts_class.dart';
export 'uts_enum.dart';
export 'uts_method.dart';
export 'uts_type.dart';

part 'unified_type_schema.g.dart';

/// The source platform of a native package.
enum PackageSource {
  npm,
  cocoapods,
  gradle,
  spm,
}

/// The Unified Type Schema — the intermediate representation that all parsers
/// output and all generators consume.
///
/// A UTS captures the complete public API surface of a native package in a
/// platform-agnostic format.
@JsonSerializable(explicitToJson: true)
class UnifiedTypeSchema {
  /// The package name.
  final String package;

  /// The source platform (npm, cocoapods, gradle, spm).
  final PackageSource source;

  /// The package version.
  final String version;

  /// Top-level classes/structs/interfaces defined by this package.
  final List<UtsClass> classes;

  /// Top-level standalone functions exported by this package.
  final List<UtsMethod> functions;

  /// Custom type definitions (data classes, option objects, etc.).
  final List<UtsClass> types;

  /// Enum definitions.
  final List<UtsEnum> enums;

  /// Platform-specific additional imports for nativeBody code.
  /// Keys are platform names (e.g. "swift", "kotlin"), values are import strings.
  final Map<String, List<String>>? nativeImports;

  /// Platform-specific additional instance fields for the plugin class.
  /// Keys are platform names, values are field declaration strings.
  final Map<String, List<String>>? nativeFields;

  const UnifiedTypeSchema({
    required this.package,
    required this.source,
    required this.version,
    this.classes = const [],
    this.functions = const [],
    this.types = const [],
    this.enums = const [],
    this.nativeImports,
    this.nativeFields,
  });

  /// Returns all type names that are defined in this schema.
  Set<String> get definedTypeNames {
    final names = <String>{};
    for (final cls in classes) {
      names.add(cls.name);
    }
    for (final type in types) {
      names.add(type.name);
    }
    for (final e in enums) {
      names.add(e.name);
    }
    return names;
  }

  /// Resolves a type reference name to its definition, if found.
  UtsClass? resolveType(String name) {
    for (final cls in classes) {
      if (cls.name == name) return cls;
    }
    for (final type in types) {
      if (type.name == name) return type;
    }
    return null;
  }

  /// Resolves an enum reference name to its definition, if found.
  UtsEnum? resolveEnum(String name) {
    for (final e in enums) {
      if (e.name == name) return e;
    }
    return null;
  }

  factory UnifiedTypeSchema.fromJson(Map<String, dynamic> json) =>
      _$UnifiedTypeSchemaFromJson(json);

  Map<String, dynamic> toJson() => _$UnifiedTypeSchemaToJson(this);

  @override
  String toString() =>
      'UnifiedTypeSchema($package@$version from $source, '
      '${classes.length} classes, ${functions.length} functions, '
      '${types.length} types, ${enums.length} enums)';
}
