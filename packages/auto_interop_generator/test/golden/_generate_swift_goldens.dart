import 'dart:io';

import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/generators/swift_glue_generator.dart';
import 'package:auto_interop_generator/src/parsers/swift_parser.dart';

/// Helper script to regenerate golden files for Swift packages.
///
/// Run with: dart test/golden/_generate_swift_goldens.dart
void main() {
  final parser = SwiftParser();
  final dartGen = DartGenerator();
  final swiftGen = SwiftGlueGenerator();

  // Alamofire
  _generate(
    parser: parser,
    dartGen: dartGen,
    swiftGen: swiftGen,
    fixturePath: 'test/fixtures/swift/golden_alamofire.swift',
    packageName: 'Alamofire',
    version: '5.9.0',
    outputDir: 'test/golden/alamofire',
  );

  // SDWebImage
  _generate(
    parser: parser,
    dartGen: dartGen,
    swiftGen: swiftGen,
    fixturePath: 'test/fixtures/swift/golden_sdwebimage.swift',
    packageName: 'SDWebImage',
    version: '5.19.0',
    outputDir: 'test/golden/sdwebimage',
  );

  print('Golden files generated successfully.');
}

void _generate({
  required SwiftParser parser,
  required DartGenerator dartGen,
  required SwiftGlueGenerator swiftGen,
  required String fixturePath,
  required String packageName,
  required String version,
  required String outputDir,
}) {
  final content = File(fixturePath).readAsStringSync();
  final schema = parser.parse(
    content: content,
    packageName: packageName,
    version: version,
  );

  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Dart bindings
  final dartFiles = dartGen.generate(schema);
  for (final entry in dartFiles.entries) {
    File('$outputDir/${entry.key}.golden').writeAsStringSync(entry.value);
    print('  Wrote $outputDir/${entry.key}.golden');
  }

  // Swift glue
  final swiftFiles = swiftGen.generate(schema);
  for (final entry in swiftFiles.entries) {
    File('$outputDir/${entry.key}.golden').writeAsStringSync(entry.value);
    print('  Wrote $outputDir/${entry.key}.golden');
  }
}
