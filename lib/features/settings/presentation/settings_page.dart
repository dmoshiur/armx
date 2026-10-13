// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/presentation/widgets/kill_switch_button.dart';

/// The settings hub.
///
/// Six destinations, each its own screen, because a settings page that scrolls for a screen
/// and a half is a settings page nobody reads. The two controls worth having on the hub
/// itself are here: theme mode and language — they are the ones people change often, and
/// making them a two-tap trip is a small cruelty.
class SettingsPage extends ConsumerWidget {
  /// Creates the page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences prefs = ref.watch(preferencesProvider);
    final AuthState auth = ref.watch(authControllerProvider);
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(context.l10n.navSettings)),
      body: PageBody(
        maxWidth: 900,
        children: <Widget>[
          ArmxCard(
            title: auth.user?.displayName ?? context.l10n.settingsAccountTitle,
            leading: const Icon(Icons.person_outline_rounded),
            trailing: ArmxBadge(
              label: switch (auth.role) {
                UserRole.admin => context.l10n.roleAdmin,
                UserRole.vip => context.l10n.roleVip,
                UserRole.user => context.l10n.roleUser,
              },
              tone: ArmxBadge.toneForRole(auth.role.name),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (auth.user != null) ...<Widget>[
                  SelectableText(
                    auth.user!.email,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: Insets.sm),
                ],
                // An unverified address is stated here too: the router holds the account on
                // the verification screen, but a user who signed in before verification
                // existed still needs to see why some things are unavailable.
                if (auth.user != null && !auth.user!.emailVerified)
                  ArmxNotice(
                    tone: ArmxBadgeToneLike.warning,
                    message: context.l10n.homeUnverifiedBanner,
                  ),
                if (auth.user != null && !auth.user!.emailVerified)
                  const SizedBox(height: Insets.md),
                ArmxButton(
                  label: context.l10n.shellLogout,
                  variant: ArmxButtonVariant.secondary,
                  icon: Icons.logout_rounded,
                  onPressed: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          _ThemeCard(prefs: prefs),
          const SizedBox(height: Insets.lg),
          _LanguageCard(prefs: prefs),
          const SizedBox(height: Insets.xl),
          ArmxSection(
            title: context.l10n.navSettings,
            child: Column(
              children: <Widget>[
                _SettingsLink(
                  icon: Icons.tune_rounded,
                  title: context.l10n.settingsPreferencesTitle,
                  subtitle: context.l10n.settingsNotificationsBody,
                  route: Routes.settingsPreferences,
                ),
                _SettingsLink(
                  icon: Icons.verified_user_outlined,
                  title: context.l10n.settingsPermissionsTitle,
                  subtitle: context.l10n.settingsPermissionsBody,
                  route: Routes.settingsPermissions,
                ),
                _SettingsLink(
                  icon: Icons.devices_other_rounded,
                  title: context.l10n.settingsAccountTitle,
                  subtitle: context.l10n.settingsAccountBody,
                  route: Routes.settingsAccount,
                ),
                _SettingsLink(
                  icon: Icons.palette_outlined,
                  title: context.l10n.settingsDesignSystemBody,
                  subtitle: context.l10n.settingsContrastRatio('4.5'),
                  route: Routes.settingsDesignSystem,
                ),
                _SettingsLink(
                  icon: Icons.monitor_heart_outlined,
                  title: context.l10n.settingsDiagnosticsConfig,
                  subtitle: context.l10n.settingsDiagnosticsBody,
                  route: Routes.settingsDiagnostics,
                ),
                _SettingsLink(
                  icon: Icons.info_outline_rounded,
                  title: context.l10n.settingsAboutTagline,
                  subtitle: context.l10n.settingsAboutBody,
                  route: Routes.settingsAbout,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          ArmxCard(
            title: context.l10n.adminKillSwitchTitle,
            leading: const Icon(Icons.power_settings_new_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.adminKillSwitchBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.md),
                // The kill-switch is reachable from settings as well as from the shell, so
                // a user who cannot find the hold-gesture is not stuck.
                const KillSwitchButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.shellLogoutConfirmTitle,
        action: 'logout',
        target: ref.read(authControllerProvider).user?.email ?? '—',
        consequence: context.l10n.settingsSessionsEmpty,
        confirmLabel: context.l10n.shellLogout,
      ),
    );
    if (!confirmed) {
      return;
    }
    await ref.read(authControllerProvider.notifier).signOut();
  }
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({required this.prefs});

  final AppPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ArmxCard(
      title: context.l10n.settingsTheme,
      leading: const Icon(Icons.brightness_6_outlined),
      child: AdaptiveWrap(
        children: <Widget>[
          ArmxChip(
            label: context.l10n.settingsThemeDark,
            selected: prefs.themeMode == ThemeMode.dark,
            icon: Icons.dark_mode_outlined,
            onSelected: (_) =>
                ref.read(preferencesProvider.notifier).setThemeMode(ThemeMode.dark),
          ),
          ArmxChip(
            label: context.l10n.settingsThemeLight,
            selected: prefs.themeMode == ThemeMode.light,
            icon: Icons.light_mode_outlined,
            onSelected: (_) =>
                ref.read(preferencesProvider.notifier).setThemeMode(ThemeMode.light),
          ),
          ArmxChip(
            label: context.l10n.settingsThemeSystem,
            selected: prefs.themeMode == ThemeMode.system,
            icon: Icons.brightness_auto_outlined,
            onSelected: (_) =>
                ref.read(preferencesProvider.notifier).setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard({required this.prefs});

  final AppPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ArmxCard(
      title: context.l10n.settingsLanguage,
      leading: const Icon(Icons.translate_rounded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdaptiveWrap(
            children: <Widget>[
              ArmxChip(
                label: context.l10n.settingsLanguageEnglish,
                selected: prefs.localeCode == 'en',
                onSelected: (_) =>
                    ref.read(preferencesProvider.notifier).setLocale('en'),
              ),
              ArmxChip(
                label: context.l10n.settingsLanguageBengali,
                selected: prefs.localeCode == 'bn',
                onSelected: (_) =>
                    ref.read(preferencesProvider.notifier).setLocale('bn'),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          // Says plainly that either language is complete, because that is a promise the
          // translation coverage makes and users reasonably doubt.
          Text(
            context.l10n.settingsLanguageParity,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: ArmxCard(
        dense: true,
        leading: Icon(icon, color: ArmxColors.of(context).accentText),
        title: title,
        trailing: const Icon(Icons.chevron_right_rounded),
        semanticLabel: '$title. $subtitle',
        onTap: () => context.go(route),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
