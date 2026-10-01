// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// Localized labels for the tray menu.
///
/// A native menu bar cannot read a `BuildContext`, so the app resolves the labels once at
/// startup (from the stored language preference) and hands the map to the desktop
/// controller. English is the fallback whenever resolution has not happened yet.
abstract final class DesktopMenuLabels {
  /// Loads the labels for [locale] (or English when the locale is unsupported).
  static Future<Map<String, String>> forLocale(Locale? locale) async {
    final delegate = AppLocalizations.delegate;
    final target = _supported(locale) ?? const Locale('en');
    final l10n = await delegate.load(target);
    return <String, String>{
      'open': l10n.desktopMenuOpen,
      'talk': l10n.desktopMenuTalk,
      'pause15': l10n.desktopMenuPause15,
      'pause60': l10n.desktopMenuPause60,
      'pause240': l10n.desktopMenuPause240,
      'resume': l10n.desktopMenuResume,
      'status': l10n.desktopMenuStatus,
      'kill': l10n.desktopMenuKill,
      'settings': l10n.desktopMenuSettings,
      'quit': l10n.desktopMenuQuit,
      'engaged': l10n.desktopTrayKilled,
    };
  }

  static Locale? _supported(Locale? locale) {
    if (locale == null) {
      return null;
    }
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }
    return null;
  }
}
