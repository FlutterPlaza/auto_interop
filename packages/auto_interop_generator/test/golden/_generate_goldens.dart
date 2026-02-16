// Helper script to generate golden files.
// Run: dart test/golden/_generate_goldens.dart

import 'dart:io';
import 'package:auto_interop_generator/src/parsers/npm_parser.dart';
import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/generators/js_glue_generator.dart';

void main() {
  final parser = NpmParser();
  final dartGen = DartGenerator();
  final jsGen = JsGlueGenerator();

  // date-fns
  _generateGolden(
    parser: parser,
    dartGen: dartGen,
    jsGen: jsGen,
    fixture: 'test/fixtures/npm/golden_date_fns.d.ts',
    packageName: 'date-fns',
    version: '3.6.0',
    goldenDir: 'test/golden/date_fns',
  );

  // lodash
  _generateGolden(
    parser: parser,
    dartGen: dartGen,
    jsGen: jsGen,
    fixture: 'test/fixtures/npm/golden_lodash.d.ts',
    packageName: 'lodash',
    version: '4.17.21',
    goldenDir: 'test/golden/lodash',
  );

  // uuid
  _generateGolden(
    parser: parser,
    dartGen: dartGen,
    jsGen: jsGen,
    fixture: 'test/fixtures/npm/golden_uuid.d.ts',
    packageName: 'uuid',
    version: '9.0.0',
    goldenDir: 'test/golden/uuid',
  );

  print('Golden files generated successfully.');
}

void _generateGolden({
  required NpmParser parser,
  required DartGenerator dartGen,
  required JsGlueGenerator jsGen,
  required String fixture,
  required String packageName,
  required String version,
  required String goldenDir,
}) {
  final content = File(fixture).readAsStringSync();
  final schema = parser.parse(
    content: content,
    packageName: packageName,
    version: version,
  );

  final dartFiles = dartGen.generate(schema);
  final jsFiles = jsGen.generate(schema);

  final dir = Directory(goldenDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  for (final entry in dartFiles.entries) {
    File('$goldenDir/${entry.key}.golden').writeAsStringSync(entry.value);
    print('  Wrote $goldenDir/${entry.key}.golden');
  }

  for (final entry in jsFiles.entries) {
    File('$goldenDir/${entry.key}.golden').writeAsStringSync(entry.value);
    print('  Wrote $goldenDir/${entry.key}.golden');
  }
}
