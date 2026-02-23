import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../schema/unified_type_schema.dart';

/// Loads UTS type definitions from .uts.json files on disk.
///
/// Used for loading override files and test fixture definitions.
class TypeDefinitionLoader {
  /// The directory containing .uts.json files.
  final String definitionsDir;

  /// Creates a loader that reads from the given directory.
  TypeDefinitionLoader({required this.definitionsDir});

  /// Lists all available type definition files.
  List<String> listAvailable() {
    final dir = Directory(definitionsDir);
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.uts.json'))
        .map((f) => p.basenameWithoutExtension(f.path).replaceAll('.uts', ''))
        .toList()
      ..sort();
  }

  /// Loads a type definition by its file name (without extension).
  ///
  /// Returns null if no definition is found.
  UnifiedTypeSchema? load(String name) {
    final file = File(p.join(definitionsDir, '$name.uts.json'));
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return UnifiedTypeSchema.fromJson(json);
  }

  /// Loads a type definition that matches the given package name.
  ///
  /// Tries common naming conventions (snake_case, lowercase).
  UnifiedTypeSchema? loadForPackage(String packageName) {
    // Try exact match first
    final exact = load(packageName);
    if (exact != null) return exact;

    // Try snake_case
    final snakeCase = packageName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
    final snake = load(snakeCase);
    if (snake != null) return snake;

    // Try simple lowercase
    final lower = load(packageName.toLowerCase());
    if (lower != null) return lower;

    // Fallback: scan all definitions for a matching package field
    for (final name in listAvailable()) {
      final schema = load(name);
      if (schema != null && schema.package == packageName) {
        return schema;
      }
    }

    return null;
  }

  /// Saves a UTS schema as a type definition.
  void save(String name, UnifiedTypeSchema schema) {
    final dir = Directory(definitionsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(definitionsDir, '$name.uts.json'));
    final json = const JsonEncoder.withIndent('  ').convert(schema.toJson());
    file.writeAsStringSync(json);
  }
}
