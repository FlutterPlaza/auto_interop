import 'package:json_annotation/json_annotation.dart';

part 'uts_enum.g.dart';

/// Represents a single enum value/case.
@JsonSerializable(explicitToJson: true)
class UtsEnumValue {
  /// The enum value name.
  final String name;

  /// The raw value (for string/numeric enums), if any.
  final Object? rawValue;

  /// Documentation for this enum value.
  final String? documentation;

  const UtsEnumValue({
    required this.name,
    this.rawValue,
    this.documentation,
  });

  factory UtsEnumValue.fromJson(Map<String, dynamic> json) =>
      _$UtsEnumValueFromJson(json);

  Map<String, dynamic> toJson() => _$UtsEnumValueToJson(this);

  @override
  String toString() => 'UtsEnumValue($name)';
}

/// Represents an enum in the Unified Type Schema.
@JsonSerializable(explicitToJson: true)
class UtsEnum {
  /// The enum name.
  final String name;

  /// The enum values/cases.
  final List<UtsEnumValue> values;

  /// Documentation for this enum.
  final String? documentation;

  const UtsEnum({
    required this.name,
    this.values = const [],
    this.documentation,
  });

  factory UtsEnum.fromJson(Map<String, dynamic> json) =>
      _$UtsEnumFromJson(json);

  Map<String, dynamic> toJson() => _$UtsEnumToJson(this);

  @override
  String toString() => 'UtsEnum($name)';
}
