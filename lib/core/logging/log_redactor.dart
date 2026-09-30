// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

/// Removes secrets and biometric material from anything that reaches a log sink.
///
/// This class is deliberately aggressive: a false positive only costs readability,
/// whereas a false negative leaks a bearer token or a face embedding into a log file.
abstract final class LogRedactor {
  /// Placeholder inserted in place of redacted content.
  static const String mask = '<redacted>';

  /// Keys whose values are always replaced, matched case-insensitively.
  static const Set<String> sensitiveKeys = <String>{
    'password',
    'passcode',
    'pin',
    'token',
    'access_token',
    'accessToken',
    'refresh_token',
    'refreshToken',
    'id_token',
    'authorization',
    'private_key',
    'privateKey',
    'secret',
    'client_secret',
    'api_key',
    'apiKey',
    'device_key',
    'deviceKey',
    'signature',
    'nonce',
    'face_template',
    'faceTemplate',
    'embedding',
    'voice_print',
    'voicePrint',
    'biometric',
    'owner_verified',
    'ownerVerified',
  };

  /// `Bearer <token>` headers.
  static final RegExp _bearer = RegExp(r'(Bearer|bearer)\s+[A-Za-z0-9\-._~+/=]+');

  /// Three-part JWT strings (`header.payload.signature`).
  static final RegExp _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b',
  );

  /// Long base64/hex blobs, which is how keys, pins and embeddings usually travel.
  static final RegExp _blob = RegExp(r'\b[A-Za-z0-9+/]{40,}={0,2}\b|\b[0-9a-fA-F]{48,}\b');

  /// `key=value` pairs for sensitive keys in query strings or log lines.
  static final RegExp _keyValue = RegExp(
    '(${sensitiveKeys.map(RegExp.escape).join('|')})'
    r'\s*[=:]\s*("?)([^"&\s,}]+)\2',
    caseSensitive: false,
  );

  /// Redacts [input] and returns the safe string.
  static String redact(String input) {
    if (input.isEmpty) {
      return input;
    }
    var output = input
        .replaceAllMapped(_bearer, (m) => '${m.group(1)} $mask')
        .replaceAllMapped(_jwt, (_) => mask)
        .replaceAllMapped(_keyValue, (m) => '${m.group(1)}=$mask')
        .replaceAllMapped(_blob, (m) {
      final value = m.group(0) ?? '';
      if (value.length < 48) {
        return value;
      }
      return '${value.substring(0, 6)}…$mask';
    });
    // Guard against a token that happens to be shorter than the blob heuristic.
    output = output.replaceAll(RegExp(r'\beyJ[\w-]{6,}\b'), mask);
    return output;
  }

  /// Returns a deep copy of [data] with sensitive keys and values redacted.
  ///
  /// Safe to call on anything decoded from JSON: the input is not mutated.
  static Object? redactValue(Object? data, {int depth = 0}) {
    if (depth > 6) {
      return mask;
    }
    if (data is Map) {
      return <String, Object?>{
        for (final entry in data.entries)
          entry.key.toString(): sensitiveKeys
                  .contains(entry.key.toString().toLowerCase())
              ? mask
              : redactValue(entry.value, depth: depth + 1),
      };
    }
    if (data is Iterable) {
      return data.map((item) => redactValue(item, depth: depth + 1)).toList(growable: false);
    }
    if (data is String) {
      return redact(data);
    }
    return data;
  }

  /// Convenience helper for logging structured payloads.
  static String encodeRedacted(Object? data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(redactValue(data));
    } on Object {
      return mask;
    }
  }

  /// Short, non-reversible fingerprint of a secret, for diagnostics ("is it the same key?").
  ///
  /// Returns the first and last four characters plus the length, which is enough to
  /// compare two tokens by eye without revealing either.
  static String fingerprint(String secret) {
    if (secret.length <= 12) {
      return '<len:${secret.length}>';
    }
    return '${secret.substring(0, 4)}…${secret.substring(secret.length - 4)}'
        '(len:${secret.length})';
  }
}
