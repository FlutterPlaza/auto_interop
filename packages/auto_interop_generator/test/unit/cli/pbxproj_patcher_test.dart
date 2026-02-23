import 'package:auto_interop_generator/src/cli/pbxproj_patcher.dart';
import 'package:test/test.dart';

/// Minimal pbxproj content with the required sections for testing.
const _minimalPbxproj = '''
// !${''}*UTF8*${''}!
{
	archiveVersion = 1;
	objectVersion = 54;
	objects = {

/* Begin PBXBuildFile section */
		33CC10F12044A3C60003C045 /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = 33CC10F02044A3C60003C045 /* AppDelegate.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		33CC10F02044A3C60003C045 /* AppDelegate.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		33CC10E62044A3C60003C045 /* Runner */ = {
			isa = PBXGroup;
			children = (
				33CC10F02044A3C60003C045 /* AppDelegate.swift */,
			);
			path = Runner;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXSourcesBuildPhase section */
		33CC10E92044A3C60003C045 = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				33CC10F12044A3C60003C045 /* AppDelegate.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

	};
}
''';

void main() {
  const patcher = PbxprojPatcher();

  group('PbxprojPatcher', () {
    group('hasFileReference', () {
      test('returns false when file is not referenced', () {
        expect(patcher.hasFileReference(_minimalPbxproj, 'MyPlugin.swift'),
            isFalse);
      });

      test('returns true when file is already referenced', () {
        expect(
            patcher.hasFileReference(_minimalPbxproj, 'AppDelegate.swift'),
            isTrue);
      });
    });

    group('addSwiftFile', () {
      test('adds all 4 entries to pbxproj', () {
        final result =
            patcher.addSwiftFile(_minimalPbxproj, 'AlamofirePlugin.swift');

        // PBXFileReference
        expect(result, contains('/* AlamofirePlugin.swift */'));
        expect(result, contains('lastKnownFileType = sourcecode.swift'));
        expect(result, contains('path = AlamofirePlugin.swift'));

        // PBXBuildFile
        expect(result, contains('/* AlamofirePlugin.swift in Sources */'));

        // Verify the entries are in the right sections
        final fileRefSection = result.indexOf('/* End PBXFileReference section */');
        final buildFileSection = result.indexOf('/* End PBXBuildFile section */');
        expect(fileRefSection, greaterThan(-1));
        expect(buildFileSection, greaterThan(-1));

        // File reference entry should be before the end marker
        final fileRefEntry = result.indexOf(
            'path = AlamofirePlugin.swift; sourceTree = "<group>"');
        expect(fileRefEntry, lessThan(fileRefSection));

        // Build file entry should be before its end marker
        final buildFileEntry = result
            .indexOf('/* AlamofirePlugin.swift in Sources */ = {isa = PBXBuildFile');
        expect(buildFileEntry, lessThan(buildFileSection));
      });

      test('returns content unchanged when file already referenced', () {
        final result =
            patcher.addSwiftFile(_minimalPbxproj, 'AppDelegate.swift');
        expect(result, equals(_minimalPbxproj));
      });
    });

    group('deterministic IDs', () {
      test('same input produces same output', () {
        final result1 =
            patcher.addSwiftFile(_minimalPbxproj, 'TestPlugin.swift');
        final result2 =
            patcher.addSwiftFile(_minimalPbxproj, 'TestPlugin.swift');
        expect(result1, equals(result2));
      });

      test('different filenames produce different IDs', () {
        final result1 =
            patcher.addSwiftFile(_minimalPbxproj, 'PluginA.swift');
        final result2 =
            patcher.addSwiftFile(_minimalPbxproj, 'PluginB.swift');
        expect(result1, isNot(equals(result2)));
      });
    });

    group('idempotency', () {
      test('hasFileReference returns true after addSwiftFile', () {
        final result =
            patcher.addSwiftFile(_minimalPbxproj, 'NewPlugin.swift');
        expect(patcher.hasFileReference(result, 'NewPlugin.swift'), isTrue);
      });

      test('double addSwiftFile produces same result', () {
        final first =
            patcher.addSwiftFile(_minimalPbxproj, 'NewPlugin.swift');
        final second = patcher.addSwiftFile(first, 'NewPlugin.swift');
        expect(second, equals(first));
      });
    });

    group('multiple files', () {
      test('can add multiple different files', () {
        var content = _minimalPbxproj;
        content = patcher.addSwiftFile(content, 'PluginA.swift');
        content = patcher.addSwiftFile(content, 'PluginB.swift');

        expect(patcher.hasFileReference(content, 'PluginA.swift'), isTrue);
        expect(patcher.hasFileReference(content, 'PluginB.swift'), isTrue);
        // Original file still there
        expect(
            patcher.hasFileReference(content, 'AppDelegate.swift'), isTrue);
      });
    });
  });
}
