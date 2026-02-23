import 'dart:typed_data';

/// Converts Dart types to platform channel-compatible types and back.
///
/// Platform channels support a limited set of types. This class handles
/// encoding/decoding of types that need special serialization (e.g., DateTime).
class TypeConverter {
  /// Converts a Dart value to a platform channel-compatible value.
  static Object? toPlatform(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Duration) return value.inMicroseconds;
    if (value is Uri) return value.toString();
    if (value is Uint8List) return value;
    if (value is List) return value.map(toPlatform).toList();
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(toPlatform(key), toPlatform(val)),
      );
    }
    // Primitives (int, double, String, bool) pass through directly
    return value;
  }

  /// Converts a platform channel value back to a Dart type.
  ///
  /// The [dartType] parameter indicates the expected Dart type name
  /// (e.g., 'DateTime', 'int', 'String') for proper decoding.
  static Object? fromPlatform(Object? value, {String? dartType}) {
    if (value == null) return null;
    if (dartType == 'DateTime' && value is String) {
      return DateTime.parse(value);
    }
    // Preserve typed byte data from platform channels (FlutterStandardTypedData)
    if (value is Uint8List) return value;
    if (value is List) {
      return value.map((e) => fromPlatform(e, dartType: dartType)).toList();
    }
    if (value is Map) {
      return <dynamic, dynamic>{
        for (final entry in value.entries)
          fromPlatform(entry.key, dartType: dartType):
              fromPlatform(entry.value),
      };
    }
    return value;
  }

  /// Converts a DateTime to ISO 8601 string for platform channel transport.
  static String dateTimeToString(DateTime dt) => dt.toUtc().toIso8601String();

  /// Converts an ISO 8601 string back to DateTime.
  static DateTime stringToDateTime(String s) => DateTime.parse(s);
}
