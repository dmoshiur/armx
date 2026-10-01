// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:io';
import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/platform/autostart_service.dart';
import '../../core/platform/desktop_shell.dart';
import '../../core/platform/device_availability.dart';
import '../../core/providers.dart';
import '../chat/chat_controller.dart';
import 'desktop_state.dart';

part 'desktop_controller.g.dart';

/// Menu-row identifiers. The tray only reports which row was pressed; every behaviour
/// lives here so it is identical from the tray, the hotkey and the in-app UI.
abstract final class TrayCommand {
  /// Open the main window on the dashboard.
  static const String open = 'open';

  /// Open the popup and start listening (push-to-talk style).
  static const String talk = 'talk';

  /// Pause listening for 15 minutes.
  static const String pause15 = 'pause15';

  /// Pause listening for an hour.
  static const String pause60 = 'pause60';

  /// Pause listening for four hours.
  static const String pause240 = 'pause240';

  /// Resume listening now.
  static const String resume = 'resume';

  /// Open the background-readiness screen.
  static const String status = 'status';

  /// Engage the kill-switch (no biometric, same behaviour as mobile).
  static const String kill = 'kill';

  /// Open Settings.
  static const String settings = 'settings';

  /// Leave the process entirely.
  static const String quit = 'quit';
}

/// Owns desktop background mode: tray, hotkey, autostart, hardware probe, popup.
///
/// This is the only place that talks to [DesktopShell], so the whole state machine is
/// unit-testable with `NoopDesktopShell` + `NoopAutostartService`.
@Riverpod(keepAlive: true)
class DesktopController extends _$DesktopController {
  /// How long a "pause listening" menu row suspends capture.
  static const Map<String, Duration> pauseDurations = <String, Duration>{
    TrayCommand.pause15: Duration(minutes: 15),
    TrayCommand.pause60: Duration(hours: 1),
    TrayCommand.pause240: Duration(hours: 4),
  };

  Map<String, String>? _labels;

  /// True when the OS taskbar is dark, which selects the bright tray icon variant.
  bool get _darkTaskbar =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  StreamSubscription<DeviceStatus>? _deviceSubscription;
  Timer? _muteTimer;
  bool _starting = false;

  @override
  DesktopState build() {
    final preferences = ref.watch(appPreferencesProvider).value;
    final hotkey = HotkeyDescriptor.fromJson(
      preferences?.desktopHotkey,
      platform: _platform,
    );
    ref.onDispose(_dispose);
    // "Thinking" is a chat concept; mirroring it here keeps the tray icon honest while a
    // reply streams, which is exactly what the user is waiting for.
    final streaming = ref.read(chatControllerProvider).isStreaming;

    final initialState = DesktopState(
      hotkey: hotkey,
      launchAtLogin: preferences?.autostartEnabled ?? true,
      killed: ref.read(chatControllerProvider).killed,
      tray: streaming ? TrayVisualState.thinking : TrayVisualState.idle,
    );

    // Kick off the native side once; everything else reacts to preference changes.
    scheduleMicrotask(() => unawaited(_start()));
    return initialState;
  }

  /// `windows` | `macos` | `linux` — drives the default hotkey and the docs.
  String get _platform {
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    return 'linux';
  }

  Future<void> _start() async {
    if (_starting) {
      return;
    }
    _starting = true;
    final shell = ref.read(desktopShellProvider);
    final devices = ref.read(deviceAvailabilityProvider);
    final autostart = ref.read(autostartServiceProvider);

    _deviceSubscription = devices.changes.listen((DeviceStatus status) {
      state = state.copyWith(devices: status, popupTypedMode: !status.microphoneUsable);
    });

    try {
      await shell.start(_ShellCallbacks(this));
      final registered = await shell.registerHotkey(state.hotkey);
      state = state.copyWith(
        started: true,
        hotkeyStatus: registered ? HotkeyStatus.registered : HotkeyStatus.conflict,
        issue: registered ? DesktopIssue.none : DesktopIssue.hotkeyConflict,
      );
      if (!registered) {
        ref.read(appLoggerProvider).w('desktop: hotkey ${state.hotkey.describe()} is taken');
      }
      final enabled = await autostart.isEnabled;
      state = state.copyWith(launchAtLogin: enabled);
      final status = await devices.probe();
      state = state.copyWith(devices: status, popupTypedMode: !status.microphoneUsable);
    } on Object catch (_) {
      state = state.copyWith(started: false, issue: DesktopIssue.startFailed);
    }
    await _pushTray();
    _starting = false;
  }

