import 'package:auto_interop_generator/src/generators/swift_glue_generator.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late SwiftGlueGenerator generator;

  setUp(() {
    generator = SwiftGlueGenerator();
  });

  group('SwiftGlueGenerator', () {
    group('generate', () {
      test('returns map with Plugin.swift file name', () {
        final schema = _createMinimalSchema('test');
        final result = generator.generate(schema);
        expect(result.keys, contains('TestPlugin.swift'));
      });

      test('converts package name to PascalCase for class', () {
        final schema = _createMinimalSchema('Alamofire');
        final result = generator.generate(schema);
        expect(result.keys, contains('AlamofirePlugin.swift'));
      });

      test('produces deterministic output', () {
        final schema = _createMinimalSchema('test');
        final result1 = generator.generateSwiftCode(schema);
        final result2 = generator.generateSwiftCode(schema);
        expect(result1, result2);
      });
    });

    group('header and imports', () {
      test('includes GENERATED header', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code, contains('GENERATED'));
        expect(code, contains('DO NOT EDIT'));
      });

      test('includes package name in header', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('Alamofire'));
        expect(code, contains('Swift platform channel handler for Alamofire'));
      });

      test('imports Flutter', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code, contains('import Flutter'));
      });

      test('imports UIKit', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code, contains('import UIKit'));
      });
    });

    group('plugin class structure', () {
      test('declares public class extending NSObject, FlutterPlugin', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code,
            contains('public class TestPlugin: NSObject, FlutterPlugin'));
      });

      test('has register(with:) static method', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code,
            contains('public static func register(with registrar: FlutterPluginRegistrar)'));
      });

      test('creates method channel with snake_case name', () {
        final code = generator
            .generateSwiftCode(_createMinimalSchema('my-package'));
        expect(code, contains('"my_package"'));
      });

      test('has handle method', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code,
            contains('public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)'));
      });

      test('has default case returning FlutterMethodNotImplemented', () {
        final code = generator.generateSwiftCode(_createSchemaWithMethod());
        expect(code, contains('result(FlutterMethodNotImplemented)'));
      });
    });

    group('method dispatch', () {
      test('generates case for each function', () {
        final schema = _createSchemaWithMethod();
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('case "greet":'));
      });

      test('extracts String arguments', () {
        final schema = _createSchemaWithMethod();
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let name = args["name"] as! String'));
      });

      test('extracts Int arguments', () {
        final schema = _createSchemaWithParam('age', 'int');
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let age = args["age"] as! Int'));
      });

      test('extracts Bool arguments', () {
        final schema = _createSchemaWithParam('active', 'bool');
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let active = args["active"] as! Bool'));
      });

      test('extracts Double arguments', () {
        final schema = _createSchemaWithParam('price', 'double');
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let price = args["price"] as! Double'));
      });

      test('extracts DateTime as String with ISO conversion', () {
        final schema = _createSchemaWithParam('date', 'DateTime');
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let date = args["date"] as! String'));
        expect(code, contains('ISO8601DateFormatter'));
      });

      test('extracts optional arguments with as?', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'search',
              parameters: [
                UtsParameter(
                  name: 'query',
                  type: UtsType.primitive('String'),
                ),
                UtsParameter(
                  name: 'limit',
                  type: UtsType.primitive('int'),
                  isOptional: true,
                ),
              ],
              returnType: UtsType.primitive('String'),
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let query = args["query"] as! String'));
        expect(code, contains('let limit = args["limit"] as? Int'));
      });

      test('extracts object as dictionary', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'process',
              parameters: [
                UtsParameter(
                  name: 'config',
                  type: UtsType.object('Config'),
                ),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let config = args["config"] as! [String: Any]'));
      });

      test('extracts list arguments', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'process',
              parameters: [
                UtsParameter(
                  name: 'items',
                  type: UtsType.list(UtsType.primitive('String')),
                ),
              ],
              returnType: UtsType.voidType(),
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let items = args["items"] as! [Any]'));
      });

      test('void methods return nil', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'reset',
              returnType: UtsType.voidType(),
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('result(nil)'));
      });

      test('non-void methods have error handling', () {
        final schema = _createSchemaWithMethod();
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('do {'));
        expect(code, contains('} catch {'));
        expect(code, contains('FlutterError'));
      });

      test('async methods have error handling', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'fetch',
              isAsync: true,
              returnType: UtsType.future(UtsType.primitive('String')),
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('do {'));
        expect(code, contains('} catch {'));
      });
    });

    group('class method prefixing', () {
      test('prefixes class methods with class name', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'ImageLoader',
              methods: [
                UtsMethod(
                  name: 'load',
                  parameters: [
                    UtsParameter(
                        name: 'url', type: UtsType.primitive('String')),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('case "ImageLoader.load":'));
      });
    });

    group('full Alamofire example', () {
      test('generates valid structure', () {
        final schema = _createAlamofireSchema();
        final code = generator.generateSwiftCode(schema);

        expect(code, contains('AlamofirePlugin'));
        expect(code, contains('case "AF.request":'));
        expect(code, contains('case "AF.download":'));
        expect(code, contains('let url = args["url"] as! String'));
        expect(code, contains('FlutterMethodNotImplemented'));
      });
    });
  });
}

// --- Test helpers ---

UnifiedTypeSchema _createMinimalSchema(String packageName) {
  return UnifiedTypeSchema(
    package: packageName,
    source: PackageSource.cocoapods,
    version: '1.0.0',
  );
}

UnifiedTypeSchema _createSchemaWithMethod() {
  return UnifiedTypeSchema(
    package: 'test',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'greet',
        parameters: [
          UtsParameter(name: 'name', type: UtsType.primitive('String')),
        ],
        returnType: UtsType.primitive('String'),
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithParam(String paramName, String typeName) {
  return UnifiedTypeSchema(
    package: 'test',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'doStuff',
        parameters: [
          UtsParameter(name: paramName, type: UtsType.primitive(typeName)),
        ],
        returnType: UtsType.primitive('String'),
      ),
    ],
  );
}

UnifiedTypeSchema _createAlamofireSchema() {
  return UnifiedTypeSchema(
    package: 'Alamofire',
    source: PackageSource.cocoapods,
    version: '5.9.0',
    classes: [
      UtsClass(
        name: 'AF',
        methods: [
          UtsMethod(
            name: 'request',
            parameters: [
              UtsParameter(
                  name: 'url', type: UtsType.primitive('String')),
              UtsParameter(
                  name: 'method', type: UtsType.primitive('String')),
            ],
            returnType: UtsType.primitive('String'),
            documentation: 'Makes an HTTP request.',
          ),
          UtsMethod(
            name: 'download',
            parameters: [
              UtsParameter(
                  name: 'url', type: UtsType.primitive('String')),
            ],
            returnType: UtsType.primitive('String'),
            isAsync: true,
          ),
        ],
      ),
    ],
  );
}
