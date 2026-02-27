import 'dart:io';

/// Function type for running external processes. Allows test mocking.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// Detects availability of native toolchains needed by AST helpers.
///
/// Results are cached per-instance so each check runs at most once.
class ToolchainDetector {
  final ProcessRunner _runProcess;

  bool? _hasNode;
  bool? _hasSwift;
  bool? _hasKotlinc;
  String? _cachedSwiftBinary;
  bool _swiftBinaryChecked = false;

  ToolchainDetector({ProcessRunner? processRunner})
      : _runProcess = processRunner ?? _defaultProcessRunner;

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(executable, arguments,
        workingDirectory: workingDirectory);
  }

  /// Whether Node.js >= 18 is available.
  Future<bool> hasNode() async {
    if (_hasNode != null) return _hasNode!;
    try {
      final result = await _runProcess('node', ['--version']);
      if (result.exitCode != 0) {
        _hasNode = false;
        return false;
      }
      // Parse version like "v18.17.0" or "v20.0.0"
      final version = (result.stdout as String).trim();
      final match = RegExp(r'^v(\d+)\.').firstMatch(version);
      _hasNode = match != null && int.parse(match.group(1)!) >= 18;
    } catch (_) {
      _hasNode = false;
    }
    return _hasNode!;
  }

  /// Whether `swift` is available.
  Future<bool> hasSwift() async {
    if (_hasSwift != null) return _hasSwift!;
    try {
      final result = await _runProcess('swift', ['--version']);
      _hasSwift = result.exitCode == 0;
    } catch (_) {
      _hasSwift = false;
    }
    return _hasSwift!;
  }

  /// Whether `kotlinc` is available.
  Future<bool> hasKotlinc() async {
    if (_hasKotlinc != null) return _hasKotlinc!;
    try {
      final result = await _runProcess('kotlinc', ['-version']);
      _hasKotlinc = result.exitCode == 0;
    } catch (_) {
      _hasKotlinc = false;
    }
    return _hasKotlinc!;
  }

  /// Path to the cached Swift AST helper binary, or `null` if not compiled yet.
  String? cachedSwiftBinary() {
    if (_swiftBinaryChecked) return _cachedSwiftBinary;
    _swiftBinaryChecked = true;
    final home = homeDirectory();
    if (home == null) return null;
    final binaryPath = '$home/.auto_interop/tools/swift_ast_helper';
    if (File(binaryPath).existsSync()) {
      _cachedSwiftBinary = binaryPath;
    }
    return _cachedSwiftBinary;
  }

  /// Resets the cached Swift binary path (e.g. after compilation).
  void invalidateSwiftBinaryCache() {
    _swiftBinaryChecked = false;
    _cachedSwiftBinary = null;
  }

  /// Returns the installed kotlinc version string (e.g. "2.3.10"), or null.
  Future<String?> kotlincVersion() async {
    try {
      final result = await _runProcess('kotlinc', ['-version']);
      if (result.exitCode != 0) return null;
      // Output: "info: kotlinc-jvm 2.3.10 (JRE ...)" on stderr or stdout
      final output = '${result.stdout}${result.stderr}'.trim();
      final match = RegExp(r'kotlinc-jvm\s+([\d.]+)').firstMatch(output);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  /// Returns the user home directory, checking HOME then USERPROFILE (Windows).
  static String? homeDirectory() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) return home;
    // Windows fallback
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) return userProfile;
    return null;
  }
}
