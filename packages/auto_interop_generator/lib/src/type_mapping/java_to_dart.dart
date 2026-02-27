import '../schema/uts_type.dart';
import 'type_mapper.dart';

/// Maps Java types to Dart UTS types.
class JavaToDartMapper {
  /// Registers all Java → Dart type mappings on the given [TypeMapper].
  void registerAll(TypeMapper mapper) {
    mapper.register(
      'Java:int',
      TypeMapping(
        sourceType: 'int',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:Integer',
      TypeMapping(
        sourceType: 'Integer',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:long',
      TypeMapping(
        sourceType: 'long',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:Long',
      TypeMapping(
        sourceType: 'Long',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:double',
      TypeMapping(
        sourceType: 'double',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:Double',
      TypeMapping(
        sourceType: 'Double',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:float',
      TypeMapping(
        sourceType: 'float',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:Float',
      TypeMapping(
        sourceType: 'Float',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:String',
      TypeMapping(
        sourceType: 'String',
        dartType: UtsType.primitive('String'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:boolean',
      TypeMapping(
        sourceType: 'boolean',
        dartType: UtsType.primitive('bool'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:Boolean',
      TypeMapping(
        sourceType: 'Boolean',
        dartType: UtsType.primitive('bool'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:byte[]',
      TypeMapping(
        sourceType: 'byte[]',
        dartType: UtsType.primitive('Uint8List'),
        encoding: ChannelEncoding.byteArray,
      ),
    );
    mapper.register(
      'Java:void',
      TypeMapping(
        sourceType: 'void',
        dartType: UtsType.voidType(),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Java:Object',
      TypeMapping(
        sourceType: 'Object',
        dartType: UtsType.dynamicType(),
        encoding: ChannelEncoding.standard,
      ),
    );
  }

  /// Maps a Java type string to a Dart [UtsType].
  UtsType mapType(String javaType, {bool nullable = false}) {
    // Handle Java Optional<T>
    if (javaType.startsWith('Optional<') && javaType.endsWith('>')) {
      final inner = javaType.substring(9, javaType.length - 1);
      return mapType(inner, nullable: true);
    }

    // Handle @Nullable annotation (handled externally, nullable param)

    // Handle List<T> / ArrayList<T>
    if ((javaType.startsWith('List<') || javaType.startsWith('ArrayList<')) &&
        javaType.endsWith('>')) {
      final start = javaType.indexOf('<') + 1;
      final inner = javaType.substring(start, javaType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle Map<K, V> / HashMap<K, V>
    if ((javaType.startsWith('Map<') || javaType.startsWith('HashMap<')) &&
        javaType.endsWith('>')) {
      final start = javaType.indexOf('<') + 1;
      final inner = javaType.substring(start, javaType.length - 1);
      final parts = _splitGenericArgs(inner);
      if (parts.length == 2) {
        return UtsType.map(
          mapType(parts[0].trim()),
          mapType(parts[1].trim()),
          nullable: nullable,
        );
      }
    }

    // Handle Set<T> / HashSet<T> → List<T>
    if ((javaType.startsWith('Set<') || javaType.startsWith('HashSet<')) &&
        javaType.endsWith('>')) {
      final start = javaType.indexOf('<') + 1;
      final inner = javaType.substring(start, javaType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle arrays (T[])
    if (javaType.endsWith('[]')) {
      final inner = javaType.substring(0, javaType.length - 2);
      if (inner == 'byte') {
        return UtsType.primitive('Uint8List', nullable: nullable);
      }
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Primitive mappings
    switch (javaType) {
      case 'int':
      case 'Integer':
      case 'short':
      case 'Short':
      case 'byte':
      case 'Byte':
        return UtsType.primitive('int', nullable: nullable);
      case 'long':
      case 'Long':
        return UtsType.primitive('int', nullable: nullable);
      case 'double':
      case 'Double':
      case 'float':
      case 'Float':
        return UtsType.primitive('double', nullable: nullable);
      case 'String':
        return UtsType.primitive('String', nullable: nullable);
      case 'boolean':
      case 'Boolean':
        return UtsType.primitive('bool', nullable: nullable);
      case 'URI':
      case 'URL':
      case 'java.net.URI':
      case 'java.net.URL':
        return UtsType.primitive('Uri', nullable: nullable);
      case 'Duration':
        return UtsType.primitive('Duration', nullable: nullable);
      case 'BigDecimal':
        return UtsType.primitive('double', nullable: nullable);
      case 'BigInteger':
        return UtsType.primitive('int', nullable: nullable);
      case 'UUID':
      case 'CharSequence':
        return UtsType.primitive('String', nullable: nullable);
      case 'void':
      case 'Void':
        return UtsType.voidType();
      case 'Object':
        return UtsType.dynamicType(nullable: nullable);
      // Native object handles — opaque platform types
      case 'Exception':
      case 'Throwable':
      case 'IOException':
      case 'InputStream':
      case 'OutputStream':
      case 'Context':
        return UtsType.nativeObject(javaType, nullable: nullable);
      default:
        return UtsType.object(javaType, nullable: nullable);
    }
  }

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
