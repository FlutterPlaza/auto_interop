import '../schema/uts_type.dart';
import 'type_mapper.dart';

/// Maps Swift types to Dart UTS types.
class SwiftToDartMapper {
  /// Registers all Swift → Dart type mappings on the given [TypeMapper].
  void registerAll(TypeMapper mapper) {
    mapper.register(
      'Swift:Int',
      TypeMapping(
        sourceType: 'Int',
        dartType: UtsType.primitive('int'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Swift:Double',
      TypeMapping(
        sourceType: 'Double',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Swift:Float',
      TypeMapping(
        sourceType: 'Float',
        dartType: UtsType.primitive('double'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Swift:String',
      TypeMapping(
        sourceType: 'String',
        dartType: UtsType.primitive('String'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Swift:Bool',
      TypeMapping(
        sourceType: 'Bool',
        dartType: UtsType.primitive('bool'),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Swift:Date',
      TypeMapping(
        sourceType: 'Date',
        dartType: UtsType.primitive('DateTime'),
        encoding: ChannelEncoding.iso8601String,
      ),
    );
    mapper.register(
      'Swift:Data',
      TypeMapping(
        sourceType: 'Data',
        dartType: UtsType.primitive('Uint8List'),
        encoding: ChannelEncoding.byteArray,
      ),
    );
    mapper.register(
      'Swift:Void',
      TypeMapping(
        sourceType: 'Void',
        dartType: UtsType.voidType(),
        encoding: ChannelEncoding.standard,
      ),
    );
    mapper.register(
      'Swift:Any',
      TypeMapping(
        sourceType: 'Any',
        dartType: UtsType.dynamicType(),
        encoding: ChannelEncoding.standard,
      ),
    );
  }

  /// Maps a Swift type string to a Dart [UtsType].
  UtsType mapType(String swiftType, {bool nullable = false}) {
    // Handle Swift optionals (T?)
    if (swiftType.endsWith('?')) {
      final inner = swiftType.substring(0, swiftType.length - 1);
      return mapType(inner, nullable: true);
    }

    // Handle Optional<T>
    if (swiftType.startsWith('Optional<') && swiftType.endsWith('>')) {
      final inner = swiftType.substring(9, swiftType.length - 1);
      return mapType(inner, nullable: true);
    }

    // Handle [T] → List<T>
    if (swiftType.startsWith('[') && swiftType.endsWith(']') && !swiftType.contains(':')) {
      final inner = swiftType.substring(1, swiftType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle Array<T>
    if (swiftType.startsWith('Array<') && swiftType.endsWith('>')) {
      final inner = swiftType.substring(6, swiftType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle [K: V] → Map<K, V>
    if (swiftType.startsWith('[') && swiftType.endsWith(']') && swiftType.contains(':')) {
      final inner = swiftType.substring(1, swiftType.length - 1);
      final colonIdx = inner.indexOf(':');
      final key = inner.substring(0, colonIdx).trim();
      final value = inner.substring(colonIdx + 1).trim();
      return UtsType.map(mapType(key), mapType(value), nullable: nullable);
    }

    // Handle Dictionary<K, V>
    if (swiftType.startsWith('Dictionary<') && swiftType.endsWith('>')) {
      final inner = swiftType.substring(11, swiftType.length - 1);
      final parts = _splitGenericArgs(inner);
      if (parts.length == 2) {
        return UtsType.map(
          mapType(parts[0].trim()),
          mapType(parts[1].trim()),
          nullable: nullable,
        );
      }
    }

    // Handle Set<T> → List<T> (Dart Set isn't channel-friendly)
    if (swiftType.startsWith('Set<') && swiftType.endsWith('>')) {
      final inner = swiftType.substring(4, swiftType.length - 1);
      return UtsType.list(mapType(inner), nullable: nullable);
    }

    // Handle Result<Success, Failure> → Future<Success>
    if (swiftType.startsWith('Result<') && swiftType.endsWith('>')) {
      final inner = swiftType.substring(7, swiftType.length - 1);
      final parts = _splitGenericArgs(inner);
      if (parts.isNotEmpty) {
        return UtsType.future(mapType(parts[0].trim()), nullable: nullable);
      }
    }

    // Handle async: no direct type syntax, handled at method level

    // Handle AsyncSequence (→ Stream)
    if (swiftType.startsWith('AsyncStream<') && swiftType.endsWith('>')) {
      final inner = swiftType.substring(12, swiftType.length - 1);
      return UtsType.stream(mapType(inner), nullable: nullable);
    }

    // Primitive mappings
    switch (swiftType) {
      case 'Int':
      case 'Int8':
      case 'Int16':
      case 'Int32':
      case 'Int64':
      case 'UInt':
      case 'UInt8':
      case 'UInt16':
      case 'UInt32':
      case 'UInt64':
        return UtsType.primitive('int', nullable: nullable);
      case 'Double':
      case 'Float':
      case 'CGFloat':
        return UtsType.primitive('double', nullable: nullable);
      case 'String':
        return UtsType.primitive('String', nullable: nullable);
      case 'Bool':
        return UtsType.primitive('bool', nullable: nullable);
      case 'Date':
        return UtsType.primitive('DateTime', nullable: nullable);
      case 'Data':
        return UtsType.primitive('Uint8List', nullable: nullable);
      case 'URL':
        return UtsType.primitive('Uri', nullable: nullable);
      case 'Duration':
        return UtsType.primitive('Duration', nullable: nullable);
      case 'TimeInterval':
        return UtsType.primitive('double', nullable: nullable);
      case 'NSNumber':
        return UtsType.primitive('num', nullable: nullable);
      case 'NSInteger':
      case 'NSUInteger':
        return UtsType.primitive('int', nullable: nullable);
      case 'UUID':
      case 'NSUUID':
      case 'NSString':
        return UtsType.primitive('String', nullable: nullable);
      case 'NSArray':
        return UtsType.list(UtsType.dynamicType(), nullable: nullable);
      case 'NSDictionary':
        return UtsType.map(
          UtsType.primitive('String'),
          UtsType.dynamicType(),
          nullable: nullable,
        );
      case 'Void':
        return UtsType.voidType();
      case 'Any':
      case 'AnyObject':
        return UtsType.dynamicType(nullable: nullable);
      // Native object handles — opaque platform types
      case 'URLRequest':
      case 'URLResponse':
      case 'HTTPURLResponse':
      case 'URLSession':
      case 'URLSessionTask':
      case 'URLSessionConfiguration':
      case 'Error':
      case 'NSError':
      case 'DispatchQueue':
      case 'OperationQueue':
      case 'Notification':
      case 'NSObject':
        return UtsType.nativeObject(swiftType, nullable: nullable);
      default:
        return UtsType.object(swiftType, nullable: nullable);
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
