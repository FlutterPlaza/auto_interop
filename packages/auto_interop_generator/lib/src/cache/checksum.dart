import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Computes SHA-256 checksums for content-based caching.
class Checksum {
  const Checksum._();

  /// Computes the SHA-256 digest of [content] and returns the hex string.
  static String of(String content) {
    final bytes = utf8.encode(content);
    return sha256.convert(bytes).toString();
  }

  /// Computes a combined checksum for multiple strings by hashing their
  /// sorted individual checksums. Order-independent.
  static String ofAll(Iterable<String> contents) {
    final hashes = contents.map(of).toList()..sort();
    return of(hashes.join());
  }
}
