// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_empty_state.dart';

/// Text and push-to-talk input.
///
/// * **Typing always works.** Voice is an addition, never the only way in: on the web, on
///   desktop, or with the microphone refused, the field and Send behave identically and the
///   microphone is simply marked unavailable.
/// * **Push-to-talk, not a toggle.** The button is *held*; releasing ends the turn. A tap
///   does nothing, so a pocketed phone cannot start recording.
/// * **The mic chip states the truth**: idle, listening, or unavailable.
class AssistantComposer extends StatefulWidget {
  /// Creates the composer.
  const AssistantComposer({
    required this.listening,
    required this.sending,
    required this.onSend,
    required this.onTalkStart,
    required this.onTalkEnd,
    this.voiceAvailable = true,
    super.key,
  });

  /// Whether capture is active.
  final bool listening;

  /// Whether a message is currently being sent.
  final bool sending;

  /// Called with the composed text.
  final ValueChanged<String> onSend;

  /// Called when push-to-talk begins.
  final VoidCallback onTalkStart;

  /// Called when push-to-talk ends.
  final VoidCallback onTalkEnd;

  /// Whether this platform can capture audio at all.
  final bool voiceAvailable;

  @override
  State<AssistantComposer> createState() => _AssistantComposerState();
}

class _AssistantComposerState extends State<AssistantComposer> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _held = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final String value = _text.text.trim();
    if (value.isEmpty || widget.sending) {
      return;
    }
    _text.clear();
    widget.onSend(value);
    _focus.requestFocus();
  }

  void _startTalk() {
    if (!widget.voiceAvailable || _held) {
      return;
    }
    setState(() => _held = true);
    widget.onTalkStart();
  }

  void _stopTalk() {
    if (!_held) {
      return;
    }
    setState(() => _held = false);
    widget.onTalkEnd();
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final bool recording = widget.listening || _held;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(top: BorderSide(color: colors.hairline)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.isCompact ? Insets.md : Insets.lg,
          Insets.md,
          context.isCompact ? Insets.md : Insets.lg,
          Insets.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!widget.voiceAvailable) ...<Widget>[
              ArmxNotice(
                tone: ArmxBadgeToneLike.info,
                message: context.l10n.assistantVoiceUnavailable,
              ),
              const SizedBox(height: Insets.sm),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: context.l10n.assistantComposerHint,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Semantics(
                  button: true,
                  label: context.l10n.assistantHoldToTalk,
                  hint: context.l10n.assistantHoldToTalkHint,
                  child: Tooltip(
                    message: context.l10n.assistantHoldToTalk,
                    child: GestureDetector(
                      onLongPressStart: (_) => _startTalk(),
                      onLongPressEnd: (_) => _stopTalk(),
                      onLongPressCancel: _stopTalk,
                      child: Container(
                        width: Insets.minTouchTarget,
                        height: Insets.minTouchTarget,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: recording ? colors.dangerFill : colors.surfaceAlt,
                          border: Border.all(
                            color: recording ? colors.danger : colors.hairline,
                          ),
                        ),
                        child: Icon(
                          recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                          size: 20,
                          color: recording
                              ? colors.onDangerFill
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                ArmxButton(
                  label: context.l10n.assistantSend,
                  icon: Icons.arrow_upward_rounded,
                  loading: widget.sending,
                  onPressed: widget.sending ? null : _send,
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ArmxChip(
                  label: recording
                      ? context.l10n.assistantListeningNow
                      : context.l10n.assistantMicIdle,
                  icon: recording ? Icons.mic_rounded : Icons.mic_off_outlined,
                  selected: recording,
                ),
                ArmxChip(
                  label: context.l10n.assistantHoldToTalkHint,
                  icon: Icons.touch_app_outlined,
                  selected: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
