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
        expect(code, contains("method: 'RealtimeClient.observe'"));
      });

      test('stream method with parameters passes arguments', () {
        final schema = _createSchemaWithStreamAndParams();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains("method: 'FileWatcher.watchChanges'"));
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

      test('generates stream comment', () {
        final schema = _createSchemaWithStream();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('Stream: events forwarded via eventSink'));
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

      test('generates stream comment', () {
        final schema = _createSchemaWithStream();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('Stream: events forwarded via eventSink'));
      });
    });
  });

  group('NativeObject support', () {
    group('DartGenerator', () {
      test('generates NativeObject return type', () {
        final schema = _createSchemaWithNativeObject();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('Connection'));
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
      expect(type.toDartType(), 'Connection');
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

  group('Stream deserialization', () {
    group('DartGenerator', () {
      test('object element type generates .map() with fromMap', () {
        final schema = _createSchemaWithObjectStream();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('.map((raw)'));
        expect(code, contains('AccelerometerEvent.fromMap'));
        expect(code, contains('receiveStream<Map<Object?, Object?>>'));
      });

      test('enum element type generates .map() with values.byName', () {
        final schema = _createSchemaWithEnumStream();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('.map((raw) => Status.values.byName(raw))'));
        expect(code, contains('receiveStream<String>'));
      });

      test('DateTime element type generates .map() with DateTime.parse', () {
        final schema = _createSchemaWithDateTimeStream();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('.map((raw) => DateTime.parse(raw))'));
        expect(code, contains('receiveStream<String>'));
      });

      test('primitive element type has no .map() deserialization', () {
        final schema = _createSchemaWithStream();
        final code = dartGen.generateDartCode(schema);
        expect(code, isNot(contains('.map((raw)')));
        expect(code, contains('receiveStream<String>'));
      });
    });
  });

  group('Callback wrapping with deserialization', () {
    group('DartGenerator', () {
      test('callback with object param generates wrapper', () {
        final schema = _createSchemaWithObjectCallback();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('final _onProgressId = CallbackManager.instance.register'));
        expect(code, contains('DownloadProgress.fromMap'));
        expect(code, contains("'onProgress': _onProgressId"));
      });

      test('callback with primitive params keeps simple registration', () {
        final schema = _createSchemaWithCallback();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('CallbackManager.instance.register(onEvent)'));
        expect(code, isNot(contains('_onEventId')));
      });

      test('callback with enum param generates wrapper', () {
        final schema = _createSchemaWithEnumCallback();
        final code = dartGen.generateDartCode(schema);
        expect(code, contains('final _onStatusId = CallbackManager.instance.register'));
        expect(code, contains('Status.values.byName'));
        expect(code, contains("'onStatus': _onStatusId"));
      });
    });
  });

  group('Callback channel generation', () {
    group('SwiftGlueGenerator', () {
      test('generates callbackChannel when callbacks present', () {
        final schema = _createSchemaWithObjectCallback();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, contains('private var callbackChannel: FlutterMethodChannel!'));
        expect(code, contains('FlutterMethodChannel(name: "auto_interop/callbacks"'));
      });

      test('no callbackChannel without callbacks', () {
        final schema = _createSchemaWithRegularMethods();
        final code = swiftGen.generateSwiftCode(schema);
        expect(code, isNot(contains('callbackChannel')));
      });
    });

    group('KotlinGlueGenerator', () {
      test('generates callbackChannel when callbacks present', () {
        final schema = _createSchemaWithObjectCallback();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, contains('private lateinit var callbackChannel: MethodChannel'));
        expect(code, contains('MethodChannel(binding.binaryMessenger, "auto_interop/callbacks")'));
      });

      test('no callbackChannel without callbacks', () {
        final schema = _createSchemaWithRegularMethods();
        final code = kotlinGen.generateKotlinCode(schema);
        expect(code, isNot(contains('callbackChannel')));
      });
    });
  });

  group('Kotlin nativeBody support', () {
    test('uses verbatim kotlin nativeBody when present', () {
      final schema = _createSchemaWithKotlinNativeBody();
      final code = kotlinGen.generateKotlinCode(schema);
      expect(code, contains('// custom kotlin logic'));
      expect(code, contains('result.success("custom")'));
    });

    test('auto-generates when no nativeBody', () {
      final schema = _createSchemaWithRegularMethods();
      final code = kotlinGen.generateKotlinCode(schema);
      // Auto-generated code has argument extraction
      expect(code, contains('call.argument'));
    });
  });

  group('Swift onListen/onCancel dispatch', () {
    test('single stream method emits nativeBody directly', () {
      final schema = _createSchemaWithSingleStreamNativeBody();
      final code = swiftGen.generateSwiftCode(schema);
      expect(code, contains('func onListen'));
      expect(code, contains('self.eventSink = events'));
      expect(code, contains('Timer.scheduledTimer'));
    });

    test('multiple stream methods dispatch via switch', () {
      final schema = _createSchemaWithMultipleStreams();
      final code = swiftGen.generateSwiftCode(schema);
      expect(code, contains('switch method'));
      expect(code, contains('case "accel"'));
      expect(code, contains('case "gyro"'));
    });

    test('onCancel includes custom nativeBody when present', () {
      final schema = _createSchemaWithSingleStreamNativeBody();
      final code = swiftGen.generateSwiftCode(schema);
      expect(code, contains('func onCancel'));
      expect(code, contains('timer.invalidate'));
      expect(code, contains('self.eventSink = nil'));
    });
  });

  group('Kotlin onListen/onCancel dispatch', () {
    test('single stream method emits nativeBody directly', () {
      final schema = _createSchemaWithSingleStreamKotlinNativeBody();
      final code = kotlinGen.generateKotlinCode(schema);
      expect(code, contains('override fun onListen'));
      expect(code, contains('eventSink = events'));
      expect(code, contains('start sensor'));
    });

    test('multiple stream methods dispatch via when', () {
      final schema = _createSchemaWithMultipleKotlinStreams();
      final code = kotlinGen.generateKotlinCode(schema);
      expect(code, contains('when (method)'));
      expect(code, contains('"accel"'));
      expect(code, contains('"gyro"'));
    });

    test('onCancel includes custom nativeBody when present', () {
      final schema = _createSchemaWithSingleStreamKotlinNativeBody();
      final code = kotlinGen.generateKotlinCode(schema);
      expect(code, contains('override fun onCancel'));
      expect(code, contains('stop sensor'));
      expect(code, contains('eventSink = null'));
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

// --- New helper schemas for stream deserialization, callback wrapping, etc. ---

UnifiedTypeSchema _createSchemaWithObjectStream() {
  return UnifiedTypeSchema(
    package: 'sensor',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'accelerometerEvents',
        isStatic: true,
        returnType: UtsType.stream(UtsType.object('AccelerometerEvent')),
      ),
    ],
    types: [
      UtsClass(
        name: 'AccelerometerEvent',
        kind: UtsClassKind.dataClass,
        fields: [
          UtsField(name: 'x', type: UtsType.primitive('double')),
          UtsField(name: 'y', type: UtsType.primitive('double')),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithEnumStream() {
  return UnifiedTypeSchema(
    package: 'status-monitor',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'statusUpdates',
        isStatic: true,
        returnType: UtsType.stream(UtsType.enumType('Status')),
      ),
    ],
    enums: [
      UtsEnum(name: 'Status', values: [
        UtsEnumValue(name: 'active'),
        UtsEnumValue(name: 'inactive'),
      ]),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithDateTimeStream() {
  return UnifiedTypeSchema(
    package: 'timer',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'timestamps',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('DateTime')),
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithObjectCallback() {
  return UnifiedTypeSchema(
    package: 'downloader',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'downloadFile',
        isStatic: true,
        isAsync: true,
        parameters: [
          UtsParameter(
            name: 'url',
            type: UtsType.primitive('String'),
          ),
          UtsParameter(
            name: 'onProgress',
            type: UtsType.callback(
              parameterTypes: [UtsType.object('DownloadProgress')],
              returnType: UtsType.voidType(),
            ),
            isNamed: true,
            isOptional: true,
          ),
        ],
        returnType: UtsType.future(UtsType.primitive('String')),
      ),
    ],
    types: [
      UtsClass(
        name: 'DownloadProgress',
        kind: UtsClassKind.dataClass,
        fields: [
          UtsField(name: 'bytesReceived', type: UtsType.primitive('int')),
          UtsField(name: 'totalBytes', type: UtsType.primitive('int')),
        ],
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithEnumCallback() {
  return UnifiedTypeSchema(
    package: 'monitor',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'observe',
        isStatic: true,
        parameters: [
          UtsParameter(
            name: 'onStatus',
            type: UtsType.callback(
              parameterTypes: [UtsType.enumType('Status')],
              returnType: UtsType.voidType(),
            ),
          ),
        ],
        returnType: UtsType.voidType(),
      ),
    ],
    enums: [
      UtsEnum(name: 'Status', values: [
        UtsEnumValue(name: 'active'),
        UtsEnumValue(name: 'inactive'),
      ]),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithKotlinNativeBody() {
  return UnifiedTypeSchema(
    package: 'custom-lib',
    source: PackageSource.gradle,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'doSomething',
        isStatic: true,
        parameters: [],
        returnType: UtsType.primitive('String'),
        nativeBody: {
          'kotlin': '// custom kotlin logic\nresult.success("custom")',
        },
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithSingleStreamNativeBody() {
  return UnifiedTypeSchema(
    package: 'sensor',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'accel',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('double')),
        nativeBody: {
          'swift_onListen': 'Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in\n    self.eventSink?(1.0)\n}',
          'swift_onCancel': 'timer.invalidate()',
        },
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithMultipleStreams() {
  return UnifiedTypeSchema(
    package: 'multi-sensor',
    source: PackageSource.cocoapods,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'accel',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('double')),
        nativeBody: {
          'swift_onListen': 'startAccel()',
        },
      ),
      UtsMethod(
        name: 'gyro',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('double')),
        nativeBody: {
          'swift_onListen': 'startGyro()',
        },
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithSingleStreamKotlinNativeBody() {
  return UnifiedTypeSchema(
    package: 'sensor',
    source: PackageSource.gradle,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'accel',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('double')),
        nativeBody: {
          'kotlin_onListen': '// start sensor',
          'kotlin_onCancel': '// stop sensor',
        },
      ),
    ],
  );
}

UnifiedTypeSchema _createSchemaWithMultipleKotlinStreams() {
  return UnifiedTypeSchema(
    package: 'multi-sensor',
    source: PackageSource.gradle,
    version: '1.0.0',
    functions: [
      UtsMethod(
        name: 'accel',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('double')),
        nativeBody: {
          'kotlin_onListen': 'startAccel()',
        },
      ),
      UtsMethod(
        name: 'gyro',
        isStatic: true,
        returnType: UtsType.stream(UtsType.primitive('double')),
        nativeBody: {
          'kotlin_onListen': 'startGyro()',
        },
      ),
    ],
  );
}
