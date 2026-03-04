// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uts_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UtsType _$UtsTypeFromJson(Map<String, dynamic> json) => UtsType(
      kind: $enumDecode(_$UtsTypeKindEnumMap, json['kind']),
      name: json['name'] as String,
      nullable: json['nullable'] as bool? ?? false,
      ref: json['ref'] as String?,
      typeArguments: (json['typeArguments'] as List<dynamic>?)
          ?.map((e) => UtsType.fromJson(e as Map<String, dynamic>))
          .toList(),
      parameterTypes: (json['parameterTypes'] as List<dynamic>?)
          ?.map((e) => UtsType.fromJson(e as Map<String, dynamic>))
          .toList(),
      returnType: json['returnType'] == null
          ? null
          : UtsType.fromJson(json['returnType'] as Map<String, dynamic>),
      nativeName: json['nativeName'] as String?,
    );

Map<String, dynamic> _$UtsTypeToJson(UtsType instance) {
  final json = <String, dynamic>{
    'kind': _$UtsTypeKindEnumMap[instance.kind]!,
    'name': instance.name,
    'nullable': instance.nullable,
    'ref': instance.ref,
    'typeArguments': instance.typeArguments?.map((e) => e.toJson()).toList(),
    'parameterTypes': instance.parameterTypes?.map((e) => e.toJson()).toList(),
    'returnType': instance.returnType?.toJson(),
  };
  if (instance.nativeName != null) {
    json['nativeName'] = instance.nativeName;
  }
  return json;
}

const _$UtsTypeKindEnumMap = {
  UtsTypeKind.primitive: 'primitive',
  UtsTypeKind.object: 'object',
  UtsTypeKind.list: 'list',
  UtsTypeKind.map: 'map',
  UtsTypeKind.callback: 'callback',
  UtsTypeKind.stream: 'stream',
  UtsTypeKind.future: 'future',
  UtsTypeKind.nativeObject: 'nativeObject',
  UtsTypeKind.enumType: 'enumType',
  UtsTypeKind.voidType: 'voidType',
  UtsTypeKind.dynamic: 'dynamic',
};
