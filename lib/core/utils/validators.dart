// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../l10n/generated/app_localizations.dart';

/// Form validation, written as pure functions so they are unit-testable without a widget
/// tree and so the same rule backs both inline validation and a submit-time check.
///
/// Every validator returns `null` when the value is acceptable, or a **localized** message
/// ready to hand to `TextFormField.validator`. No validator returns a hard-coded string.
abstract final class Validators {
  /// Minimum password length enforced client-side.
  ///
  /// The server is the authority; this is the same floor so the user is not told "ok"
  /// and then rejected by the backend.
  static const int minPasswordLength = 8;

  /// Maximum length accepted by the text fields, matching the server contract.
  static const int maxEmailLength = 254;

  /// Email address, pragmatic check: exactly one `@`, a dot in the domain, no spaces.
  static String? email(String? value, AppLocalizations l10n) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return l10n.validatorEmailRequired;
    }
    if (text.length > maxEmailLength) {
      return l10n.validatorTooLong(maxEmailLength);
    }
    return isEmail(text) ? null : l10n.validatorEmailInvalid;
  }

  /// Non-localized email predicate, for callers that only need a boolean.
  static bool isEmail(String value) {
    final String text = value.trim();
    if (text.isEmpty || text.contains(' ')) {
      return false;
    }
    final List<String> parts = text.split('@');
    if (parts.length != 2) {
      return false;
    }
    final String local = parts[0];
    final String domain = parts[1];
    if (local.isEmpty || domain.isEmpty) {
      return false;
    }
    if (!domain.contains('.')) {
      return false;
    }
    if (domain.startsWith('.') || domain.endsWith('.') || domain.contains('..')) {
      return false;
    }
    return true;
  }

  /// A required password of at least [minPasswordLength] characters.
  static String? password(
    String? value,
    AppLocalizations l10n, {
    int minLength = minPasswordLength,
  }) {
    final String text = value ?? '';
    if (text.isEmpty) {
      return l10n.validatorPasswordRequired;
    }
    if (text.length < minLength) {
      return l10n.validatorPasswordTooShort(minLength);
    }
    return null;
  }

  /// A strong password: length **and** a lower-case letter, an upper-case letter and a
  /// digit. Used on sign-up and password reset, not on sign-in (an existing password may
  /// predate the rule, and rejecting it client-side would lock the user out).
  static String? strongPassword(String? value, AppLocalizations l10n) {
    final String? basic = password(value, l10n);
    if (basic != null) {
      return basic;
    }
    final String text = value ?? '';
    final bool hasLower = text.contains(RegExp('[a-z]'));
    final bool hasUpper = text.contains(RegExp('[A-Z]'));
    final bool hasDigit = text.contains(RegExp('[0-9]'));
    if (!hasLower || !hasUpper || !hasDigit) {
      return l10n.validatorPasswordWeak;
    }
    return null;
  }

  /// Confirmation field: non-empty and equal to [original].
  static String? confirmPassword(
    String? value,
    String original,
    AppLocalizations l10n,
  ) {
    final String text = value ?? '';
    if (text.isEmpty) {
      return l10n.validatorConfirmRequired;
    }
    return text == original ? null : l10n.validatorPasswordMismatch;
  }

  /// A required, non-blank text value with an optional length ceiling.
  static String? requiredText(
    String? value,
    AppLocalizations l10n, {
    int? maxLength,
  }) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return l10n.validatorRequired;
    }
    if (maxLength != null && text.length > maxLength) {
      return l10n.validatorTooLong(maxLength);
    }
    return null;
  }

  /// A required display name.
  static String? displayName(String? value, AppLocalizations l10n) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return l10n.validatorNameRequired;
    }
    if (text.length > 80) {
      return l10n.validatorTooLong(80);
    }
    return null;
  }

  /// A pairing code: exactly [codeLength] characters from the unambiguous alphabet.
  static String? pairingCode(
    String? value,
    AppLocalizations l10n, {
    int codeLength = 8,
  }) {
    final String text = normalizePairingCode(value ?? '');
    if (text.length != codeLength) {
      return l10n.validatorCodeInvalid;
    }
    return null;
  }

  /// A positive whole number, e.g. a snooze duration or a sensor threshold.
  static String? positiveNumber(String? value, AppLocalizations l10n) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return l10n.validatorRequired;
    }
    final num? parsed = num.tryParse(text);
    if (parsed == null) {
      return l10n.validatorNumberInvalid;
    }
    if (parsed <= 0) {
      return l10n.validatorNumberInvalid;
    }
    return null;
  }

  /// A time of day in 24-hour `HH:MM`, as typed into an alarm row.
  static String? timeOfDay(String? value, AppLocalizations l10n) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return l10n.validatorRequired;
    }
    final RegExpMatch? match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (match == null) {
      return l10n.validatorNumberInvalid;
    }
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      return l10n.validatorNumberInvalid;
    }
    return null;
  }

  /// Strips separator characters and upper-cases a pairing code, so `abcd-1234`,
  /// `abcd 1234` and `ABCD1234` all denote the same code.
  static String normalizePairingCode(String value) => value
      .toUpperCase()
      .replaceAll(RegExp('[^A-Z0-9]'), '');

  /// Formats a raw pairing code as `XXXX-XXXX` for display as it is typed.
  static String formatPairingCode(String value, {int groupSize = 4}) {
    final String normalized = normalizePairingCode(value);
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < normalized.length; i++) {
      if (i > 0 && i % groupSize == 0) {
        buffer.write('-');
      }
      buffer.write(normalized[i]);
    }
    return buffer.toString();
  }
}
