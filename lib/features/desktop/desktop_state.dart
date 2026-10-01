// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';

import '../../core/platform/desktop_shell.dart';
import '../../core/platform/device_availability.dart';

/// Result of the last hotkey registration attempt.
enum HotkeyStatus {
  /// Not attempted yet (desktop shell still starting).
  unknown,

  /// Registered and live.
  registered,

  /// The OS refused the combination; the previous binding is still active.
  conflict,

  /// The stored descriptor names a key this build cannot map.
  unusable,
}

/// One row of the background-readiness checklist.
@immutable
class ReadinessItem {
  /// Creates a checklist row.
  const ReadinessItem({
    required this.id,
    required this.ok,
    required this.summary,
    this.fixHint,
    this.actionId,
  });

  /// Stable id (`autostart`, `tray`, `hotkey`, `microphone`, `camera`, `notifications`).
  final String id;

  /// True when the row is green.
  final bool ok;

  /// What the app currently knows (localized by the caller).
  final String summary;

  /// What the user can do about it (localized by the caller).
  final String? fixHint;

  /// Identifier of the fix action (open OS settings, pick another hotkey, …).
  final String? actionId;
}

/// Machine-readable failure the UI can localize.
enum DesktopIssue {
  /// Nothing to report.
  none,

  /// The OS already owns the requested hotkey combination.
  hotkeyConflict,

  /// A tray "release" was refused because re-enabling needs the open window.
  killSwitchReleaseBlocked,

  /// The login entry could not be written.
  autostartFailed,

  /// The kill-switch could not be applied (the backend refused or was unreachable).
  killSwitchFailed,

  /// The native shell failed to start.
  startFailed,
}

/// Immutable snapshot of desktop background mode.
@immutable
class DesktopState {
  /// Creates the desktop state.
  const DesktopState({
    this.tray = TrayVisualState.idle,
    this.hotkey = const HotkeyDescriptor(keyLabel: 'a', modifiers: <String>['ctrl', 'alt']),
    this.hotkeyStatus = HotkeyStatus.unknown,
    this.launchAtLogin = true,
    this.listening = false,
    this.mutedUntil,
    this.killed = false,
    this.serverConnected = false,
    this.popupOpen = false,
    this.popupTypedMode = false,
    this.devices = const DeviceStatus(),
    this.singleInstancePrimary = true,
    this.started = false,
    this.error,
  });

  /// Visual state of the tray icon.
  final TrayVisualState tray;

  /// Hotkey the app is trying to keep registered.
  final HotkeyDescriptor hotkey;

  /// Outcome of the last registration attempt.
  final HotkeyStatus hotkeyStatus;

  /// Whether the app is registered to start at login (mirrors the settings toggle).
  final bool launchAtLogin;

  /// Wake-word listening is running.
  final bool listening;

  /// When set, listening is paused until this instant (UTC).
  final DateTime? mutedUntil;

  /// Global kill-switch engaged.
  final bool killed;

  /// The realtime socket is delivering frames.
  final bool serverConnected;

  /// The popup window is on screen.
  final bool popupOpen;

  /// The popup opened in typed-input mode because no microphone is available.
  final bool popupTypedMode;

  /// Latest hardware probe.
  final DeviceStatus devices;

  /// False when another process is already running (this copy is passive).
  final bool singleInstancePrimary;

  /// True once the native shell finished starting.
  final bool started;

  /// Last failure worth showing the user.
  final DesktopIssue issue;

  /// True while the pause window is active.
  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now().toUtc());

  /// True when the tray should show the "voice unavailable" hint.
  bool get voiceUnavailable => !devices.microphoneUsable;

  /// The tray visual state implied by the current flags.
  TrayVisualState get visualState {
    if (killed) {
      return TrayVisualState.killed;
    }
    if (isMuted) {
      return TrayVisualState.muted;
    }
    if (listening) {
      return TrayVisualState.listening;
    }
    return TrayVisualState.idle;
  }

  /// Checklist rows for the background-readiness screen.
  List<ReadinessItem> get readiness => <ReadinessItem>[
        ReadinessItem(
          id: 'autostart',
          ok: launchAtLogin,
          summary: launchAtLogin ? 'enabled' : 'disabled',
          fixHint: launchAtLogin ? null : 'enable',
          actionId: launchAtLogin ? null : 'autostart',
        ),
        ReadinessItem(
          id: 'tray',
          ok: started,
          summary: started ? 'running' : 'not started',
          fixHint: started ? null : 'restart',
          actionId: started ? null : 'restart',
        ),
        ReadinessItem(
          id: 'hotkey',
          ok: hotkeyStatus == HotkeyStatus.registered,
          summary: switch (hotkeyStatus) {
            HotkeyStatus.registered => 'registered',
            HotkeyStatus.conflict => 'in use by another app',
            HotkeyStatus.unusable => 'unsupported key',
            HotkeyStatus.unknown => 'checking',
          },
          fixHint: hotkeyStatus == HotkeyStatus.registered ? null : 'rebind',
          actionId: hotkeyStatus == HotkeyStatus.registered ? null : 'hotkey',
        ),
        ReadinessItem(
          id: 'microphone',
          ok: devices.microphoneUsable,
          summary: deviceAvailabilityLabel(devices.microphone),
          fixHint: devices.microphoneUsable ? null : 'check',
          actionId: devices.microphoneUsable ? null : 'audio-settings',
        ),
        ReadinessItem(
          id: 'camera',
          ok: devices.cameraUsable,
          summary: deviceAvailabilityLabel(devices.camera),
          fixHint: devices.cameraUsable ? null : 'check',
          actionId: devices.cameraUsable ? null : 'camera-settings',
        ),
      ];

  /// True when every checklist row is green.
  bool get isReady => readiness.every((ReadinessItem item) => item.ok);

  DesktopState copyWith({
    TrayVisualState? tray,
    HotkeyDescriptor? hotkey,
    HotkeyStatus? hotkeyStatus,
    bool? launchAtLogin,
    bool? listening,
    Object? mutedUntil = _clear,
    bool? killed,
    bool? serverConnected,
    bool? popupOpen,
    bool? popupTypedMode,
    DeviceStatus? devices,
    bool? singleInstancePrimary,
    bool? started,
    DesktopIssue? issue,
  }) =>
      DesktopState(
        tray: tray ?? this.tray,
        hotkey: hotkey ?? this.hotkey,
        hotkeyStatus: hotkeyStatus ?? this.hotkeyStatus,
        launchAtLogin: launchAtLogin ?? this.launchAtLogin,
        listening: listening ?? this.listening,
        mutedUntil: mutedUntil == _clear ? this.mutedUntil : mutedUntil as DateTime?,
        killed: killed ?? this.killed,
        serverConnected: serverConnected ?? this.serverConnected,
        popupOpen: popupOpen ?? this.popupOpen,
        popupTypedMode: popupTypedMode ?? this.popupTypedMode,
        devices: devices ?? this.devices,
        singleInstancePrimary: singleInstancePrimary ?? this.singleInstancePrimary,
        started: started ?? this.started,
        issue: issue ?? this.issue,
      );
}
