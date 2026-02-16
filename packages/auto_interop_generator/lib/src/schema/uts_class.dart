import 'package:json_annotation/json_annotation.dart';

import 'uts_method.dart';
import 'uts_type.dart';

part 'uts_class.g.dart';

/// Represents a field in a UTS class/struct.
@JsonSerializable(explicitToJson: true)
class UtsField {
  /// The field name.
  final String name;

  /// The field type.
  final UtsType type;

  /// Whether this field is nullable.
  final bool nullable;

  /// Whether this field is read-only.
  final bool isReadOnly;

  /// Default value as a string expression, if any.
  final String? defaultValue;

  /// Documentation for this field.
  final String? documentation;

  const UtsField({
    required this.name,
    required this.type,
    this.nullable = false,
    this.isReadOnly = false,
    this.defaultValue,
    this.documentation,
  });

  factory UtsField.fromJson(Map<String, dynamic> json) =>
      _$UtsFieldFromJson(json);

  Map<String, dynamic> toJson() => _$UtsFieldToJson(this);

  @override
  String toString() => 'UtsField($name: ${type.toDartType()})';
}

/// The kind of a UTS class definition.
enum UtsClassKind {
  /// A concrete class.
  concreteClass,

  /// An abstract class / interface / protocol.
  abstractClass,

  /// A data class / struct.
  dataClass,

  /// A sealed class (Kotlin sealed, Swift enum with associated values).
  sealedClass,
}

/// Represents a class/struct/interface in the Unified Type Schema.
@JsonSerializable(explicitToJson: true)
class UtsClass {
  /// The class name.
  final String name;

  /// The kind of class.
  final UtsClassKind kind;

  /// Fields/properties of this class.
  final List<UtsField> fields;

  /// Methods of this class.
  final List<UtsMethod> methods;

  /// Superclass name, if any.
  final String? superclass;

  /// Implemented interfaces/protocols.
  final List<String> interfaces;

  /// For sealed classes, the subclass names.
  final List<String> sealedSubclasses;

  /// Documentation for this class.
  final String? documentation;

  const UtsClass({
    required this.name,
    this.kind = UtsClassKind.concreteClass,
    this.fields = const [],
    this.methods = const [],
    this.superclass,
    this.interfaces = const [],
    this.sealedSubclasses = const [],
    this.documentation,
  });

  factory UtsClass.fromJson(Map<String, dynamic> json) =>
      _$UtsClassFromJson(json);

  Map<String, dynamic> toJson() => _$UtsClassToJson(this);

  @override
  String toString() => 'UtsClass($name)';
}
