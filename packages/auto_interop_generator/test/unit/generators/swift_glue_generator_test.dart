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
        final code = generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code, contains('GENERATED'));
        expect(code, contains('DO NOT EDIT'));
      });

      test('includes package name in header', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('Alamofire'));
        expect(code, contains('Swift platform channel handler for Alamofire'));
      });

      test('uses conditional imports for macOS/iOS', () {
        final code = generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(code, contains('#if os(macOS)'));
        expect(code, contains('import FlutterMacOS'));
        expect(code, contains('#else'));
        expect(code, contains('import Flutter'));
        expect(code, contains('import UIKit'));
        expect(code, contains('#endif'));
      });
    });

    group('plugin class structure', () {
      test('declares public class extending NSObject, FlutterPlugin', () {
        final code = generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(
            code, contains('public class TestPlugin: NSObject, FlutterPlugin'));
      });

      test('has register(with:) static method', () {
        final code = generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(
            code,
            contains(
                'public static func register(with registrar: FlutterPluginRegistrar)'));
      });

      test('creates method channel with snake_case name', () {
        final code =
            generator.generateSwiftCode(_createMinimalSchema('my-package'));
        expect(code, contains('"auto_interop/my_package"'));
      });

      test('has handle method', () {
        final code = generator.generateSwiftCode(_createMinimalSchema('test'));
        expect(
            code,
            contains(
                'public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)'));
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

      test('sync non-void methods call directly without do/catch', () {
        final schema = _createSchemaWithMethod();
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('let nativeResult ='));
        expect(code, contains('result(nativeResult)'));
      });

      test('async methods have error handling with normalizeErrorCode', () {
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
        expect(code, contains('normalizeErrorCode(error)'));
      });

      test('emits normalizeErrorCode helper', () {
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
        expect(
            code,
            contains(
                'private func normalizeErrorCode(_ error: Error) -> String'));
        expect(code, contains('NSURLErrorDomain'));
        expect(code, contains('"TIMEOUT"'));
        expect(code, contains('"NETWORK_ERROR"'));
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

    group('nativeLabel and nativeType', () {
      test('nativeLabel "_" produces unlabeled argument', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Foo',
              methods: [
                UtsMethod(
                  name: 'bar',
                  parameters: [
                    UtsParameter(
                      name: 'url',
                      type: UtsType.primitive('String'),
                      nativeLabel: '_',
                    ),
                    UtsParameter(
                      name: 'method',
                      type: UtsType.primitive('String'),
                    ),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        // The native call should have unlabeled first arg: bar(url, method: method)
        expect(code, contains('instance.bar(url, method: method)'));
      });

      test('nativeLabel with custom label', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Router',
              methods: [
                UtsMethod(
                  name: 'doSomething',
                  parameters: [
                    UtsParameter(
                      name: 'target',
                      type: UtsType.primitive('String'),
                      nativeLabel: 'to',
                    ),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('instance.doSomething(to: target)'));
      });

      test('nativeType wraps required argument', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Client',
              methods: [
                UtsMethod(
                  name: 'process',
                  parameters: [
                    UtsParameter(
                      name: 'data',
                      type: UtsType.map(
                        UtsType.primitive('String'),
                        UtsType.primitive('String'),
                      ),
                      nativeType: 'HTTPHeaders',
                    ),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('instance.process(data: HTTPHeaders(data))'));
      });

      test('nativeType wraps optional argument with nil check', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Client',
              methods: [
                UtsMethod(
                  name: 'process',
                  parameters: [
                    UtsParameter(
                      name: 'headers',
                      type: UtsType(
                        kind: UtsTypeKind.map,
                        name: 'Map',
                        nullable: true,
                        typeArguments: [
                          UtsType.primitive('String'),
                          UtsType.primitive('String'),
                        ],
                      ),
                      isOptional: true,
                      nativeType: 'HTTPHeaders',
                    ),
                  ],
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        );
        final code = generator.generateSwiftCode(schema);
        expect(code, contains('headers != nil ? HTTPHeaders(headers!) : nil'));
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
              UtsParameter(name: 'url', type: UtsType.primitive('String')),
              UtsParameter(name: 'method', type: UtsType.primitive('String')),
            ],
            returnType: UtsType.primitive('String'),
            documentation: 'Makes an HTTP request.',
          ),
          UtsMethod(
            name: 'download',
            parameters: [
              UtsParameter(name: 'url', type: UtsType.primitive('String')),
            ],
            returnType: UtsType.primitive('String'),
            isAsync: true,
          ),
        ],
      ),
    ],
  );
}
