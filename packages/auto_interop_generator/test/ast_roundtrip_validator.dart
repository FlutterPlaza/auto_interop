import 'dart:convert';
import 'dart:io';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run test/ast_roundtrip_validator.dart <json_file>...');
    exit(1);
  }
  var allPassed = true;
  for (final filePath in args) {
    stdout.write('$filePath ... ');
    try {
      final json = jsonDecode(File(filePath).readAsStringSync()) as Map<String, dynamic>;
      final schema = UnifiedTypeSchema.fromJson(json);
      final schema2 = UnifiedTypeSchema.fromJson(
        jsonDecode(jsonEncode(schema.toJson())) as Map<String, dynamic>,
      );
      assert(schema.package == schema2.package);
      assert(schema.classes.length == schema2.classes.length);
      assert(schema.functions.length == schema2.functions.length);
      assert(schema.types.length == schema2.types.length);
      assert(schema.enums.length == schema2.enums.length);
      stdout.writeln('OK  (${schema.classes.length}c ${schema.functions.length}f ${schema.types.length}t ${schema.enums.length}e)');
    } catch (e) {
      stdout.writeln('FAILED: $e');
      allPassed = false;
    }
  }
  exit(allPassed ? 0 : 1);
}
