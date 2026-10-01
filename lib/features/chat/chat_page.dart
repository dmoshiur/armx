// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/armx_orb.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/chat.dart';
import 'chat_controller.dart';
import 'chat_state.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_suggestions.dart';
import 'widgets/tool_approval_card.dart';

/// The assistant conversation tab: streaming transcript, tool approval cards
/// and the composer.
///
/// Everything on this screen is driven by [ChatController]; the page holds no
/// conversation state of its own beyond the draft text and scroll position.
class ChatPage extends ConsumerStatefulWidget {
  /// Creates the chat tab.
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _composer.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    final canSend = _composer.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  void _submit() {
    if (!_canSend) {
      return;
    }
    final text = _composer.text;
    _composer.clear();
    unawaited(ref.read(chatControllerProvider.notifier).send(text));
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    // The list is reversed, so offset 0 is the newest message.
    _scrollController.animateTo(
      0,
      duration: ArmxMotion.quick,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(chatControllerProvider);
    ref.listen<ChatState>(chatControllerProvider, (previous, next) {
      final grew = previous == null ||
          next.messages.length != previous.messages.length ||
          next.streamingMessageId != previous.streamingMessageId ||
          next.toolCalls.length != previous.toolCalls.length;
      if (grew) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: ArmxAppBar(
        title: l10n.chatTitle,
        subtitle: state.isStreaming ? l10n.chatStreaming : null,
        actions: <Widget>[
          if (state.messages.isNotEmpty)
            IconButton(
              tooltip: l10n.chatClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref.read(chatControllerProvider.notifier).clear(),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ConnectionPill(state: state),
          ),
        ],
      ),
      body: ArmxBackground(
        child: Column(
          children: <Widget>[
            if (state.killed) const _KillBanner(),
            if (state.error != null && !state.killed)
              _ErrorBanner(
                error: state.error!,
                onDismiss: ref.read(chatControllerProvider.notifier).dismissError,
              ),
            Expanded(
              child: state.messages.isEmpty
                  ? _EmptyTranscript(
                      onSelected: (prompt) =>
                          ref.read(chatControllerProvider.notifier).send(prompt),
                    )
                  : _Transcript(
                      state: state,
                      scrollController: _scrollController,
                      onRetry: ref.read(chatControllerProvider.notifier).retry,
                      onApprove: ref.read(chatControllerProvider.notifier).approve,
                      onDeny: ref.read(chatControllerProvider.notifier).deny,
                    ),
            ),
            ChatComposer(
              controller: _composer,
              enabled: !state.killed && !state.isStreaming,
              onSend: _canSend ? _submit : null,
              hintText: l10n.chatComposerHint,
              sendTooltip: l10n.chatSend,
            ),
          ],
        ),
      ),
    );
  }
}

/// The transcript: a reversed list so the newest message anchors the bottom.
class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onApprove,
    required this.onDeny,
  });

  final ChatState state;
  final ScrollController scrollController;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onDeny;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[state.messages.length - 1 - index];
        return _MessageRow(
          message: message,
          call: message.toolCallId == null ? null : state.toolCalls[message.toolCallId],
          streaming: state.streamingMessageId == message.id,
          verifying: state.verifyingToolCallId == message.toolCallId,
          onRetry: onRetry,
          onApprove: onApprove,
          onDeny: onDeny,
        );
      },
    );
  }
}

/// Routes one transcript entry to its widget: bubble, card or tool line.
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.call,
    required this.streaming,
    required this.verifying,
    required this.onRetry,
    required this.onApprove,
    required this.onDeny,
  });

  final ChatMessage message;
  final ToolCall? call;
  final bool streaming;
  final bool verifying;
  final ValueChanged<String> onRetry;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onDeny;

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.tool) {
      final toolCall = call;
      if (toolCall == null) {
        // LOW-tier call: it ran without a card, show the outcome line.
        return ChatBubble(message: message);
      }
      return ToolApprovalCard(
        call: toolCall,
        verifying: verifying,
        onApprove: toolCall.needsDecision ? () => onApprove(toolCall.id) : null,
        onDeny: toolCall.needsDecision ? () => onDeny(toolCall.id) : null,
      );
    }
    return ChatBubble(
      message: message,
      streaming: streaming,
      onRetry: message.isFailed ? () => onRetry(message.id) : null,
    );
  }
}

/// Empty transcript: the orb, the pitch and the starter prompts.
class _EmptyTranscript extends StatelessWidget {
  const _EmptyTranscript({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ArmxOrb(state: ArmxOrbState.idle, size: 128, showLabel: false),
            const SizedBox(height: 20),
            EmptyView(
              title: l10n.chatEmptyTitle,
              message: l10n.chatEmptyBody,
              icon: Icons.forum_outlined,
            ),
            const SizedBox(height: 8),
            ChatSuggestions(onSelected: onSelected),
          ],
        ),
      ),
    );
  }
}

/// Live connection (or kill-switch) state, shown in the app bar.
class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.state});

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (state.killed) {
      return StatusPill(
        label: l10n.statusKilled,
        tone: SeverityTone.danger,
        icon: Icons.power_settings_new,
        compact: true,
      );
    }
    return StatusPill(
      label: switch (state.connection) {
        ChatConnection.live => l10n.chatStatusLive,
        ChatConnection.reconnecting => l10n.chatStatusReconnecting,
        ChatConnection.offline => l10n.chatStatusOffline,
      },
      tone: switch (state.connection) {
        ChatConnection.live => SeverityTone.success,
        ChatConnection.reconnecting => SeverityTone.warning,
        ChatConnection.offline => SeverityTone.danger,
      },
      icon: switch (state.connection) {
        ChatConnection.live => Icons.cloud_done_outlined,
        ChatConnection.reconnecting => Icons.cloud_sync_outlined,
        ChatConnection.offline => Icons.cloud_off_outlined,
      },
      compact: true,
    );
  }
}

/// Persistent banner while the global kill-switch is engaged.
class _KillBanner extends StatelessWidget {
  const _KillBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: colors.red.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(Icons.power_settings_new, size: 16, color: colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.errorKillSwitchTitle,
                  style: textTheme.labelLarge?.copyWith(color: colors.red),
                ),
                Text(
                  l10n.errorKillSwitchBody,
                  style: textTheme.labelSmall?.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dismissible banner for the last failure (send, decision, verification).
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onDismiss});

  final AppException error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: GlassPanel(
        accent: ArmxColors.of(context).red,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, size: 16, color: ArmxColors.of(context).red),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.errorTitle(error),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    context.errorBody(error),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ArmxColors.of(context).muted,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.commonDismiss,
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
