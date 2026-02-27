import 'package:auto_interop_generator/src/analyzer/compatibility_checker.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  const checker = CompatibilityChecker();

  group('CompatibilityChecker', () {
    group('platformsForSource', () {
      test('npm maps to web', () {
        expect(
          CompatibilityChecker.platformsForSource(PackageSource.npm),
          {Platform.web},
        );
      });

      test('cocoapods maps to iOS and macOS', () {
        expect(
          CompatibilityChecker.platformsForSource(PackageSource.cocoapods),
          {Platform.ios, Platform.macos},
        );
      });

      test('spm maps to iOS and macOS', () {
        expect(
          CompatibilityChecker.platformsForSource(PackageSource.spm),
          {Platform.ios, Platform.macos},
        );
      });

      test('gradle maps to Android', () {
        expect(
          CompatibilityChecker.platformsForSource(PackageSource.gradle),
          {Platform.android},
        );
      });
    });

    group('check', () {
      test('assigns primary platform from source', () {
        final schema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '3.6.0',
          functions: [
            UtsMethod(
              name: 'format',
              returnType: UtsType.primitive('String'),
            ),
          ],
        );
        final report = checker.check(schema);
        expect(report.primaryPlatforms, {Platform.web});
      });

      test('flags sealed classes as Android-only', () {
        final schema = UnifiedTypeSchema(
          package: 'okhttp3',
          source: PackageSource.gradle,
          version: '4.12.0',
          classes: [
            UtsClass(
              name: 'ResponseBody',
              kind: UtsClassKind.sealedClass,
              sealedSubclasses: ['StringBody', 'ByteBody'],
            ),
          ],
        );
        final report = checker.check(schema);
        final support =
            report.classSupport.where((s) => s.name == 'ResponseBody').first;
        expect(support.isAndroidOnly, isTrue);
        expect(support.note, contains('Sealed class'));
      });

      test('cocoapods classes get iOS+macOS platforms', () {
        final schema = UnifiedTypeSchema(
          package: 'Alamofire',
          source: PackageSource.cocoapods,
          version: '5.9.0',
          classes: [
            UtsClass(name: 'Session'),
          ],
        );
        final report = checker.check(schema);
        expect(report.primaryPlatforms, {Platform.ios, Platform.macos});
        final support = report.classSupport.first;
        expect(support.platforms, {Platform.ios, Platform.macos});
        expect(support.isMacosOnly, isFalse);
      });

      test('flags Swift closure patterns as iOS-only', () {
        final schema = UnifiedTypeSchema(
          package: 'Alamofire',
          source: PackageSource.cocoapods,
          version: '5.9.0',
          classes: [
            UtsClass(
              name: 'Session',
              methods: [
                UtsMethod(
                  name: 'request',
                  returnType: UtsType.voidType(),
                  parameters: [
                    UtsParameter(
                      name: 'completion',
                      type: UtsType.callback(
                        parameterTypes: [UtsType.object('Response')],
                        returnType: UtsType.voidType(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          types: [UtsClass(name: 'Response')],
        );
        final report = checker.check(schema);
        expect(report.methodNotes, isNotEmpty);
        final note = report.methodNotes.first;
        expect(note.name, 'Session.request');
        expect(note.platforms, {Platform.ios});
      });

      test('regular classes get primary platform', () {
        final schema = UnifiedTypeSchema(
          package: 'okhttp3',
          source: PackageSource.gradle,
          version: '4.12.0',
          classes: [
            UtsClass(name: 'OkHttpClient'),
          ],
        );
        final report = checker.check(schema);
        final support = report.classSupport.first;
        expect(support.platforms, {Platform.android});
      });

      test('types get primary platform', () {
        final schema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '3.6.0',
          types: [UtsClass(name: 'FormatOptions')],
        );
        final report = checker.check(schema);
        final support =
            report.classSupport.where((s) => s.name == 'FormatOptions').first;
        expect(support.platforms, {Platform.web});
      });
    });
  });
}