  void _dispose() {
    _deviceSubscription?.cancel();
    _muteTimer?.cancel();
    unawaited(ref.read(desktopShellProvider).stop());
  }

  // ---- Tray ----------------------------------------------------------------

  Future<void> _pushTray() async {
    final shell = ref.read(desktopShellProvider);
    await shell.updateTray(
      state: state.visualState,
      darkIcon: _darkTaskbar,
      tooltip: _tooltip(),
      menu: _menu(),
    );
  }

  /// Tooltip: current state, voice availability and the connected server.
  String _tooltip() {
    final buffer = StringBuffer('A.R.M.X AI');
    if (state.killed) {
      buffer.write(' · KILL-SWITCH ENGAGED');
    } else if (state.isMuted) {
      buffer.write(' · paused');
    } else if (state.listening) {
      buffer.write(' · listening');
    } else {
      buffer.write(' · ready');
    }
    if (state.voiceUnavailable) {
      buffer.write(' · voice unavailable — use hotkey');
    }
    buffer.write(state.serverConnected ? ' · connected' : ' · offline');
    return buffer.toString();
  }

  List<TrayMenuItem> _menu() {
    final muted = state.isMuted;
    String label(String id, String fallback) => _labels?[id] ?? fallback;
    return <TrayMenuItem>[
      TrayMenuItem(id: TrayCommand.open, label: label(TrayCommand.open, 'Open A.R.M.X')),
      TrayMenuItem(
        id: TrayCommand.talk,
        label: label(TrayCommand.talk, 'Talk now'),
        enabled: !state.killed,
      ),
      if (muted)
        TrayMenuItem(
          id: TrayCommand.resume,
          label: label(TrayCommand.resume, 'Resume listening'),
        )
      else ...<TrayMenuItem>[
        TrayMenuItem(id: TrayCommand.pause15, label: label(TrayCommand.pause15, 'Pause 15 min')),
        TrayMenuItem(id: TrayCommand.pause60, label: label(TrayCommand.pause60, 'Pause 1 hour')),
        TrayMenuItem(id: TrayCommand.pause240, label: label(TrayCommand.pause240, 'Pause 4 hours')),
      ],
      TrayMenuItem(
        id: TrayCommand.status,
        label: label(TrayCommand.status, 'Background readiness'),
      ),
      TrayMenuItem(
        id: TrayCommand.kill,
        label: state.killed
            ? '${label(TrayCommand.kill, 'KILL-SWITCH')} (${_labels?['engaged'] ?? 'engaged'})'
            : label(TrayCommand.kill, 'KILL-SWITCH'),
        destructive: true,
      ),
      TrayMenuItem(
        id: TrayCommand.settings,
        label: label(TrayCommand.settings, 'Settings'),
      ),
      TrayMenuItem(
        id: TrayCommand.quit,
        label: label(TrayCommand.quit, 'Quit'),
        destructive: true,
      ),
    ];
  }

  /// Injects localized tray labels (resolved by the bootstrap from the stored locale).
  ///
  /// The controller is not a widget, so it cannot read `BuildContext.l10n`; the app shell
  /// hands the resolved map in once at startup and the English defaults above keep working
  /// whenever that has not happened (tests, mobile builds).
  void setMenuLabels(Map<String, String> labels) {
    _labels = labels;
    unawaited(_pushTray());
  }

