// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/sanitized_markdown.dart';
import '../../../data/models/chat.dart';

/// One row of the transcript: a user/assistant bubble, a system notice or a
/// tool-result line.
///
/// Assistant text always renders through [SanitizedMarkdown]: the reply arrives
/// from the backend and is therefore untrusted. User text is plain by design.
class ChatBubble extends StatelessWidget {
  /// Creates a bubble for [message].
  const ChatBubble({
    required this.message,
    this.streaming = false,
    this.onRetry,
    super.key,
  });

  /// The message to render.
  final ChatMessage message;

  /// True while this bubble is still receiving tokens.
  final bool streaming;

  /// Retry handler for a failed user message.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (message.role) {
      ChatRole.user => _userBubble(context),
      ChatRole.assistant => _assistantBubble(context),
      ChatRole.system => _systemNotice(context),
      ChatRole.tool => _toolLine(context),
    };
  }

  Widget _userBubble(BuildContext context) {
    final colors = ArmxColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.cyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.cyan.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(message.text, style: textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  _meta(context, message),
                  if (message.isFailed) ...<Widget>[
                    const SizedBox(height: 8),
                    ArmxButton(
                      label: context.l10n.commonRetry,
                      variant: ArmxButtonVariant.outlined,
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assistantBubble(BuildContext context) {
    final colors = ArmxColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final blocked = message.status == ChatMessageStatus.blocked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.violet.withValues(alpha: 0.18),
              border: Border.all(color: colors.violet.withValues(alpha: 0.5)),
            ),
            child: Icon(Icons.auto_awesome, size: 14, color: colors.violet),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.panel.withValues(alpha: colors.isDark ? 0.88 : 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: blocked ? colors.amber.withValues(alpha: 0.6) : colors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SanitizedMarkdown(
                    text: message.text,
                    textStyle: textTheme.bodyMedium,
                  ),
                  if (streaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '▍',
                        style: textTheme.bodyMedium?.copyWith(color: colors.cyan),
                      ),
                    ),
                  if (blocked) ...<Widget>[
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(Icons.block, size: 13, color: colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.chatBlocked,
                          style: textTheme.labelSmall?.copyWith(color: colors.amber),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  _meta(context, message),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemNotice(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
        ),
      ),
    );
  }

  Widget _toolLine(BuildContext context) {
    final colors = ArmxColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final failed = message.status == ChatMessageStatus.failed;
    final accent = failed ? colors.red : colors.green;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(failed ? Icons.error_outline : Icons.check_circle_outline, size: 14, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text,
              style: textTheme.labelSmall?.copyWith(color: colors.muted),
            ),
          ),
          _meta(context, message),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, ChatMessage message) {
    final colors = ArmxColors.of(context);
    return Text(
      ArmxFormatters.time(message.at),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.muted,
            fontSize: 10,
            fontFamily: 'JetBrainsMono',
          ),
    );
  }
}
