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
                UtsParameter(
                    name: 'date', type: UtsType.primitive('String')),
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
        final code =
            generator.generateDartCode(_createMinimalSchema());
        expect(code, contains('GENERATED'));
        expect(code, contains('DO NOT EDIT'));
      });

      test('imports auto_interop', () {
        final code =
            generator.generateDartCode(_createMinimalSchema());
        expect(code,
            contains("import 'package:auto_interop/auto_interop.dart';"));
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
                UtsParameter(
                    name: 'a', type: UtsType.primitive('int')),
                UtsParameter(
                    name: 'b', type: UtsType.primitive('int')),
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
                UtsParameter(
                    name: 'date', type: UtsType.primitive('String')),
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
                UtsParameter(
                    name: 'date', type: UtsType.primitive('DateTime')),
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
                UtsParameter(
                    name: 'options',
                    type: UtsType.object('Options')),
              ],
              returnType: UtsType.voidType(),
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
                UtsParameter(
                    name: 'name', type: UtsType.primitive('String')),
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
                UtsField(
                    name: 'timeout', type: UtsType.primitive('int')),
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
                UtsField(
                    name: 'name', type: UtsType.primitive('String')),
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
                UtsEnumValue(
                    name: 'high', documentation: 'High priority.'),
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

      test('generates sealed class', () {
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
        ));
        expect(code, contains('sealed class Result'));
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
                        name: 'url',
                        type: UtsType.primitive('String')),
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

      test('generates interface for concrete class with instance methods',
          () {
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
                        name: 'url',
                        type: UtsType.primitive('String')),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        expect(
            code, contains('abstract interface class ApiClientInterface'));
        expect(code,
            contains('class ApiClient implements ApiClientInterface'));
        expect(code, contains('@override'));
      });
    });

    group('full date-fns example', () {
      test('generates complete date-fns binding with interface', () {
        final code =
            generator.generateDartCode(_createDateFnsSchema());

        // Interface
        expect(
            code, contains('abstract interface class DateFnsInterface'));
        expect(code, contains('Future<String> format('));

        // Class name
        expect(
            code, contains('class DateFns implements DateFnsInterface'));

        // Instance accessor
        expect(code,
            contains('static final DateFns instance = DateFns._();'));
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
        final code =
            generator.generateDartCode(_createMinimalSchema());
        final interfacePos =
            code.indexOf('abstract interface class TestInterface');
        final classPos =
            code.indexOf('class Test implements TestInterface');
        expect(interfacePos, greaterThanOrEqualTo(0));
        expect(classPos, greaterThan(interfacePos));
      });

      test('interface contains method signatures without bodies', () {
        final code =
            generator.generateDartCode(_createMinimalSchema());
        // Interface should have signature ending with ;
        final interfaceBlock = code.substring(
          code.indexOf('abstract interface class TestInterface'),
          code.indexOf('}',
                  code.indexOf('abstract interface class TestInterface')) +
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
          code.indexOf('}',
                  code.indexOf('abstract interface class TestInterface')) +
              1,
        );
        expect(interfaceBlock, contains('/// Does some work.'));
        expect(interfaceBlock, contains('Future<String> doWork();'));
      });

      test(
          'generates interface for concrete class with instance methods',
          () {
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
                        name: 'src',
                        type: UtsType.primitive('String')),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        ));
        expect(code,
            contains('abstract interface class GsonInterface'));
        expect(code,
            contains('class Gson implements GsonInterface'));
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
                UtsField(
                    name: 'x', type: UtsType.primitive('double')),
              ],
            ),
          ],
        ));
        expect(code, isNot(contains('PointInterface')));
      });

      test('abstract class becomes abstract interface class', () {
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
        expect(
            code, contains('abstract interface class Repository {'));
        // Abstract classes don't get a separate RepositoryInterface
        expect(code, isNot(contains('RepositoryInterface')));
      });

      test(
          'concrete class with only static methods does not get interface',
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
        documentation:
            'Formats a date according to the given format string.',
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
