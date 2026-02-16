import 'package:native_bridge_generator/src/generators/dart_generator.dart';
import 'package:native_bridge_generator/src/schema/unified_type_schema.dart';
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

      test('imports native_bridge', () {
        final code =
            generator.generateDartCode(_createMinimalSchema());
        expect(code,
            contains("import 'package:native_bridge/native_bridge.dart';"));
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
        expect(code, contains('class DateFns'));
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
        expect(code, contains("NativeBridgeChannel('date_fns')"));
      });
    });

    group('method generation', () {
      test('generates static async method', () {
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
        expect(code, contains('static Future<String> doSomething() async'));
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
        expect(code, contains('static Future<void> reset()'));
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
      test('generates abstract class', () {
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
        expect(code, contains('abstract class Repository'));
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

      test('generates class with methods and channel', () {
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
        expect(code, contains('class HttpClient'));
        expect(code, contains("NativeBridgeChannel('my_lib')"));
        expect(code, contains('Future<String> get'));
      });
    });

    group('full date-fns example', () {
      test('generates complete date-fns binding', () {
        final code =
            generator.generateDartCode(_createDateFnsSchema());

        // Class name
        expect(code, contains('class DateFns'));

        // Channel
        expect(code, contains("NativeBridgeChannel('date_fns')"));

        // format method
        expect(code, contains('Future<String> format('));
        expect(code, contains('DateTime date'));
        expect(code, contains('String formatStr'));
        expect(code, contains('date.toIso8601String()'));

        // addDays method
        expect(code, contains('Future<DateTime> addDays('));

        // FormatOptions data class
        expect(code, contains('class FormatOptions'));
        expect(code, contains('final String? locale'));
        expect(code, contains('final int? weekStartsOn'));
        expect(code, contains('FormatOptions.fromMap'));
        expect(code, contains('Map<String, dynamic> toMap()'));
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
        expect(code, contains('class MyAwesomeLib'));
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
        expect(code, contains("NativeBridgeChannel('com_example_lib')"));
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
