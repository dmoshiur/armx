// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// Ergonomic access to the generated localization bindings.
///
/// Every user-facing string in the app is reached through `context.l10n.<key>`. There are
/// no hard-coded English literals in `lib/features/**`: EN and BN ship side by side and
/// the app is fully usable with the Bengali set alone.
extension ArmxL10n on BuildContext {
  /// The [AppLocalizations] for the active locale.
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// The active locale's language code (`en` or `bn`).
  String get languageCode => Localizations.localeOf(this).languageCode;

  /// True when the UI is being read in Bengali.
  bool get isBengali => languageCode == 'bn';

  /// Localized name of a language for the settings picker, without a [BuildContext].
  static String languageName(String code, AppLocalizations l10n) => switch (code) {
        'bn' => l10n.settingsLanguageBengali,
        _ => l10n.settingsLanguageEnglish,
      };
}
