// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/theme/armx_effects.dart';
import '../../../core/widgets/armx_controls.dart';
import '../../../core/widgets/armx_orb.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/status_pill.dart';
import '../../chat/chat_controller.dart';
import '../../chat/widgets/chat_bubble.dart';
import '../../chat/widgets/tool_approval_card.dart';
import '../../../data/models/chat.dart';
import '../desktop_controller.dart';
import '../desktop_state.dart';

/// The desktop popup card: frameless, always-on-top, dismissed by Esc or click-outside.
///
/// It reuses the mobile popup pieces — the orb, the transcript bubbles and the tool
/// approval cards — so a MEDIUM/HIGH action raised from the popup looks and behaves
/// exactly like the one raised in the full window.
///
/// When no microphone is available the card opens in typed-input mode instead of
/// listening mode, which is the documented fallback for a desktop without capture
/// hardware.
class DesktopPopupPage extends ConsumerStatefulWidget {
  /// Creates the popup.
  const DesktopPopupPage({super.key});

  @override
  ConsumerState<DesktopPopupPage> createState() => _DesktopPopupPageState();
}

class _DesktopPopupPageState extends ConsumerState<DesktopPopupPage> {
  final TextEditingController _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final desktop = ref.watch(desktopControllerProvider);
    final chat = ref.watch(chatControllerProvider);
    final controller = ref.read(desktopControllerProvider.notifier);

    final orbState = switch ((desktop.killed, desktop.listening, chat.isStreaming)) {
      (true, _, _) => ArmxOrbState.idle,
      (_, true, _) => ArmxOrbState.listening,
      (_, _, true) => ArmxOrbState.thinking,
      (_, _, _) => ArmxOrbState.idle,
    };

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): controller.closePopup,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Absorb the tap so the popup is not dismissed by its own content.
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(10),
            child: GlassPanel(
              accent: desktop.killed
                  ? colors.red
                  : desktop.listening
                      ? colors.cyan
                      : colors.violet,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ArmxOrb(state: orbState, size: 56, showLabel: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              desktop.killed
                                  ? l10n.errorKillSwitchTitle
                                  : desktop.listening
                                      ? l10n.orbStateListening
                                      : l10n.chatTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            StatusPill(
                              label: desktop.popupTypedMode
                                  ? l10n.desktopPopupTypedMode
                                  : desktop.listening
                                      ? l10n.desktopPopupListening
                                      : l10n.chatStatusLive,
                              tone: desktop.killed
                                  ? SeverityTone.danger
                                  : desktop.listening
                                      ? SeverityTone.success
                                      : SeverityTone.neutral,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.commonClose,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: controller.closePopup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: chat.messages.isEmpty
                        ? Center(
                            child: Text(
                              desktop.popupTypedMode
                                  ? l10n.desktopPopupTypedHint
                                  : l10n.chatEmptyBody,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.muted),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            itemCount: chat.messages.length,
                            itemBuilder: (context, index) {
                              final message = chat.messages[chat.messages.length - 1 - index];
                              final call = message.toolCallId == null
                                  ? null
                                  : chat.toolCalls[message.toolCallId];
                              if (message.role == ChatRole.tool && call != null) {
                                return ToolApprovalCard(
                                  call: call,
                                  verifying: chat.verifyingToolCallId == call.id,
                                  onApprove: call.needsDecision
                                      ? () => unawaited(_approve(call.id))
                                      : null,
                                  onDeny: call.needsDecision
                                      ? () => unawaited(_deny(call.id))
                                      : null,
                                );
                              }
                              return ChatBubble(message: message);
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ArmxTextField(
                          controller: _composer,
                          label: l10n.chatComposerHint,
                          enabled: !desktop.killed,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: ArmxEffects.brandGradient(colors.cyan, colors.violet),
                        ),
                        child: IconButton(
                          tooltip: l10n.chatSend,
                          icon: const Icon(Icons.send_rounded, size: 20),
                          onPressed: desktop.killed ? null : _send,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: controller.closePopup,
                      child: Text(l10n.desktopPopupDismiss),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approve(String callId) =>
      ref.read(chatControllerProvider.notifier).approve(callId);

  Future<void> _deny(String callId) =>
      ref.read(chatControllerProvider.notifier).deny(callId);

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) {
      return;
    }
    _composer.clear();
    unawaited(ref.read(chatControllerProvider.notifier).send(text));
  }
}
