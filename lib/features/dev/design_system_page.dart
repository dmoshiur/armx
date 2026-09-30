// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../core/config/app_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/security/risk_tier.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/theme/armx_typography.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/armx_orb.dart';
import '../../core/widgets/risk_tier_chip.dart';
import '../../core/widgets/sanitized_markdown.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';

/// Design-system gallery: the fastest way to eyeball every token and signature widget.
///
/// Kept in the app (behind the Settings route, not in the primary navigation) because it is
/// also the manual QA checklist for dark/light contrast, reduced motion and touch targets.
class DesignSystemPage extends StatelessWidget {
  /// Creates the gallery.
  const DesignSystemPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: ArmxAppBar(title: l10n.designSystemTitle),
      body: ArmxBackground(
        showGrid: true,
        child: ArmxPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionHeader(title: 'Palette', subtitle: colors.isDark ? 'dark' : 'light'),
              GlassPanel(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final entry in <String, Color>{
                      'background': colors.background,
                      'panel': colors.panel,
                      'panel2': colors.panel2,
                      'cyan': colors.cyan,
                      'violet': colors.violet,
                      'text': colors.text,
                      'muted': colors.muted,
                      'border': colors.border,
                      'amber': colors.amber,
                      'green': colors.green,
                      'red': colors.red,
                    }.entries)
                      _Swatch(name: entry.key, color: entry.value),
                  ],
                ),
              ),
              SectionHeader(title: 'Assistant orb'),
              GlassPanel(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 16,
                  children: <Widget>[
                    for (final state in ArmxOrbState.values)
                      ArmxOrb(state: state, size: 84),
                  ],
                ),
              ),
              SectionHeader(title: 'Risk tiers'),
              GlassPanel(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    for (final tier in RiskTier.values)
                      RiskTierChip(tier: tier, showRequirements: true),
                  ],
                ),
              ),
              SectionHeader(title: 'Status pills'),
              GlassPanel(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    StatusPill(label: l10n.commonOnline, tone: SeverityTone.success),
                    StatusPill(label: l10n.commonOffline, tone: SeverityTone.danger),
                    StatusPill(label: l10n.statusReconnecting, tone: SeverityTone.warning),
                    StatusPill(label: l10n.shellMockBackend, tone: SeverityTone.info),
                    StatusPill(label: l10n.statusLocked, tone: SeverityTone.accent),
                  ],
                ),
              ),
              SectionHeader(title: 'Buttons'),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ArmxGlowButton(
                      label: 'Primary glow button',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    ArmxButton(
                      label: 'Outlined',
                      icon: Icons.tune_rounded,
                      variant: ArmxButtonVariant.outlined,
                      expanded: true,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    ArmxButton(
                      label: 'Danger',
                      icon: Icons.gpp_maybe_rounded,
                      variant: ArmxButtonVariant.danger,
                      expanded: true,
                      onPressed: () {},
                    ),
                    const SizedBox(height: 12),
                    ArmxButton(
                      label: 'Loading…',
                      loading: true,
                      expanded: true,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              SectionHeader(title: 'Typography'),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Display 44 / Inter 700', style: Theme.of(context).textTheme.displayLarge),
                    const SizedBox(height: 6),
                    Text('Headline 24 / Inter 600', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Body 16', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 6),
                    Text(
                      'JetBrains Mono 13.5 — audit, logs, keys',
                      style: ArmxTypography.mono(color: colors.cyan),
                    ),
                  ],
                ),
              ),
              SectionHeader(
                title: 'Untrusted text rendering',
                subtitle: 'links are inert, HTML is never interpreted',
              ),
              GlassPanel(
                child: const SanitizedMarkdown(
                  text: '## Reply from the assistant\n'
                      'This is **bold**, this is *italic*, this is `code`.\n'
                      '- first bullet\n'
                      '- [tap me](https://evil.example) shows the URL as plain text\n'
                      '> quoted instruction\n'
                      '```\n'
                      'mqtt: armx/home/dev-gate/cmd\n'
                      '```',
                ),
              ),
              SectionHeader(title: 'States'),
              const GlassPanel(child: LoadingView(compact: true)),
              EmptyView(title: l10n.commonEmpty, message: l10n.placeholderStepBody),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppInfo.credit,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
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

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 64,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: Theme.of(context).textTheme.labelSmall),
        Text(
          '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9.5),
        ),
      ],
    );
  }
}
