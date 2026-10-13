// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../data/models/assistant.dart';
import '../application/assistant_controller.dart';
import 'widgets/assistant_composer.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/tool_call_card.dart';

/// The assistant conversation.
///
/// ## Layout
///
/// * **compact / medium** — one column: transcript, then the composer pinned to the bottom.
///   The transcript is the only scrolling region, so the composer never moves.
/// * **expanded** — the transcript keeps a reading width (it is *not* stretched to 2560 dp)
///   and the pending proposals sit in their own panel, because a HIGH-risk proposal must not
///   be able to scroll out of sight while the user reads back through the conversation.
///
/// ## What the transcript promises
///
/// Streaming replies arrive as partial text attributed to the assistant; a message that
/// failed to send stays visible with a retry. Nothing is auto-approached: proposals wait in
/// their cards until a person decides, and the wake-word indicator always states whether
/// capture is armed, listening or off.
class AssistantPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(assistantControllerProvider.notifier).start(),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantState state = ref.watch(assistantControllerProvider);
    final ArmxColors colors = ArmxColors.of(context);

    // Follow the conversation as it grows, including while a reply streams in.
    ref.listen<AssistantState>(assistantControllerProvider,
        (AssistantState? previous, AssistantState next) {
      final bool grew = next.messages.length != (previous?.messages.length ?? 0) ||
          next.streamingText.length != (previous?.streamingText.length ?? 0) ||
          next.toolCalls.length != (previous?.toolCalls.length ?? 0);
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    });

    final Widget transcript = _Transcript(
      state: state,
      controller: _scroll,
      onRetry: (ChatMessage message) =>
          ref.read(assistantControllerProvider.notifier).retry(message),
      onRetryLoad: () =>
          ref.read(assistantControllerProvider.notifier).start(force: true),
      onSendSample: (String prompt) =>
          ref.read(assistantControllerProvider.notifier).send(prompt),
    );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Text(context.l10n.navAssistant),
            const SizedBox(width: Insets.md),
            WakeWordIndicator(
              armed: state.wakeWordArmed,
              listening: state.listening,
            ),
          ],
        ),
        actions: <Widget>[
          ArmxIconButton(
            icon: state.wakeWordArmed
                ? Icons.hearing_rounded
                : Icons.hearing_disabled_rounded,
            semanticLabel: state.wakeWordArmed
                ? context.l10n.assistantWakeWordArmed
                : context.l10n.assistantWakeWordOff,
            selected: state.wakeWordArmed,
            // Arming the wake word is a microphone decision, so it is an explicit toggle
            // rather than something that happens when the screen opens.
            onPressed: () => ref
                .read(assistantControllerProvider.notifier)
                .setWakeWordArmed(!state.wakeWordArmed),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Breakpoint breakpoint = Breakpoint.fromWidth(constraints.maxWidth);
            final bool showPanel = breakpoint == Breakpoint.expanded;

            final Widget column = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: <Widget>[
                  Expanded(child: transcript),
                  AssistantComposer(
                    listening: state.listening,
                    sending: state.sending,
                    onSend: (String text) => ref
                        .read(assistantControllerProvider.notifier)
                        .send(text),
                    onTalkStart: () => ref
                        .read(assistantControllerProvider.notifier)
                        .setListening(listening: true),
                    onTalkEnd: () => ref
                        .read(assistantControllerProvider.notifier)
                        .setListening(listening: false),
                  ),
                ],
              ),
            );

            if (!showPanel) {
              return Center(child: column);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: Center(child: column)),
                SizedBox(
                  width: 340,
                  child: _PendingPanel(calls: state.openCalls),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) {
      return;
    }
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: Motion.durationOf(context, Motion.standard),
      curve: Curves.easeOut,
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.state,
    required this.controller,
    required this.onRetry,
    required this.onRetryLoad,
    required this.onSendSample,
  });

  final AssistantState state;
  final ScrollController controller;
  final ValueChanged<ChatMessage> onRetry;
  final VoidCallback onRetryLoad;
  final ValueChanged<String> onSendSample;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.all(Insets.lg),
        child: Column(
          children: <Widget>[
            ArmxSkeletonCard(lines: 2),
            SizedBox(height: Insets.md),
            ArmxSkeletonCard(lines: 3),
          ],
        ),
      );
    }

    // A load failure with nothing to show yet is a whole-screen state; a failure after some
    // history exists is shown as a banner above the history instead (see below), because
    // throwing away a readable conversation to show an error is worse than useless.
    if (state.error != null && state.messages.isEmpty) {
      return ArmxErrorState(error: state.error, onRetry: onRetryLoad);
    }

    if (state.messages.isEmpty && state.toolCalls.isEmpty) {
      return ArmxEmptyState(
        icon: Icons.graphic_eq_rounded,
        title: context.l10n.assistantEmptyTitle,
        message: context.l10n.assistantEmptyBody,
        actionLabel: context.l10n.assistantTrySample,
        onAction: () => onSendSample(context.l10n.assistantSampleLowRisk),
        secondaryActionLabel: context.l10n.assistantSampleHighRiskHint,
        onSecondaryAction: () => onSendSample(context.l10n.assistantSampleDeploy),
      );
    }

    final List<Widget> children = <Widget>[
      if (state.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: ArmxErrorState(error: state.error, compact: true, onRetry: onRetryLoad),
        ),
      for (final ChatMessage message in state.messages)
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: ChatBubble(
            message: message,
            onRetry: message.failed && message.author == ChatAuthor.user
                ? () => onRetry(message)
                : null,
          ),
        ),
      // Streaming text is a bubble in its own right, marked pending, so a partial reply is
      // never mistaken for a finished one.
      if (state.streamingMessageId != null)
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: ChatBubble(
            message: ChatMessage(
              id: state.streamingMessageId!,
              author: ChatAuthor.assistant,
              text: state.partial,
              createdAt: DateTime.now().toUtc(),
              pending: true,
            ),
          ),
        ),
      // Proposals are newest-first here: the one needing a decision is the one nearest the
      // top of the list the user just scrolled past.
      for (final ToolCall call in state.toolCalls)
        Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: ToolCallCard(call: call),
        ),
    ];

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      itemCount: children.length,
      itemBuilder: (BuildContext context, int index) => children[index],
    );
  }
}

