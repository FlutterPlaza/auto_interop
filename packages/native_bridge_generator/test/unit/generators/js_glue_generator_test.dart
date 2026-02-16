import 'package:native_bridge_generator/src/generators/js_glue_generator.dart';
import 'package:native_bridge_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late JsGlueGenerator generator;

  setUp(() {
    generator = JsGlueGenerator();
  });

  group('JsGlueGenerator', () {
    group('generate', () {
      test('returns map with _web.dart file name', () {
        final schema = _createMinimalSchema();
        final result = generator.generate(schema);
        expect(result.keys, contains('test_web.dart'));
      });

      test('converts package name to snake_case for file', () {
        final schema = _createSchemaWithPackage('date-fns');
        final result = generator.generate(schema);
        expect(result.keys, contains('date_fns_web.dart'));
      });

      test('produces deterministic output', () {
        final schema = _createDateFnsSchema();
        final result1 = generator.generateJsInteropCode(schema);
        final result2 = generator.generateJsInteropCode(schema);
        expect(result1, result2);
      });
    });

    group('header and imports', () {
      test('includes GENERATED header', () {
        final code = generator.generateJsInteropCode(_createMinimalSchema());
        expect(code, contains('GENERATED'));
        expect(code, contains('DO NOT EDIT'));
      });

      test('imports dart:js_interop', () {
        final code = generator.generateJsInteropCode(_createMinimalSchema());
        expect(code, contains("import 'dart:js_interop';"));
      });

      test('does not import dart:typed_data when not needed', () {
        final code = generator.generateJsInteropCode(_createMinimalSchema());
        expect(code, isNot(contains("import 'dart:typed_data';")));
      });

      test('imports dart:typed_data when Uint8List is used', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'download',
              isStatic: true,
              returnType: UtsType.future(UtsType.primitive('Uint8List')),
              isAsync: true,
            ),
          ],
        ));
        expect(code, contains("import 'dart:typed_data';"));
      });

      test('includes package name in header comment', () {
        final code = generator.generateJsInteropCode(
            _createSchemaWithPackage('date-fns'));
        expect(code, contains('Web JS interop bindings for date-fns'));
      });
    });

    group('JS external functions', () {
      test('generates @JS annotation with namespace', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '1.0.0',
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
        ));
        expect(code, contains("@JS('dateFns.format')"));
        expect(code, contains('external JSString _jsFormat('));
      });

      test('maps String params to JSString', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('JSString name'));
      });

      test('maps int/double params to JSNumber', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'add',
              isStatic: true,
              parameters: [
                UtsParameter(name: 'a', type: UtsType.primitive('int')),
                UtsParameter(
                    name: 'b', type: UtsType.primitive('double')),
              ],
              returnType: UtsType.primitive('double'),
            ),
          ],
        ));
        expect(code, contains('JSNumber a'));
        expect(code, contains('JSNumber b'));
      });

      test('maps bool params to JSBoolean', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
              returnType: UtsType.primitive('bool'),
            ),
          ],
        ));
        expect(code, contains('JSBoolean value'));
      });

      test('maps DateTime params to JSString', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('JSString date'));
      });

      test('maps async return to JSPromise', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'fetchData',
              isStatic: true,
              isAsync: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('JSPromise<JSString> _jsFetchData'));
      });

      test('maps Future return type to JSPromise', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'fetchData',
              isStatic: true,
              returnType: UtsType.future(UtsType.primitive('String')),
            ),
          ],
        ));
        expect(code, contains('JSPromise<JSString>'));
      });

      test('maps void return to void', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('external void _jsReset'));
      });

      test('maps callback params to JSFunction', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'listen',
              isStatic: true,
              parameters: [
                UtsParameter(
                  name: 'handler',
                  type: UtsType.callback(
                    parameterTypes: [UtsType.primitive('String')],
                    returnType: UtsType.voidType(),
                  ),
                ),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        ));
        expect(code, contains('JSFunction handler'));
      });
    });

    group('Dart wrapper class', () {
      test('generates class with PascalCase name', () {
        final code = generator.generateJsInteropCode(
            _createSchemaWithPackage('date-fns'));
        expect(code, contains('class DateFns'));
      });

      test('generates static methods', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('static String greet(String name)'));
      });

      test('converts String to JS and back', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'echo',
              isStatic: true,
              parameters: [
                UtsParameter(
                    name: 'msg', type: UtsType.primitive('String')),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('msg.toJS'));
        expect(code, contains('jsResult.toDart'));
      });

      test('converts DateTime to ISO string for JS', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'formatDate',
              isStatic: true,
              parameters: [
                UtsParameter(
                    name: 'date', type: UtsType.primitive('DateTime')),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('date.toIso8601String().toJS'));
      });

      test('converts JSString back to DateTime', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getDate',
              isStatic: true,
              returnType: UtsType.primitive('DateTime'),
            ),
          ],
        ));
        expect(code, contains('DateTime.parse(jsResult.toDart)'));
      });

      test('converts JSNumber to int', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'count',
              isStatic: true,
              returnType: UtsType.primitive('int'),
            ),
          ],
        ));
        expect(code, contains('jsResult.toDartInt'));
      });

      test('converts JSNumber to double', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'measure',
              isStatic: true,
              returnType: UtsType.primitive('double'),
            ),
          ],
        ));
        expect(code, contains('jsResult.toDartDouble'));
      });

      test('generates async method with await', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'fetchData',
              isStatic: true,
              isAsync: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains('Future<String> fetchData'));
        expect(code, contains('async'));
        expect(code, contains('.toDart'));
      });

      test('generates void method', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('static void reset()'));
        expect(code, contains('_jsReset()'));
      });

      test('generates documentation', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              returnType: UtsType.primitive('String'),
              documentation: 'Formats a date string.',
            ),
          ],
        ));
        expect(code, contains('/// Formats a date string.'));
      });
    });

    group('JS interop types (interfaces)', () {
      test('generates JS extension type for interface', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          types: [
            UtsClass(
              name: 'Response',
              kind: UtsClassKind.dataClass,
              fields: [
                UtsField(name: 'status', type: UtsType.primitive('double')),
                UtsField(name: 'body', type: UtsType.primitive('String')),
              ],
            ),
          ],
        ));
        expect(code, contains('@JS()'));
        expect(code, contains('extension type _JsResponse._(JSObject _)'));
        expect(code, contains('external JSNumber get status'));
        expect(code, contains('external JSString get body'));
      });

      test('handles nullable fields in extension type', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('external JSString? get locale'));
      });

      test('generates Dart data class with fromJs', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('class Point'));
        expect(code, contains('final double x'));
        expect(code, contains('final double y'));
        expect(code, contains('factory Point.fromJs(_JsPoint js)'));
        expect(code, contains('js.x.toDartDouble'));
        expect(code, contains('js.y.toDartDouble'));
      });

      test('generates constructor with required and optional fields', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
                    name: 'timeout',
                    type: UtsType.primitive('int'),
                    nullable: true),
              ],
            ),
          ],
        ));
        expect(code, contains('required this.name'));
        expect(code, contains('this.timeout'));
      });

      test('generates toJs method', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        expect(code, contains('JSObject toJs()'));
      });
    });

    group('JS interop classes', () {
      test('generates JS extension type for class', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'HttpClient',
              methods: [
                UtsMethod(
                  name: 'get',
                  isAsync: true,
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
        expect(code, contains("@JS('HttpClient')"));
        expect(code, contains('extension type _JsHttpClient._(JSObject _)'));
        expect(code, contains('external factory _JsHttpClient()'));
        expect(code, contains('external JSPromise<JSString> get('));
        expect(code, contains('external void close('));
      });

      test('generates Dart wrapper class', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'HttpClient',
              documentation: 'HTTP client.',
              methods: [
                UtsMethod(
                  name: 'close',
                  returnType: UtsType.voidType(),
                ),
              ],
            ),
          ],
        ));
        expect(code, contains('/// HTTP client.'));
        expect(code, contains('class HttpClient'));
        expect(code, contains('final _JsHttpClient _js'));
        expect(code, contains('HttpClient() : _js = _JsHttpClient()'));
      });

      test('generates Dart async method that awaits JSPromise', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Client',
              methods: [
                UtsMethod(
                  name: 'fetch',
                  isAsync: true,
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
        expect(code, contains('Future<String> fetch(String url) async'));
        expect(code, contains('await _js.fetch(url.toJS).toDart'));
      });

      test('generates void method calling JS directly', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Timer',
              methods: [
                UtsMethod(
                  name: 'stop',
                  returnType: UtsType.voidType(),
                ),
              ],
            ),
          ],
        ));
        expect(code, contains('void stop()'));
        expect(code, contains('_js.stop()'));
      });
    });

    group('enum generation', () {
      test('generates Dart enum', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
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
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(
              name: 'Priority',
              documentation: 'Priority levels.',
              values: [
                UtsEnumValue(
                    name: 'high', documentation: 'High priority.'),
                UtsEnumValue(name: 'low'),
              ],
            ),
          ],
        ));
        expect(code, contains('/// Priority levels.'));
        expect(code, contains('/// High priority.'));
      });
    });

    group('JS namespace', () {
      test('converts hyphenated package to camelCase', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains("@JS('dateFns.format')"));
      });

      test('keeps simple package name lowercase', () {
        final code = generator.generateJsInteropCode(UnifiedTypeSchema(
          package: 'lodash',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'chunk',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        ));
        expect(code, contains("@JS('lodash.chunk')"));
      });
    });

    group('full date-fns example', () {
      test('generates complete web bindings', () {
        final code =
            generator.generateJsInteropCode(_createDateFnsSchema());

        // Imports
        expect(code, contains("import 'dart:js_interop';"));

        // JS external functions
        expect(code, contains("@JS('dateFns.format')"));
        expect(code, contains('external JSString _jsFormat('));
        expect(code, contains("@JS('dateFns.addDays')"));

        // Dart wrapper
        expect(code, contains('class DateFns'));
        expect(code, contains('static String format('));
        expect(code, contains('DateTime date'));
        expect(code, contains('date.toIso8601String().toJS'));

        // Data class
        expect(code, contains('class FormatOptions'));
        expect(code, contains('factory FormatOptions.fromJs'));
        expect(code, contains('JSObject toJs()'));
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

UnifiedTypeSchema _createSchemaWithPackage(String packageName) {
  return UnifiedTypeSchema(
    package: packageName,
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
