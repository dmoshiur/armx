// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/colors.dart';
import 'armx_button.dart';
import 'armx_card.dart';

/// Shown when a request **succeeded** and there is genuinely nothing to display.
///
/// The distinction from [ArmxErrorState] is the whole point: "you have no alarms yet" is a
/// different situation from "we could not load your alarms", and the two must never share
/// a rendering. This widget is only ever reached on success, so it never implies failure.
class ArmxEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const ArmxEmptyState({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    super.key,
  });

  /// Headline, e.g. "No alarms yet".
  final String title;

  /// Explanation of what will appear here and how to make it appear.
  final String? message;

  /// Glyph above the headline.
  final IconData icon;

  /// Optional call to action.
  final String? actionLabel;

  /// Invoked by the primary action.
  final VoidCallback? onAction;

  /// Optional second action.
  final String? secondaryActionLabel;

  /// Invoked by the secondary action.
  final VoidCallback? onSecondaryAction;

  /// A smaller icon and tighter spacing, for an empty state nested inside a card or a
  /// half-width pane. The wording is unchanged: a small box still has to say what is
  /// missing and how to fill it.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Semantics(
      container: true,
      label: message == null ? title : '$title. $message',
      child: ArmxStateFrame(
        icon: icon,
        iconColor: colors.textMuted,
        iconSize: compact ? 28 : null,
        title: title,
        body: message,
        action: actionLabel == null || onAction == null
            ? null
            : ArmxButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: ArmxButtonVariant.secondary,
              ),
        secondaryAction: secondaryActionLabel == null || onSecondaryAction == null
            ? null
            : ArmxButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryAction,
                variant: ArmxButtonVariant.ghost,
                size: ArmxButtonSize.small,
              ),
      ),
    );
  }
}

/// A compact, inline empty state for a single card rather than a whole page.
///
/// Used inside the guest-greeter enrollment list and the linked-device audit table where a
/// full-page state would waste the layout.
class ArmxEmptyHint extends StatelessWidget {
  /// Creates an inline hint.
  const ArmxEmptyHint({
    required this.message,
    this.icon = Icons.info_outline_rounded,
    super.key,
  });

  /// The hint text.
  final String message;

  /// Leading glyph.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: colors.textMuted),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// A banner for a page-level condition that is not an error: offline, read-only, a
/// permission the user has not granted yet.
///
/// Never dismissible by accident — the caller decides whether the condition can be
/// dismissed, because "you are offline" must not vanish while the user is still offline.
class ArmxNotice extends StatelessWidget {
  /// Creates a notice.
  const ArmxNotice({
    required this.message,
    this.title,
    this.tone = ArmxBadgeToneLike.info,
    this.icon,
    this.action,
    super.key,
  });

  /// Body text.
  final String message;

  /// Optional bold lead-in.
  final String? title;

  /// Colour intent.
  final ArmxBadgeToneLike tone;

  /// Optional glyph override.
  final IconData? icon;

  /// Optional trailing action (for example "Grant permission").
  final Widget? action;

  /// Resolves the tone colour.
  static Color toneColor(ArmxBadgeToneLike tone, ArmxColors colors) =>
      switch (tone) {
        ArmxBadgeToneLike.info => colors.accentText,
        ArmxBadgeToneLike.success => colors.successText,
        ArmxBadgeToneLike.warning => colors.warningText,
        ArmxBadgeToneLike.danger => colors.dangerText,
      };

  /// Resolves the tone glyph.
  static IconData toneIcon(ArmxBadgeToneLike tone) => switch (tone) {
        ArmxBadgeToneLike.info => Icons.info_outline_rounded,
        ArmxBadgeToneLike.success => Icons.check_circle_outline_rounded,
        ArmxBadgeToneLike.warning => Icons.warning_amber_rounded,
        ArmxBadgeToneLike.danger => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final Color color = toneColor(tone, colors);
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon ?? toneIcon(tone), size: 18, color: color),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (title != null)
                    Text(
                      title!,
                      style: text.titleSmall?.copyWith(color: color),
                    ),
                  Text(
                    message,
                    style: text.bodySmall?.copyWith(color: colors.text),
                  ),
                ],
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(width: Insets.sm),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// The four tones a notice can take.
enum ArmxBadgeToneLike {
  /// Informational.
  info,

  /// Something succeeded.
  success,

  /// Something needs attention but is not broken.
  warning,

  /// Something failed or was blocked.
  danger,
}

/// A standardized "read-only because the backend is unavailable" notice (§6 smart home:
/// "manual fallback note if the backend/integration is offline").
class ArmxOfflineFallbackNote extends StatelessWidget {
  /// Creates the note.
  const ArmxOfflineFallbackNote({this.onRetry, super.key});

  /// Optional retry action.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ArmxNotice(
      tone: ArmxBadgeToneLike.warning,
      message: context.l10n.errorBackendUnavailable,
      action: onRetry == null
          ? null
          : ArmxButton(
              label: context.l10n.commonRetry,
              onPressed: onRetry,
              variant: ArmxButtonVariant.ghost,
              size: ArmxButtonSize.small,
            ),
    );
  }
}
