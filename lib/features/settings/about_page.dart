// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/armx_wordmark.dart';
import '../../core/widgets/state_views.dart';

/// About page: identity, ownership, the mandatory credit line and the licence viewer.
class AboutPage extends StatelessWidget {
  /// Creates the About page.
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: ArmxAppBar(title: l10n.aboutTitle),
      body: ArmxBackground(
        child: ArmxPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: <Widget>[
                    const ArmxWordmark(fontSize: 36),
                    const SizedBox(height: 6),
                    Text(
                      l10n.appTagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.aboutVersion(AppInfo.versionLabel),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colors.cyan, fontFamily: 'JetBrainsMono'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.aboutTitle),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _LabelledRow(label: l10n.aboutOwner, value: AppInfo.owner),
                    const Divider(height: 20),
                    _LabelledRow(label: l10n.aboutBrand, value: AppInfo.brand),
                    const Divider(height: 20),
                    _LabelledRow(
                      label: 'Application id',
                      value: AppInfo.applicationId,
                      mono: true,
                    ),
                    const Divider(height: 20),
                    _LabelledRow(
                      label: 'Product',
                      value: '${AppInfo.productName} — ${AppInfo.productLongName}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassPanel(
                accent: colors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.privacy_tip_outlined, size: 18, color: colors.cyan),
                        const SizedBox(width: 8),
                        Text(
                          l10n.aboutPrivacy,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Face templates and voice prints are processed on-device, stored '
                      'encrypted, and never sent to any server. Only a signed, '
                      'single-use owner-verified token (60 s, scoped) may leave the device '
                      'when you approve a HIGH risk action.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ArmxButton(
                label: l10n.aboutLicenses,
                icon: Icons.article_outlined,
                variant: ArmxButtonVariant.outlined,
                expanded: true,
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: AppInfo.productName,
                  applicationVersion: AppInfo.versionLabel,
                  applicationLegalese: AppInfo.credit,
                ),
              ),
              const SizedBox(height: 10),
              ArmxButton(
                label: l10n.aboutDiagnostics,
                icon: Icons.monitor_heart_outlined,
                variant: ArmxButtonVariant.ghost,
                expanded: true,
                onPressed: () => context.push(AppRoutes.diagnostics),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  AppInfo.credit,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colors.muted),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  AppInfo.copyrightHeader,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colors.muted, fontSize: 10),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelledRow extends StatelessWidget {
  const _LabelledRow({required this.label, required this.value, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: mono
                ? Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontFamily: 'JetBrainsMono', color: colors.text)
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
