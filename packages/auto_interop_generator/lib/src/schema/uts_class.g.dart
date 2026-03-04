// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'uts_class.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UtsField _$UtsFieldFromJson(Map<String, dynamic> json) => UtsField(
      name: json['name'] as String,
      type: UtsType.fromJson(json['type'] as Map<String, dynamic>),
      nullable: json['nullable'] as bool? ?? false,
      isReadOnly: json['isReadOnly'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
      documentation: json['documentation'] as String?,
    );

Map<String, dynamic> _$UtsFieldToJson(UtsField instance) => <String, dynamic>{
      'name': instance.name,
      'type': instance.type.toJson(),
      'nullable': instance.nullable,
      'isReadOnly': instance.isReadOnly,
      'defaultValue': instance.defaultValue,
      'documentation': instance.documentation,
    };

UtsClass _$UtsClassFromJson(Map<String, dynamic> json) => UtsClass(
      name: json['name'] as String,
      nativeName: json['nativeName'] as String?,
      kind: $enumDecodeNullable(_$UtsClassKindEnumMap, json['kind']) ??
          UtsClassKind.concreteClass,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((e) => UtsField.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      methods: (json['methods'] as List<dynamic>?)
              ?.map((e) => UtsMethod.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      superclass: json['superclass'] as String?,
      interfaces: (json['interfaces'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sealedSubclasses: (json['sealedSubclasses'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      documentation: json['documentation'] as String?,
      constructorParameters: (json['constructorParameters'] as List<dynamic>?)
          ?.map((e) => UtsParameter.fromJson(e as Map<String, dynamic>))
          .toList(),
      constructorThrows: json['constructorThrows'] as bool? ?? false,
    );

const _$UtsClassKindEnumMap = {
  UtsClassKind.concreteClass: 'concreteClass',
  UtsClassKind.abstractClass: 'abstractClass',
  UtsClassKind.dataClass: 'dataClass',
  UtsClassKind.sealedClass: 'sealedClass',
};
