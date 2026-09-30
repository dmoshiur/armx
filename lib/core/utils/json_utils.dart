// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Defensive readers for JSON that arrives from the network.
///
/// Assistant text, tool parameters and device payloads are **untrusted input**: a hostile
/// server, a compromised ESP32 node or a prompt-injected model can put anything in those
/// fields. These helpers never throw, always bound their output, and make the failure mode
/// explicit instead of crashing the UI with a `TypeError`.
abstract final class JsonUtils {
  /// Maximum accepted string length (defence against memory-exhaustion payloads).
  static const int maxStringLength = 32768;

  /// Reads a string, clamping its length and trimming control characters.
  static String? string(Map<Object?, Object?>? json, String key, {int? maxLength}) {
    final value = json?[key];
    if (value is String) {
      final limit = maxLength ?? maxStringLength;
      final sanitised = value.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');
      return sanitised.length > limit ? sanitised.substring(0, limit) : sanitised;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  /// Reads an int, accepting only integral values or integral doubles.
  static int? integer(Map<Object?, Object?>? json, String key) {
    final value = json?[key];
    if (value is int) {
      return value;
    }
    if (value is double && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  /// Reads a double, rejecting NaN/Infinity.
  static double? number(Map<Object?, Object?>? json, String key) {
    final value = json?[key];
    if (value is num) {
      final asDouble = value.toDouble();
      return asDouble.isFinite ? asDouble : null;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed != null && parsed.isFinite ? parsed : null;
    }
    return null;
  }

  /// Reads a bool, accepting `true/false`, `1/0` and `"true"/"false"`.
  static bool? boolean(Map<Object?, Object?>? json, String key) {
    final value = json?[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') {
        return true;
      }
      if (lower == 'false' || lower == '0') {
        return false;
      }
    }
    return null;
  }

  /// Reads an ISO-8601 timestamp into UTC.
  static DateTime? dateTime(Map<Object?, Object?>? json, String key) {
    final value = json?[key];
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    if (value is int) {
      // Epoch seconds or milliseconds, whichever is plausible.
      final magnitude = value.abs();
      return magnitude < 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    return null;
  }

  /// Narrows a dynamic value to a JSON map without throwing.
  static Map<Object?, Object?>? asMap(Object? value) =>
      value is Map ? value.cast<Object?, Object?>() : null;

  /// Narrows a dynamic value to a list of maps, skipping non-map elements.
  static List<Map<Object?, Object?>> asMapList(Object? value) {
    if (value is! List) {
      return const <Map<Object?, Object?>>[];
    }
    return value
        .map(asMap)
        .whereType<Map<Object?, Object?>>()
        .toList(growable: false);
  }

  /// Reads a list of strings, skipping malformed entries.
  static List<String> stringList(Map<Object?, Object?>? json, String key) {
    final value = json?[key];
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }
}
