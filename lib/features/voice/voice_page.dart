// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/armx_orb.dart';
import '../../core/widgets/armx_tile.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/layout_blocks.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import 'voice_controller.dart';
import 'voice_state.dart';
import 'widgets/voice_widgets.dart';
import 'widgets/wake_word_card.dart';

/// The voice screen: push-to-talk, wake-word mode, spoken replies and engine honesty.
class VoicePage extends ConsumerStatefulWidget {
  /// Creates the voice screen.
  const VoicePage({super.key});

  @override
  ConsumerState<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends ConsumerState<VoicePage> {
  bool _wakeWordBusy = false;

  Future<void> _toggleWakeWord(bool enabled) async {
    setState(() => _wakeWordBusy = true);
    final controller = ref.read(voiceControllerProvider.notifier);
    if (enabled) {
      // Arming always goes through the microphone gate first, so the user's privacy switch
      // is never bypassed by the wake-word toggle.
      final state = ref.read(voiceControllerProvider);
      if (!state.microphoneEnabled) {
        await controller.setMicrophoneEnabled(true);
      }
    }
    await controller.setWakeWordEnabled(enabled);
    if (mounted) {
      setState(() => _wakeWordBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final state = ref.watch(voiceControllerProvider);
    final controller = ref.read(voiceControllerProvider.notifier);
    final preferences = ref.watch(appPreferencesProvider);
    final language = preferences.value?.language ?? 'system';

    return Scaffold(
      appBar: ArmxAppBar(
        title: l10n.voiceTitle,
        subtitle: l10n.voiceSubtitle,
        actions: <Widget>[
          if (state.phase == VoicePhase.speaking)
            IconButton(
              tooltip: l10n.voiceStopSpeaking,
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: controller.stopSpeaking,
            ),
        ],
      ),
      body: ArmxBackground(
        child: ArmxPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (state.errorCode != null) _VoiceErrorBanner(
                code: state.errorCode!,
                onDismiss: controller.clearError,
              ),
              Center(
                child: ArmxOrb(
                  state: _orbState(state.phase),
                  size: 140,
                  onTap: () {
                    if (state.isCapturing) {
                      controller.stopPushToTalk();
                    } else {
                      controller.startPushToTalk();
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              VoiceLevelMeter(level: state.level, active: state.isCapturing),
              const SizedBox(height: 18),
              Center(
                child: PushToTalkButton(
                  phase: state.phase,
                  enabled: state.microphoneEnabled && !state.isResponding,
                  label: state.isCapturing ? l10n.voiceHoldRelease : l10n.voiceHoldToTalk,
                  hint: l10n.voicePushToTalkHint,
                  onStart: controller.startPushToTalk,
                  onStop: () => controller.stopPushToTalk(sendToAssistant: true),
                ),
              ),
              const SizedBox(height: 22),
              TranscriptCard(
                text: state.displayTranscript,
                capturing: state.isCapturing,
                onSend: () => controller.stopPushToTalk(sendToAssistant: true),
                onDiscard: controller.cancelCapture,
              ),
              if (!state.microphoneEnabled) ...<Widget>[
                const SizedBox(height: 12),
                GlassPanel(
                  accent: colors.amber,
                  child: Text(
                    l10n.voiceMicOffNotice,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SectionHeader(title: l10n.voiceLanguageTitle),
              GlassPanel(
                child: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'en', label: Text('English')),
                    ButtonSegment<String>(value: 'bn', label: Text('বাংলা')),
                  ],
                  selected: <String>{state.localeCode},
                  onSelectionChanged: (selection) {
                    controller.setLocaleCode(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 22),
              SectionHeader(title: l10n.voicePrivacyTitle),
              GlassPanel(
                child: Column(
                  children: <Widget>[
                    ArmxTile(
                      title: l10n.voiceMicrophoneTitle,
                      subtitle: l10n.voiceMicrophoneSubtitle,
                      leading: Icon(
                        state.microphoneEnabled ? Icons.mic_rounded : Icons.mic_off_outlined,
                        color: state.microphoneEnabled ? colors.cyan : colors.muted,
                      ),
                      trailing: Switch(
                        value: state.microphoneEnabled,
                        onChanged: controller.setMicrophoneEnabled,
                      ),
                    ),
                    const Divider(height: 18),
                    ArmxTile(
                      title: l10n.voiceAutoSpeakTitle,
                      subtitle: l10n.voiceAutoSpeakSubtitle,
                      leading: Icon(
                        state.autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: state.autoSpeak ? colors.cyan : colors.muted,
                      ),
                      trailing: Switch(
                        value: state.autoSpeak,
                        onChanged: controller.setAutoSpeak,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              WakeWordCard(
                enabled: state.wakeWordEnabled,
                supported: ref.read(wakeWordAdapterProvider).isSupported,
                isStub: state.engines.wakeWordIsStub,
                phrase: preferences.value?.wakeWordPhrase ?? 'Armex',
                serviceState: state.listeningServiceState,
                busy: _wakeWordBusy,
                onChanged: _toggleWakeWord,
                onSimulate: controller.simulateWakeWord,
              ),
              const SizedBox(height: 22),
              SectionHeader(title: l10n.voiceEnginesTitle),
              GlassPanel(
                child: Column(
                  children: <Widget>[
                    VoiceEngineRow(
                      label: l10n.voiceEngineStt,
                      engineId: state.engines.sttEngineId,
                      available: state.engines.sttAvailable,
                      simulated: false,
                      note: l10n.voiceEngineSttNote,
                    ),
                    VoiceEngineRow(
                      label: l10n.voiceEngineTts,
                      engineId: state.engines.ttsEngineId,
                      available: state.engines.ttsAvailable,
                      simulated: state.engines.ttsSimulated,
                      note: l10n.voiceEngineTtsNote,
                    ),
                    VoiceEngineRow(
                      label: l10n.voiceEngineWakeWord,
                      engineId: state.engines.wakeWordEngineId,
                      available: state.engines.wakeWordAvailable,
                      simulated: state.engines.wakeWordIsStub,
                      note: l10n.voiceEngineWakeWordNote,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (!state.engines.sttAvailable)
                const UnsupportedView(
                  feature: 'push-to-talk',
                  reason: 'No speech recognizer on this platform; the demo engine is active.',
                ),
              const SizedBox(height: 14),
              const VoiceVerificationNotice(),
              const SizedBox(height: 8),
              Text(
                l10n.voiceLanguageNote(language),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ArmxOrbState _orbState(VoicePhase phase) => switch (phase) {
        VoicePhase.arming || VoicePhase.listening || VoicePhase.transcribing => ArmxOrbState.listening,
        VoicePhase.thinking => ArmxOrbState.thinking,
        VoicePhase.speaking => ArmxOrbState.speaking,
        VoicePhase.error || VoicePhase.unsupported => ArmxOrbState.locked,
        VoicePhase.idle => ArmxOrbState.idle,
      };
}

/// Localized error banner for a stable voice error code.
class _VoiceErrorBanner extends StatelessWidget {
  const _VoiceErrorBanner({required this.code, required this.onDismiss});

  final String code;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final message = switch (code) {
      'microphone_switch_off' => l10n.voiceErrorMicOff,
      'microphone_permission_denied' || 'microphone_permission_required' =>
        l10n.voiceErrorPermission,
      'notification_permission_denied' => l10n.voiceErrorNotificationPermission,
      'stt_unavailable' => l10n.voiceErrorUnavailable,
      'background_listening_unsupported' => l10n.voiceErrorBackgroundUnsupported,
      'wake_word_engine_error' ||
      'wake_word_engine_start_failed' =>
        l10n.voiceErrorWakeWordEngine,
      _ => l10n.voiceErrorGeneric,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassPanel(
        accent: colors.amber,
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, size: 16, color: colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
              ),
            ),
            IconButton(
              tooltip: l10n.commonDismiss,
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
