import '../schema/uts_type.dart';

/// Encoding strategy for platform channel communication.
enum ChannelEncoding {
  standard,
  iso8601String,
  jsonMap,
  byteArray,
  asyncChannel,
  eventChannel,
  callbackChannel,
  opaqueHandle,
  taggedUnion,
  stringName,
}

/// A single type mapping result.
class TypeMapping {
  /// The source language type name.
  final String sourceType;

  /// The mapped Dart UTS type.
  final UtsType dartType;

  /// How this type is encoded over a platform channel.
  final ChannelEncoding encoding;

  const TypeMapping({
    required this.sourceType,
    required this.dartType,
    required this.encoding,
  });
}

/// Master type mapping registry.
///
/// Delegates to language-specific mappers (JS, Swift, Kotlin, Java) and
/// maintains the canonical mapping from source types to Dart UTS types.
class TypeMapper {
  final Map<String, TypeMapping> _mappings = {};

  /// Registers a type mapping.
  void register(String sourceType, TypeMapping mapping) {
    _mappings[sourceType] = mapping;
  }

  /// Looks up a mapping by source type name.
  TypeMapping? lookup(String sourceType) => _mappings[sourceType];

  /// Returns all registered mappings.
  Iterable<TypeMapping> get allMappings => _mappings.values;

  /// Returns all registered source type names.
  Set<String> get registeredTypes => _mappings.keys.toSet();
}
