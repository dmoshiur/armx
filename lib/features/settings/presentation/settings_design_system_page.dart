// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../core/widgets/armx_text_field.dart';

/// The design system, on screen, with its contrast ratios computed live.
///
/// This page is a test as much as a gallery: every foreground/background pair the theme
/// exposes is measured with [Contrast.ratio] at build time and labelled pass or fail. If a
/// token is ever changed to something that fails AA, this page says so in the app — not only
/// in the unit test — and the numbers shown are the real ones rather than documented ones.
class SettingsDesignSystemPage extends StatefulWidget {
  /// Creates the page.
  const SettingsDesignSystemPage({super.key});

  @override
  State<SettingsDesignSystemPage> createState() =>
      _SettingsDesignSystemPageState();
}

class _SettingsDesignSystemPageState extends State<SettingsDesignSystemPage> {
  final TextEditingController _sample = TextEditingController(text: 'A.R.M.X');

  @override
  void dispose() {
    _sample.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(context.l10n.settingsDesignSystem)),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.settingsDesignSystemBody,
            style: text.bodyMedium,
          ),
          const SizedBox(height: Insets.xl),

          // ---- Palette ------------------------------------------------------
          ArmxCard(
            title: context.l10n.settingsTheme,
            leading: const Icon(Icons.palette_outlined),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Chosen from the *available* width, not the window: this card sits inside a
                // constrained column on expanded layouts.
                final int columns = constraints.maxWidth < 420
                    ? 2
                    : constraints.maxWidth < 760
                        ? 3
                        : 4;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Insets.md,
                  crossAxisSpacing: Insets.md,
                  childAspectRatio: 1.6,
                  children: <Widget>[
                    _Swatch(
                      name: 'ink',
                      color: ArmxPalette.ink,
                      onColor: ArmxPalette.fog,
                    ),
                    _Swatch(
                      name: 'navy',
                      color: ArmxPalette.navy,
                      onColor: ArmxPalette.fog,
                    ),
                    _Swatch(
                      name: 'accent',
                      color: ArmxPalette.accent,
                      onColor: ArmxPalette.ink,
                    ),
                    _Swatch(
                      name: 'accent2',
                      color: ArmxPalette.accent2,
                      onColor: ArmxPalette.ink,
                    ),
                    _Swatch(
                      name: 'fog',
                      color: ArmxPalette.fog,
                      onColor: ArmxPalette.ink,
                    ),
                    _Swatch(
                      name: 'line',
                      color: ArmxPalette.line,
                      onColor: ArmxPalette.ink,
                    ),
                    _Swatch(
                      name: 'muted',
                      color: ArmxPalette.muted,
                      onColor: ArmxPalette.fog,
                    ),
                    _Swatch(
                      name: 'danger',
                      color: ArmxPalette.danger,
                      onColor: ArmxPalette.onDangerStrong,
                    ),
                    _Swatch(
                      name: 'success',
                      color: ArmxPalette.success,
                      onColor: ArmxPalette.ink,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Contrast -----------------------------------------------------
          ArmxCard(
            title: context.l10n.settingsContrastRatio,
            leading: const Icon(Icons.contrast_rounded),
            child: Column(
              children: <Widget>[
                _ContrastRow(label: 'text / background', foreground: colors.text, background: colors.background),
                _ContrastRow(label: 'text / surface', foreground: colors.text, background: colors.surface),
                _ContrastRow(
                  label: 'muted / background',
                  foreground: colors.textMuted,
                  background: colors.background,
                ),
                _ContrastRow(
                  label: 'accentText / surface',
                  foreground: colors.accentText,
                  background: colors.surface,
                ),
                _ContrastRow(
                  label: 'accent2Text / surface',
                  foreground: colors.accent2Text,
                  background: colors.surface,
                ),
                _ContrastRow(
                  label: 'successText / surface',
                  foreground: colors.successText,
                  background: colors.surface,
                ),
                _ContrastRow(
                  label: 'warningText / surface',
                  foreground: colors.warningText,
                  background: colors.surface,
                ),
                _ContrastRow(
                  label: 'dangerText / surface',
                  foreground: colors.dangerText,
                  background: colors.surface,
                ),
                _ContrastRow(
                  label: 'onDangerFill / dangerFill',
                  foreground: colors.onDangerFill,
                  background: colors.dangerFill,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Type scale ---------------------------------------------------
          ArmxCard(
            title: context.l10n.settingsDesignSystem,
            leading: const Icon(Icons.text_fields_rounded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Specimen(label: 'Display 32/40', style: text.displaySmall),
                _Specimen(label: 'H1 24/30', style: text.headlineSmall),
                _Specimen(label: 'H2 18/24', style: text.titleLarge),
                _Specimen(label: 'H3 14/20', style: text.titleSmall),
                _Specimen(label: 'Body 14/21', style: text.bodyMedium),
                _Specimen(label: 'Caption 12/16', style: text.bodySmall),
                const SizedBox(height: Insets.md),
                Text(
                  'Latin and Bengali: A.R.M.X AI · এ.আর.এম.এক্স এআই',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),

          // ---- Components ---------------------------------------------------
          ArmxCard(
            title: context.l10n.homeQuickActions,
            leading: const Icon(Icons.widgets_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveWrap(
                  children: <Widget>[
                    ArmxButton(
                      label: 'Primary',
                      onPressed: () {},
                      icon: Icons.check_rounded,
                    ),
                    ArmxButton(
                      label: 'Secondary',
                      variant: ArmxButtonVariant.secondary,
                      onPressed: () {},
                    ),
                    ArmxButton(
                      label: 'Destructive',
                      variant: ArmxButtonVariant.destructive,
                      onPressed: () {},
                    ),
                    ArmxButton(
                      label: 'Ghost',
                      variant: ArmxButtonVariant.ghost,
                      onPressed: () {},
                    ),
                    ArmxButton(
                      label: 'Loading',
                      loading: true,
                      onPressed: () {},
                    ),
                    const ArmxButton(label: 'Disabled', onPressed: null),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                AdaptiveWrap(
                  children: <Widget>[
                    ArmxStatusPill(status: ArmxStatus.online, label: 'online'),
                    ArmxStatusPill(status: ArmxStatus.pending, label: 'pending', pulse: true),
                    ArmxStatusPill(status: ArmxStatus.warning, label: 'warning'),
                    ArmxStatusPill(status: ArmxStatus.failed, label: 'failed'),
                    ArmxStatusPill(status: ArmxStatus.stopped, label: 'stopped'),
                    ArmxStatusPill(status: ArmxStatus.unknown, label: 'unknown'),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                AdaptiveWrap(
                  children: <Widget>[
                    for (final ArmxBadgeTone tone in ArmxBadgeTone.values)
                      ArmxBadge(label: tone.name, tone: tone),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                ArmxTextField(
                  label: 'ArmxTextField',
                  hint: 'label · helper · error',
                  helper: 'Helper text',
                  controller: _sample,
                  maxLength: 24,
                ),
                const SizedBox(height: Insets.md),
                const ArmxSwitchRow(
                  title: 'ArmxSwitchRow',
                  subtitle: 'Enabled and disabled variants',
                  value: true,
                  onChanged: null,
                ),
                const SizedBox(height: Insets.md),
                const ArmxEmptyHint(
                  icon: Icons.info_outline_rounded,
                  message: 'ArmxEmptyHint',
                ),
                const SizedBox(height: Insets.md),
                ArmxNotice(
                  tone: ArmxBadgeToneLike.warning,
                  title: 'ArmxNotice',
                  message: 'Title, body and optional action in one callout.',
                ),
                const SizedBox(height: Insets.md),
                const ArmxDetailRow(
                  label: 'ArmxDetailRow',
                  value: 'monospace',
                  monospace: true,
                ),
                const SizedBox(height: Insets.md),
                const Divider(),
                const SizedBox(height: Insets.md),
                const ArmxSkeletonCard(lines: 3),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color, required this.onColor});

  final String name;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Insets.controlRadius),
        border: Border.all(color: ArmxPalette.line.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              name,
              style: ArmxTypography.mono(size: 12, color: onColor),
            ),
            Text(
              '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: ArmxTypography.mono(size: 11, color: onColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContrastRow extends StatelessWidget {
  const _ContrastRow({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final double ratio = Contrast.ratio(foreground, background);
    final bool passes = ratio >= 4.5;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          ArmxBadge(
            label: '${ratio.toStringAsFixed(2)}:1',
            tone: passes ? ArmxBadgeTone.success : ArmxBadgeTone.danger,
            icon: passes ? Icons.check_rounded : Icons.priority_high_rounded,
          ),
          const SizedBox(width: Insets.sm),
          // The verdict is a word as well as a badge, so it reads without colour.
          SizedBox(
            width: 44,
            child: Text(
              passes
                  ? context.l10n.settingsContrastPass
                  : context.l10n.settingsContrastFail,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Specimen extends StatelessWidget {
  const _Specimen({required this.label, required this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text('The quick brown fox · দ্রুত বাদামী শিয়াল', style: style),
          ),
        ],
      ),
    );
  }
}
