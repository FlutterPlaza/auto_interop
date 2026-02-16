// Helper script to generate golden files for Gradle/Kotlin/Java.
// Run: dart test/golden/_generate_gradle_goldens.dart

import 'dart:io';
import 'package:auto_interop_generator/src/parsers/gradle_parser.dart';
import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/generators/kotlin_glue_generator.dart';

void main() {
  final parser = GradleParser();
  final dartGen = DartGenerator();
  final kotlinGen = KotlinGlueGenerator();

  // OkHttp (Kotlin)
  _generateGolden(
    parser: parser,
    dartGen: dartGen,
    kotlinGen: kotlinGen,
    fixture: 'test/fixtures/kotlin/golden_okhttp.kt',
    packageName: 'com.squareup.okhttp3:okhttp',
    version: '4.12.0',
    goldenDir: 'test/golden/okhttp',
  );

  // Gson (Java)
  _generateGolden(
    parser: parser,
    dartGen: dartGen,
    kotlinGen: kotlinGen,
    fixture: 'test/fixtures/java/golden_gson.java',
    packageName: 'com.google.code.gson:gson',
    version: '2.10.1',
    goldenDir: 'test/golden/gson',
  );

  print('Gradle golden files generated successfully.');
}

void _generateGolden({
  required GradleParser parser,
  required DartGenerator dartGen,
  required KotlinGlueGenerator kotlinGen,
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
  final kotlinFiles = kotlinGen.generate(schema);

  final dir = Directory(goldenDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  for (final entry in dartFiles.entries) {
    File('$goldenDir/${entry.key}.golden').writeAsStringSync(entry.value);
    print('  Wrote $goldenDir/${entry.key}.golden');
  }

  for (final entry in kotlinFiles.entries) {
    File('$goldenDir/${entry.key}.golden').writeAsStringSync(entry.value);
    print('  Wrote $goldenDir/${entry.key}.golden');
  }
}
