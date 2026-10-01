// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/theme/armx_colors.dart';
import '../../../core/theme/armx_effects.dart';
import '../../../core/widgets/armx_controls.dart';
import '../../../core/widgets/armx_text_field.dart';

/// The message input row: a branded text field and the send button.
///
/// The row disables itself while the kill-switch is engaged or a reply is
/// streaming, so the owner can never queue work behind a stopped assistant.
class ChatComposer extends StatelessWidget {
  /// Creates the composer.
  const ChatComposer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.hintText,
    this.sendTooltip,
    this.focusNode,
    super.key,
  });

  /// Text controller owning the draft message.
  final TextEditingController controller;

  /// False while the kill-switch is engaged or a reply is streaming.
  final bool enabled;

  /// Send handler; `null` disables the button (the draft is kept).
  final VoidCallback? onSend;

  /// Floating label / hint of the input field.
  final String hintText;

  /// Accessibility label of the send button.
  final String? sendTooltip;

  /// Optional focus node shared with the page.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ArmxTextField(
                controller: controller,
                label: hintText,
                enabled: enabled,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend?.call(),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(
              enabled: enabled && onSend != null,
              onPressed: onSend,
              tooltip: sendTooltip ?? hintText,
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular 48 dp send button: brand gradient when armed, muted when not.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.onPressed,
    required this.tooltip,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled ? ArmxEffects.brandGradient(colors.cyan, colors.violet) : null,
          color: enabled ? null : colors.panel2,
          border: Border.all(color: colors.border),
        ),
        child: IconButton(
          onPressed: enabled ? onPressed : null,
          tooltip: tooltip,
          icon: Icon(
            Icons.send_rounded,
            size: 20,
            color: enabled ? colors.background : colors.muted,
          ),
        ),
      ),
    );
  }
}