  /// Routes one tray row (also used by the hotkey and the in-app buttons).
  Future<void> handleCommand(String command) async {
    final shell = ref.read(desktopShellProvider);
    switch (command) {
      case TrayCommand.open:
        await shell.focusMainWindow();
      case TrayCommand.talk:
        await _openPopup(listening: true);
      case TrayCommand.resume:
        await setMuted(false);
      case TrayCommand.status:
      case TrayCommand.settings:
        await shell.focusMainWindow();
      case TrayCommand.kill:
        await _toggleKillSwitch();
      case TrayCommand.quit:
        await _quit();
      default:
        final duration = DesktopController.pauseDurations[command];
        if (duration != null) {
          await setMuted(true, duration: duration);
        }
    }
  }

  /// Hotkey or tray-icon activation: toggle the popup.
  Future<void> togglePopup() async {
    final shell = ref.read(desktopShellProvider);
    if (await shell.popupVisible) {
      await _closePopup();
      return;
    }
    // Push-to-talk style: the hotkey always starts listening, even while the wake word
    // engine is paused.
    await _openPopup(listening: !state.killed);
  }

  Future<void> _openPopup({required bool listening}) async {
    final shell = ref.read(desktopShellProvider);
    if (state.popupTypedMode) {
      // No microphone: typed input is the primary trigger, exactly as specified.
      state = state.copyWith(popupOpen: true, listening: false);
    } else {
      state = state.copyWith(popupOpen: true, listening: listening);
    }
    await shell.showPopup(nearCursor: true);
    await _pushTray();
  }

  Future<void> _closePopup() async {
    final shell = ref.read(desktopShellProvider);
    state = state.copyWith(popupOpen: false, listening: false);
    await shell.hidePopup();
    await _pushTray();
  }

  /// Called when the popup is dismissed (Esc / click-outside).
  void onPopupDismissed() {
    if (state.popupOpen) {
      unawaited(_closePopup());
    }
  }

  // ---- Listening / kill-switch --------------------------------------------

  /// Pauses or resumes capture. A pause always expires on its own.
  Future<void> setMuted(bool muted, {Duration duration = const Duration(minutes: 15)}) async {
    _muteTimer?.cancel();
    _muteTimer = null;
    if (!muted) {
      state = state.copyWith(mutedUntil: null, listening: !state.killed);
    } else {
      final until = DateTime.now().toUtc().add(duration);
      state = state.copyWith(mutedUntil: until, listening: false);
      _muteTimer = Timer(duration, () {
        if (!state.isMuted) {
          unawaited(setMuted(false));
        }
      });
    }
    await _pushTray();
  }

  /// Engages or releases the kill-switch.
  ///
  /// Parity rule: the tray can ENGAGE without any biometric (identical to the mobile
  /// kill-switch), but RELEASING is only possible from the open app window, so a stray
  /// click can never re-arm a stopped assistant.
  Future<void> toggleKillSwitch() async {
    if (state.killed) {
      // Refuse from the tray: re-enable from the open window only.
      state = state.copyWith(issue: DesktopIssue.killSwitchReleaseBlocked);
      return;
    }
    await _engageKillSwitch();
  }

  Future<void> _toggleKillSwitch() async {
    if (state.killed) {
      state = state.copyWith(issue: DesktopIssue.killSwitchReleaseBlocked);
      return;
    }
    await _engageKillSwitch();
  }

  Future<void> _engageKillSwitch() async {
    try {
      await ref.read(armxApiProvider).setKillSwitch(engaged: true);
    } on Object catch (_) {
      state = state.copyWith(issue: DesktopIssue.killSwitchFailed);
      return;
    }
    state = state.copyWith(
      killed: true,
      listening: false,
      popupOpen: false,
      issue: DesktopIssue.none,
    );
    await ref.read(desktopShellProvider).hidePopup();
    await _pushTray();
  }

  /// Releases the kill-switch. Only reachable from the open window.
  Future<void> releaseKillSwitch() async {
    try {
      await ref.read(armxApiProvider).setKillSwitch(engaged: false);
    } on Object catch (_) {
      state = state.copyWith(issue: DesktopIssue.killSwitchFailed);
      return;
    }
    state = state.copyWith(killed: false, issue: DesktopIssue.none);
    await _pushTray();
  }

