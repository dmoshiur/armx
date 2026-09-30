// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:json_annotation/json_annotation.dart';

import '../../core/security/risk_tier.dart';

/// Parses a risk tier from wire values, failing **closed** (unknown ⇒ HIGH).
///
/// Implemented as plain top-level functions rather than a `JsonConverter` so that a
/// malformed payload can never throw a `TypeError` deep inside generated code.
RiskTier riskTierFromJson(Object? value) => RiskTier.fromWire(value);

/// Serialises a risk tier to its wire name (`LOW`/`MEDIUM`/`HIGH`).
String riskTierToJson(RiskTier tier) => tier.wireName;

/// Maps a `"key=value"` string into a nullable string lookup (MQTT-ish topics, tags).
Map<String, String> stringMapFromJson(Object? value) {
  if (value is Map) {
    return <String, String>{
      for (final entry in value.entries) entry.key.toString(): entry.value?.toString() ?? '',
    };
  }
  return const <String, String>{};
}

/// Parses an arbitrary JSON object into `Map<String, Object?>`.
Map<String, Object?> objectMapFromJson(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return const <String, Object?>{};
}
