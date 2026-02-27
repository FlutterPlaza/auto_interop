import 'dart:isolate';

import '../npm_parser.dart';
import 'ast_parser_base.dart';

/// AST-based npm/TypeScript parser.
///
/// Invokes `ts_ast_helper.mjs` via Node.js to parse TypeScript declaration
/// files using the TypeScript Compiler API. Falls back to [NpmParser] if
/// Node.js is unavailable or the subprocess fails.
class AstNpmParser extends AstParserBase {
  String? _helperPath;

  AstNpmParser({
    super.toolchainDetector,
    super.processRunner,
    super.timeout,
  }) : super(fallbackParser: NpmParser());

  @override
  Future<bool> isToolchainAvailable() => toolchainDetector.hasNode();

  @override
  Future<void> prepare() async {
    _helperPath ??= await _resolveHelperPath();
  }

  @override
  List<String> helperCommand({
    required List<String> filePaths,
    required String packageName,
    required String version,
  }) {
    final path = _helperPath;
    if (path == null) return [];
    return [
      'node',
      path,
      '--package',
      packageName,
      '--version',
      version,
      ...filePaths,
    ];
  }

  /// Resolves the path to `ts_ast_helper.mjs` within this package.
  static Future<String> _resolveHelperPath() async {
    final packageUri = Uri.parse(
        'package:auto_interop_generator/src/parsers/ast/helpers/ts_ast_helper.mjs');
    final resolved = await Isolate.resolvePackageUri(packageUri);
    if (resolved != null) {
      return resolved.toFilePath();
    }
    // Fallback for development
    return 'lib/src/parsers/ast/helpers/ts_ast_helper.mjs';
  }
}
