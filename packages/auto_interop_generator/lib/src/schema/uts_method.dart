import 'package:json_annotation/json_annotation.dart';

import 'uts_type.dart';

part 'uts_method.g.dart';

/// Represents a parameter in a UTS method.
@JsonSerializable(explicitToJson: true)
class UtsParameter {
  /// The parameter name.
  final String name;

  /// The parameter type.
  final UtsType type;

  /// Whether this parameter is optional.
  final bool isOptional;

  /// Whether this is a named parameter.
  final bool isNamed;

  /// Default value as a string expression, if any.
  final String? defaultValue;

  /// Documentation for this parameter.
  final String? documentation;

  /// Native external parameter label (Swift only).
  /// `"_"` means unlabeled first parameter, `null` means use param name.
  final String? nativeLabel;

  /// Native wrapper type for conversion.
  /// When set, generates `NativeType(channelValue)` conversion in glue code.
  final String? nativeType;

  const UtsParameter({
    required this.name,
    required this.type,
    this.isOptional = false,
    this.isNamed = false,
    this.defaultValue,
    this.documentation,
    this.nativeLabel,
    this.nativeType,
  });

  factory UtsParameter.fromJson(Map<String, dynamic> json) =>
      _$UtsParameterFromJson(json);

  Map<String, dynamic> toJson() => _$UtsParameterToJson(this);

  @override
  String toString() => 'UtsParameter($name: ${type.toDartType()})';
}

/// Represents a method/function in the Unified Type Schema.
@JsonSerializable(explicitToJson: true)
class UtsMethod {
  /// The method name.
  final String name;

  /// Whether this is a static method.
  final bool isStatic;

  /// Whether this method is asynchronous.
  final bool isAsync;

  /// The method parameters.
  final List<UtsParameter> parameters;

  /// The return type.
  final UtsType returnType;

  /// Documentation for this method.
  final String? documentation;

  /// Platform-specific native method body override.
  /// When present, the generator uses this code verbatim instead of
  /// auto-generating the native call. Keys are platform names:
  /// 'swift', 'kotlin', 'js'.
  final Map<String, String>? nativeBody;

  const UtsMethod({
    required this.name,
    this.isStatic = false,
    this.isAsync = false,
    this.parameters = const [],
    required this.returnType,
    this.documentation,
    this.nativeBody,
  });

  factory UtsMethod.fromJson(Map<String, dynamic> json) =>
      _$UtsMethodFromJson(json);

  Map<String, dynamic> toJson() => _$UtsMethodToJson(this);

  @override
  String toString() => 'UtsMethod($name)';
}
