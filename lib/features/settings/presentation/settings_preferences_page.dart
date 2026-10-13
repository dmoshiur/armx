// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/preferences/preferences_store.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_text_field.dart';

/// Language, theme and notification preferences.
///
/// Everything on this page is stored on the device and applies at once, so there is nothing
/// to save and nothing to confirm. The one honest exception is notifications: whether the
/// platform will actually deliver them is not something the app can promise from a switch,
/// so the platform state is read and shown beside the preference instead of being assumed.
class SettingsPreferencesPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences prefs = ref.watch(preferencesProvider);
    final PreferencesController controller = ref.read(preferencesProvider.notifier);

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(title: Text(context.l10n.settingsPreferencesTitle)),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.settingsPreferencesBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.xl),

          // ---- Language ------------------------------------------------------
          ArmxCard(
            title: context.l10n.settingsLanguage,
            leading: const Icon(Icons.translate_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: <Widget>[
                    for (final String code in const <String>['en', 'bn'])
                      ArmxChip(
                        label: ArmxL10n.languageName(code, context.l10n),
                        selected: prefs.localeCode == code,
                        icon: prefs.localeCode == code
                            ? Icons.check_rounded
                            : Icons.language_rounded,
                        onSelected: (_) => controller.setLocale(code),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.md),
                // Stated plainly rather than hidden: both bundles carry every key, and a
                // Bengali reader should not have to discover that by trying.
                Text(
                  context.l10n.settingsLanguageParity,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Theme ---------------------------------------------------------
          ArmxCard(
            title: context.l10n.settingsTheme,
            leading: const Icon(Icons.contrast_rounded),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                ArmxChip(
                  label: context.l10n.settingsThemeDark,
                  selected: prefs.themeMode == ThemeMode.dark,
                  icon: Icons.dark_mode_outlined,
                  onSelected: (_) => controller.setThemeMode(ThemeMode.dark),
                ),
                ArmxChip(
                  label: context.l10n.settingsThemeLight,
                  selected: prefs.themeMode == ThemeMode.light,
                  icon: Icons.light_mode_outlined,
                  onSelected: (_) => controller.setThemeMode(ThemeMode.light),
                ),
                ArmxChip(
                  label: context.l10n.settingsThemeSystem,
                  selected: prefs.themeMode == ThemeMode.system,
                  icon: Icons.brightness_auto_outlined,
                  onSelected: (_) => controller.setThemeMode(ThemeMode.system),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Notifications -------------------------------------------------
          ArmxCard(
            title: context.l10n.settingsNotifications,
            leading: const Icon(Icons.notifications_none_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.l10n.settingsNotificationsBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.md),
                ArmxSwitchRow(
                  title: context.l10n.settingsNotifyAlarms,
                  value: prefs.notifyAlarms,
                  icon: Icons.alarm_rounded,
                  onChanged: (bool value) =>
                      controller.setNotification(alarms: value),
                ),
                ArmxSwitchRow(
                  title: context.l10n.settingsNotifyTools,
                  value: prefs.notifyToolCalls,
                  icon: Icons.build_outlined,
                  onChanged: (bool value) =>
                      controller.setNotification(toolCalls: value),
                ),
                ArmxSwitchRow(
                  title: context.l10n.settingsNotifyDeploys,
                  value: prefs.notifyDeployments,
                  icon: Icons.rocket_launch_outlined,
                  onChanged: (bool value) =>
                      controller.setNotification(deployments: value),
                ),
                const SizedBox(height: Insets.sm),
                // The distinction that matters: these switches describe what the app will
                // try to send, not a promise that the OS will deliver it.
                ArmxNotice(
                  tone: ArmxBadgeToneLike.info,
                  message: context.l10n.settingsNotificationsUnavailable,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Layout --------------------------------------------------------
          ArmxCard(
            title: context.l10n.settingsTitle,
            leading: const Icon(Icons.view_sidebar_outlined),
            child: ArmxSwitchRow(
              title: context.l10n.shellRailCollapse,
              value: prefs.railCollapsed,
              icon: Icons.vertical_split_outlined,
              onChanged: (bool value) =>
                  controller.setRailCollapsed(collapsed: value),
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}
