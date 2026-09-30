// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Action risk classification used across chat tool calls, device commands, rules and unlock.
///
/// The ordering of the enum is meaningful: `index` is used to compare tiers, so a higher
/// tier always requires at least everything the lower tier requires.
enum RiskTier {
  /// Read-only or reversible action. Face **or** voice is enough.
  low,

  /// State-changing action (relay toggle, scene, rule change). Face **and** voice.
  medium,

  /// Privileged action (unlock a machine, disarm, destructive command).
  /// Face **and** voice **and** system biometric or device PIN.
  high;

  /// Human readable identifier used in logs and API payloads.
  String get wireName => name.toUpperCase();

  /// Whether this tier is at least as privileged as [other].
  bool isAtLeast(RiskTier other) => index >= other.index;

  /// Parses a wire value (`LOW`, `MEDIUM`, `HIGH`, or lower-case) into a tier.
  ///
  /// Unknown or missing values are treated as [RiskTier.high]: fail closed, never open.
  static RiskTier fromWire(Object? value) {
    if (value is RiskTier) {
      return value;
    }
    final text = value?.toString().trim().toUpperCase();
    return switch (text) {
      'LOW' => RiskTier.low,
      'MEDIUM' => RiskTier.medium,
      'HIGH' => RiskTier.high,
      _ => RiskTier.high,
    };
  }
}
