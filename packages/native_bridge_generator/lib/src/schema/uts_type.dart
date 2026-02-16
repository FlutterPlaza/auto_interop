import 'package:json_annotation/json_annotation.dart';

part 'uts_type.g.dart';

/// The kind of a UTS type.
enum UtsTypeKind {
  primitive,
  object,
  list,
  map,
  callback,
  stream,
  future,
  nativeObject,
  enumType,
  voidType,
  dynamic,
}

/// Represents a type in the Unified Type Schema.
///
/// This is the core type representation that all parsers produce and all
/// generators consume. It supports primitives, objects, collections,
/// callbacks, async types, and opaque native handles.
@JsonSerializable(explicitToJson: true)
class UtsType {
  /// The kind of this type (primitive, object, list, etc.).
  final UtsTypeKind kind;

  /// The name of this type (e.g., 'String', 'int', 'DateTime').
  /// For primitives, this is the Dart type name.
  /// For objects, this is the class/struct name.
  final String name;

  /// Whether this type is nullable.
  final bool nullable;

  /// For object types, a reference to the type definition name.
  final String? ref;

  /// For generic types (List, Map, Future, Stream), the type arguments.
  final List<UtsType>? typeArguments;

  /// For callback types, the parameter types.
  final List<UtsType>? parameterTypes;

  /// For callback types, the return type.
  final UtsType? returnType;

  const UtsType({
    required this.kind,
    required this.name,
    this.nullable = false,
    this.ref,
    this.typeArguments,
    this.parameterTypes,
    this.returnType,
  });

  /// Creates a primitive type (String, int, double, bool, DateTime).
  factory UtsType.primitive(String name, {bool nullable = false}) => UtsType(
        kind: UtsTypeKind.primitive,
        name: name,
        nullable: nullable,
      );

  /// Creates a void type.
  factory UtsType.voidType() => const UtsType(
        kind: UtsTypeKind.voidType,
        name: 'void',
      );

  /// Creates a dynamic type.
  factory UtsType.dynamicType({bool nullable = false}) => UtsType(
        kind: UtsTypeKind.dynamic,
        name: 'dynamic',
        nullable: nullable,
      );

  /// Creates an object reference type.
  factory UtsType.object(String name, {bool nullable = false}) => UtsType(
        kind: UtsTypeKind.object,
        name: name,
        nullable: nullable,
        ref: name,
      );

  /// Creates a List<T> type.
  factory UtsType.list(UtsType elementType, {bool nullable = false}) => UtsType(
        kind: UtsTypeKind.list,
        name: 'List',
        nullable: nullable,
        typeArguments: [elementType],
      );

  /// Creates a Map<K, V> type.
  factory UtsType.map(UtsType keyType, UtsType valueType,
          {bool nullable = false}) =>
      UtsType(
        kind: UtsTypeKind.map,
        name: 'Map',
        nullable: nullable,
        typeArguments: [keyType, valueType],
      );

  /// Creates a Future<T> type.
  factory UtsType.future(UtsType valueType, {bool nullable = false}) =>
      UtsType(
        kind: UtsTypeKind.future,
        name: 'Future',
        nullable: nullable,
        typeArguments: [valueType],
      );

  /// Creates a Stream<T> type.
  factory UtsType.stream(UtsType valueType, {bool nullable = false}) =>
      UtsType(
        kind: UtsTypeKind.stream,
        name: 'Stream',
        nullable: nullable,
        typeArguments: [valueType],
      );

  /// Creates a callback/function type.
  factory UtsType.callback({
    required List<UtsType> parameterTypes,
    required UtsType returnType,
    bool nullable = false,
  }) =>
      UtsType(
        kind: UtsTypeKind.callback,
        name: 'Function',
        nullable: nullable,
        parameterTypes: parameterTypes,
        returnType: returnType,
      );

  /// Creates an opaque native object handle type.
  factory UtsType.nativeObject(String name, {bool nullable = false}) =>
      UtsType(
        kind: UtsTypeKind.nativeObject,
        name: name,
        nullable: nullable,
        ref: name,
      );

  /// Creates an enum reference type.
  factory UtsType.enumType(String name, {bool nullable = false}) => UtsType(
        kind: UtsTypeKind.enumType,
        name: name,
        nullable: nullable,
        ref: name,
      );

  /// Returns a nullable copy of this type.
  UtsType asNullable() => UtsType(
        kind: kind,
        name: name,
        nullable: true,
        ref: ref,
        typeArguments: typeArguments,
        parameterTypes: parameterTypes,
        returnType: returnType,
      );

  /// Returns the Dart type string representation.
  String toDartType() {
    final suffix = nullable ? '?' : '';
    switch (kind) {
      case UtsTypeKind.primitive:
        return '$name$suffix';
      case UtsTypeKind.object:
        return '$name$suffix';
      case UtsTypeKind.list:
        final elementType = typeArguments?.first.toDartType() ?? 'dynamic';
        return 'List<$elementType>$suffix';
      case UtsTypeKind.map:
        final keyType = typeArguments?.first.toDartType() ?? 'dynamic';
        final valueType =
            typeArguments != null && typeArguments!.length > 1
                ? typeArguments![1].toDartType()
                : 'dynamic';
        return 'Map<$keyType, $valueType>$suffix';
      case UtsTypeKind.future:
        final valueType = typeArguments?.first.toDartType() ?? 'void';
        return 'Future<$valueType>$suffix';
      case UtsTypeKind.stream:
        final valueType = typeArguments?.first.toDartType() ?? 'dynamic';
        return 'Stream<$valueType>$suffix';
      case UtsTypeKind.callback:
        final params =
            parameterTypes?.map((t) => t.toDartType()).join(', ') ?? '';
        final ret = returnType?.toDartType() ?? 'void';
        return '$ret Function($params)$suffix';
      case UtsTypeKind.nativeObject:
        return 'NativeObject<$name>$suffix';
      case UtsTypeKind.enumType:
        return '$name$suffix';
      case UtsTypeKind.voidType:
        return 'void';
      case UtsTypeKind.dynamic:
        return 'dynamic';
    }
  }

  factory UtsType.fromJson(Map<String, dynamic> json) =>
      _$UtsTypeFromJson(json);

  Map<String, dynamic> toJson() => _$UtsTypeToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UtsType &&
          kind == other.kind &&
          name == other.name &&
          nullable == other.nullable &&
          ref == other.ref;

  @override
  int get hashCode => Object.hash(kind, name, nullable, ref);

  @override
  String toString() => 'UtsType(${toDartType()})';
}
