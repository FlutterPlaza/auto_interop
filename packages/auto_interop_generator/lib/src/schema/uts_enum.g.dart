// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uts_enum.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UtsEnumValue _$UtsEnumValueFromJson(Map<String, dynamic> json) => UtsEnumValue(
      name: json['name'] as String,
      rawValue: json['rawValue'],
      documentation: json['documentation'] as String?,
    );

Map<String, dynamic> _$UtsEnumValueToJson(UtsEnumValue instance) =>
    <String, dynamic>{
      'name': instance.name,
      'rawValue': instance.rawValue,
      'documentation': instance.documentation,
    };

UtsEnum _$UtsEnumFromJson(Map<String, dynamic> json) => UtsEnum(
      name: json['name'] as String,
      nativeName: json['nativeName'] as String?,
      values: (json['values'] as List<dynamic>?)
              ?.map((e) => UtsEnumValue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      documentation: json['documentation'] as String?,
    );

Map<String, dynamic> _$UtsEnumToJson(UtsEnum instance) {
  final json = <String, dynamic>{
    'name': instance.name,
    'values': instance.values.map((e) => e.toJson()).toList(),
    'documentation': instance.documentation,
  };
  if (instance.nativeName != null) {
    json['nativeName'] = instance.nativeName;
  }
  return json;
}
