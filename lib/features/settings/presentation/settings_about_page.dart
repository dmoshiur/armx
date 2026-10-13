// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/breakpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_brand.dart';
import '../../../core/widgets/armx_card.dart';

/// Who made this, what version it is, and under what licence it ships.
///
/// The licence section is not a link to a web page: the project is proprietary, and this
/// page states the ownership in the app itself, in both languages, next to the version the
/// build was cut from.
class SettingsAboutPage extends StatelessWidget {
  /// Creates the page.
  const SettingsAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(context.l10n.settingsAbout)),
      body: PageBody(
        children: <Widget>[
          ArmxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const ArmxOrb(size: 72),
                const SizedBox(height: Insets.md),
                const ArmxWordmark(),
                const SizedBox(height: Insets.sm),
                Text(
                  context.l10n.settingsAboutTagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.md),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    ArmxBadge(
                      label: '${context.l10n.settingsVersion} '
                          '${AppConfig.appVersion}',
                      tone: ArmxBadgeTone.accent,
                      icon: Icons.info_outline_rounded,
                    ),
                    ArmxBadge(
                      label: AppConfig.buildLabel,
                      tone: ArmxBadgeTone.neutral,
                      icon: Icons.tag_rounded,
                    ),
                    if (AppConfig.useMockBackend)
                      ArmxBadge(
                        label: context.l10n.commonSimulated,
                        tone: ArmxBadgeTone.warning,
                        icon: Icons.science_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          ArmxCard(
            title: context.l10n.settingsOwner,
            leading: const Icon(Icons.person_outline_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ArmxDetailRow(
                  label: 'owner',
                  value: AppConfig.owner,
                  icon: Icons.badge_outlined,
                ),
                const ArmxDetailRow(
                  label: 'brand',
                  value: AppConfig.brand,
                  monospace: true,
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  context.l10n.settingsAboutBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          ArmxCard(
            title: context.l10n.settingsLicences,
            leading: const Icon(Icons.gavel_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ArmxNotice(
                  tone: ArmxBadgeToneLike.info,
                  message: context.l10n.settingsLicencesBody,
                ),
                const SizedBox(height: Insets.md),
                Text(
                  context.l10n.settingsProprietary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Insets.md),
                // The third-party notices Flutter itself ships.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => showAboutDialog(
                      context: context,
                      applicationName: AppConfig.appName,
                      applicationVersion: AppConfig.appVersion,
                      applicationLegalese: context.l10n.settingsProprietary,
                    ),
                    child: Text(MaterialLocalizations.of(context).showLicensesButtonLabel),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}