  /// Mirrors the kill-switch owned by the chat controller (single source of truth).
  void onKillSwitchChanged(bool killed) {
    if (state.killed == killed) {
      return;
    }
    state = state.copyWith(killed: killed, listening: killed ? false : state.listening);
    unawaited(_pushTray());
  }

  /// Mirrors socket connectivity for the tooltip.
  void onConnectionChanged(bool connected) {
    if (state.serverConnected == connected) {
      return;
    }
    state = state.copyWith(serverConnected: connected);
    unawaited(_pushTray());
  }

  // ---- Hotkey --------------------------------------------------------------

  /// Applies [descriptor], persisting it and reporting conflicts back to the UI.
  ///
  /// Returns the resulting status so the recorder widget can show "already in use".
  Future<HotkeyStatus> rebindHotkey(HotkeyDescriptor descriptor) async {
    final shell = ref.read(desktopShellProvider);
    final repository = ref.read(preferencesRepositoryProvider);
    final registered = await shell.registerHotkey(descriptor);
    final status = registered ? HotkeyStatus.registered : HotkeyStatus.conflict;
    state = state.copyWith(
      hotkey: descriptor,
      hotkeyStatus: status,
      issue: registered ? DesktopIssue.none : DesktopIssue.hotkeyConflict,
    );
    await repository.setDesktopHotkey(descriptor.storageKey);
    await _pushTray();
    return status;
  }

  // ---- Autostart -----------------------------------------------------------

  /// Flips the "Launch A.R.M.X at login" preference and applies it to the OS.
  Future<void> setLaunchAtLogin(bool enabled) async {
    final repository = ref.read(preferencesRepositoryProvider);
    await repository.setLaunchAtLogin(enabled);
    final autostart = ref.read(autostartServiceProvider);
    await autostart.setEnabled(enabled);
    state = state.copyWith(launchAtLogin: enabled);
    await _pushTray();
  }

  // ---- Popup -------------------------------------------------------------

  /// Opens the popup from the in-app UI (used by the hotkey hint row).
  Future<void> openPopup() => _openPopup(listening: !state.killed);

  /// Closes the popup from the in-app UI.
  Future<void> closePopup() => _closePopup();

  /// Closing the main window hides it to the tray; the process keeps running.
  ///
  /// "Never quit on close" is the whole point of background mode: the tray icon stays
  /// visible so the user can always quit deliberately.
  Future<void> minimizeToTray() async {
    await ref.read(desktopShellProvider).minimizeToTray();
    state = state.copyWith(popupOpen: false, listening: false);
    await _pushTray();
  }

  /// Marks the popup as typed-input mode (no microphone).
  void setPopupTypedMode(bool typed) {
    state = state.copyWith(popupTypedMode: typed);
  }

  Future<void> _quit() async {
    final shell = ref.read(desktopShellProvider);
    await shell.quit();
  }

  /// Re-probes hardware now (used by the readiness screen's "check again").
  Future<void> refreshDevices() async {
    final status = await ref.read(deviceAvailabilityProvider).probe();
    state = state.copyWith(devices: status, popupTypedMode: !status.microphoneUsable);
    await _pushTray();
  }

  /// Localized-ready summary of the desktop platform (for diagnostics).
  String get platformLabel => _platform;
}

/// Adapts [DesktopShellCallbacks] to the controller.
class _ShellCallbacks implements DesktopShellCallbacks {
  _ShellCallbacks(this._controller);

  final DesktopController _controller;

  @override
  void onMenuCommand(String id) => unawaited(_controller.handleCommand(id));

  @override
  void onHotkey() => unawaited(_controller.togglePopup());

  @override
  void onPopupDismissed() => _controller.onPopupDismissed();

  @override
  void onWindowCloseRequested() => unawaited(_controller.minimizeToTray());
}