/// The expanded-layout column of proposals still awaiting a decision.
class _PendingPanel extends StatelessWidget {
  const _PendingPanel({required this.calls});

  final List<ToolCall> calls;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(start: BorderSide(color: colors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.toolPendingPanelTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  context.l10n.toolPendingPanelBody,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: calls.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: ArmxEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: context.l10n.toolNothingPending,
                      compact: true,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      0,
                      Insets.lg,
                      Insets.lg,
                    ),
                    children: <Widget>[
                      for (final ToolCall call in calls)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Insets.md),
                          child: ToolCallCard(call: call),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Whether the microphone is armed, listening, or off.
///
/// Three states, always labelled: an icon alone cannot distinguish "armed but quiet" from
/// "listening right now", and that distinction is the whole point of the control.
class WakeWordIndicator extends StatelessWidget {
  /// Creates the indicator.
  const WakeWordIndicator({
    required this.armed,
    required this.listening,
    super.key,
  });

  /// Whether the wake word is armed.
  final bool armed;

  /// Whether capture is active right now.
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final ArmxStatus status = listening
        ? ArmxStatus.online
        : armed
            ? ArmxStatus.pending
            : ArmxStatus.unknown;
    final String label = listening
        ? context.l10n.assistantListeningNow
        : armed
            ? context.l10n.assistantWakeWordArmed
            : context.l10n.assistantWakeWordOff;

    return ArmxStatusPill(status: status, label: label, pulse: listening);
  }
}
