import 'dart:convert';
import 'dart:io';

import 'package:auto_interop_generator/src/cache/checksum.dart';
import 'package:auto_interop_generator/src/cache/parse_cache.dart';
import 'package:auto_interop_generator/src/config/package_spec.dart';
import 'package:auto_interop_generator/src/parsers/parser_base.dart';
import 'package:auto_interop_generator/src/resolver/override_loader.dart';
import 'package:auto_interop_generator/src/resolver/registry_client.dart';
import 'package:auto_interop_generator/src/resolver/schema_resolver.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nb_resolver_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('SchemaResolver', () {
    group('override priority', () {
      test('uses override schema when provided', () async {
        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
        );

        final schema = UnifiedTypeSchema(
          package: 'test-pkg',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'hello',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        );

        final overrideJson =
            const JsonEncoder.withIndent('  ').convert(schema.toJson());

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'test-pkg',
          version: '1.0.0',
        );

        final resolution =
            await resolver.resolve(spec, overrideSchema: overrideJson);
        expect(resolution.schema, isNotNull);
        expect(resolution.source, SchemaSource.override);
        expect(resolution.schema!.functions, hasLength(1));
      });

      test('returns warning on invalid override JSON', () async {
        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
        );

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'test-pkg',
          version: '1.0.0',
        );

        final resolution =
            await resolver.resolve(spec, overrideSchema: 'not valid json');
        expect(resolution.schema, isNull);
        expect(resolution.warning, contains('Failed to parse'));
      });
    });

    group('project/global override priority', () {
      test('uses project override when available', () async {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final schema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '3.0.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        );
        File('${projectDir.path}/date-fns.uts.json').writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(schema.toJson()));

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
          overrideLoader: loader,
        );

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'date-fns',
          version: '3.0.0',
        );

        final resolution = await resolver.resolve(spec);
        expect(resolution.schema, isNotNull);
        expect(resolution.source, SchemaSource.projectOverride);
        expect(resolution.schema!.functions, hasLength(1));
      });

      test('uses global override when no project override', () async {
        final globalDir = Directory('${tempDir.path}/global_overrides')
          ..createSync();
        final schema = UnifiedTypeSchema(
          package: 'Alamofire',
          source: PackageSource.cocoapods,
          version: '5.9.0',
        );
        File('${globalDir.path}/Alamofire.uts.json').writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(schema.toJson()));

        final loader = OverrideLoader(
          projectDir: '${tempDir.path}/no_project',
          globalDir: globalDir.path,
        );

        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
          overrideLoader: loader,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Alamofire',
          version: '5.9.0',
        );

        final resolution = await resolver.resolve(spec);
        expect(resolution.schema, isNotNull);
        expect(resolution.source, SchemaSource.globalOverride);
      });

      test('CLI --override takes priority over override loader', () async {
        final projectDir = Directory('${tempDir.path}/project_overrides')
          ..createSync();
        final loaderSchema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '3.0.0',
        );
        File('${projectDir.path}/date-fns.uts.json').writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert(loaderSchema.toJson()));

        final cliSchema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '4.0.0',
          functions: [
            UtsMethod(
              name: 'fromCli',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        );

        final loader = OverrideLoader(
          projectDir: projectDir.path,
          globalDir: '${tempDir.path}/global_overrides',
        );

        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
          overrideLoader: loader,
        );

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'date-fns',
          version: '3.0.0',
        );

        final resolution = await resolver.resolve(spec,
            overrideSchema:
                const JsonEncoder.withIndent('  ').convert(cliSchema.toJson()));
        expect(resolution.source, SchemaSource.override);
        expect(resolution.schema!.version, '4.0.0');
      });
    });

    group('registry integration', () {
      test('uses registry when no overrides found', () async {
        final cacheDir = '${tempDir.path}/registry_cache';
        final schema = UnifiedTypeSchema(
          package: 'date-fns',
          source: PackageSource.npm,
          version: '3.6.0',
          functions: [
            UtsMethod(
              name: 'format',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        );
        final schemaBody =
            const JsonEncoder.withIndent('  ').convert(schema.toJson());

        final registryClient = RegistryClient(
          cacheDir: cacheDir,
          fetcher: (url, {ifNoneMatch}) async {
            if (url.path.endsWith('index.json')) {
              return HttpFetchResult(
                statusCode: 200,
                body: jsonEncode({
                  'version': 1,
                  'updatedAt': '2026-02-23T00:00:00Z',
                  'packages': {
                    'npm/date-fns': {
                      'latestVersion': '3.6.0',
                      'versions': {
                        '3.6.0': {
                          'path': 'registry/npm/date-fns/3.6.0.uts.json',
                          'sha256': 'skip', // Will be computed below
                        }
                      }
                    }
                  }
                }),
              );
            }
            return HttpFetchResult(statusCode: 200, body: schemaBody);
          },
        );

        // Pre-cache the schema to avoid checksum issues
        final schemaDir = Directory('$cacheDir/schemas/npm/date-fns')
          ..createSync(recursive: true);
        File('${schemaDir.path}/3.6.0.uts.json').writeAsStringSync(schemaBody);

        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
          registryClient: registryClient,
        );

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'date-fns',
          version: '3.6.0',
        );

        final resolution = await resolver.resolve(spec);
        expect(resolution.schema, isNotNull);
        expect(resolution.source, SchemaSource.registry);
      });

      test('skips registry when useRegistry is false', () async {
        var registryCalled = false;
        final registryClient = RegistryClient(
          cacheDir: '${tempDir.path}/registry_cache',
          fetcher: (url, {ifNoneMatch}) async {
            registryCalled = true;
            return const HttpFetchResult(statusCode: 500, body: '');
          },
        );

        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
          registryClient: registryClient,
          useRegistry: false,
        );

        final spec = PackageSpec(
          source: PackageSource.npm,
          package: 'date-fns',
          version: '3.0.0',
          sourcePath: '${tempDir.path}/no-sources',
        );

        await resolver.resolve(spec);
        expect(registryCalled, isFalse);
      });

      test('falls through to parsing when registry has no match', () async {
        final sourceDir = Directory('${tempDir.path}/swift-src')..createSync();
        File('${sourceDir.path}/Hello.swift').writeAsStringSync('''
public class Hello {
    public func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }
}
''');

        final registryClient = RegistryClient(
          cacheDir: '${tempDir.path}/registry_cache',
          fetcher: (url, {ifNoneMatch}) async {
            return HttpFetchResult(
              statusCode: 200,
              body: jsonEncode({
                'version': 1,
                'updatedAt': '2026-02-23T00:00:00Z',
                'packages': {},
              }),
            );
          },
        );

        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
          registryClient: registryClient,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Hello',
          version: '1.0.0',
          sourcePath: sourceDir.path,
        );

        final resolution = await resolver.resolve(spec);
        expect(resolution.schema, isNotNull);
        expect(resolution.source, SchemaSource.parsed);
      });
    });

    group('cache hit', () {
      test('returns cached schema when checksum matches', () async {
        final parseCache =
            ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache');

        // Create source files
        final sourceDir = Directory('${tempDir.path}/sources')..createSync();
        File('${sourceDir.path}/Example.swift').writeAsStringSync(
            'public class Example { public func hello() -> String { return "hi" } }');

        // Pre-populate cache with correct checksum
        final schema = UnifiedTypeSchema(
          package: 'Example',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Example',
              methods: [
                UtsMethod(
                  name: 'hello',
                  returnType: UtsType.primitive('String'),
                ),
              ],
            ),
          ],
        );

        final sourceContent =
            File('${sourceDir.path}/Example.swift').readAsStringSync();
        final checksum = Checksum.ofAll([sourceContent]);
        parseCache.put('Example', checksum, schema);

        final resolver = SchemaResolver(
          parseCache: parseCache,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Example',
          version: '1.0.0',
          sourcePath: sourceDir.path,
        );

        final resolution = await resolver.resolve(spec);
        expect(resolution.schema, isNotNull);
        expect(resolution.source, SchemaSource.cache);
      });
    });

    group('parse from source', () {
      test('parses Swift source when no cache', () async {
        final parseCache =
            ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache');

        final sourceDir = Directory('${tempDir.path}/swift-src')..createSync();
        File('${sourceDir.path}/Hello.swift').writeAsStringSync('''
public class Hello {
    public func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }
}
''');

        final resolver = SchemaResolver(
          parseCache: parseCache,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Hello',
          version: '1.0.0',
          sourcePath: sourceDir.path,
        );

        final resolution = await resolver.resolve(spec);
        expect(resolution.schema, isNotNull);
        expect(resolution.source, SchemaSource.parsed);
        expect(resolution.schema!.classes, isNotEmpty);
      });

      test('caches parsed result for subsequent calls', () async {
        final parseCache =
            ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache');

        final sourceDir = Directory('${tempDir.path}/cached-src')..createSync();
        File('${sourceDir.path}/Lib.swift').writeAsStringSync('''
public class Lib {
    public func doWork() -> String { return "done" }
}
''');

        final resolver = SchemaResolver(
          parseCache: parseCache,
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'Lib',
          version: '1.0.0',
          sourcePath: sourceDir.path,
        );

        // First call: parse
        final first = await resolver.resolve(spec);
        expect(first.source, SchemaSource.parsed);

        // Second call: cache hit
        final second = await resolver.resolve(spec);
        expect(second.source, SchemaSource.cache);
      });
    });

    group('no sources found', () {
      test('returns warning when sources not located', () async {
        final resolver = SchemaResolver(
          parseCache:
              ParseCache(cacheDir: '${tempDir.path}/.auto_interop_cache'),
        );

        final spec = PackageSpec(
          source: PackageSource.cocoapods,
          package: 'NonExistent',
          version: '1.0.0',
          sourcePath: '${tempDir.path}/does-not-exist',
        );

        final resolution = await resolver.resolve(spec);
        expect(resolution.schema, isNull);
        expect(resolution.warning, isNotNull);
      });
    });

    group('resolveUnknownTypes', () {
      test('replaces unresolved object types with nativeObject', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'MyClass',
              methods: [
                UtsMethod(
                  name: 'doStuff',
                  returnType: UtsType.object('UnknownType'),
                  parameters: [
                    UtsParameter(
                      name: 'arg',
                      type: UtsType.object('AnotherUnknown'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final method = result.schema.classes.first.methods.first;
        expect(method.returnType.kind, UtsTypeKind.nativeObject);
        expect(method.returnType.name, 'UnknownType');
        expect(method.parameters.first.type.kind, UtsTypeKind.nativeObject);
        expect(method.parameters.first.type.name, 'AnotherUnknown');
        expect(result.warnings, hasLength(2));
        expect(result.warnings.first.message,
            contains('resolved to nativeObject'));
      });

      test('preserves known types', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'KnownClass',
              methods: [
                UtsMethod(
                  name: 'getKnown',
                  returnType: UtsType.object('KnownClass'),
                ),
              ],
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final method = result.schema.classes.first.methods.first;
        expect(method.returnType.kind, UtsTypeKind.object);
        expect(method.returnType.name, 'KnownClass');
        expect(result.warnings, isEmpty);
      });

      test('resolves types in nested generics', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Container',
              methods: [
                UtsMethod(
                  name: 'getList',
                  returnType: UtsType.list(UtsType.object('Unknown')),
                ),
              ],
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final method = result.schema.classes.first.methods.first;
        expect(method.returnType.kind, UtsTypeKind.list);
        expect(method.returnType.typeArguments!.first.kind,
            UtsTypeKind.nativeObject);
        expect(method.returnType.typeArguments!.first.name, 'Unknown');
      });

      test('converts Map with non-primitive key to Map<dynamic, V>', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'CustomKey',
              methods: [
                UtsMethod(
                  name: 'getMap',
                  returnType: UtsType.map(
                    UtsType.object('CustomKey'),
                    UtsType.primitive('String'),
                  ),
                ),
              ],
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final method = result.schema.classes.first.methods.first;
        expect(method.returnType.kind, UtsTypeKind.map);
        expect(
            method.returnType.typeArguments!.first.kind, UtsTypeKind.dynamic);
        expect(method.returnType.typeArguments![1].kind, UtsTypeKind.primitive);
        expect(
            result.warnings.any(
              (w) =>
                  w.message.contains('Map key type') &&
                  w.message.contains('converted to dynamic'),
            ),
            isTrue);
      });

      test('preserves Map with primitive key', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'getMap',
              isStatic: true,
              returnType: UtsType.map(
                UtsType.primitive('String'),
                UtsType.primitive('int'),
              ),
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final fn = result.schema.functions.first;
        expect(fn.returnType.kind, UtsTypeKind.map);
        expect(fn.returnType.typeArguments!.first.kind, UtsTypeKind.primitive);
        expect(fn.returnType.typeArguments!.first.name, 'String');
        expect(result.warnings, isEmpty);
      });

      test('preserves Map with enum key', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          enums: [
            UtsEnum(name: 'Color', values: [
              UtsEnumValue(name: 'red'),
            ]),
          ],
          functions: [
            UtsMethod(
              name: 'getMap',
              isStatic: true,
              returnType: UtsType.map(
                UtsType.enumType('Color'),
                UtsType.primitive('String'),
              ),
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final fn = result.schema.functions.first;
        expect(fn.returnType.typeArguments!.first.kind, UtsTypeKind.enumType);
        expect(
            result.warnings
                .where((w) => w.message.contains('Map key type'))
                .toList(),
            isEmpty);
      });

      test('falls back to dynamic for non-identifier type refs', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.cocoapods,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'MyClass',
              methods: [
                UtsMethod(
                  name: 'doStuff',
                  returnType: UtsType.object('() -> Void'),
                  parameters: [
                    UtsParameter(
                      name: 'handler',
                      type: UtsType.object('any Error'),
                    ),
                    UtsParameter(
                      name: 'mixed',
                      type: UtsType.object('A | B'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final method = result.schema.classes.first.methods.first;
        expect(method.returnType.kind, UtsTypeKind.dynamic);
        expect(method.parameters[0].type.kind, UtsTypeKind.dynamic);
        expect(method.parameters[1].type.kind, UtsTypeKind.dynamic);
        expect(result.warnings, hasLength(3));
        expect(result.warnings.first.message, contains('resolved to dynamic'));
      });

      test('does not modify primitive types', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          functions: [
            UtsMethod(
              name: 'add',
              isStatic: true,
              returnType: UtsType.primitive('int'),
              parameters: [
                UtsParameter(
                  name: 'a',
                  type: UtsType.primitive('int'),
                ),
              ],
            ),
          ],
        );

        final result = SchemaResolver.resolveUnknownTypes(
          ParseResult(schema),
        );

        final fn = result.schema.functions.first;
        expect(fn.returnType.kind, UtsTypeKind.primitive);
        expect(fn.parameters.first.type.kind, UtsTypeKind.primitive);
        expect(result.warnings, isEmpty);
      });
    });

    group('filterByImports', () {
      test('returns full schema when imports is empty', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(name: 'A'),
            UtsClass(name: 'B'),
          ],
        );

        final filtered = SchemaResolver.filterByImports(schema, []);
        expect(filtered.classes, hasLength(2));
      });

      test('keeps only imported classes', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(name: 'Session'),
            UtsClass(name: 'Internal'),
          ],
        );

        final filtered = SchemaResolver.filterByImports(schema, ['Session']);
        expect(filtered.classes, hasLength(1));
        expect(filtered.classes.first.name, 'Session');
      });

      test('transitively includes referenced types', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Session',
              methods: [
                UtsMethod(
                  name: 'request',
                  returnType: UtsType.object('DataRequest'),
                ),
              ],
            ),
            UtsClass(name: 'DataRequest'),
            UtsClass(name: 'Unrelated'),
          ],
        );

        final filtered = SchemaResolver.filterByImports(schema, ['Session']);
        expect(filtered.classes.map((c) => c.name).toList()..sort(),
            ['DataRequest', 'Session']);
      });

      test('includes transitively referenced enums', () {
        final schema = UnifiedTypeSchema(
          package: 'test',
          source: PackageSource.npm,
          version: '1.0.0',
          classes: [
            UtsClass(
              name: 'Client',
              fields: [
                UtsField(name: 'status', type: UtsType.enumType('Status')),
              ],
            ),
          ],
          enums: [
            UtsEnum(name: 'Status', values: [
              UtsEnumValue(name: 'active'),
            ]),
            UtsEnum(name: 'UnusedEnum', values: [
              UtsEnumValue(name: 'a'),
            ]),
          ],
        );

        final filtered = SchemaResolver.filterByImports(schema, ['Client']);
        expect(filtered.classes, hasLength(1));
        expect(filtered.enums, hasLength(1));
        expect(filtered.enums.first.name, 'Status');
      });

      test('keeps imported functions', () {
        final schema = UnifiedTypeSchema(
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
              name: 'parse',
              isStatic: true,
              returnType: UtsType.primitive('String'),
            ),
          ],
        );

        final filtered = SchemaResolver.filterByImports(schema, ['format']);
        expect(filtered.functions, hasLength(1));
        expect(filtered.functions.first.name, 'format');
      });
    });
  });
}
