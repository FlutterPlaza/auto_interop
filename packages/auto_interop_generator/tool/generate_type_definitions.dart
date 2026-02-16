// Generates pre-built UTS JSON type definition files from golden fixtures.
//
// Run with: dart run tool/generate_type_definitions.dart
import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/parsers/npm_parser.dart';
import 'package:auto_interop_generator/src/parsers/gradle_parser.dart';
import 'package:auto_interop_generator/src/parsers/swift_parser.dart';

void main() {
  final outDir = Directory('lib/src/type_definitions');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final npmParser = NpmParser();
  final gradleParser = GradleParser();
  final swiftParser = SwiftParser();

  // npm packages
  _generate(
    parser: npmParser,
    fixturePath: 'test/fixtures/npm/golden_date_fns.d.ts',
    packageName: 'date-fns',
    version: '3.6.0',
    outPath: '${outDir.path}/date_fns.uts.json',
  );

  _generate(
    parser: npmParser,
    fixturePath: 'test/fixtures/npm/golden_lodash.d.ts',
    packageName: 'lodash',
    version: '4.17.21',
    outPath: '${outDir.path}/lodash.uts.json',
  );

  _generate(
    parser: npmParser,
    fixturePath: 'test/fixtures/npm/golden_uuid.d.ts',
    packageName: 'uuid',
    version: '9.0.0',
    outPath: '${outDir.path}/uuid.uts.json',
  );

  // Gradle packages
  _generate(
    parser: gradleParser,
    fixturePath: 'test/fixtures/kotlin/golden_okhttp.kt',
    packageName: 'com.squareup.okhttp3:okhttp',
    version: '4.12.0',
    outPath: '${outDir.path}/okhttp3.uts.json',
  );

  // CocoaPods packages
  _generate(
    parser: swiftParser,
    fixturePath: 'test/fixtures/swift/golden_alamofire.swift',
    packageName: 'Alamofire',
    version: '5.9.0',
    outPath: '${outDir.path}/alamofire.uts.json',
  );

  _generate(
    parser: swiftParser,
    fixturePath: 'test/fixtures/swift/golden_sdwebimage.swift',
    packageName: 'SDWebImage',
    version: '5.19.0',
    outPath: '${outDir.path}/sdwebimage.uts.json',
  );

  print('Generated ${outDir.listSync().length} type definition files.');
}

void _generate({
  required dynamic parser,
  required String fixturePath,
  required String packageName,
  required String version,
  required String outPath,
}) {
  final content = File(fixturePath).readAsStringSync();
  final schema = parser.parse(
    content: content,
    packageName: packageName,
    version: version,
  );
  final json = const JsonEncoder.withIndent('  ').convert(schema.toJson());
  File(outPath).writeAsStringSync(json);
  print('  Generated $outPath');
}
