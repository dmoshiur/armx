// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../data/models/assistant.dart';

/// One transcript entry.
///
/// Rules:
/// * **The speaker is always named in text**, not just implied by alignment or colour — a
///   transcript is evidence, and a bubble the user cannot attribute is useless.
/// * **Pending and failed sends look different.** A message in flight says so; a message that
///   failed offers retry. Neither is ever rendered as delivered.
/// * **Assistant text is untrusted.** It is rendered as plain text: no markup, no links, no
///   images. Text selection is enabled so a user can copy a value out of it deliberately.
class ChatBubble extends StatelessWidget {
  /// Creates a bubble.
  const ChatBubble({
    required this.message,
    this.onRetry,
    super.key,
  });

  /// The message.
  final ChatMessage message;

  /// Called when the user retries a failed send.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final bool fromUser = message.author == ChatAuthor.user;
    final bool fromSystem = message.author == ChatAuthor.system;

    if (fromSystem) {
      // System entries (approval outcomes, connection notices) are inline lines, never
      // bubbles — the assistant must not appear to have said them.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: colors.textMuted,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final Color fill = fromUser
        ? colors.accent.withValues(alpha: colors.isDark ? 0.22 : 0.14)
        : colors.surface;
    final Color border = fromUser
        ? colors.accent.withValues(alpha: 0.45)
        : colors.hairline;

    return Semantics(
      label: fromUser
          ? context.l10n.chatYouSaid
          : context.l10n.chatAssistantSaid,
      child: Align(
        alignment:
            fromUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          // Never more than 76 % of the column: on a 1440 dp window a full-width bubble is
          // impossible to attribute at a glance.
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.md,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(Insets.cardRadius),
                topEnd: const Radius.circular(Insets.cardRadius),
                bottomStart: Radius.circular(fromUser ? Insets.cardRadius : 4),
                bottomEnd: Radius.circular(fromUser ? 4 : Insets.cardRadius),
              ),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      fromUser
                          ? context.l10n.chatYouSaid
                          : context.l10n.chatAssistantSaid,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (message.languageCode != null) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      Text(
                        message.languageCode!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(
                  message.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (message.pending) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        context.l10n.chatSending,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                if (message.failed) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: colors.dangerText,
                      ),
                      const SizedBox(width: Insets.sm),
                      Text(
                        context.l10n.chatSendFailed,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.dangerText),
                      ),
                      if (onRetry != null) ...<Widget>[
                        const SizedBox(width: Insets.sm),
                        TextButton(
                          onPressed: onRetry,
                          child: Text(context.l10n.commonRetry),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
