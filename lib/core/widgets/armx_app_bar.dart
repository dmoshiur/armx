// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';

/// Standard app bar with an optional wordmark title and a slot for the kill-switch.
class ArmxAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates an app bar.
  const ArmxAppBar({
    this.title,
    this.useWordmark = false,
    this.actions,
    this.leading,
    this.subtitle,
    this.bottom,
    this.automaticallyImplyLeading = true,
    super.key,
  });

  /// Plain-text title (ignored when [useWordmark] is true).
  final String? title;

  /// Renders the `A.R.M.X AI` wordmark instead of a text title.
  final bool useWordmark;

  /// Right-hand actions (kill-switch lives here from step 6 onwards).
  final List<Widget>? actions;

  /// Leading widget.
  final Widget? leading;

  /// Small line under the title.
  final String? subtitle;

  /// Optional bottom widget.
  final PreferredSizeWidget? bottom;

  /// Whether Flutter should add a back button.
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (subtitle == null ? 0 : 18) + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return AppBar(
      backgroundColor: colors.background.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      actions: actions,
      title: useWordmark
          ? const ArmxWordmark(fontSize: 22)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colors.muted),
                  ),
              ],
            ),
      bottom: bottom,
    );
  }
}
