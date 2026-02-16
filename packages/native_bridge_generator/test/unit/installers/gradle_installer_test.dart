import 'package:native_bridge_generator/src/installers/gradle_installer.dart';
import 'package:test/test.dart';

const _sampleGroovy = '''
plugins {
    id 'com.android.application'
    id 'kotlin-android'
}

android {
    compileSdk 34
}

dependencies {
    implementation 'org.jetbrains.kotlin:kotlin-stdlib:1.9.0'
    implementation 'androidx.core:core-ktx:1.12.0'
}
''';

const _sampleKotlinDsl = '''
plugins {
    id("com.android.application")
    kotlin("android")
}

android {
    compileSdk = 34
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
    implementation("androidx.core:core-ktx:1.12.0")
}
''';

const _emptyBuildFile = '''
plugins {
    id 'com.android.application'
}

android {
    compileSdk 34
}
''';

void main() {
  late GradleInstaller installer;

  setUp(() {
    installer = GradleInstaller();
  });

  group('GradleInstaller', () {
    group('addDependency (Groovy DSL)', () {
      test('adds dependency to existing block', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleGroovy,
          group: 'com.squareup.okhttp3',
          artifact: 'okhttp',
          version: '4.12.0',
        );
        expect(result,
            contains("implementation 'com.squareup.okhttp3:okhttp:4.12.0'"));
      });

      test('preserves existing dependencies', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleGroovy,
          group: 'com.squareup.okhttp3',
          artifact: 'okhttp',
          version: '4.12.0',
        );
        expect(result,
            contains("implementation 'org.jetbrains.kotlin:kotlin-stdlib:1.9.0'"));
        expect(result,
            contains("implementation 'androidx.core:core-ktx:1.12.0'"));
      });

      test('updates existing dependency version', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleGroovy,
          group: 'androidx.core',
          artifact: 'core-ktx',
          version: '1.13.0',
        );
        expect(result,
            contains("implementation 'androidx.core:core-ktx:1.13.0'"));
        expect(result,
            isNot(contains("implementation 'androidx.core:core-ktx:1.12.0'")));
      });

      test('creates dependencies block if missing', () {
        final result = installer.addDependency(
          buildGradleContent: _emptyBuildFile,
          group: 'com.squareup.okhttp3',
          artifact: 'okhttp',
          version: '4.12.0',
        );
        expect(result, contains('dependencies {'));
        expect(result,
            contains("implementation 'com.squareup.okhttp3:okhttp:4.12.0'"));
      });

      test('supports custom configuration', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleGroovy,
          group: 'junit',
          artifact: 'junit',
          version: '4.13.2',
          configuration: 'testImplementation',
        );
        expect(result,
            contains("testImplementation 'junit:junit:4.13.2'"));
      });

      test('does not duplicate existing dependency', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleGroovy,
          group: 'androidx.core',
          artifact: 'core-ktx',
          version: '1.12.0',
        );
        final matches = RegExp('androidx.core:core-ktx')
            .allMatches(result)
            .length;
        expect(matches, 1);
      });
    });

    group('addDependency (Kotlin DSL)', () {
      test('adds dependency with Kotlin DSL format', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleKotlinDsl,
          group: 'com.squareup.okhttp3',
          artifact: 'okhttp',
          version: '4.12.0',
          isKotlinDsl: true,
        );
        expect(result,
            contains('implementation("com.squareup.okhttp3:okhttp:4.12.0")'));
      });

      test('updates existing Kotlin DSL dependency', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleKotlinDsl,
          group: 'androidx.core',
          artifact: 'core-ktx',
          version: '1.13.0',
          isKotlinDsl: true,
        );
        expect(result,
            contains('implementation("androidx.core:core-ktx:1.13.0")'));
      });
    });

    group('removeDependency', () {
      test('removes from Groovy DSL', () {
        final result = installer.removeDependency(
          buildGradleContent: _sampleGroovy,
          group: 'androidx.core',
          artifact: 'core-ktx',
        );
        expect(result, isNot(contains('androidx.core:core-ktx')));
        expect(result, contains('kotlin-stdlib'));
      });

      test('removes from Kotlin DSL', () {
        final result = installer.removeDependency(
          buildGradleContent: _sampleKotlinDsl,
          group: 'androidx.core',
          artifact: 'core-ktx',
          isKotlinDsl: true,
        );
        expect(result, isNot(contains('androidx.core:core-ktx')));
      });

      test('returns unchanged if not found', () {
        final result = installer.removeDependency(
          buildGradleContent: _sampleGroovy,
          group: 'com.example',
          artifact: 'nonexistent',
        );
        expect(result, contains('kotlin-stdlib'));
        expect(result, contains('core-ktx'));
      });
    });

    group('hasDependency', () {
      test('returns true for Groovy dependency', () {
        expect(
          installer.hasDependency(
            buildGradleContent: _sampleGroovy,
            group: 'androidx.core',
            artifact: 'core-ktx',
          ),
          true,
        );
      });

      test('returns true for Kotlin DSL dependency', () {
        expect(
          installer.hasDependency(
            buildGradleContent: _sampleKotlinDsl,
            group: 'androidx.core',
            artifact: 'core-ktx',
            isKotlinDsl: true,
          ),
          true,
        );
      });

      test('returns false when not present', () {
        expect(
          installer.hasDependency(
            buildGradleContent: _sampleGroovy,
            group: 'com.example',
            artifact: 'nonexistent',
          ),
          false,
        );
      });
    });

    group('getDependencyVersion', () {
      test('returns version from Groovy DSL', () {
        expect(
          installer.getDependencyVersion(
            buildGradleContent: _sampleGroovy,
            group: 'androidx.core',
            artifact: 'core-ktx',
          ),
          '1.12.0',
        );
      });

      test('returns version from Kotlin DSL', () {
        expect(
          installer.getDependencyVersion(
            buildGradleContent: _sampleKotlinDsl,
            group: 'androidx.core',
            artifact: 'core-ktx',
          ),
          '1.12.0',
        );
      });

      test('returns null when not found', () {
        expect(
          installer.getDependencyVersion(
            buildGradleContent: _sampleGroovy,
            group: 'com.example',
            artifact: 'nonexistent',
          ),
          null,
        );
      });
    });

    group('addDependencies (batch)', () {
      test('adds multiple dependencies at once', () {
        final result = installer.addDependencies(
          buildGradleContent: _sampleGroovy,
          dependencies: [
            const GradleDependency(
              group: 'com.squareup.okhttp3',
              artifact: 'okhttp',
              version: '4.12.0',
            ),
            const GradleDependency(
              group: 'com.google.code.gson',
              artifact: 'gson',
              version: '2.10.1',
            ),
          ],
        );
        expect(result,
            contains("implementation 'com.squareup.okhttp3:okhttp:4.12.0'"));
        expect(result,
            contains("implementation 'com.google.code.gson:gson:2.10.1'"));
      });

      test('supports mixed configurations', () {
        final result = installer.addDependencies(
          buildGradleContent: _sampleGroovy,
          dependencies: [
            const GradleDependency(
              group: 'com.squareup.okhttp3',
              artifact: 'okhttp',
              version: '4.12.0',
            ),
            const GradleDependency(
              group: 'junit',
              artifact: 'junit',
              version: '4.13.2',
              configuration: 'testImplementation',
            ),
          ],
        );
        expect(result,
            contains("implementation 'com.squareup.okhttp3:okhttp:4.12.0'"));
        expect(result,
            contains("testImplementation 'junit:junit:4.13.2'"));
      });
    });

    group('preserves file structure', () {
      test('preserves plugins block', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleGroovy,
          group: 'com.squareup.okhttp3',
          artifact: 'okhttp',
          version: '4.12.0',
        );
        expect(result, contains("id 'com.android.application'"));
        expect(result, contains("id 'kotlin-android'"));
      });

      test('preserves android block', () {
        final result = installer.addDependency(
          buildGradleContent: _sampleGroovy,
          group: 'com.squareup.okhttp3',
          artifact: 'okhttp',
          version: '4.12.0',
        );
        expect(result, contains('compileSdk 34'));
      });
    });
  });
}
