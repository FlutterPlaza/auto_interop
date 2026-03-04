import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late DartGenerator generator;

  setUp(() {
    generator = DartGenerator();
  });

  group('DartGenerator', () {
    group('generate', () {
      test('returns map with correct file name', () {
        final schema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '3.6.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'date', type: UtsType.primitive('String')),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        );

        final result = generator.generate(schema);
        expect(result.keys, contains('date_fns.dart'));
      });

      test('produces deterministic output', () {
        final schema = _createDateFnsSchema();
        final result1 = generator.generateDartCode(schema);
        final result2 = generator.generateDartCode(schema);
        expect(result1, result2);
      });
    });

    group('header', () {
      test('includes GENERATED header', () {
        final code = generator.generateDartCode(_createMinimalSchema());
        expect(code, contains('GENERATED'));
        expect(code, contains('DO NOT EDIT'));
      });

      test('imports auto_interop', () {
        final code = generator.generateDartCode(_createMinimalSchema());
        expect(
            code, contains("import 'package:auto_interop/auto_interop.dart';"));
      });
    });

    group('binding class generation', () {
      test('generates class with PascalCase name from package', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('class DateFns implements DateFnsInterface'));
      });

      test('generates channel with snake_case name', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains("AutoInteropChannel('date_fns')"));
      });

      test('generates private constructor and static instance', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('static final DateFns instance = DateFns._();'));
        expect(code, contains('DateFns._();'));
      });
    });

    group('method generation', () {
      test('generates instance async method with @override in binding class',
          () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'doSomething',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('@override'));
        expect(code, contains('Future<String> doSomething() async'));
        // Should NOT be static in binding class (instance method)
        expect(code, isNot(contains('static Future<String> doSomething')));
      });

      test('generates method with positional parameters', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'add',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'a', type: UtsType.primitive('int')),
                UtsParameter(name: 'b', type: UtsType.primitive('int')),
              ],
              returnType: UtsType.primitive('int'),
            ),
          ],
        ));
        expect(code, contains('int a, int b'));
      });

      test('generates method with named optional parameters', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'date', type: UtsType.primitive('String')),
                UtsParameter(
                  name: 'locale',
                  type: UtsType.primitive('String'),
                  isNamed: true,
                  isOptional: true,
                ),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('String date'));
        expect(code, contains('{String? locale}'));
      });

      test('generates void method', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'reset',
              isStatic: true,
              parameters: [],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code, contains('Future<void> reset()'));
      });

      test('generates method with documentation', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('String'),
              documentation: 'Formats a date string.',
            ),
          ],
        ));
        expect(code, contains('/// Formats a date string.'));
      });

      test('serializes DateTime parameters as ISO 8601', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'setDate',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'date', type: UtsType.primitive('DateTime')),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code, contains('date.toIso8601String()'));
      });

      test('serializes object parameters with toMap()', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'configure',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'options', type: UtsType.object('Options')),
              ],
              returnType: UtsType.voidType(),
            ),
          ], types: [
            UtsClass(
              name: 'Options',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'value', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        expect(code, contains('options.toMap()'));
      });

      test('generates channel invoke call', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'greet',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'name', type: UtsType.primitive('String')),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains("_channel.invoke<String>('greet'"));
      });
    });

    group('data class generation', () {
      test('generates class with fields', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Options',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'timeout', type: UtsType.primitive('int')),
                UtsField(
                    name: 'locale',
                    type: UtsType.primitive('String'),
                    nullable: true),
              ],
            ),
          ],
        ));
        expect(code, contains('class Options'));
        expect(code, contains('final int timeout'));
        expect(code, contains('final String? locale'));
      });

      test('generates constructor', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Config',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'name', type: UtsType.primitive('String')),
                UtsField(
                    name: 'count',
                    type: UtsType.primitive('int'),
                    nullable: true),
              ],
            ),
          ],
        ));
        expect(code, contains('required this.name'));
        expect(code, contains('this.count'));
      });

      test('generates fromMap factory', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Point',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'x', type: UtsType.primitive('double')),
                UtsField(name: 'y', type: UtsType.primitive('double')),
              ],
            ),
          ],
        ));
        expect(code, contains('factory Point.fromMap'));
        expect(code, contains("map['x'] as double"));
        expect(code, contains("map['y'] as double"));
      });

      test('generates toMap method', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Point',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'x', type: UtsType.primitive('double')),
                UtsField(name: 'y', type: UtsType.primitive('double')),
              ],
            ),
          ],
        ));
        expect(code, contains('Map<String, dynamic> toMap()'));
        expect(code, contains("'x': x"));
        expect(code, contains("'y': y"));
      });

      test('nullable fields omitted from toMap when null', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Options',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(
                    name: 'locale',
                    type: UtsType.primitive('String'),
                    nullable: true),
              ],
            ),
          ],
        ));
        expect(code, contains("if (locale != null) 'locale': locale"));
      });

      test('generates documentation for data class', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Config',
              kind: UtsClassKind.dataClass,
              documentation: 'Configuration options.',
              fields: [
                UtsField(
                  name: 'timeout',
                  type: UtsType.primitive('int'),
                  documentation: 'Timeout in milliseconds.',
                ),
              ],
            ),
          ],
        ));
        expect(code, contains('/// Configuration options.'));
        expect(code, contains('/// Timeout in milliseconds.'));
      });
    });

    group('enum generation', () {
      test('generates simple enum', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(
              name: 'Color',
              values: [
                UtsEnumValue(name: 'red'),
                UtsEnumValue(name: 'green'),
                UtsEnumValue(name: 'blue'),
              ],
            ),
          ],
        ));
        expect(code, contains('enum Color'));
        expect(code, contains('red,'));
        expect(code, contains('green,'));
        expect(code, contains('blue;'));
      });

      test('generates enum with documentation', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(
              name: 'Priority',
              documentation: 'Task priority levels.',
              values: [
                UtsEnumValue(name: 'high', documentation: 'High priority.'),
                UtsEnumValue(name: 'low'),
              ],
            ),
          ],
        ));
        expect(code, contains('/// Task priority levels.'));
        expect(code, contains('/// High priority.'));
      });
    });

    group('class generation', () {
      test('generates abstract interface class', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Repository',
              kind: UtsClassKind.abstractClass,
            ),
          ],
        ));
        expect(code, contains('abstract interface class Repository'));
      });

      test('generates sealed class when subclasses are defined', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Result',
              kind: UtsClassKind.sealedClass,
              sealedSubclasses: ['Success', 'Failure'],
            ),
          ],
          types: [
            UtsClass(
              name: 'Success',
              kind: UtsClassKind.dataClass,
              superclass: 'Result',
              fields: [
                UtsField(name: 'value', type: UtsType.primitive('String')),
              ],
            ),
            UtsClass(
              name: 'Failure',
              kind: UtsClassKind.dataClass,
              superclass: 'Result',
              fields: [
                UtsField(name: 'error', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        expect(code, contains('sealed class Result'));
      });

      test('generates enum for sealed class when no subclasses defined', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Variant',
              kind: UtsClassKind.sealedClass,
              sealedSubclasses: ['md5', 'sha1', 'sha256'],
            ),
          ],
        ));
        expect(code, contains('enum Variant'));
        expect(code, contains('md5'));
        expect(code, contains('sha1'));
        expect(code, contains('sha256'));
        expect(code, isNot(contains('sealed class Variant')));
      });

      test('generates class with static methods and channel (no interface)',
          () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'my-lib',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'HttpClient',
              methods: [
                UtsMethod(
                  name: 'get',
                  isStatic: true,
                  parameters: [
                    UtsParameter(
                        name: 'url', type: UtsType.primitive('String')),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        // Static-only class: no interface, no implements
        expect(code, contains('class HttpClient {'));
        expect(code, isNot(contains('HttpClientInterface')));
        expect(code, contains("AutoInteropChannel('my_lib')"));
        expect(code, contains('static Future<String> get'));
      });

      test('generates interface for concrete class with instance methods', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'my-lib',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'ApiClient',
              methods: [
                UtsMethod(
                  name: 'fetch',
                  parameters: [
                    UtsParameter(
                        name: 'url', type: UtsType.primitive('String')),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        expect(code, contains('abstract interface class ApiClientInterface'));
        expect(code, contains('class ApiClient implements ApiClientInterface'));
        expect(code, contains('@override'));
      });
    });

    group('full date-fns example', () {
      test('generates complete date-fns binding with interface', () {
        final code = generator.generateDartCode(_createDateFnsSchema());

        // Interface
        expect(code, contains('abstract interface class DateFnsInterface'));
        expect(code, contains('Future<String> format('));

        // Class name
        expect(code, contains('class DateFns implements DateFnsInterface'));

        // Instance accessor
        expect(code, contains('static final DateFns instance = DateFns._();'));
        expect(code, contains('DateFns._();'));

        // Channel
        expect(code, contains("AutoInteropChannel('date_fns')"));

        // format method with @override
        expect(code, contains('@override'));
        expect(code, contains('Future<String> format('));
        expect(code, contains('DateTime date'));
        expect(code, contains('String formatStr'));
        expect(code, contains('date.toIso8601String()'));

        // addDays method
        expect(code, contains('Future<DateTime> addDays('));

        // FormatOptions data class (unchanged)
        expect(code, contains('class FormatOptions'));
        expect(code, contains('final String? locale'));
        expect(code, contains('final int? weekStartsOn'));
        expect(code, contains('FormatOptions.fromMap'));
        expect(code, contains('Map<String, dynamic> toMap()'));
      });
    });

    group('interface generation', () {
      test('generates interface before binding class', () {
        final code = generator.generateDartCode(_createMinimalSchema());
        final interfacePos =
            code.indexOf('abstract interface class TestInterface');
        final classPos = code.indexOf('class Test implements TestInterface');
        expect(interfacePos, greaterThanOrEqualTo(0));
        expect(classPos, greaterThan(interfacePos));
      });

      test('interface contains method signatures without bodies', () {
        final code = generator.generateDartCode(_createMinimalSchema());
        // Interface should have signature ending with ;
        final interfaceBlock = code.substring(
          code.indexOf('abstract interface class TestInterface'),
          code.indexOf(
                  '}', code.indexOf('abstract interface class TestInterface')) +
              1,
        );
        expect(interfaceBlock, contains('Future<void> noop();'));
        expect(interfaceBlock, isNot(contains('async')));
      });

      test('interface includes documented method signatures', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'doWork',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('String'),
              documentation: 'Does some work.',
            ),
          ],
        ));
        final interfaceBlock = code.substring(
          code.indexOf('abstract interface class TestInterface'),
          code.indexOf(
                  '}', code.indexOf('abstract interface class TestInterface')) +
              1,
        );
        expect(interfaceBlock, contains('/// Does some work.'));
        expect(interfaceBlock, contains('Future<String> doWork();'));
      });

      test('generates interface for concrete class with instance methods', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'lib',
          source: PackageSource.gradle,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Gson',
              documentation: 'JSON serializer.',
              methods: [
                UtsMethod(
                  name: 'toJson',
                  parameters: [
                    UtsParameter(
                        name: 'src', type: UtsType.primitive('String')),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        expect(code, contains('abstract interface class GsonInterface'));
        expect(code, contains('class Gson implements GsonInterface'));
      });

      test('does not generate interface for sealed class', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Result',
              kind: UtsClassKind.sealedClass,
              sealedSubclasses: ['Success', 'Failure'],
            ),
          ],
          types: [
            UtsClass(
              name: 'Success',
              kind: UtsClassKind.dataClass,
              superclass: 'Result',
              fields: [
                UtsField(name: 'value', type: UtsType.primitive('String')),
              ],
            ),
            UtsClass(
              name: 'Failure',
              kind: UtsClassKind.dataClass,
              superclass: 'Result',
              fields: [
                UtsField(name: 'error', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        expect(code, isNot(contains('ResultInterface')));
        expect(code, contains('sealed class Result'));
      });

      test('does not generate interface for data class', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Point',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'x', type: UtsType.primitive('double')),
              ],
            ),
          ],
        ));
        expect(code, isNot(contains('PointInterface')));
      });

      test('abstract class with instance methods becomes concrete handle proxy',
          () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Repository',
              kind: UtsClassKind.abstractClass,
              methods: [
                UtsMethod(
                  name: 'findAll',
                  parameters: [],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        // Abstract classes with instance methods become concrete handle proxies
        expect(code, contains('class Repository {'));
        expect(code, contains('final String _handle;'));
        expect(code, contains('static Repository fromHandle('));
        expect(code, contains("'_handle': _handle,"));
        // Abstract classes don't get a separate RepositoryInterface
        expect(code, isNot(contains('RepositoryInterface')));
        // Abstract classes don't get a create() factory
        expect(code, isNot(contains('create()')));
      });

      test('concrete class with only static methods does not get interface',
          () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Utils',
              methods: [
                UtsMethod(
                  name: 'helper',
                  isStatic: true,
                  parameters: [],
                  returnType: UtsType.voidType(),
                ),
              ],
            ),
          ],
        ));
        expect(code, isNot(contains('UtilsInterface')));
        expect(code, contains('class Utils {'));
      });
    });

    group('Uri serialization', () {
      test('serializes Uri parameters with .toString()', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'open',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'url', type: UtsType.primitive('Uri')),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code, contains('url.toString()'));
      });

      test('deserializes Uri return values with Uri.parse()', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getUrl',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('Uri'),
            ),
          ],
        ));
        expect(code, contains("invoke<String>('getUrl')"));
        expect(code, contains('Uri.parse(result)'));
      });

      test('deserializes Uri from map fields with Uri.parse()', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Link',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'url', type: UtsType.primitive('Uri')),
              ],
            ),
          ],
        ));
        expect(code, contains("Uri.parse(map['url'] as String)"));
        expect(code, contains("'url': url.toString()"));
      });
    });

    group('nativeObject serialization', () {
      test('serializes nativeObject parameters with ._handle', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'send',
              isStatic: true,
              parameters: [
                UtsParameter(
                    name: 'request', type: UtsType.nativeObject('URLRequest')),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code, contains('request._handle'));
      });

      test('deserializes nativeObject from map fields with fromHandle', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Container',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'error', type: UtsType.nativeObject('NSError')),
              ],
            ),
          ],
        ));
        expect(code, contains("NSError.fromHandle(map['error'] as String)"));
        expect(code, contains("'error': error._handle"));
      });
    });

    group('stub class generation', () {
      test('generates opaque stub for external nativeObject types', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getError',
              isStatic: true,
              parameters: [],
              returnType: UtsType.nativeObject('NSError'),
            ),
          ],
        ));
        expect(code, contains('class NSError {'));
        expect(code, contains('final String _handle;'));
        expect(code, contains('NSError._(this._handle);'));
        expect(code, contains('static NSError fromHandle(String handle)'));
      });

      test('does not generate stub for defined types', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'MyClass',
              methods: [
                UtsMethod(
                  name: 'doWork',
                  returnType: UtsType.nativeObject('MyClass'),
                ),
              ],
            ),
          ],
        ));
        // MyClass is defined in schema, so no stub should be generated
        // It should appear once as the actual class (+ interface), not as a stub
        // Use word boundary to avoid matching MyClassInterface
        expect(
            RegExp(r'class MyClass\b[^I]').allMatches(code).length, equals(1));
      });

      test('emits import for custom type overrides instead of stub', () {
        final code = generator.generateDartCode(
          UnifiedTypeSchema(
            package: 'test',
            source: PackageSource.npm,
            version: '1.0.0',
            functions: [
              UtsMethod(
                name: 'getReq',
                isStatic: true,
                parameters: [],
                returnType: UtsType.nativeObject('URLRequest'),
              ),
            ],
          ),
          customTypes: {'URLRequest': 'lib/types/networking.dart'},
        );
        expect(code, contains("import 'lib/types/networking.dart';"));
        expect(code, isNot(contains('class URLRequest {')));
      });
    });

    group('double-nullable fix', () {
      test('does not produce double ?? for already-nullable optional params',
          () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'doWork',
              isStatic: true,
              parameters: [
                UtsParameter(
                  name: 'error',
                  type: UtsType.object('AFError', nullable: true),
                  isNamed: true,
                  isOptional: true,
                ),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
          types: [
            UtsClass(
              name: 'AFError',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'message', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        // Should contain AFError? but NOT AFError??
        expect(code, contains('AFError?'));
        expect(code, isNot(contains('AFError??')));
      });

      test('still makes non-nullable optional params nullable', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'doWork',
              isStatic: true,
              parameters: [
                UtsParameter(
                  name: 'name',
                  type: UtsType.primitive('String'),
                  isNamed: true,
                  isOptional: true,
                ),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code, contains('String? name'));
      });
    });

    group('empty enum fix', () {
      test('generates placeholder for enums with zero values', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(name: 'EmptyEnum', values: []),
          ],
        ));
        expect(code, contains('enum EmptyEnum'));
        expect(code, contains('_placeholder;'));
      });

      test('still generates enums with values normally', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(name: 'Color', values: [
              UtsEnumValue(name: 'red'),
            ]),
          ],
        ));
        expect(code, contains('enum Color'));
        expect(code, isNot(contains('_placeholder')));
      });
    });

    group('Object method conflict fix', () {
      test('filters toString from interface methods', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'MyObj',
              methods: [
                UtsMethod(
                  name: 'toString',
                  returnType: UtsType.primitive('String'),
                ),
                UtsMethod(
                  name: 'doWork',
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        // Interface should not contain toString
        final interfaceBlock = code.substring(
          code.indexOf('abstract interface class MyObjInterface'),
          code.indexOf('}',
                  code.indexOf('abstract interface class MyObjInterface')) +
              1,
        );
        expect(interfaceBlock, isNot(contains('toString')));
        expect(interfaceBlock, contains('doWork'));
      });

      test('filters hashCode from class methods', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'MyObj',
              methods: [
                UtsMethod(
                  name: 'hashCode',
                  returnType: UtsType.primitive('int'),
                ),
                UtsMethod(
                  name: 'doWork',
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        // Class body should not contain hashCode method
        expect(code, isNot(contains("'MyObj.hashCode'")));
        expect(code, contains("'MyObj.doWork'"));
      });
    });

    group('empty data class fix', () {
      test('generates toMap for zero-field data class', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'FormatOptions',
              kind: UtsClassKind.dataClass,
              fields: [],
            ),
          ],
        ));
        expect(code, contains('class FormatOptions'));
        expect(code, contains('FormatOptions.fromMap'));
        expect(code, contains('Map<String, dynamic> toMap()'));
      });

      test('empty data class toMap returns empty map', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Empty',
              kind: UtsClassKind.dataClass,
              fields: [],
            ),
          ],
        ));
        expect(code, contains('Map<String, dynamic> toMap() => {'));
      });
    });

    group('dart:core stub blocklist fix', () {
      test('does not generate stub for Duration', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getTimeout',
              isStatic: true,
              parameters: [],
              returnType: UtsType.nativeObject('Duration'),
            ),
          ],
        ));
        expect(code, isNot(contains('class Duration {')));
      });

      test('does not generate stub for Error', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getError',
              isStatic: true,
              parameters: [],
              returnType: UtsType.nativeObject('Error'),
            ),
          ],
        ));
        expect(code, isNot(contains('class Error {')));
      });

      test('does not generate stub for Exception', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getException',
              isStatic: true,
              parameters: [],
              returnType: UtsType.nativeObject('Exception'),
            ),
          ],
        ));
        expect(code, isNot(contains('class Exception {')));
      });

      test('still generates stub for non-dart:core native objects', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getReq',
              isStatic: true,
              parameters: [],
              returnType: UtsType.nativeObject('URLRequest'),
            ),
          ],
        ));
        expect(code, contains('class URLRequest {'));
      });
    });

    group('reserved keyword escaping', () {
      test('escapes reserved field names in data class declarations', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Filter',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'in', type: UtsType.primitive('String')),
                UtsField(name: 'for', type: UtsType.primitive('int')),
                UtsField(name: 'safe', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        // Field declarations use escaped names
        expect(code, contains(r'final String in$;'));
        expect(code, contains(r'final int for$;'));
        expect(code, contains('final String safe;'));
      });

      test('escapes reserved field names in constructor', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Filter',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'in', type: UtsType.primitive('String')),
                UtsField(name: 'for', type: UtsType.primitive('int')),
              ],
            ),
          ],
        ));
        expect(code, contains(r'required this.in$'));
        expect(code, contains(r'required this.for$'));
      });

      test('escapes reserved field names in fromMap', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Filter',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'in', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        // fromMap uses escaped name for the named parameter but original for map key
        expect(code, contains(r"in$: map['in']"));
      });

      test('preserves original wire names in toMap keys', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Filter',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'in', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        // toMap key is the original wire name, value is escaped
        expect(code, contains(r"'in': in$"));
      });

      test('does not escape non-reserved names', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Filter',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'value', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        expect(code, contains('final String value;'));
        expect(code, contains('required this.value'));
        expect(code, isNot(contains(r'value$')));
      });

      test('escapes reserved parameter names in methods', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'search',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'in', type: UtsType.primitive('String')),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        // Parameter declaration uses escaped name
        expect(code, contains(r'String in$'));
        // Map key preserves wire name
        expect(code, contains("'in':"));
      });

      test('escapes reserved method names in interface and implementation', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'in',
              isStatic: true,
              parameters: [],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        // Method declaration uses escaped name
        expect(code, contains(r'in$('));
        // Channel wire name preserves original
        expect(code, contains("('in')"));
      });

      test('escapes reserved enum value names', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(
              name: 'Direction',
              values: [
                UtsEnumValue(name: 'in'),
                UtsEnumValue(name: 'out'),
                UtsEnumValue(name: 'for'),
              ],
            ),
          ],
        ));
        expect(code, contains(r'in$,'));
        expect(code, contains('out,'));
        expect(code, contains(r'for$;'));
      });

      test('escapes nullable reserved field in toMap null check', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Options',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(
                    name: 'in',
                    type: UtsType.primitive('String'),
                    nullable: true),
              ],
            ),
          ],
        ));
        // Null-check uses escaped name, map key stays original
        expect(code, contains(r"if (in$ != null) 'in': in$"));
      });
    });

    group('deduplication', () {
      test('duplicate methods produce only one method in output', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'MyClass',
              kind: UtsClassKind.concreteClass,
              methods: [
                UtsMethod(
                  name: 'doWork',
                  isStatic: false,
                  returnType: UtsType.voidType(),
                ),
                UtsMethod(
                  name: 'doWork',
                  isStatic: false,
                  parameters: [
                    UtsParameter(name: 'x', type: UtsType.primitive('int')),
                  ],
                  returnType: UtsType.voidType(),
                ),
              ],
            ),
          ],
        ));
        // Should appear exactly once in the interface
        expect(
          RegExp(r'doWork\(').allMatches(code).length,
          // Once in interface, once in class (with @override)
          equals(2),
        );
      });

      test('duplicate fields produce only one field in data class output', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Options',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'timeout', type: UtsType.primitive('int')),
                UtsField(name: 'timeout', type: UtsType.primitive('double')),
              ],
            ),
          ],
        ));
        // 'final int timeout;' should appear only once
        expect(
          RegExp(r'final \w+ timeout;').allMatches(code).length,
          equals(1),
        );
      });
    });

    group('reference types', () {
      test('reference type classes do not emit data fields', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Client',
              kind: UtsClassKind.concreteClass,
              fields: [
                UtsField(name: 'timeout', type: UtsType.primitive('int')),
              ],
              methods: [
                UtsMethod(
                  name: 'fetch',
                  isStatic: false,
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        // Should have _handle but NOT the data field
        expect(code, contains('_handle'));
        expect(code, isNot(contains('final int timeout;')));
      });

      test('reference type classes do not emit fromMap or toMap', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Client',
              kind: UtsClassKind.concreteClass,
              fields: [
                UtsField(name: 'timeout', type: UtsType.primitive('int')),
              ],
              methods: [
                UtsMethod(
                  name: 'fetch',
                  isStatic: false,
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        expect(code, isNot(contains('fromMap')));
        expect(code, isNot(contains('toMap')));
      });

      test('reference type classes do not emit field-based constructor', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Client',
              kind: UtsClassKind.concreteClass,
              fields: [
                UtsField(name: 'timeout', type: UtsType.primitive('int')),
              ],
              methods: [
                UtsMethod(
                  name: 'fetch',
                  isStatic: false,
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        // Should NOT have Client({required this.timeout})
        expect(code, isNot(contains('required this.timeout')));
      });
    });

    group('static/instance conflicts', () {
      test('static method conflicting with instance method is skipped', () {
        final code = generator.generateDartCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Session',
              kind: UtsClassKind.concreteClass,
              methods: [
                UtsMethod(
                  name: 'start',
                  isStatic: true,
                  returnType: UtsType.voidType(),
                ),
                UtsMethod(
                  name: 'start',
                  isStatic: false,
                  returnType: UtsType.voidType(),
                ),
              ],
            ),
          ],
        ));
        // 'static' should not appear before 'start' — instance wins
        expect(code, isNot(contains('static Future<void> start(')));
      });
    });

    group('naming conventions', () {
      test('converts package name with hyphens to PascalCase', () {
        final schema = UnifiedTypeSchema(
          package: 'my-awesome-lib',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'test',
              isStatic: true,
              returnType: UtsType.voidType(),
            ),
          ],
        );
        final code = generator.generateDartCode(schema);
        expect(code,
            contains('class MyAwesomeLib implements MyAwesomeLibInterface'));
      });

      test('converts package name with dots to snake_case channel', () {
        final schema = UnifiedTypeSchema(
          package: 'com.example.lib',
          source: PackageSource.gradle,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'test',
              isStatic: true,
              returnType: UtsType.voidType(),
            ),
          ],
        );
        final code = generator.generateDartCode(schema);
        expect(code, contains("AutoInteropChannel('com_example_lib')"));
      });
    });
  });
}

