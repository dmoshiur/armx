// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_theme.dart';
import 'glass_panel.dart';

/// Rounded icon + text tile used by settings rows and quick actions.
class ArmxTile extends StatelessWidget {
  /// Creates a tile.
  const ArmxTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.accent,
    super.key,
  });

  /// Primary line.
  final String title;

  /// Secondary line.
  final String? subtitle;

  /// Leading widget (usually an [Icon]).
  final Widget? leading;

  /// Trailing widget (switch, chevron, badge).
  final Widget? trailing;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Optional accent colour for the leading icon.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return GlassPanel(
      onTap: onTap,
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            IconTheme(
              data: IconThemeData(color: accent ?? colors.cyan, size: 20),
              child: leading!,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 10),
            trailing!,
          ] else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: colors.muted),
        ],
      ),
    );
  }
}

/// Applies the theme's minimum touch target to any child.
class MinTouchTarget extends StatelessWidget {
  /// Creates a minimum-size wrapper.
  const MinTouchTarget({required this.child, super.key});

  /// Child widget.
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: ArmxTheme.minimumTouchTarget,
          minHeight: ArmxTheme.minimumTouchTarget,
        ),
        child: child,
      );
}
