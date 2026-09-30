// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_theme.dart';
import 'state_views.dart';

/// Visual variants of [ArmxButton].
enum ArmxButtonVariant {
  /// Solid cyan CTA.
  filled,

  /// Outlined, low emphasis.
  outlined,

  /// Text only.
  ghost,

  /// Danger action (deny, revoke, delete).
  danger,
}

/// The app's button: 48 dp minimum height, optional spinner, explicit semantics.
class ArmxButton extends StatelessWidget {
  /// Creates a button.
  const ArmxButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ArmxButtonVariant.filled,
    this.loading = false,
    this.expanded = false,
    this.tooltip,
    super.key,
  });

  /// Button label (already localized).
  final String label;

  /// Tap handler; `null` disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Visual variant.
  final ArmxButtonVariant variant;

  /// Shows a spinner and disables interaction.
  final bool loading;

  /// Stretches the button to the available width.
  final bool expanded;

  /// Optional tooltip; also used as the semantics hint.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final isDark = colors.isDark;
    final accent = switch (variant) {
      ArmxButtonVariant.filled => colors.cyan,
      ArmxButtonVariant.danger => colors.red,
      ArmxButtonVariant.outlined || ArmxButtonVariant.ghost => colors.text,
    };
    final onAccent = isDark ? ArmxPalette.darkBackground : Colors.white;
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == ArmxButtonVariant.filled || variant == ArmxButtonVariant.danger
                    ? onAccent
                    : colors.cyan,
              ),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: variant == ArmxButtonVariant.filled || variant == ArmxButtonVariant.danger
                      ? onAccent
                      : accent,
                ),
          ),
        ),
      ],
    );

    final button = switch (variant) {
      ArmxButtonVariant.filled || ArmxButtonVariant.danger => FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            minimumSize: const Size(64, ArmxTheme.minimumTouchTarget),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: variant == ArmxButtonVariant.filled ? 2 : 0,
            shadowColor: accent.withValues(alpha: 0.4),
          ),
          child: child,
        ),
      ArmxButtonVariant.outlined => OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(64, ArmxTheme.minimumTouchTarget),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: child,
        ),
      ArmxButtonVariant.ghost => TextButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
    };

    final wrapped = expanded
        ? SizedBox(width: double.infinity, child: button)
        : MinTouchTarget(child: button);

    return tooltip == null ? wrapped : Tooltip(message: tooltip!, child: wrapped);
  }
}
