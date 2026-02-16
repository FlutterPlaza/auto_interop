import 'package:auto_interop_generator/src/generators/dart_generator.dart';
import 'package:auto_interop_generator/src/generators/kotlin_glue_generator.dart';
import 'package:auto_interop_generator/src/generators/swift_glue_generator.dart';
import 'package:auto_interop_generator/src/generators/js_glue_generator.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late DartGenerator dartGen;
  late KotlinGlueGenerator kotlinGen;
  late SwiftGlueGenerator swiftGen;
  late JsGlueGenerator jsGen;

  setUp(() {
    dartGen = DartGenerator();
    kotlinGen = KotlinGlueGenerator();
    swiftGen = SwiftGlueGenerator();
    jsGen = JsGlueGenerator();
  });

  group('Callback support', () {
    group('DartGenerator', () {
      test('serializes callback param via CallbackManager', () {
        final schema = _createSchemaWithCallback();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('CallbackManager.instance.register(onEvent)'));
      });

      test('callback parameter uses Function type', () {
        final schema = _createSchemaWithCallback();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('void Function(String) onEvent'));
      });

      test('nullable callback parameter serializes correctly', () {
        final schema = _createSchemaWithNullableCallback();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('CallbackManager.instance.register(onProgress)'));
      });

      test('method with callback and regular params', () {
        final schema = _createSchemaWithMixedParams();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains("'url': url"));
        expect(code, contains('CallbackManager.instance.register(onComplete)'));
      });
    });

    group('KotlinGlueGenerator', () {
      test('extracts callback ID as String', () {
        final schema = _createSchemaWithCallback();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(
            code, contains('val onEvent = call.argument<String>("onEvent")!!'));
      });
    });

    group('SwiftGlueGenerator', () {
      test('extracts callback ID as String', () {
        final schema = _createSchemaWithCallback();
        final code = swiftGen.generateSwiftCode(schema);
        expect(
            code, contains('let onEvent = args["onEvent"] as! String'));
      });
    });

    group('JsGlueGenerator', () {
      test('maps callback to JSFunction type', () {
        final schema = _createSchemaWithCallback();
        final code = jsGen.generateJsInteropCode(schema);
        expect(code, contains('JSFunction'));
      });
    });
  });

  group('Stream support', () {
    group('DartGenerator', () {
      test('generates Stream return type for stream method', () {
        final schema = _createSchemaWithStream();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('Stream<String> observe()'));
      });

      test('does not use async for stream methods', () {
        final schema = _createSchemaWithStream();
        final code = dartGen.generateDartCode(schema);
        // Stream methods are not async — they return a Stream synchronously
        expect(code, isNot(contains('Stream<String> observe() async')));
      });

      test('declares _eventChannel for class with stream methods', () {
        final schema = _createSchemaWithStream();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('AutoInteropEventChannel'));
      });

      test('uses receiveStream for stream method body', () {
        final schema = _createSchemaWithStream();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains("_eventChannel.receiveStream<String>"));
        expect(code, contains("method: 'observe'"));
      });

      test('stream method with parameters passes arguments', () {
        final schema = _createSchemaWithStreamAndParams();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains("method: 'watchChanges'"));
        expect(code, contains("'path': path"));
      });

      test('class with only non-stream methods has no _eventChannel', () {
        final schema = _createSchemaWithRegularMethods();
        final code = dartGen.generateDartCode(schema);
        expect(code, isNot(contains('AutoInteropEventChannel')));
      });

      test('class with mixed stream and regular methods has both channels', () {
        final schema = _createSchemaWithMixedMethods();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('AutoInteropChannel'));
        expect(code, contains('AutoInteropEventChannel'));
      });

      test('top-level stream function creates _eventChannel', () {
        final schema = _createSchemaWithStreamFunction();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('AutoInteropEventChannel'));
      });
    });

    group('KotlinGlueGenerator', () {
      test('imports EventChannel when stream methods present', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('import io.flutter.plugin.common.EventChannel'));
      });

      test('implements EventChannel.StreamHandler', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('EventChannel.StreamHandler'));
      });

      test('declares eventChannel and eventSink', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('private lateinit var eventChannel: EventChannel'));
        expect(code,
            contains('private var eventSink: EventChannel.EventSink? = null'));
      });

      test('sets up EventChannel in onAttachedToEngine', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('EventChannel(binding.binaryMessenger'));
        expect(code, contains('eventChannel.setStreamHandler(this)'));
      });

      test('cleans up EventChannel in onDetachedFromEngine', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('eventChannel.setStreamHandler(null)'));
      });

      test('implements onListen and onCancel', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('override fun onListen'));
        expect(code, contains('override fun onCancel'));
      });

      test('no EventChannel without stream methods', () {
        final schema = _createSchemaWithRegularMethods();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, isNot(contains('EventChannel')));
      });

      test('generates stream TODO comment', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('TODO: Set up stream'));
      });
    });

    group('SwiftGlueGenerator', () {
      test('implements FlutterStreamHandler when stream methods present', () {
        final schema = _createSchemaWithStream();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('FlutterStreamHandler'));
      });

      test('declares eventSink property', () {
        final schema = _createSchemaWithStream();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('private var eventSink: FlutterEventSink?'));
      });

      test('sets up FlutterEventChannel in register', () {
        final schema = _createSchemaWithStream();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('FlutterEventChannel'));
        expect(code, contains('setStreamHandler(instance)'));
      });

      test('implements onListen and onCancel', () {
        final schema = _createSchemaWithStream();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('func onListen'));
        expect(code, contains('func onCancel'));
      });

      test('no FlutterStreamHandler without stream methods', () {
        final schema = _createSchemaWithRegularMethods();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, isNot(contains('FlutterStreamHandler')));
      });

      test('generates stream TODO comment', () {
        final schema = _createSchemaWithStream();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('TODO: Set up stream'));
      });
    });
  });

  group('NativeObject support', () {
    group('DartGenerator', () {
      test('generates NativeObject return type', () {
        final schema = _createSchemaWithNativeObject();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('NativeObject<Connection>'));
      });
    });

    group('KotlinGlueGenerator', () {
      test('maps nativeObject to Any type', () {
        final schema = _createSchemaWithNativeObject();
        final code = kotlinGen.generateKotlinCode(schema);
        // native objects are passed as opaque handles
        expect(code, contains('call.argument'));
      });
    });

    group('SwiftGlueGenerator', () {
      test('maps nativeObject to Any type', () {
        final schema = _createSchemaWithNativeObject();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('args'));
      });
    });
  });

  group('UtsType', () {
    test('callback type produces correct Dart type string', () {
      final type = UtsType.callback(
        parameterTypes: [UtsType.primitive('String')],
        returnType: UtsType.voidType(),
      );
      expect(type.toDartType(), 'void Function(String)');
    });

    test('nullable callback type produces correct Dart type string', () {
      final type = UtsType.callback(
        parameterTypes: [UtsType.primitive('int')],
        returnType: UtsType.primitive('bool'),
        nullable: true,
      );
      expect(type.toDartType(), 'bool Function(int)?');
    });

    test('stream type produces correct Dart type string', () {
      final type = UtsType.stream(UtsType.primitive('String'));
      expect(type.toDartType(), 'Stream<String>');
    });

    test('nativeObject type produces correct Dart type string', () {
      final type = UtsType.nativeObject('Connection');
      expect(type.toDartType(), 'NativeObject<Connection>');
    });

    test('future type produces correct Dart type string', () {
      final type = UtsType.future(UtsType.primitive('int'));
      expect(type.toDartType(), 'Future<int>');
    });

    test('callback with multiple params', () {
      final type = UtsType.callback(
        parameterTypes: [
          UtsType.primitive('String'),
          UtsType.primitive('int'),
        ],
        returnType: UtsType.voidType(),
      );
      expect(type.toDartType(), 'void Function(String, int)');
    });

    test('callback with no params', () {
      final type = UtsType.callback(
        parameterTypes: [],
        returnType: UtsType.voidType(),
      );
      expect(type.toDartType(), 'void Function()');
    });
  });

  group('Determinism', () {
    test('callback schema produces deterministic output', () {
      final schema = _createSchemaWithCallback();
      final code1 = dartGen.generateDartCode(schema);
      final code2 = dartGen.generateDartCode(schema);
      expect(code1, code2);
    });

    test('stream schema produces deterministic output', () {
      final schema = _createSchemaWithStream();
      final code1 = dartGen.generateDartCode(schema);
      final code2 = dartGen.generateDartCode(schema);
      expect(code1, code2);
    });
  });
}

