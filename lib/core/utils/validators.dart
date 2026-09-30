// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Reason a piece of user input was rejected. UI code maps these to ARB strings.
enum ValidationIssue {
  /// Nothing was entered.
  empty,

  /// Not parseable as an absolute URL.
  notAbsoluteUrl,

  /// Scheme other than http/https (or wss/ws) was used.
  unsupportedScheme,

  /// Cleartext `http`/`ws` while the build requires TLS.
  cleartextNotAllowed,

  /// No host component.
  missingHost,

  /// Port outside 1..65535.
  badPort,

  /// Input longer than the allowed maximum.
  tooLong,

  /// Characters that have no business being in this field.
  invalidCharacters,

  /// A device key must be 32–128 base64url characters.
  badDeviceKey,

  /// Face-match threshold outside the sensible 0.10–0.99 band.
  badThreshold,

  /// Wake word must be 2–32 letters/numbers.
  badWakeWord,
}

/// Pure input validation shared by every form in the app.
///
/// Functions return `null` when the input is acceptable, otherwise a [ValidationIssue].
/// They never throw and never localise: the UI owns the translation.
abstract final class Validators {
  static final RegExp _host = RegExp(r'^[A-Za-z0-9.\-]+$');
  static final RegExp _deviceKey = RegExp(r'^[A-Za-z0-9_\-]{32,128}$');
  static final RegExp _wakeWord = RegExp(r'^[A-Za-z0-9 ]{2,32}$');

  /// Validates an A.R.M.X server URL such as `https://armx.example.com:8443`.
  static ValidationIssue? serverUrl(String? raw, {bool requireTls = true}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return ValidationIssue.empty;
    }
    if (value.length > 512) {
      return ValidationIssue.tooLong;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return ValidationIssue.notAbsoluteUrl;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return ValidationIssue.unsupportedScheme;
    }
    if (uri.host.isEmpty || !_host.hasMatch(uri.host)) {
      return ValidationIssue.missingHost;
    }
    if (requireTls && uri.scheme == 'http') {
      return ValidationIssue.cleartextNotAllowed;
    }
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      return ValidationIssue.badPort;
    }
    return null;
  }

  /// Normalises a validated server URL (trims, drops trailing slash, keeps port/path).
  static Uri normaliseServerUrl(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.parse(trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed);
    return uri.replace(path: uri.path.isEmpty ? '' : uri.path);
  }

  /// Validates the device pairing key pasted/typed by a user.
  static ValidationIssue? deviceKey(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return ValidationIssue.empty;
    }
    if (value.length > 128) {
      return ValidationIssue.tooLong;
    }
    if (!_deviceKey.hasMatch(value)) {
      return ValidationIssue.badDeviceKey;
    }
    return null;
  }

  /// Validates a free-text field with a sensible upper bound.
  static ValidationIssue? nonEmpty(String? raw, {int maxLength = 512}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return ValidationIssue.empty;
    }
    if (value.length > maxLength) {
      return ValidationIssue.tooLong;
    }
    return null;
  }

  /// Validates the configured face match threshold.
  static ValidationIssue? matchThreshold(double value) =>
      value < 0.10 || value > 0.99 ? ValidationIssue.badThreshold : null;

  /// Validates a wake word (the default is "Armex").
  static ValidationIssue? wakeWord(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return ValidationIssue.empty;
    }
    if (!_wakeWord.hasMatch(value)) {
      return ValidationIssue.badWakeWord;
    }
    return null;
  }
}
