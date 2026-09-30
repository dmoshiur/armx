// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/status_pill.dart';
import 'armx_listening_service.dart';

/// Settings controls and status for the Android foreground listening-service shell.
///
/// This card is deliberately explicit that wake-word detection is not active yet. A running
/// foreground service in this delivery does not access the microphone.
class AssistantListeningStatusPanel extends StatefulWidget {
  /// Creates the status panel.
  const AssistantListeningStatusPanel({super.key, this.service});

  /// Optional bridge override for tests.
  final ArmxListeningService? service;

  @override
  State<AssistantListeningStatusPanel> createState() => _AssistantListeningStatusPanelState();
}

class _AssistantListeningStatusPanelState extends State<AssistantListeningStatusPanel> {
  late final ArmxListeningService _service = widget.service ?? ArmxListeningService();
  late final StreamSubscription<ArmxListenEvent> _events;

  ArmxListenStatus _status = ArmxListenStatus.unsupported;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = _service.isSupported
        ? const ArmxListenStatus(phase: ArmxListenPhase.stopped)
        : ArmxListenStatus.unsupported;
    _events = _service.events.listen(
      _onEvent,
      // The status request below remains the source of truth if a platform stream fails.
      onError: (Object _) {},
    );
    unawaited(_refresh());
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    super.dispose();
  }

  void _onEvent(ArmxListenEvent event) {
    if (!mounted) return;
    if (event.status != null) {
      setState(() => _status = event.status!);
    } else if (event.type == ArmxListenEventType.error) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final next = await _service.status();
    if (!mounted) return;
    setState(() {
      _status = next;
      _loading = false;
    });
  }

  Future<void> _run(Future<ArmxListenStatus> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final next = await operation();
      if (mounted) setState(() => _status = next);
    } on Object {
      // Keep raw platform exceptions out of diagnostics and show a stable UI state instead.
      if (mounted) setState(() => _status = ArmxListenStatus.error('service_command_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final supported = _service.isSupported;
    final phase = _status.phase;
    final label = switch (phase) {
      ArmxListenPhase.unsupported => l10n.assistantModeUnsupported,
      ArmxListenPhase.stopped => l10n.assistantModeStopped,
      ArmxListenPhase.starting => l10n.assistantModeStarting,
      ArmxListenPhase.running => l10n.assistantModeRunning,
      ArmxListenPhase.paused => l10n.assistantModePaused,
      ArmxListenPhase.killed => l10n.assistantModeKilled,
      ArmxListenPhase.error => l10n.assistantModeError,
    };
    final tone = switch (phase) {
      ArmxListenPhase.running => SeverityTone.success,
      ArmxListenPhase.starting || ArmxListenPhase.paused => SeverityTone.warning,
      ArmxListenPhase.killed || ArmxListenPhase.error => SeverityTone.danger,
      _ => SeverityTone.neutral,
    };
    final errorCode = _status.errorCode;
    final permissionDenied = errorCode == 'microphone_permission_denied' ||
        errorCode == 'notification_permission_denied' ||
        errorCode == 'microphone_permission_required' ||
        errorCode == 'notification_permission_required';
    final backgroundStartBlocked =
        errorCode == 'background_start_blocked' || errorCode == 'foreground_start_not_allowed';
    final errorText = !supported
        ? l10n.assistantModeDesktopUnsupported
        : permissionDenied
            ? l10n.assistantModePermissionNeeded
            : backgroundStartBlocked
                ? l10n.assistantModeBackgroundStartBlocked
                : phase == ArmxListenPhase.error
                    ? l10n.assistantModeServiceError
                    : null;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                supported ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
                color: supported ? colors.cyan : colors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.assistantModeTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                StatusPill(label: label, tone: tone, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _status.wakeWordEngineReady
                ? l10n.assistantModeEngineReady
                : l10n.assistantModeWakeWordPending,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.assistantModeRebootNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
          if (errorText != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              errorText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: phase == ArmxListenPhase.error ? colors.red : colors.amber,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!supported || phase == ArmxListenPhase.unsupported)
                const SizedBox.shrink()
              else if (_busy || phase == ArmxListenPhase.starting)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (phase == ArmxListenPhase.running)
                FilledButton.tonalIcon(
                  onPressed: () => _run(_service.pause),
                  icon: const Icon(Icons.pause_rounded),
                  label: Text(l10n.assistantModePause),
                )
              else if (phase == ArmxListenPhase.paused)
                FilledButton.icon(
                  onPressed: () => _run(_service.resume),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.assistantModeResume),
                )
              else
                FilledButton.icon(
                  onPressed: () => _run(
                    () => _service.start(languageCode: l10n.localeName),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.assistantModeStart),
                ),
              if (supported && _status.isForegroundServiceActive && !_busy)
                OutlinedButton.icon(
                  onPressed: () => _run(_service.stop),
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(l10n.assistantModeStop),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
