// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_type_schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

const _$PackageSourceEnumMap = {
  PackageSource.npm: 'npm',
  PackageSource.cocoapods: 'cocoapods',
  PackageSource.gradle: 'gradle',
  PackageSource.spm: 'spm',
};

UnifiedTypeSchema _$UnifiedTypeSchemaFromJson(Map<String, dynamic> json) =>
    UnifiedTypeSchema(
      package: json['package'] as String,
      source: $enumDecode(_$PackageSourceEnumMap, json['source']),
      version: json['version'] as String,
      classes: (json['classes'] as List<dynamic>?)
              ?.map((e) => UtsClass.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      functions: (json['functions'] as List<dynamic>?)
              ?.map((e) => UtsMethod.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      types: (json['types'] as List<dynamic>?)
              ?.map((e) => UtsClass.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      enums: (json['enums'] as List<dynamic>?)
              ?.map((e) => UtsEnum.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nativeImports: (json['nativeImports'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      nativeFields: (json['nativeFields'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
    );

Map<String, dynamic> _$UnifiedTypeSchemaToJson(UnifiedTypeSchema instance) =>
    <String, dynamic>{
      'package': instance.package,
      'source': _$PackageSourceEnumMap[instance.source]!,
      'version': instance.version,
      'classes': instance.classes.map((e) => e.toJson()).toList(),
      'functions': instance.functions.map((e) => e.toJson()).toList(),
      'types': instance.types.map((e) => e.toJson()).toList(),
      'enums': instance.enums.map((e) => e.toJson()).toList(),
      if (instance.nativeImports != null)
        'nativeImports': instance.nativeImports,
      if (instance.nativeFields != null) 'nativeFields': instance.nativeFields,
    };
