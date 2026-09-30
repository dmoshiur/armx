// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../errors/app_exception.dart';
import '../errors/error_messages.dart';
import '../utils/validators.dart';

export '../../l10n/generated/app_localizations.dart';

/// Localization access + error/validation translation helpers.
extension ArmxL10n on BuildContext {
  /// The generated localizations for the active locale.
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// Localized headline for [exception].
  String errorTitle(AppException exception) => AppErrorMessages.title(this, exception);

  /// Localized body for [exception].
  String errorBody(AppException exception) => AppErrorMessages.body(this, exception);

  /// Localized message for an input [issue].
  String validationMessage(ValidationIssue issue) => switch (issue) {
        ValidationIssue.empty => l10n.validationEmpty,
        ValidationIssue.notAbsoluteUrl => l10n.validationNotAbsoluteUrl,
        ValidationIssue.unsupportedScheme => l10n.validationUnsupportedScheme,
        ValidationIssue.cleartextNotAllowed => l10n.validationCleartextNotAllowed,
        ValidationIssue.missingHost => l10n.validationMissingHost,
        ValidationIssue.badPort => l10n.validationBadPort,
        ValidationIssue.tooLong => l10n.validationTooLong,
        ValidationIssue.invalidCharacters => l10n.validationInvalidCharacters,
        ValidationIssue.badDeviceKey => l10n.validationBadDeviceKey,
        ValidationIssue.badThreshold => l10n.validationBadThreshold,
        ValidationIssue.badWakeWord => l10n.validationBadWakeWord,
      };
}

/// Locale identifiers supported by the product.
enum AppLanguage {
  /// Follow the operating system.
  system(null, 'System default', 'সিস্টেম ডিফল্ট'),

  /// English.
  english(Locale('en'), 'English', 'English'),

  /// Bengali (Bangladesh).
  bengali(Locale('bn'), 'বাংলা', 'বাংলা');

  const AppLanguage(this.locale, this.englishLabel, this.bengaliLabel);

  /// Locale to request, or `null` for "system".
  final Locale? locale;

  /// English label for the picker.
  final String englishLabel;

  /// Bengali label for the picker.
  final String bengaliLabel;

  /// Parses a stored language code back into an [AppLanguage].
  static AppLanguage fromCode(String? code) => switch (code) {
        'en' => AppLanguage.english,
        'bn' => AppLanguage.bengali,
        _ => AppLanguage.system,
      };

  /// Stable code persisted in preferences.
  String get code => switch (this) {
        AppLanguage.system => 'system',
        AppLanguage.english => 'en',
        AppLanguage.bengali => 'bn',
      };

  /// Human readable label in [display], falling back to English.
  String label(AppLocalizations display) =>
      display.localeName == 'bn' ? bengaliLabel : englishLabel;
}
