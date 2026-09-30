// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/state_views.dart';

/// Honest placeholder for a screen scheduled for a later delivery step.
///
/// A.R.M.X is delivered in reported steps, so routes that are not implemented yet render
/// this page instead of a blank screen or a crash: navigation, theming and localization are
/// already verifiable, and the page states exactly which step fills it in.
class PlaceholderPage extends StatelessWidget {
  /// Creates a placeholder.
  const PlaceholderPage({
    required this.title,
    required this.step,
    this.icon = Icons.construction_outlined,
    super.key,
  });

  /// Screen title (already localized by the caller).
  final String title;

  /// Delivery step that implements this screen.
  final int step;

  /// Icon shown in the empty state.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Scaffold(
      appBar: ArmxAppBar(title: title),
      body: ArmxBackground(
        child: ArmxPageBody(
          child: EmptyView(
            title: context.l10n.placeholderStartedInStep(step),
            message: context.l10n.placeholderStepBody,
            icon: icon,
            action: Text(
              'step $step',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.cyan, fontFamily: 'JetBrainsMono'),
            ),
          ),
        ),
      ),
    );
  }
}
