@Tags(['integration'])
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:auto_interop_generator/src/parsers/ast/ast_npm_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/ast_swift_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/ast_gradle_parser.dart';
import 'package:auto_interop_generator/src/parsers/ast/toolchain_detector.dart';
import 'package:auto_interop_generator/src/parsers/npm_parser.dart';
import 'package:auto_interop_generator/src/parsers/swift_parser.dart';
import 'package:auto_interop_generator/src/parsers/gradle_parser.dart';
import 'package:auto_interop_generator/src/schema/unified_type_schema.dart';
import 'package:test/test.dart';

/// Integration tests for AST-based parsers.
///
/// These tests require actual native toolchains to be installed:
/// - Node.js >= 18 with `typescript` npm package
/// - Swift (macOS only)
/// - kotlinc
///
/// Run with: dart test --tags integration
void main() {
  late ToolchainDetector detector;
  late Directory tempDir;

  setUp(() {
    detector = ToolchainDetector();
    tempDir = Directory.systemTemp.createTempSync('ast_integration_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('Isolate.resolvePackageUri path resolution', () {
    test('resolves ts_ast_helper.mjs path', () async {
      final uri = Uri.parse(
          'package:auto_interop_generator/src/parsers/ast/helpers/ts_ast_helper.mjs');
      final resolved = await Isolate.resolvePackageUri(uri);
      expect(resolved, isNotNull, reason: 'ts_ast_helper.mjs not resolved');
      expect(File.fromUri(resolved!).existsSync(), isTrue,
          reason: 'Resolved path does not exist: ${resolved.toFilePath()}');
    });

    test('resolves swift_ast_helper Package.swift path', () async {
      final uri = Uri.parse(
          'package:auto_interop_generator/src/parsers/ast/helpers/swift_ast_helper/Package.swift');
      final resolved = await Isolate.resolvePackageUri(uri);
      expect(resolved, isNotNull,
          reason: 'swift_ast_helper/Package.swift not resolved');
      expect(File.fromUri(resolved!).existsSync(), isTrue,
          reason: 'Resolved path does not exist: ${resolved.toFilePath()}');
    });

    test('resolves kt_ast_helper.main.kts path', () async {
      final uri = Uri.parse(
          'package:auto_interop_generator/src/parsers/ast/helpers/kt_ast_helper.main.kts');
      final resolved = await Isolate.resolvePackageUri(uri);
      expect(resolved, isNotNull,
          reason: 'kt_ast_helper.main.kts not resolved');
      expect(File.fromUri(resolved!).existsSync(), isTrue,
          reason: 'Resolved path does not exist: ${resolved.toFilePath()}');
    });
  });

  group('AST npm parser integration', () {
    test('parses TypeScript declarations via Node.js', () async {
      if (!await detector.hasNode()) {
        markTestSkipped('Node.js >= 18 not available');
        return;
      }

      // Check typescript is available using ESM import (same as helper)
      final tsCheck = await Process.run(
          'node', ['--input-type=module', '-e', 'import("typescript")']);
      if (tsCheck.exitCode != 0) {
        markTestSkipped('typescript npm package not installed');
        return;
      }

      final tsFile = File('${tempDir.path}/index.d.ts');
      tsFile.writeAsStringSync('''
export declare function format(date: Date, formatStr: string): string;
export declare function addDays(date: Date, amount: number): Date;
export declare function isValid(date: Date): boolean;

export interface FormatOptions {
  locale?: string;
  weekStartsOn?: number;
}

export declare enum Weekday {
  Monday = 0,
  Tuesday = 1,
  Wednesday = 2,
}
''');

      final parser = AstNpmParser();
      final result = await parser.parseFilesAsync(
        files: {tsFile.path: tsFile.readAsStringSync()},
        packageName: 'date-fns',
        version: '3.6.0',
      );

      expect(result.schema.package, 'date-fns');
      expect(result.schema.source, PackageSource.npm);

      // Verify functions parsed
      expect(result.schema.functions.length, 3);
      expect(result.schema.functions.map((f) => f.name),
          containsAll(['format', 'addDays', 'isValid']));

      // Verify type mapping: Date → DateTime, number → double
      final addDays =
          result.schema.functions.firstWhere((f) => f.name == 'addDays');
      expect(addDays.parameters[0].type.name, 'DateTime');
      expect(addDays.parameters[1].type.name, 'double');
      expect(addDays.returnType.name, 'DateTime');

      // Verify interface → dataClass
      expect(result.schema.types.length, 1);
      expect(result.schema.types.first.name, 'FormatOptions');
      expect(result.schema.types.first.kind, UtsClassKind.dataClass);
      expect(result.schema.types.first.fields.length, 2);

      // Verify enum
      expect(result.schema.enums.length, 1);
      expect(result.schema.enums.first.name, 'Weekday');
      expect(result.schema.enums.first.values.length, 3);

      // Round-trip: serialize → deserialize → compare
      final json = jsonEncode(result.schema.toJson());
      final roundTripped =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(roundTripped.functions.length, result.schema.functions.length);
      expect(roundTripped.types.length, result.schema.types.length);
      expect(roundTripped.enums.length, result.schema.enums.length);
    });
  });

  group('AST Swift parser integration', () {
    test('parses Swift source via swift-syntax', () async {
      if (!await detector.hasSwift()) {
        markTestSkipped('Swift not available');
        return;
      }

      final swiftFile = File('${tempDir.path}/Hello.swift');
      swiftFile.writeAsStringSync('''
import Foundation

public class Session {
    public var baseURL: URL?
    public let timeout: TimeInterval

    public init(baseURL: URL? = nil, timeout: TimeInterval = 30.0) {
        self.baseURL = baseURL
        self.timeout = timeout
    }

    public func request(_ url: String, method: String = "GET") -> String {
        return ""
    }

    public func download(from url: URL) async throws -> Data {
        return Data()
    }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public struct RequestOptions {
    public let headers: [String: String]
    public let timeout: TimeInterval
}
''');

      final parser = AstSwiftParser(
        timeout: const Duration(seconds: 120),
      );
      final result = await parser.parseFilesAsync(
        files: {swiftFile.path: swiftFile.readAsStringSync()},
        packageName: 'MyHTTP',
        version: '1.0.0',
      );

      expect(result.schema.package, 'MyHTTP');
      expect(result.schema.source, PackageSource.cocoapods);

      // Session class
      final session =
          result.schema.classes.firstWhere((c) => c.name == 'Session');
      expect(session.kind, UtsClassKind.concreteClass);
      expect(session.methods.length, greaterThanOrEqualTo(2));

      // request method with nativeLabel
      final requestMethod =
          session.methods.firstWhere((m) => m.name == 'request');
      expect(requestMethod.parameters[0].name, 'url');

      // download method is async
      final downloadMethod =
          session.methods.firstWhere((m) => m.name == 'download');
      expect(downloadMethod.isAsync, isTrue);
      expect(downloadMethod.returnType.kind, UtsTypeKind.future);

      // Enum
      expect(result.schema.enums.length, 1);
      expect(result.schema.enums.first.name, 'HTTPMethod');
      expect(result.schema.enums.first.values.length, 4);

      // Struct → dataClass
      final opts =
          result.schema.types.firstWhere((t) => t.name == 'RequestOptions');
      expect(opts.kind, UtsClassKind.dataClass);
      expect(opts.fields.length, 2);

      // Type mapping: [String: String] → Map<String, String>
      final headersField = opts.fields.firstWhere((f) => f.name == 'headers');
      expect(headersField.type.kind, UtsTypeKind.map);

      // Round-trip
      final json = jsonEncode(result.schema.toJson());
      final roundTripped =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(roundTripped.classes.length, result.schema.classes.length);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('AST Gradle parser integration', () {
    test('parses Kotlin source via kotlinc PSI', () async {
      if (!await detector.hasKotlinc()) {
        markTestSkipped('kotlinc not available');
        return;
      }

      final ktFile = File('${tempDir.path}/Client.kt');
      ktFile.writeAsStringSync('''
package com.example

data class Config(
    val baseUrl: String,
    val timeout: Long = 30000,
    val headers: Map<String, String> = emptyMap()
)

class HttpClient(private val config: Config) {
    fun get(url: String): String = ""
    fun post(url: String, body: String): String = ""
    suspend fun getAsync(url: String): String = ""
}

enum class Method {
    GET, POST, PUT, DELETE
}

sealed class Result {
    data class Success(val data: String) : Result()
    data class Failure(val error: String) : Result()
}
''');

      final parser = AstGradleParser(
        timeout: const Duration(seconds: 180),
      );
      final result = await parser.parseFilesAsync(
        files: {ktFile.path: ktFile.readAsStringSync()},
        packageName: 'com.example:http-client',
        version: '1.0.0',
      );

      expect(result.schema.package, 'com.example:http-client');
      expect(result.schema.source, PackageSource.gradle);

      // HttpClient class
      final client =
          result.schema.classes.firstWhere((c) => c.name == 'HttpClient');
      expect(client.kind, UtsClassKind.concreteClass);
      expect(client.methods.length, 3);

      // get and post return String
      final getMethod = client.methods.firstWhere((m) => m.name == 'get');
      expect(getMethod.returnType.name, 'String');

      // getAsync is async → Future
      final getAsync = client.methods.firstWhere((m) => m.name == 'getAsync');
      expect(getAsync.isAsync, isTrue);
      expect(getAsync.returnType.kind, UtsTypeKind.future);

      // Config data class → type
      final config = result.schema.types.firstWhere((t) => t.name == 'Config');
      expect(config.kind, UtsClassKind.dataClass);
      expect(config.fields.length, 3);

      // Map<String, String> type mapping
      final headersField = config.fields.firstWhere((f) => f.name == 'headers');
      expect(headersField.type.kind, UtsTypeKind.map);

      // Enum
      final methodEnum =
          result.schema.enums.firstWhere((e) => e.name == 'Method');
      expect(methodEnum.values.length, 4);

      // Sealed class
      final sealedResult =
          result.schema.classes.firstWhere((c) => c.name == 'Result');
      expect(sealedResult.kind, UtsClassKind.sealedClass);

      // Round-trip
      final json = jsonEncode(result.schema.toJson());
      final roundTripped =
          UnifiedTypeSchema.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(roundTripped.classes.length, result.schema.classes.length);
      expect(roundTripped.types.length, result.schema.types.length);
      expect(roundTripped.enums.length, result.schema.enums.length);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('AST vs regex comparison', () {
    test('AST finds at least as many declarations as regex for Swift',
        () async {
      if (!await detector.hasSwift()) {
        markTestSkipped('Swift not available');
        return;
      }

      final fixturePath = 'test/fixtures/swift/golden_alamofire.swift';
      if (!File(fixturePath).existsSync()) {
        markTestSkipped('Fixture not found');
        return;
      }

      final content = File(fixturePath).readAsStringSync();
      final files = {fixturePath: content};

      // Regex parse
      final regexParser = SwiftParser();
      final regexResult = regexParser.parseFilesWithValidation(
        files: files,
        packageName: 'Alamofire',
        version: '5.9.1',
      );

      // AST parse
      final astParser = AstSwiftParser(
        timeout: const Duration(seconds: 120),
      );
      final astResult = await astParser.parseFilesAsync(
        files: files,
        packageName: 'Alamofire',
        version: '5.9.1',
      );

      final regexTotal = regexResult.schema.classes.length +
          regexResult.schema.functions.length +
          regexResult.schema.types.length +
          regexResult.schema.enums.length;

      final astTotal = astResult.schema.classes.length +
          astResult.schema.functions.length +
          astResult.schema.types.length +
          astResult.schema.enums.length;

      // AST should find at least as many declarations
      expect(astTotal, greaterThanOrEqualTo(regexTotal),
          reason: 'AST found $astTotal declarations, regex found $regexTotal');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('AST finds at least as many declarations as regex for TypeScript',
        () async {
      if (!await detector.hasNode()) {
        markTestSkipped('Node.js >= 18 not available');
        return;
      }
      final tsCheck = await Process.run(
          'node', ['--input-type=module', '-e', 'import("typescript")']);
      if (tsCheck.exitCode != 0) {
        markTestSkipped('typescript npm package not installed');
        return;
      }

      final fixturePath = 'test/fixtures/npm/golden_date_fns.d.ts';
      if (!File(fixturePath).existsSync()) {
        markTestSkipped('Fixture not found');
        return;
      }

      final content = File(fixturePath).readAsStringSync();
      final files = {fixturePath: content};

      final regexParser = NpmParser();
      final regexResult = regexParser.parseFilesWithValidation(
        files: files,
        packageName: 'date-fns',
        version: '3.6.0',
      );

      final astParser = AstNpmParser();
      final astResult = await astParser.parseFilesAsync(
        files: files,
        packageName: 'date-fns',
        version: '3.6.0',
      );

      final regexTotal =
          regexResult.schema.functions.length + regexResult.schema.types.length;
      final astTotal =
          astResult.schema.functions.length + astResult.schema.types.length;

      expect(astTotal, greaterThanOrEqualTo(regexTotal),
          reason: 'AST found $astTotal, regex found $regexTotal');
    });
  });

  group('AST Kotlin extension functions', () {
    test(
        'folds extensions into matching class and emits unmatched as top-level',
        () async {
      if (!await detector.hasKotlinc()) {
        markTestSkipped('kotlinc not available');
        return;
      }

      final ktFile = File('${tempDir.path}/Extensions.kt');
      ktFile.writeAsStringSync('''
package com.example.ext

class StringUtils {
    fun isEmpty(value: String): Boolean {
        return value.isEmpty()
    }
}

fun StringUtils.reverse(input: String): String {
    return input.reversed()
}

fun String.trimWhitespace(): String {
    return this.trim()
}

fun Int.isEven(): Boolean {
    return this % 2 == 0
}
''');

      final parser = AstGradleParser(
        timeout: const Duration(seconds: 180),
      );
      final result = await parser.parseFilesAsync(
        files: {ktFile.path: ktFile.readAsStringSync()},
        packageName: 'com.example:ext',
        version: '1.0.0',
      );

      expect(result.schema.package, 'com.example:ext');

      // StringUtils should have isEmpty + folded reverse
      final stringUtils =
          result.schema.classes.firstWhere((c) => c.name == 'StringUtils');
      expect(stringUtils.methods.length, 2,
          reason: 'StringUtils should have isEmpty + reverse');
      expect(stringUtils.methods.map((m) => m.name),
          containsAll(['isEmpty', 'reverse']));

      // Unmatched extensions become top-level functions with self param
      expect(result.schema.functions.length, greaterThanOrEqualTo(2),
          reason: 'trimWhitespace and isEven should be top-level');

      final trimFn = result.schema.functions
          .where((f) => f.name == 'trimWhitespace')
          .toList();
      expect(trimFn, hasLength(1));
      expect(trimFn.first.parameters.first.name, 'self',
          reason: 'Extension receiver becomes self param');

      final isEvenFn =
          result.schema.functions.where((f) => f.name == 'isEven').toList();
      expect(isEvenFn, hasLength(1));
      expect(isEvenFn.first.parameters.first.name, 'self');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('AST Kotlin overload deduplication', () {
    test('deduplicates overloaded top-level and class methods', () async {
      if (!await detector.hasKotlinc()) {
        markTestSkipped('kotlinc not available');
        return;
      }

      final ktFile = File('${tempDir.path}/Overloads.kt');
      ktFile.writeAsStringSync('''
package com.example.overloads

fun process(input: String): String {
    return input
}

fun process(input: Int): Int {
    return input
}

fun uniqueFunction(data: String): Boolean {
    return true
}

class OverloadedService {
    fun fetch(url: String): String {
        return ""
    }

    fun fetch(url: String, timeout: Int): String {
        return ""
    }

    fun transform(data: String): String {
        return data
    }
}
''');

      final parser = AstGradleParser(
        timeout: const Duration(seconds: 180),
      );
      final result = await parser.parseFilesAsync(
        files: {ktFile.path: ktFile.readAsStringSync()},
        packageName: 'com.example:overloads',
        version: '1.0.0',
      );

      // Top-level: process (deduped to 1) + uniqueFunction = 2
      expect(result.schema.functions.length, 2,
          reason: 'Overloaded process() should be deduplicated');
      final fnNames = result.schema.functions.map((f) => f.name).toList();
      expect(fnNames, containsAll(['process', 'uniqueFunction']));
      expect(fnNames.toSet().length, fnNames.length,
          reason: 'No duplicate function names');

      // Class: fetch (deduped to 1) + transform = 2
      final service = result.schema.classes
          .firstWhere((c) => c.name == 'OverloadedService');
      expect(service.methods.length, 2,
          reason: 'Overloaded fetch() should be deduplicated');
      final methodNames = service.methods.map((m) => m.name).toList();
      expect(methodNames, containsAll(['fetch', 'transform']));
      expect(methodNames.toSet().length, methodNames.length,
          reason: 'No duplicate method names');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('AST Swift throws propagation', () {
    test('throwing functions marked async with Future return', () async {
      if (!await detector.hasSwift()) {
        markTestSkipped('Swift not available');
        return;
      }

      final swiftFile = File('${tempDir.path}/Throws.swift');
      swiftFile.writeAsStringSync('''
import Foundation

public class NetworkService {
    public func fetchData(url: String) throws -> String {
        return ""
    }

    public func uploadData(data: Data, to url: String) async throws -> Bool {
        return true
    }

    public func syncMethod(value: Int) -> Int {
        return value
    }
}

public func riskyOperation(input: String) throws -> String {
    return input
}

public func safeOperation(input: String) -> String {
    return input
}
''');

      final parser = AstSwiftParser(
        timeout: const Duration(seconds: 120),
      );
      final result = await parser.parseFilesAsync(
        files: {swiftFile.path: swiftFile.readAsStringSync()},
        packageName: 'ThrowsLib',
        version: '1.0.0',
      );

      expect(result.schema.package, 'ThrowsLib');

      final service =
          result.schema.classes.firstWhere((c) => c.name == 'NetworkService');

      // throws → isAsync: true, Future return
      final fetchData =
          service.methods.firstWhere((m) => m.name == 'fetchData');
      expect(fetchData.isAsync, isTrue, reason: 'throws should set isAsync');
      expect(fetchData.returnType.kind, UtsTypeKind.future,
          reason: 'throws should wrap return in Future');

      // async throws → isAsync: true, Future return
      final uploadData =
          service.methods.firstWhere((m) => m.name == 'uploadData');
      expect(uploadData.isAsync, isTrue);
      expect(uploadData.returnType.kind, UtsTypeKind.future);

      // non-throwing → isAsync: false
      final syncMethod =
          service.methods.firstWhere((m) => m.name == 'syncMethod');
      expect(syncMethod.isAsync, isFalse);
      expect(syncMethod.returnType.kind, isNot(UtsTypeKind.future));

      // Top-level throwing function
      final risky =
          result.schema.functions.firstWhere((f) => f.name == 'riskyOperation');
      expect(risky.isAsync, isTrue);
      expect(risky.returnType.kind, UtsTypeKind.future);

      // Top-level safe function
      final safe =
          result.schema.functions.firstWhere((f) => f.name == 'safeOperation');
      expect(safe.isAsync, isFalse);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('AST mixed Kotlin/Java handling', () {
    test('parses both .kt and .java files in same package', () async {
      if (!await detector.hasKotlinc()) {
        markTestSkipped('kotlinc not available');
        return;
      }

      final ktFile = File('${tempDir.path}/Client.kt');
      ktFile.writeAsStringSync('''
package com.example.mixed

class KotlinClient {
    fun connect(host: String): Boolean {
        return true
    }
}
''');

      final javaFile = File('${tempDir.path}/Helper.java');
      javaFile.writeAsStringSync('''
package com.example.mixed;

public class JavaHelper {
    public String format(String input) {
        return input;
    }
}
''');

      final parser = AstGradleParser(
        timeout: const Duration(seconds: 180),
      );
      final result = await parser.parseFilesAsync(
        files: {
          ktFile.path: ktFile.readAsStringSync(),
          javaFile.path: javaFile.readAsStringSync(),
        },
        packageName: 'com.example:mixed',
        version: '1.0.0',
      );

      expect(result.schema.package, 'com.example:mixed');

      // KotlinClient from AST
      final ktClasses =
          result.schema.classes.where((c) => c.name == 'KotlinClient').toList();
      expect(ktClasses, hasLength(1),
          reason: 'KotlinClient should come from AST subprocess');
      expect(ktClasses.first.methods.length, greaterThanOrEqualTo(1));

      // JavaHelper from regex fallback
      final javaClasses =
          result.schema.classes.where((c) => c.name == 'JavaHelper').toList();
      expect(javaClasses, hasLength(1),
          reason: 'JavaHelper should come from regex fallback');
      expect(javaClasses.first.methods.length, greaterThanOrEqualTo(1));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('AST TypeScript default exports', () {
    test('parses export default interface', () async {
      if (!await detector.hasNode()) {
        markTestSkipped('Node.js >= 18 not available');
        return;
      }
      final tsCheck = await Process.run(
          'node', ['--input-type=module', '-e', 'import("typescript")']);
      if (tsCheck.exitCode != 0) {
        markTestSkipped('typescript npm package not installed');
        return;
      }

      final tsFile = File('${tempDir.path}/defaults.d.ts');
      tsFile.writeAsStringSync('''
export default interface Config {
    host: string;
    port: number;
    debug?: boolean;
}

export declare interface Logger {
    log(message: string): void;
    error(message: string, code: number): void;
}

export type Options = {
    timeout: number;
    retries: number;
};

export enum Status {
    Active = "active",
    Inactive = "inactive",
    Pending = "pending",
}
''');

      final parser = AstNpmParser();
      final result = await parser.parseFilesAsync(
        files: {tsFile.path: tsFile.readAsStringSync()},
        packageName: 'test-defaults',
        version: '1.0.0',
      );

      expect(result.schema.package, 'test-defaults');

      // Config: export default interface → dataClass
      final allTypes = result.schema.types;
      final config = allTypes.where((t) => t.name == 'Config').toList();
      expect(config, hasLength(1),
          reason: 'export default interface Config should be parsed');
      expect(config.first.kind, UtsClassKind.dataClass);
      expect(config.first.fields.length, 3);

      // Logger: export declare interface with methods → abstractClass
      final logger =
          result.schema.classes.where((c) => c.name == 'Logger').toList();
      expect(logger, hasLength(1),
          reason: 'export declare interface Logger should be parsed');

      // Options: export type → dataClass
      final options = allTypes.where((t) => t.name == 'Options').toList();
      expect(options, hasLength(1),
          reason: 'export type Options should be parsed');

      // Status: export enum
      final statusEnum =
          result.schema.enums.where((e) => e.name == 'Status').toList();
      expect(statusEnum, hasLength(1),
          reason: 'export enum Status should be parsed');
      expect(statusEnum.first.values.length, 3);
    });
  });

  group('AST Kotlin generic extension edge cases', () {
    test('handles generic and specific-generic receiver types', () async {
      if (!await detector.hasKotlinc()) {
        markTestSkipped('kotlinc not available');
        return;
      }

      final ktFile = File('${tempDir.path}/GenericExt.kt');
      ktFile.writeAsStringSync('''
package com.example.edge

class MyService {
    fun ping(): Boolean = true
}

// Extension on generic type
fun <T> List<T>.secondOrNull(): T? {
    return if (this.size >= 2) this[1] else null
}

// Extension on specific generic instantiation
fun List<String>.joinWithComma(): String {
    return this.joinToString(",")
}

// Extension on class defined in same file (should fold)
fun MyService.reset(): Unit {}
''');

      final parser = AstGradleParser(
        timeout: const Duration(seconds: 180),
      );
      final result = await parser.parseFilesAsync(
        files: {ktFile.path: ktFile.readAsStringSync()},
        packageName: 'com.example:edge',
        version: '1.0.0',
      );

      // MyService should have ping + folded reset
      final service =
          result.schema.classes.firstWhere((c) => c.name == 'MyService');
      expect(service.methods.length, 2,
          reason: 'MyService should have ping + reset');
      expect(
          service.methods.map((m) => m.name), containsAll(['ping', 'reset']));

      // Generic extensions become top-level functions with self param
      expect(result.schema.functions.length, greaterThanOrEqualTo(2),
          reason: 'secondOrNull and joinWithComma should be top-level');

      final secondOrNull = result.schema.functions
          .where((f) => f.name == 'secondOrNull')
          .toList();
      expect(secondOrNull, hasLength(1));
      expect(secondOrNull.first.parameters.first.name, 'self',
          reason: 'Generic extension receiver becomes self param');

      final joinWithComma = result.schema.functions
          .where((f) => f.name == 'joinWithComma')
          .toList();
      expect(joinWithComma, hasLength(1));
      expect(joinWithComma.first.parameters.first.name, 'self');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('AST Swift typed throws edge cases', () {
    test('typed throws(ErrorType) correctly propagates isAsync and return type',
        () async {
      if (!await detector.hasSwift()) {
        markTestSkipped('Swift not available');
        return;
      }

      final swiftFile = File('${tempDir.path}/TypedThrows.swift');
      swiftFile.writeAsStringSync('''
import Foundation

public enum NetworkError: Error {
    case timeout
    case notFound
}

public class ApiClient {
    public func fetchTyped(url: String) throws(NetworkError) -> String {
        return ""
    }

    public func fetchRegular(url: String) throws -> String {
        return ""
    }

    public func fetchSafe(url: String) -> String {
        return ""
    }
}

public func topLevelTypedThrows() throws(NetworkError) -> Bool {
    return true
}
''');

      final parser = AstSwiftParser(
        timeout: const Duration(seconds: 120),
      );
      final result = await parser.parseFilesAsync(
        files: {swiftFile.path: swiftFile.readAsStringSync()},
        packageName: 'TypedThrowsLib',
        version: '1.0.0',
      );

      final client =
          result.schema.classes.firstWhere((c) => c.name == 'ApiClient');

      // typed throws(NetworkError) → isAsync: true, Future<String>
      final fetchTyped =
          client.methods.firstWhere((m) => m.name == 'fetchTyped');
      expect(fetchTyped.isAsync, isTrue,
          reason: 'typed throws should set isAsync');
      expect(fetchTyped.returnType.kind, UtsTypeKind.future,
          reason: 'typed throws should wrap return in Future');
      expect(fetchTyped.returnType.typeArguments?.first.name, 'String',
          reason: 'typed throws should preserve return type inside Future');

      // regular throws → isAsync: true, Future<String>
      final fetchRegular =
          client.methods.firstWhere((m) => m.name == 'fetchRegular');
      expect(fetchRegular.isAsync, isTrue);
      expect(fetchRegular.returnType.kind, UtsTypeKind.future);
      expect(fetchRegular.returnType.typeArguments?.first.name, 'String');

      // no throws → isAsync: false, plain String
      final fetchSafe = client.methods.firstWhere((m) => m.name == 'fetchSafe');
      expect(fetchSafe.isAsync, isFalse);
      expect(fetchSafe.returnType.kind, isNot(UtsTypeKind.future));

      // top-level typed throws → Future<bool>
      final topLevel = result.schema.functions
          .firstWhere((f) => f.name == 'topLevelTypedThrows');
      expect(topLevel.isAsync, isTrue);
      expect(topLevel.returnType.kind, UtsTypeKind.future);
      expect(topLevel.returnType.typeArguments?.first.name, 'bool',
          reason: 'typed throws should preserve Bool → bool return type');

      // NetworkError enum should be parsed
      final errorEnum =
          result.schema.enums.where((e) => e.name == 'NetworkError').toList();
      expect(errorEnum, hasLength(1));
      expect(errorEnum.first.values.length, 2);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
