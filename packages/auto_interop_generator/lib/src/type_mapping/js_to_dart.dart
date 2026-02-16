import '../schema/uts_type.dart';
import 'type_mapper.dart';

/// Maps JavaScript/TypeScript types to Dart UTS types.
class JsToDartMapper {
  /// Registers all JS/TS → Dart type mappings on the given [TypeMapper].
  void registerAll(TypeMapper mapper) {
    // Numeric types
    mapper.register(
      'number',
      TypeMapping(
        sourceType: 'number',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'number:int',
      TypeMapping(
        sourceType: 'number:int',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );

    // String
    mapper.register(
      'string',
      TypeMapping(
        sourceType: 'string',
        dartType: UtsType.primitive('String'),
        encoding: ChannelEncoding.standard,
      ),
    );

    // Boolean
    mapper.register(
      'boolean',
      TypeMapping(
        sourceType: 'boolean',
        dartType: UtsType.primitive('bool'),
        encoding: ChannelEncoding.standard,
      ),
    );

    // Date
    mapper.register(
      'Date',
      TypeMapping(
        sourceType: 'Date',
        dartType: UtsType.primitive('DateTime'),
        encoding: ChannelEncoding.iso8601String,
      ),
    );

    // Null/undefined
    mapper.register(
      'null',
      TypeMapping(
        sourceType: 'null',
        dartType: UtsType.voidType(),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'undefined',
      TypeMapping(
        sourceType: 'undefined',
        dartType: UtsType.voidType(),
        encoding: ChannelEncoding.standard,
      ),
    );

    // void
    mapper.register(
      'void',
      TypeMapping(
        sourceType: 'void',
        dartType: UtsType.voidType(),
        encoding: ChannelEncoding.standard,
      ),
    );

    // any
    mapper.register(
      'any',
      TypeMapping(
        sourceType: 'any',
        dartType: UtsType.dynamicType(),
        encoding: ChannelEncoding.standard,
      ),
    );

    // unknown
    mapper.register(
      'unknown',
      TypeMapping(
        sourceType: 'unknown',
        dartType: UtsType.dynamicType(),
        encoding: ChannelEncoding.standard,
      ),
    );

    // Buffer
    mapper.register(
      'Buffer',
      TypeMapping(
        sourceType: 'Buffer',
        dartType: UtsType.primitive('Uint8List'),
        encoding: ChannelEncoding.byteArray,
      ),
    );
    mapper.register(
      'ArrayBuffer',
      TypeMapping(
        sourceType: 'ArrayBuffer',
        dartType: UtsType.primitive('Uint8List'),
        encoding: ChannelEncoding.byteArray,
      ),
    );
    mapper.register(
      'Uint8Array',
      TypeMapping(
        sourceType: 'Uint8Array',
        dartType: UtsType.primitive('Uint8List'),
        encoding: ChannelEncoding.byteArray,
      ),
    );
  }

  /// Maps a JS/TS type string to a Dart [UtsType].
  ///
  /// Handles generic types like `Array<T>`, `Map<K,V>`, `Promise<T>`,
  /// `ReadableStream<T>`.
  UtsType mapType(String jsType, {bool nullable = false}) {
    // Handle nullable wrapper
    if (jsType.endsWith(' | null') || jsType.endsWith(' | undefined')) {
      final baseType =
          jsType.replaceAll(' | null', '').replaceAll(' | undefined', '');
      return mapType(baseType, nullable: true);
    }

    // Handle Array<T>
    if (jsType.startsWith('Array<') && jsType.endsWith('>')) {
      final inner = jsType.substring(6, jsType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }
    if (jsType.endsWith('[]')) {
      final inner = jsType.substring(0, jsType.length - 2);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle Promise<T>
    if (jsType.startsWith('Promise<') && jsType.endsWith('>')) {
      final inner = jsType.substring(8, jsType.length - 1);
      return UtsType.future(mapType(inner), nullable: nullable);
    }

    // Handle ReadableStream<T>
    if (jsType.startsWith('ReadableStream<') && jsType.endsWith('>')) {
      final inner = jsType.substring(15, jsType.length - 1);
      return UtsType.stream(mapType(inner), nullable: nullable);
    }

    // Handle Map/Record<K, V>
    if ((jsType.startsWith('Map<') || jsType.startsWith('Record<')) &&
        jsType.endsWith('>')) {
      final start = jsType.indexOf('<') + 1;
      final inner = jsType.substring(start, jsType.length - 1);
      final parts = _splitGenericArgs(inner);
      if (parts.length == 2) {
        return UtsType.map(
          mapType(parts[0].trim()),
          mapType(parts[1].trim()),
          nullable: nullable,
        );
      }
    }

    // Primitive mappings
    switch (jsType) {
      case 'number':
        return UtsType.primitive('double', nullable: nullable);
      case 'string':
        return UtsType.primitive('String', nullable: nullable);
      case 'boolean':
        return UtsType.primitive('bool', nullable: nullable);
      case 'Date':
        return UtsType.primitive('DateTime', nullable: nullable);
      case 'void':
        return UtsType.voidType();
      case 'null':
      case 'undefined':
        return UtsType.voidType();
      case 'any':
      case 'unknown':
        return UtsType.dynamicType(nullable: nullable);
      case 'Buffer':
      case 'ArrayBuffer':
      case 'Uint8Array':
        return UtsType.primitive('Uint8List', nullable: nullable);
      default:
        // Assume it's a named object/class type
        return UtsType.object(jsType, nullable: nullable);
    }
  }

  /// Splits generic type arguments by comma, respecting nested generics.
  List<String> _splitGenericArgs(String args) {
    final result = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '<':
          depth++;
          break;
        case '>':
          depth--;
          break;
        case ',':
          if (depth == 0) {
            result.add(args.substring(start, i));
            start = i + 1;
          }
          break;
      }
    }
    result.add(args.substring(start));
    return result;
  }
}