UnifiedTypeSchema _createMinimalSchema() {
  return UnifiedTypeSchema(
    package: 'test',
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
            name: 'date',
            type: UtsType.primitive('DateTime'),
          ),
          UtsParameter(
            name: 'formatStr',
            type: UtsType.primitive('String'),
          ),
          UtsParameter(
            name: 'options',
            type: UtsType.object('FormatOptions'),
            isOptional: true,
            isNamed: true,
          ),
        ],
        returnType: UtsType.primitive('String'),
        documentation: 'Formats a date according to the given format string.',
      ),
      UtsMethod(
        name: 'addDays',
        isStatic: true,
        parameters: [
          UtsParameter(
            name: 'date',
            type: UtsType.primitive('DateTime'),
          ),
          UtsParameter(
            name: 'amount',
            type: UtsType.primitive('int'),
          ),
        ],
        returnType: UtsType.primitive('DateTime'),
      ),
    ],
    types: [
      UtsClass(
        name: 'FormatOptions',
        kind: UtsClassKind.dataClass,
        fields: [
          UtsField(
            name: 'locale',
            type: UtsType.primitive('String'),
            nullable: true,
          ),
          UtsField(
            name: 'weekStartsOn',
            type: UtsType.primitive('int'),
            nullable: true,
          ),
        ],
      ),
    ],
  );
}
