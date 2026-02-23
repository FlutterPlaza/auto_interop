import '../schema/uts_type.dart';
import 'type_mapper.dart';

/// Maps Kotlin types to Dart UTS types.
class KotlinToDartMapper {
  /// Registers all Kotlin → Dart type mappings on the given [TypeMapper].
  void registerAll(TypeMapper mapper) {
    mapper.register(
      'Kotlin:Int',
      TypeMapping(
        sourceType: 'Int',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Kotlin:Long',
      TypeMapping(
        sourceType: 'Long',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Kotlin:Double',
      TypeMapping(
        sourceType: 'Double',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Kotlin:Float',
      TypeMapping(
        sourceType: 'Float',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Kotlin:String',
      TypeMapping(
        sourceType: 'String',
        dartType: UtsType.primitive('String'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Kotlin:Boolean',
      TypeMapping(
        sourceType: 'Boolean',
        dartType: UtsType.primitive('bool'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Kotlin:ByteArray',
      TypeMapping(
        sourceType: 'ByteArray',
        dartType: UtsType.primitive('Uint8List'),
        encoding: ChannelEncoding.byteArray,
      ),
    );
    mapper.register(
      'Kotlin:Unit',
      TypeMapping(
        sourceType: 'Unit',
        dartType: UtsType.voidType(),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Kotlin:Any',
      TypeMapping(
        sourceType: 'Any',
        dartType: UtsType.dynamicType(),
        encoding: ChannelEncoding.standard,
      ),
    );
  }

  /// Maps a Kotlin type string to a Dart [UtsType].
  UtsType mapType(String kotlinType, {bool nullable = false}) {
    // Handle Kotlin nullable (T?)
    if (kotlinType.endsWith('?')) {
      final inner = kotlinType.substring(0, kotlinType.length - 1);
      return mapType(inner, nullable: true);
    }

    // Handle List<T>
    if (kotlinType.startsWith('List<') && kotlinType.endsWith('>')) {
      final inner = kotlinType.substring(5, kotlinType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle MutableList<T>
    if (kotlinType.startsWith('MutableList<') && kotlinType.endsWith('>')) {
      final inner = kotlinType.substring(12, kotlinType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle Map<K, V>
    if (kotlinType.startsWith('Map<') && kotlinType.endsWith('>')) {
      final inner = kotlinType.substring(4, kotlinType.length - 1);
      final parts = _splitGenericArgs(inner);
      if (parts.length == 2) {
        return UtsType.map(
          mapType(parts[0].trim()),
          mapType(parts[1].trim()),
          nullable: nullable,
        );
      }
    }

    // Handle Set<T> / MutableSet<T> → List<T>
    if (kotlinType.startsWith('Set<') && kotlinType.endsWith('>')) {
      final inner = kotlinType.substring(4, kotlinType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }
    if (kotlinType.startsWith('MutableSet<') && kotlinType.endsWith('>')) {
      final inner = kotlinType.substring(11, kotlinType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle Flow<T> → Stream<T>
    if (kotlinType.startsWith('Flow<') && kotlinType.endsWith('>')) {
      final inner = kotlinType.substring(5, kotlinType.length - 1);
      return UtsType.stream(mapType(inner), nullable: nullable);
    }

    // Handle Deferred<T> → Future<T>
    if (kotlinType.startsWith('Deferred<') && kotlinType.endsWith('>')) {
      final inner = kotlinType.substring(9, kotlinType.length - 1);
      return UtsType.future(mapType(inner), nullable: nullable);
    }

    // Primitive mappings
    switch (kotlinType) {
      case 'Int':
      case 'Short':
      case 'Byte':
        return UtsType.primitive('int', nullable: nullable);
      case 'Long':
        return UtsType.primitive('int', nullable: nullable);
      case 'Double':
      case 'Float':
        return UtsType.primitive('double', nullable: nullable);
      case 'String':
        return UtsType.primitive('String', nullable: nullable);
      case 'Boolean':
        return UtsType.primitive('bool', nullable: nullable);
      case 'ByteArray':
        return UtsType.primitive('Uint8List', nullable: nullable);
      case 'URI':
      case 'URL':
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
      case 'Unit':
      case 'Nothing':
        return UtsType.voidType();
      case 'Any':
        return UtsType.dynamicType(nullable: nullable);
      // Native object handles — opaque platform types
      case 'Exception':
      case 'Throwable':
      case 'IOException':
      case 'InputStream':
      case 'OutputStream':
      case 'Certificate':
      case 'SSLSocket':
      case 'Executor':
      case 'Context':
      case 'Handler':
        return UtsType.nativeObject(kotlinType, nullable: nullable);
      default:
        return UtsType.object(kotlinType, nullable: nullable);
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
