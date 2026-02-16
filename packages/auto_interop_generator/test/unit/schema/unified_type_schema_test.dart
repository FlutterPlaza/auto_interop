import 'dart:convert';

import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  group('UnifiedTypeSchema', () {
    late UnifiedTypeSchema schema;

    setUp(() {
      schema = UnifiedTypeSchema(
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
                type: UtsType.object('FormatOptions', nullable: true),
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
        enums: [
          UtsEnum(
            name: 'Weekday',
            values: [
              UtsEnumValue(name: 'monday', rawValue: 1),
              UtsEnumValue(name: 'tuesday', rawValue: 2),
              UtsEnumValue(name: 'wednesday', rawValue: 3),
              UtsEnumValue(name: 'thursday', rawValue: 4),
              UtsEnumValue(name: 'friday', rawValue: 5),
              UtsEnumValue(name: 'saturday', rawValue: 6),
              UtsEnumValue(name: 'sunday', rawValue: 0),
            ],
          ),
        ],
      );
    });

    test('stores package metadata', () {
      expect(schema.package, 'date-fns');
      expect(schema.source, PackageSource.npm);
      expect(schema.version, '3.6.0');
    });

    test('stores functions', () {
      expect(schema.functions, hasLength(2));
      expect(schema.functions[0].name, 'format');
      expect(schema.functions[1].name, 'addDays');
    });

    test('stores function parameters', () {
      final format = schema.functions[0];
      expect(format.parameters, hasLength(3));
      expect(format.parameters[0].name, 'date');
      expect(format.parameters[0].type.toDartType(), 'DateTime');
      expect(format.parameters[2].isOptional, true);
      expect(format.parameters[2].isNamed, true);
    });

    test('stores types', () {
      expect(schema.types, hasLength(1));
      expect(schema.types[0].name, 'FormatOptions');
      expect(schema.types[0].fields, hasLength(2));
    });

    test('stores enums', () {
      expect(schema.enums, hasLength(1));
      expect(schema.enums[0].name, 'Weekday');
      expect(schema.enums[0].values, hasLength(7));
    });

    group('definedTypeNames', () {
      test('returns all defined type names', () {
        final names = schema.definedTypeNames;
        expect(names, contains('FormatOptions'));
        expect(names, contains('Weekday'));
      });

      test('includes class names when present', () {
        final schemaWithClasses = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(name: 'MyClient'),
          ],
          types: [
            UtsClass(name: 'MyOptions', kind: UtsClassKind.dataClass),
          ],
        );
        final names = schemaWithClasses.definedTypeNames;
        expect(names, contains('MyClient'));
        expect(names, contains('MyOptions'));
      });
    });

    group('resolveType', () {
      test('resolves existing type', () {
        final resolved = schema.resolveType('FormatOptions');
        expect(resolved, isNotNull);
        expect(resolved!.name, 'FormatOptions');
      });

      test('returns null for unknown type', () {
        expect(schema.resolveType('Unknown'), isNull);
      });
    });

    group('resolveEnum', () {
      test('resolves existing enum', () {
        final resolved = schema.resolveEnum('Weekday');
        expect(resolved, isNotNull);
        expect(resolved!.name, 'Weekday');
      });

      test('returns null for unknown enum', () {
        expect(schema.resolveEnum('Unknown'), isNull);
      });
    });

    group('JSON serialization', () {
      test('roundtrips through JSON', () {
        final json = schema.toJson();
        final jsonStr = jsonEncode(json);
        final restored =
            UnifiedTypeSchema.fromJson(jsonDecode(jsonStr));

        expect(restored.package, schema.package);
        expect(restored.source, schema.source);
        expect(restored.version, schema.version);
        expect(restored.functions.length, schema.functions.length);
        expect(restored.types.length, schema.types.length);
        expect(restored.enums.length, schema.enums.length);
      });

      test('preserves function details through JSON', () {
        final json = schema.toJson();
        final restored = UnifiedTypeSchema.fromJson(json);

        final format = restored.functions[0];
        expect(format.name, 'format');
        expect(format.isStatic, true);
        expect(format.parameters[0].name, 'date');
        expect(format.returnType.name, 'String');
      });

      test('preserves type details through JSON', () {
        final json = schema.toJson();
        final restored = UnifiedTypeSchema.fromJson(json);

        final options = restored.types[0];
        expect(options.name, 'FormatOptions');
        expect(options.kind, UtsClassKind.dataClass);
        expect(options.fields[0].name, 'locale');
        expect(options.fields[0].nullable, true);
      });

      test('preserves enum details through JSON', () {
        final json = schema.toJson();
        final restored = UnifiedTypeSchema.fromJson(json);

        final weekday = restored.enums[0];
        expect(weekday.name, 'Weekday');
        expect(weekday.values[0].name, 'monday');
        expect(weekday.values[0].rawValue, 1);
      });
    });

    group('empty schema', () {
      test('creates empty schema with defaults', () {
        final empty = UnifiedTypeSchema(
          package: 'empty',
          source: PackageSource.gradle,
          version: '0.0.0',
        );
        expect(empty.classes, isEmpty);
        expect(empty.functions, isEmpty);
        expect(empty.types, isEmpty);
        expect(empty.enums, isEmpty);
        expect(empty.definedTypeNames, isEmpty);
      });
    });

    test('toString contains useful info', () {
      final str = schema.toString();
      expect(str, contains('date-fns'));
      expect(str, contains('3.6.0'));
      expect(str, contains('npm'));
    });
  });

  group('UtsMethod', () {
    test('creates method with all fields', () {
      final method = UtsMethod(
        name: 'doSomething',
        isStatic: true,
        isAsync: true,
        parameters: [
          UtsParameter(
            name: 'input',
            type: UtsType.primitive('String'),
          ),
        ],
        returnType: UtsType.future(UtsType.primitive('int')),
        documentation: 'Does something async.',
      );

      expect(method.name, 'doSomething');
      expect(method.isStatic, true);
      expect(method.isAsync, true);
      expect(method.parameters, hasLength(1));
      expect(method.returnType.toDartType(), 'Future<int>');
      expect(method.documentation, 'Does something async.');
    });

    test('default values for optional fields', () {
      final method = UtsMethod(
        name: 'simple',
        returnType: UtsType.voidType(),
      );
      expect(method.isStatic, false);
      expect(method.isAsync, false);
      expect(method.parameters, isEmpty);
      expect(method.documentation, isNull);
    });
  });

  group('UtsParameter', () {
    test('creates required positional parameter', () {
      final param = UtsParameter(
        name: 'value',
        type: UtsType.primitive('int'),
      );
      expect(param.isOptional, false);
      expect(param.isNamed, false);
      expect(param.defaultValue, isNull);
    });

    test('creates optional named parameter with default', () {
      final param = UtsParameter(
        name: 'count',
        type: UtsType.primitive('int'),
        isOptional: true,
        isNamed: true,
        defaultValue: '0',
      );
      expect(param.isOptional, true);
      expect(param.isNamed, true);
      expect(param.defaultValue, '0');
    });
  });

  group('UtsClass', () {
    test('creates concrete class', () {
      final cls = UtsClass(
        name: 'HttpClient',
        kind: UtsClassKind.concreteClass,
        methods: [
          UtsMethod(
            name: 'get',
            parameters: [
              UtsParameter(
                name: 'url',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.future(UtsType.object('Response')),
            isAsync: true,
          ),
        ],
      );
      expect(cls.name, 'HttpClient');
      expect(cls.kind, UtsClassKind.concreteClass);
      expect(cls.methods, hasLength(1));
    });

    test('creates data class with fields', () {
      final cls = UtsClass(
        name: 'Options',
        kind: UtsClassKind.dataClass,
        fields: [
          UtsField(
            name: 'timeout',
            type: UtsType.primitive('int'),
          ),
          UtsField(
            name: 'headers',
            type: UtsType.map(
              UtsType.primitive('String'),
              UtsType.primitive('String'),
            ),
            nullable: true,
          ),
        ],
      );
      expect(cls.kind, UtsClassKind.dataClass);
      expect(cls.fields, hasLength(2));
      expect(cls.fields[1].nullable, true);
    });

    test('creates sealed class with subclasses', () {
      final cls = UtsClass(
        name: 'Result',
        kind: UtsClassKind.sealedClass,
        sealedSubclasses: ['Success', 'Failure'],
      );
      expect(cls.kind, UtsClassKind.sealedClass);
      expect(cls.sealedSubclasses, ['Success', 'Failure']);
    });

    test('creates abstract class with interfaces', () {
      final cls = UtsClass(
        name: 'Repository',
        kind: UtsClassKind.abstractClass,
        interfaces: ['Closeable', 'Disposable'],
      );
      expect(cls.kind, UtsClassKind.abstractClass);
      expect(cls.interfaces, hasLength(2));
    });
  });

  group('UtsField', () {
    test('creates readonly field', () {
      final field = UtsField(
        name: 'id',
        type: UtsType.primitive('String'),
        isReadOnly: true,
      );
      expect(field.isReadOnly, true);
    });

    test('creates field with documentation', () {
      final field = UtsField(
        name: 'name',
        type: UtsType.primitive('String'),
        documentation: 'The user name.',
      );
      expect(field.documentation, 'The user name.');
    });
  });

  group('UtsEnum', () {
    test('creates simple enum', () {
      final e = UtsEnum(
        name: 'Color',
        values: [
          UtsEnumValue(name: 'red'),
          UtsEnumValue(name: 'green'),
          UtsEnumValue(name: 'blue'),
        ],
      );
      expect(e.name, 'Color');
      expect(e.values, hasLength(3));
    });

    test('creates enum with raw values', () {
      final e = UtsEnum(
        name: 'Status',
        values: [
          UtsEnumValue(name: 'active', rawValue: 'ACTIVE'),
          UtsEnumValue(name: 'inactive', rawValue: 'INACTIVE'),
        ],
      );
      expect(e.values[0].rawValue, 'ACTIVE');
    });

    test('creates enum with documentation', () {
      final e = UtsEnum(
        name: 'Priority',
        documentation: 'Task priority levels.',
        values: [
          UtsEnumValue(
            name: 'high',
            documentation: 'High priority.',
          ),
          UtsEnumValue(name: 'low'),
        ],
      );
      expect(e.documentation, 'Task priority levels.');
      expect(e.values[0].documentation, 'High priority.');
    });
  });
}
