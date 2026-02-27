// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uts_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UtsParameter _$UtsParameterFromJson(Map<String, dynamic> json) => UtsParameter(
      name: json['name'] as String,
      type: UtsType.fromJson(json['type'] as Map<String, dynamic>),
      isOptional: json['isOptional'] as bool? ?? false,
      isNamed: json['isNamed'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
      documentation: json['documentation'] as String?,
      nativeLabel: json['nativeLabel'] as String?,
      nativeType: json['nativeType'] as String?,
    );

Map<String, dynamic> _$UtsParameterToJson(UtsParameter instance) {
  final json = <String, dynamic>{
    'name': instance.name,
    'type': instance.type.toJson(),
    'isOptional': instance.isOptional,
    'isNamed': instance.isNamed,
    'defaultValue': instance.defaultValue,
    'documentation': instance.documentation,
  };
  if (instance.nativeLabel != null) {
    json['nativeLabel'] = instance.nativeLabel;
  }
  if (instance.nativeType != null) {
    json['nativeType'] = instance.nativeType;
  }
  return json;
}

UtsMethod _$UtsMethodFromJson(Map<String, dynamic> json) => UtsMethod(
      name: json['name'] as String,
      isStatic: json['isStatic'] as bool? ?? false,
      isAsync: json['isAsync'] as bool? ?? false,
      parameters: (json['parameters'] as List<dynamic>?)
              ?.map((e) => UtsParameter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      returnType: UtsType.fromJson(json['returnType'] as Map<String, dynamic>),
      documentation: json['documentation'] as String?,
      nativeBody: (json['nativeBody'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as String)),
    );

Map<String, dynamic> _$UtsMethodToJson(UtsMethod instance) {
  final json = <String, dynamic>{
    'name': instance.name,
    'isStatic': instance.isStatic,
    'isAsync': instance.isAsync,
    'parameters': instance.parameters.map((e) => e.toJson()).toList(),
    'returnType': instance.returnType.toJson(),
    'documentation': instance.documentation,
  };
  if (instance.nativeBody != null) {
    json['nativeBody'] = instance.nativeBody;
  }
  return json;
}
