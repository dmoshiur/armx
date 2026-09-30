// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:typed_data';

/// Byte/hex helpers used for key fingerprints, nonces and pins.
abstract final class Hex {
  static const String _digits = '0123456789abcdef';

  /// Lowercase hex encoding of [bytes].
  static String encode(List<int> bytes, {bool upperCase = false}) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      final value = byte & 0xFF;
      buffer
        ..write(_digits[(value >> 4) & 0x0F])
        ..write(_digits[value & 0x0F]);
    }
    final result = buffer.toString();
    return upperCase ? result.toUpperCase() : result;
  }

  /// Decodes [hex] into bytes. Throws [FormatException] when the input is malformed.
  static Uint8List decode(String hex) {
    final clean = hex.replaceAll(RegExp(r'[\s:-]'), '');
    if (clean.length.isOdd) {
      throw FormatException('Hex string must have an even length', hex);
    }
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      final byte = int.tryParse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) {
        throw FormatException('Invalid hex pair at index $i', hex);
      }
      result[i] = byte;
    }
    return result;
  }

  /// Groups [hex] into space-separated chunks for human comparison.
  ///
  /// The output is what the pairing screen shows as a key fingerprint, for example
  /// `A1B2 C3D4 …`. It is **not** a secret: it is a one-way digest of the public key.
  static String group(String hex, {int size = 4, int? maxGroups}) {
    final clean = hex.replaceAll(RegExp(r'[\s:-]'), '');
    final groups = <String>[];
    for (var i = 0; i < clean.length; i += size) {
      final end = (i + size).clamp(0, clean.length);
      groups.add(clean.substring(i, end).toUpperCase());
      if (maxGroups != null && groups.length >= maxGroups) {
        break;
      }
    }
    return groups.join(' ');
  }

  /// True when both byte strings are equal, compared in constant time.
  ///
  /// Used for nonce and MAC comparisons so that a timing observer learns nothing.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= (a[i] ^ b[i]) & 0xFF;
    }
    return difference == 0;
  }
}
