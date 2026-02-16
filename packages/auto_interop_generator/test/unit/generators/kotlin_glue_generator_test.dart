import 'package:auto_interop_generator/src/generators/kotlin_glue_generator.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late KotlinGlueGenerator generator;

  setUp(() {
    generator = KotlinGlueGenerator();
  });

  group('KotlinGlueGenerator', () {
    group('generate', () {
      test('returns map with Plugin.kt file name', () {
        final schema = _createMinimalSchema('test');
        final result = generator.generate(schema);
        expect(result.keys, contains('TestPlugin.kt'));
      });

      test('converts package name to PascalCase for class', () {
        final schema = _createMinimalSchema('date-fns');
        final result = generator.generate(schema);
        expect(result.keys, contains('DateFnsPlugin.kt'));
      });

      test('produces deterministic output', () {
        final schema = _createMinimalSchema('test');
        final result1 = generator.generateKotlinCode(schema);
        final result2 = generator.generateKotlinCode(schema);
        expect(result1, result2);
      });
    });

    group('header and imports', () {
      test('includes GENERATED header', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code, contains('GENERATED'));
        expect(code, contains('DO NOT EDIT'));
      });

      test('includes package name in header', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('date-fns'));
        expect(code, contains('Kotlin platform channel handler for date-fns'));
      });

      test('imports FlutterPlugin', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code, contains('import io.flutter.embedding.engine.plugins.FlutterPlugin'));
      });

      test('imports MethodChannel classes', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code, contains('import io.flutter.plugin.common.MethodCall'));
        expect(code, contains('import io.flutter.plugin.common.MethodChannel'));
        expect(code, contains('MethodChannel.MethodCallHandler'));
        expect(code, contains('MethodChannel.Result'));
      });
    });

    group('plugin class structure', () {
      test('generates class implementing FlutterPlugin and MethodCallHandler', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code,
            contains('class TestPlugin : FlutterPlugin, MethodCallHandler'));
      });

      test('declares lateinit channel', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code,
            contains('private lateinit var channel: MethodChannel'));
      });

      test('registers channel in onAttachedToEngine', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code, contains('onAttachedToEngine'));
        expect(code, contains('MethodChannel(binding.binaryMessenger, "test")'));
        expect(code, contains('channel.setMethodCallHandler(this)'));
      });

      test('uses snake_case channel name', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('date-fns'));
        expect(code,
            contains('MethodChannel(binding.binaryMessenger, "date_fns")'));
      });

      test('unregisters in onDetachedFromEngine', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code, contains('onDetachedFromEngine'));
        expect(code, contains('channel.setMethodCallHandler(null)'));
      });

      test('has when dispatch in onMethodCall', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code, contains('when (call.method)'));
      });

      test('has notImplemented fallback', () {
        final code =
            generator.generateKotlinCode(_createMinimalSchema('test'));
        expect(code, contains('result.notImplemented()'));
      });
    });

    group('method dispatch', () {
      test('generates case for each function', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
            UtsMethod(
              name: 'addDays',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('"format" ->'));
        expect(code, contains('"addDays" ->'));
      });

      test('extracts String arguments', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'greet',
              isStatic: true,
              parameters: [
                UtsParameter(
                    name: 'name', type: UtsType.primitive('String')),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code,
            contains('val name = call.argument<String>("name")!!'));
      });

      test('extracts Int arguments', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'add',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'a', type: UtsType.primitive('int')),
              ],
              returnType: UtsType.primitive('int'),
            ),
          ],
        ));
        expect(code, contains('val a = call.argument<Int>("a")!!'));
      });

      test('extracts Boolean arguments', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'toggle',
              isStatic: true,
              parameters: [
                UtsParameter(
                    name: 'value', type: UtsType.primitive('bool')),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code,
            contains('val value = call.argument<Boolean>("value")!!'));
      });

      test('extracts DateTime as String (ISO 8601)', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'setDate',
              isStatic: true,
              parameters: [
                UtsParameter(
                    name: 'date', type: UtsType.primitive('DateTime')),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code,
            contains('val date = call.argument<String>("date")!!'));
      });

      test('optional arguments use nullable extraction', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'greet',
              isStatic: true,
              parameters: [
                UtsParameter(
                  name: 'name',
                  type: UtsType.primitive('String'),
                ),
                UtsParameter(
                  name: 'greeting',
                  type: UtsType.primitive('String'),
                  isOptional: true,
                  isNamed: true,
                ),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code,
            contains('val name = call.argument<String>("name")!!'));
        expect(code,
            contains('val greeting = call.argument<String>("greeting")'));
        // Should NOT have !! for optional
        expect(
            code,
            isNot(contains(
                'val greeting = call.argument<String>("greeting")!!')));
      });

      test('void method calls result.success(null)', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'reset',
              isStatic: true,
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code, contains('result.success(null)'));
      });

      test('non-void methods have try-catch error handling', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'compute',
              isStatic: true,
              returnType: UtsType.primitive('int'),
            ),
          ],
        ));
        expect(code, contains('try {'));
        expect(code, contains('catch (e: Exception)'));
        expect(code, contains('result.error('));
      });

      test('extracts Map arguments for object types', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'configure',
              isStatic: true,
              parameters: [
                UtsParameter(
                    name: 'options',
                    type: UtsType.object('Options')),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code,
            contains('call.argument<Map<String, Any?>>("options")'));
      });

      test('extracts List arguments', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'process',
              isStatic: true,
              parameters: [
                UtsParameter(
                  name: 'items',
                  type: UtsType.list(UtsType.primitive('String')),
                ),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code,
            contains('call.argument<List<Any?>>("items")'));
      });
    });

    group('class method dispatch', () {
      test('prefixes class methods with class name', () {
        final code = generator.generateKotlinCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'HttpClient',
              methods: [
                UtsMethod(
                  name: 'get',
                  parameters: [
                    UtsParameter(
                        name: 'url', type: UtsType.primitive('String')),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
                UtsMethod(
                  name: 'close',
                  returnType: UtsType.voidType(),
                ),
              ],
            ),
          ],
        ));
        expect(code, contains('"HttpClient.get" ->'));
        expect(code, contains('"HttpClient.close" ->'));
      });
    });

    group('full date-fns example', () {
      test('generates complete plugin', () {
        final code =
            generator.generateKotlinCode(_createDateFnsSchema());

        // Class structure
        expect(code, contains('class DateFnsPlugin'));
        expect(code, contains('FlutterPlugin, MethodCallHandler'));

        // Channel registration
        expect(code,
            contains('MethodChannel(binding.binaryMessenger, "date_fns")'));

        // Method dispatch
        expect(code, contains('"format" ->'));
        expect(code, contains('"addDays" ->'));

        // Argument extraction
        expect(code, contains('call.argument<String>("date")'));
        expect(code, contains('call.argument<String>("formatStr")'));

        // Fallback
        expect(code, contains('result.notImplemented()'));
      });
    });
  });
}

UnifiedTypeSchema _createMinimalSchema(String packageName) {
  return UnifiedTypeSchema(
    package: packageName,
    source: PackageSource.npm,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'noop',
        isStatic: true,
        returnType: UtsType.voidType(),
      ),
    ],
  );
}

UnifiedTypeSchema _createDateFnsSchema() {
  return UnifiedTypeSchema(
    package: 'date-fns',
    source: PackageSource.npm,
    version: '3.6.0',
    functions: [
      UtsMethod(
        name: 'format',
        isStatic: true,
        parameters: [
          UtsParameter(
              name: 'date', type: UtsType.primitive('DateTime')),
          UtsParameter(
              name: 'formatStr', type: UtsType.primitive('String')),
        ],
        returnType: UtsType.primitive('String'),
      ),
      UtsMethod(
        name: 'addDays',
        isStatic: true,
        parameters: [
          UtsParameter(
              name: 'date', type: UtsType.primitive('DateTime')),
          UtsParameter(
              name: 'amount', type: UtsType.primitive('int')),
        ],
        returnType: UtsType.primitive('DateTime'),
      ),
    ],
  );
}
