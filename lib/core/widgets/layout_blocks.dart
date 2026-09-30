// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';

/// A themed "section" heading used above lists and grouped settings.
class SectionHeader extends StatelessWidget {
  /// Creates a section header.
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// Section title.
  final String title;

  /// Optional supporting line.
  final String? subtitle;

  /// Optional trailing widget (for example a "See all" button).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
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
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Convenience wrapper that applies the standard page padding and max content width.
class ArmxPageBody extends StatelessWidget {
  /// Creates a page body.
  const ArmxPageBody({required this.child, this.scrollable = true, super.key});

  /// Page content.
  final Widget child;

  /// Whether to wrap the content in a scroll view.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = EdgeInsets.symmetric(horizontal: media.size.width < 600 ? 16 : 28);
    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: body,
          )
        : body;
  }
}
