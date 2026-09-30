// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_info.dart';
import 'core/l10n/l10n.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/armx_theme.dart';

/// Root widget: themes, localization delegates and the router.
///
/// Preferences are watched reactively, so changing the language or the theme in Settings
/// rebuilds the entire app without a restart.
class ArmxApp extends ConsumerWidget {
  /// Creates the app.
  const ArmxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final themeMode = ArmxTheme.themeModeFromName(preferences?.themeMode);
    final language = AppLanguage.fromCode(preferences?.language);

    return MaterialApp.router(
      title: AppInfo.productName,
      debugShowCheckedModeBanner: false,
      theme: ArmxTheme.light(),
      darkTheme: ArmxTheme.dark(),
      themeMode: themeMode,
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1,
        maxScaleFactor: 1.6,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
