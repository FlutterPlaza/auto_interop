import 'dart:io';

import 'package:auto_interop_generator/src/cli/cli_runner.dart';
import 'package:test/test.dart';

void main() {
  late CliRunner runner;

  setUp(() {
    runner = CliRunner();
  });

  group('CliRunner', () {
    group('help', () {
      test('returns 0 for --help', () async {
        final code = await runner.run(['--help']);
        expect(code, 0);
      });

      test('returns 0 for help', () async {
        final code = await runner.run(['help']);
        expect(code, 0);
      });

      test('returns 0 for -h', () async {
        final code = await runner.run(['-h']);
        expect(code, 0);
      });
    });

    group('version', () {
      test('returns 0 for --version', () async {
        final code = await runner.run(['--version']);
        expect(code, 0);
      });

      test('returns 0 for version', () async {
        final code = await runner.run(['version']);
        expect(code, 0);
      });
    });

    group('unknown command', () {
      test('returns 1 for unknown command', () async {
        final code = await runner.run(['foobar']);
        expect(code, 1);
      });
    });

    group('list', () {
      test('returns 0', () async {
        final code = await runner.run(['list']);
        expect(code, 0);
      });
    });

    group('generate', () {
      test('returns 1 when config file not found', () async {
        final code = await runner.run(
            ['generate', '--config', '/nonexistent/auto_interop.yaml']);
        expect(code, 1);
      });

      test('returns 0 with empty packages', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_gen_test_');
        try {
          File('${tempDir.path}/empty.yaml')
              .writeAsStringSync('native_packages: []\n');
          final code = await runner
              .run(['generate', '--config', '${tempDir.path}/empty.yaml']);
          expect(code, 0);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('add', () {
      test('returns 1 with too few args', () async {
        final code = await runner.run(['add']);
        expect(code, 1);
      });

      test('returns 1 with unsupported source', () async {
        final code = await runner.run(['add', 'python', 'requests', '2.0.0']);
        expect(code, 1);
      });
    });

    group('--only filter', () {
      test('returns 1 when no packages match --only filter', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_gen_test_');
        try {
          File('${tempDir.path}/config.yaml').writeAsStringSync(
            'native_packages:\n'
            '  - source: npm\n'
            '    package: "date-fns"\n'
            '    version: "3.0.0"\n',
          );
          final code = await runner.run([
            'generate',
            '--config',
            '${tempDir.path}/config.yaml',
            '--only',
            'nonexistent',
          ]);
          expect(code, 1);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });
  });
}
