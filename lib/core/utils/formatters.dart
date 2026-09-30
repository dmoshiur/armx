// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:intl/intl.dart';

/// Presentation helpers shared by dashboard, audit log and diagnostics.
///
/// Every formatter is locale-aware where it matters and cheap enough to call in a build
/// method (no `intl` initialization required beyond the app delegate).
abstract final class ArmxFormatters {
  /// `12:04:59` style clock time in the device locale.
  static String time(DateTime instant) =>
      DateFormat.Hms().format(instant.toLocal());

  /// `12 Apr 2026, 12:04` style short date-time.
  static String dateTime(DateTime instant) =>
      DateFormat.yMMMd().add_Hm().format(instant.toLocal());

  /// `12 Apr` style short date.
  static String date(DateTime instant) => DateFormat.MMMd().format(instant.toLocal());

  /// `mm:ss` countdown used by verification and unlock tokens.
  static String countdown(Duration remaining) {
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Compact relative age such as `now`, `42s`, `7m`, `3h`, `5d`.
  static String relative(DateTime instant, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final delta = reference.difference(instant);
    if (delta.inSeconds.abs() < 5) {
      return 'now';
    }
    if (delta.isNegative) {
      return '-${_compact(delta.abs())}';
    }
    return _compact(delta);
  }

  static String _compact(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    }
    if (duration.inHours < 24) {
      return '${duration.inHours}h';
    }
    return '${duration.inDays}d';
  }

  /// One decimal place, used for temperatures, humidity and match scores.
  static String decimal(double value, {int fractionDigits = 1}) =>
      value.toStringAsFixed(fractionDigits);

  /// Percentage with no decimals, used for confidence and battery badges.
  static String percent(num value, {bool alreadyFraction = false}) {
    final scaled = alreadyFraction ? value * 100 : value;
    return '${scaled.toStringAsFixed(0)}%';
  }

  /// Human readable byte size for logs and exports.
  static String bytes(int value) {
    if (value < 1024) {
      return '$value B';
    }
    if (value < 1024 * 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
