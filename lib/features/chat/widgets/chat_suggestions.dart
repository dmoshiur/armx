// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/theme/armx_theme.dart';
import '../../../core/widgets/armx_tile.dart';

/// Starter prompts shown on the empty transcript.
///
/// Each chip sends the English keyword the assistant understands (the mock
/// backend matches on those), while the label itself is localized. The four
/// prompts deliberately cover the interesting paths: a MEDIUM tool approval, a
/// HIGH tool approval, a plain answer and the kill-switch.
class ChatSuggestions extends StatelessWidget {
  /// Creates the suggestion row.
  const ChatSuggestions({required this.onSelected, super.key});

  /// Called with the prompt to send when a chip is tapped.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suggestions = <(String, String)>[
      (l10n.chatSuggestionLight, 'turn on the living room light'),
      (l10n.chatSuggestionAudit, 'summarise the audit log'),
      (l10n.chatSuggestionUnlock, 'unlock my studio pc'),
      (l10n.chatSuggestionKill, 'switch off everything'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final (label, prompt) in suggestions)
          _SuggestionChip(label: label, onTap: () => onSelected(prompt)),
      ],
    );
  }
}

/// One starter prompt: a pill that meets the 48 dp minimum touch target.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return MinTouchTarget(
      child: Material(
        color: colors.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(ArmxTheme.pillRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ArmxTheme.pillRadius),
          splashColor: colors.cyan.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ArmxTheme.pillRadius),
              border: Border.all(color: colors.cyan.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.bolt_outlined, size: 14, color: colors.cyan),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