// --- Helper Schemas ---

UnifiedTypeSchema _createSchemaWithCallback() {
  return UnifiedTypeSchema(
    package: 'event-bus',
    source: PackageSource.npm,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'EventBus',
        methods: [
          UtsMethod(
            name: 'subscribe',
            parameters: [
              UtsParameter(
                name: 'event',
                type: UtsType.primitive('String'),
              ),
              UtsParameter(
                name: 'onEvent',
                type: UtsType.callback(
                  parameterTypes: [UtsType.primitive('String')],
                  returnType: UtsType.voidType(),
                ),
              ),
            ],
            returnType: UtsType.voidType(),
          ),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithNullableCallback() {
  return UnifiedTypeSchema(
    package: 'downloader',
    source: PackageSource.npm,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'Downloader',
        methods: [
          UtsMethod(
            name: 'download',
            parameters: [
              UtsParameter(
                name: 'url',
                type: UtsType.primitive('String'),
              ),
              UtsParameter(
                name: 'onProgress',
                type: UtsType.callback(
                  parameterTypes: [UtsType.primitive('double')],
                  returnType: UtsType.voidType(),
                  nullable: true,
                ),
                isOptional: true,
                isNamed: true,
              ),
            ],
            returnType: UtsType.voidType(),
          ),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithMixedParams() {
  return UnifiedTypeSchema(
    package: 'fetcher',
    source: PackageSource.npm,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'Fetcher',
        methods: [
          UtsMethod(
            name: 'fetch',
            parameters: [
              UtsParameter(
                name: 'url',
                type: UtsType.primitive('String'),
              ),
              UtsParameter(
                name: 'onComplete',
                type: UtsType.callback(
                  parameterTypes: [UtsType.primitive('String')],
                  returnType: UtsType.voidType(),
                ),
              ),
            ],
            returnType: UtsType.voidType(),
          ),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithStream() {
  return UnifiedTypeSchema(
    package: 'realtime',
    source: PackageSource.npm,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'RealtimeClient',
        methods: [
          UtsMethod(
            name: 'observe',
            returnType: UtsType.stream(UtsType.primitive('String')),
          ),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithStreamAndParams() {
  return UnifiedTypeSchema(
    package: 'watcher',
    source: PackageSource.npm,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'FileWatcher',
        methods: [
          UtsMethod(
            name: 'watchChanges',
            parameters: [
              UtsParameter(
                name: 'path',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.stream(UtsType.primitive('String')),
          ),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithStreamFunction() {
  return UnifiedTypeSchema(
    package: 'ticker',
    source: PackageSource.npm,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'tick',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('int')),
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithRegularMethods() {
  return UnifiedTypeSchema(
    package: 'utils',
    source: PackageSource.npm,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'Utils',
        methods: [
          UtsMethod(
            name: 'format',
            parameters: [
              UtsParameter(
                name: 'value',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.primitive('String'),
          ),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithMixedMethods() {
  return UnifiedTypeSchema(
    package: 'mixed',
    source: PackageSource.npm,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'MixedClient',
        methods: [
          UtsMethod(
            name: 'fetch',
            parameters: [
              UtsParameter(
                name: 'url',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.primitive('String'),
          ),
          UtsMethod(
            name: 'observe',
            returnType: UtsType.stream(UtsType.primitive('String')),
          ),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithNativeObject() {
  return UnifiedTypeSchema(
    package: 'database',
    source: PackageSource.gradle,
    version: '1.0.0',
    classes: [
      UtsClass(
        name: 'Database',
        methods: [
          UtsMethod(
            name: 'connect',
            parameters: [
              UtsParameter(
                name: 'connectionString',
                type: UtsType.primitive('String'),
              ),
            ],
            returnType: UtsType.nativeObject('Connection'),
          ),
        ],
      ),
    ],
  );
}
