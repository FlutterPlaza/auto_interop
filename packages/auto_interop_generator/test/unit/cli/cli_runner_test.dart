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
      test('returns 0 with no cached definitions', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_list_test_');
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          final code = await runner.run(['list']);
          expect(code, 0);
        } finally {
          Directory.current = originalDir;
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('generate', () {
      test('returns 1 when config file not found', () async {
        final code = await runner
            .run(['generate', '--config', '/nonexistent/auto_interop.yaml']);
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

    group('parse', () {
      test('returns 1 when --package is missing', () async {
        final code = await runner.run(['parse', 'some_file.swift']);
        expect(code, 1);
      });

      test('returns 1 when no files are given', () async {
        final code = await runner.run(['parse', '--package', 'TestLib']);
        expect(code, 1);
      });

      test('returns 1 for nonexistent file', () async {
        final code = await runner.run([
          'parse',
          '/nonexistent/file.swift',
          '--package',
          'TestLib',
        ]);
        expect(code, 1);
      });

      test('returns 0 for a valid Swift file', () async {
        final code = await runner.run([
          'parse',
          'test/fixtures/swift/simple_class.swift',
          '--package',
          'TestLib',
          '--no-analyze',
        ]);
        expect(code, 0);
      });

      test('--output writes to specified path', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_parse_test_');
        try {
          final outPath = '${tempDir.path}/output.uts.json';
          final code = await runner.run([
            'parse',
            'test/fixtures/swift/simple_class.swift',
            '--package',
            'TestLib',
            '--output',
            outPath,
            '--no-analyze',
          ]);
          expect(code, 0);
          expect(File(outPath).existsSync(), isTrue);

          // Verify it's valid JSON with expected fields
          final content = File(outPath).readAsStringSync();
          expect(content, contains('"package"'));
          expect(content, contains('"TestLib"'));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('clean/delete/purge', () {
      test('clean without package or --all returns 1', () async {
        final code = await runner.run(['clean']);
        expect(code, 1);
      });

      test('delete without package or --all returns 1', () async {
        final code = await runner.run(['delete']);
        expect(code, 1);
      });

      test('purge without package or --all returns 1', () async {
        final code = await runner.run(['purge']);
        expect(code, 1);
      });

      test('clean --all deletes cache file and parse cache', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_clean_test_');
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          // Create a fake cache file
          File('.auto_interop_cache.json').writeAsStringSync('{}');
          // Create a fake parse cache directory
          Directory('.auto_interop_cache').createSync();
          expect(File('.auto_interop_cache.json').existsSync(), isTrue);
          expect(Directory('.auto_interop_cache').existsSync(), isTrue);

          final code = await runner.run(['clean', '--all']);
          expect(code, 0);
          expect(File('.auto_interop_cache.json').existsSync(), isFalse);
          expect(Directory('.auto_interop_cache').existsSync(), isFalse);
        } finally {
          Directory.current = originalDir;
          tempDir.deleteSync(recursive: true);
        }
      });

      test('delete --all removes cache and output dir files', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_delete_test_');
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          // Create cache and output files
          File('.auto_interop_cache.json').writeAsStringSync('{}');
          Directory('lib/generated').createSync(recursive: true);
          File('lib/generated/foo.dart').writeAsStringSync('// generated');
          File('lib/generated/bar.dart').writeAsStringSync('// generated');

          final code = await runner.run(['delete', '--all']);
          expect(code, 0);
          expect(File('.auto_interop_cache.json').existsSync(), isFalse);
          expect(File('lib/generated/foo.dart').existsSync(), isFalse);
          expect(File('lib/generated/bar.dart').existsSync(), isFalse);
        } finally {
          Directory.current = originalDir;
          tempDir.deleteSync(recursive: true);
        }
      });

      test('purge per-package removes package files from cache', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_purge_test_');
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          // Create output dir with dart files
          Directory('lib/generated').createSync(recursive: true);
          File('lib/generated/alamofire.dart')
              .writeAsStringSync('// generated');

          // Create cache with Alamofire entry
          final cacheContent = '''{
  "configChecksum": "abc123",
  "packages": {
    "Alamofire": {
      "inputChecksum": "def456",
      "outputChecksums": {
        "alamofire.dart": "hash1",
        "AlamofirePlugin.swift": "hash2"
      },
      "generatedAt": "2025-01-01T00:00:00.000"
    },
    "OtherPkg": {
      "inputChecksum": "ghi789",
      "outputChecksums": {
        "other.dart": "hash3"
      },
      "generatedAt": "2025-01-01T00:00:00.000"
    }
  }
}''';
          File('.auto_interop_cache.json').writeAsStringSync(cacheContent);

          final code = await runner.run(['purge', 'Alamofire']);
          expect(code, 0);

          // Cache should still exist but without Alamofire entry
          expect(File('.auto_interop_cache.json').existsSync(), isTrue);
          final updatedCache =
              File('.auto_interop_cache.json').readAsStringSync();
          expect(updatedCache, isNot(contains('Alamofire')));
          expect(updatedCache, contains('OtherPkg'));

          // Dart file should be removed
          expect(File('lib/generated/alamofire.dart').existsSync(), isFalse);
        } finally {
          Directory.current = originalDir;
          tempDir.deleteSync(recursive: true);
        }
      });

      test('clean per-package with missing cache returns 0', () async {
        final tempDir =
            Directory.systemTemp.createTempSync('nb_clean_nocache_');
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          final code = await runner.run(['clean', 'NonExistent']);
          expect(code, 0);
        } finally {
          Directory.current = originalDir;
          tempDir.deleteSync(recursive: true);
        }
      });

      test('delete per-package with unknown package returns 0 with warning',
          () async {
        final tempDir =
            Directory.systemTemp.createTempSync('nb_delete_unknown_');
        final originalDir = Directory.current;
        try {
          Directory.current = tempDir;
          File('.auto_interop_cache.json')
              .writeAsStringSync('{"configChecksum":"x","packages":{}}');
          final code = await runner.run(['delete', 'UnknownPkg']);
          expect(code, 0);
        } finally {
          Directory.current = originalDir;
          tempDir.deleteSync(recursive: true);
        }
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

    group('--dry-run', () {
      test('returns 0 with empty packages', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_dryrun_test_');
        try {
          File('${tempDir.path}/empty.yaml')
              .writeAsStringSync('native_packages: []\n');
          final code = await runner.run([
            'generate',
            '--config',
            '${tempDir.path}/empty.yaml',
            '--dry-run'
          ]);
          expect(code, 0);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('--no-registry', () {
      test('returns 0 with empty packages', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_noreg_test_');
        try {
          File('${tempDir.path}/empty.yaml')
              .writeAsStringSync('native_packages: []\n');
          final code = await runner.run([
            'generate',
            '--config',
            '${tempDir.path}/empty.yaml',
            '--no-registry',
          ]);
          expect(code, 0);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('registry command', () {
      test('returns 1 without subcommand', () async {
        final code = await runner.run(['registry']);
        expect(code, 1);
      });

      test('returns 1 for unknown subcommand', () async {
        final code = await runner.run(['registry', 'unknown']);
        expect(code, 1);
      });

      test('fetch returns 1 without package arg', () async {
        final code = await runner.run(['registry', 'fetch']);
        expect(code, 1);
      });
    });

    group('--verbose', () {
      test('returns 0 with empty packages', () async {
        final tempDir = Directory.systemTemp.createTempSync('nb_verbose_test_');
        try {
          File('${tempDir.path}/empty.yaml')
              .writeAsStringSync('native_packages: []\n');
          final code = await runner.run([
            'generate',
            '--config',
            '${tempDir.path}/empty.yaml',
            '--verbose'
          ]);
          expect(code, 0);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });
  });
}
