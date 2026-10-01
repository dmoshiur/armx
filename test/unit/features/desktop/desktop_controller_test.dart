// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/platform/autostart_service.dart';
import 'package:armx_ai/core/platform/desktop_shell.dart';
import 'package:armx_ai/core/platform/device_availability.dart';
import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/features/desktop/desktop_controller.dart';
import 'package:armx_ai/features/desktop/desktop_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

/// The tray/hotkey state machine driven through the real controller with the native
/// plugins replaced by [NoopDesktopShell] and a scripted device probe.
void main() {
  late ProviderContainer container;
  late NoopDesktopShell shell;
  late _ScriptedDevices devices;
  late _RecordingAutostart autostart;

  setUp(() {
    shell = NoopDesktopShell();
    devices = _ScriptedDevices();
    autostart = _RecordingAutostart();
    container = ProviderContainer(
      overrides: <Override>[
        ...testOverrides(),
        desktopShellProvider.overrideWithValue(shell),
        deviceAvailabilityProvider.overrideWithValue(devices),
        autostartServiceProvider.overrideWithValue(autostart),
      ],
    );
    addTearDown(container.dispose);
  });

  DesktopController get controller => container.read(desktopControllerProvider.notifier);
  DesktopState get state => container.read(desktopControllerProvider);

  /// Waits for the controller's async `_start()` chain to settle.
  ///
  /// The shell, autostart and device probes all complete immediately, so a handful of
  /// event-loop turns is enough — no widget binding involved.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('the tray starts and the persisted hotkey is registered', () async {
    await settle();

    expect(shell.isStarted, isTrue);
    expect(shell.hotkey, isNotNull);
    expect(state.started, isTrue);
    expect(state.hotkeyStatus, HotkeyStatus.registered);
    expect(state.issue, DesktopIssue.none);
  });

  test('the tray menu always offers Open, Pause, KILL-SWITCH, Settings and Quit',
      () async {
    await settle();
    controller.onConnectionChanged(true);
    await settle();

    final ids = shell.lastMenu.map((TrayMenuItem item) => item.id).toSet();
    expect(ids, contains(TrayCommand.open));
    expect(ids, contains(TrayCommand.talk));
    expect(ids, contains(TrayCommand.pause15));
    expect(ids, contains(TrayCommand.pause60));
    expect(ids, contains(TrayCommand.pause240));
    expect(ids, contains(TrayCommand.status));
    expect(ids, contains(TrayCommand.kill));
    expect(ids, contains(TrayCommand.settings));
    expect(ids, contains(TrayCommand.quit));
    expect(
      shell.lastMenu.firstWhere((TrayMenuItem i) => i.id == TrayCommand.quit).destructive,
      isTrue,
    );
    expect(shell.lastTooltip, isNotNull);
  });

  test('while paused the menu offers Resume instead of the pause rows', () async {
    await settle();
    await controller.setMuted(true, duration: const Duration(minutes: 15));
    await settle();

    final ids = shell.lastMenu.map((TrayMenuItem item) => item.id).toSet();
    expect(ids, contains(TrayCommand.resume));
    expect(ids, isNot(contains(TrayCommand.pause15)));
    expect(shell.state, TrayVisualState.muted);
  });

  test('the kill-switch row is always present, even while engaged', () async {
    await settle();
    await controller.toggleKillSwitch();
    await settle();

    expect(shell.lastMenu.map((TrayMenuItem i) => i.id), contains(TrayCommand.quit));
    expect(shell.state, TrayVisualState.killed);
  });

  test('a hotkey conflict keeps the previous binding and reports the issue', () async {
    shell.registrationResult = false;
    await settle();

    expect(state.hotkeyStatus, HotkeyStatus.conflict);
    expect(state.issue, DesktopIssue.hotkeyConflict);
    expect(state.isReady, isFalse);
    final row = state.readiness.firstWhere((ReadinessItem r) => r.id == 'hotkey');
    expect(row.ok, isFalse);
    expect(row.actionId, 'hotkey');
  });

  test('rebinding to a free combination clears the conflict', () async {
    shell.registrationResult = false;
    await settle();
    expect(state.hotkeyStatus, HotkeyStatus.conflict);

    shell.registrationResult = true;
    final status = await controller.rebindHotkey(
      const HotkeyDescriptor(keyLabel: 'f7', modifiers: <String>['ctrl', 'alt']),
    );
    await settle();

    expect(status, HotkeyStatus.registered);
    expect(state.hotkeyStatus, HotkeyStatus.registered);
    expect(state.hotkey.keyLabel, 'f7');
    expect(state.issue, DesktopIssue.none);
  });

  test('no microphone puts the popup in typed-input mode', () async {
    devices.status = DeviceStatus(
      microphone: DeviceAvailability.missing,
      camera: DeviceAvailability.available,
      checkedAt: DateTime.utc(2026, 10, 1, 9),
    );
    await settle();

    expect(state.popupTypedMode, isTrue);
    expect(state.voiceUnavailable, isTrue);
    expect(state.readiness.firstWhere((ReadinessItem r) => r.id == 'microphone').ok, isFalse);
  });

  test('a missing camera is reported but never silently downgraded', () async {
    devices.status = DeviceStatus(
      microphone: DeviceAvailability.available,
      camera: DeviceAvailability.missing,
      checkedAt: DateTime.utc(2026, 10, 1, 9),
    );
    await settle();

    expect(state.readiness.firstWhere((ReadinessItem r) => r.id == 'camera').ok, isFalse);
    expect(state.readiness.firstWhere((ReadinessItem r) => r.id == 'microphone').ok, isTrue);
  });

  test('pausing listening shows the muted tray state and expires on its own', () async {
    await settle();
    await controller.setMuted(true, duration: const Duration(milliseconds: 20));
    await settle();
    expect(state.visualState, TrayVisualState.muted);
    expect(state.isMuted, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    await settle();
    expect(state.isMuted, isFalse);
    expect(state.visualState, TrayVisualState.idle);
  });

  test('the tray kill-switch engages without a biometric', () async {
    await settle();
    await controller.toggleKillSwitch();
    await settle();

    expect(state.killed, isTrue);
    expect(state.visualState, TrayVisualState.killed);
  });

  test('the tray cannot release the kill-switch: only the open window can', () async {
    await settle();
    await controller.toggleKillSwitch();
    await settle();

    await controller.toggleKillSwitch();
    await settle();

    expect(state.killed, isTrue, reason: 'a stray tray click must never re-arm the assistant');
    expect(state.issue, DesktopIssue.killSwitchReleaseBlocked);

    // The open app window is allowed to release it.
    await controller.releaseKillSwitch();
    await settle();
    expect(state.killed, isFalse);
  });

  test('launch at login writes the preference and the OS entry', () async {
    await settle();
    await controller.setLaunchAtLogin(false);
    await settle();

    expect(state.launchAtLogin, isFalse);
    expect(autostart.enabled, isFalse);
    expect((await container.read(preferencesRepositoryProvider).load()).autostartEnabled, isFalse);

    await controller.setLaunchAtLogin(true);
    await settle();
    expect(autostart.enabled, isTrue);
  });

  test('the popup opens listening and closes again', () async {
    await settle();
    await controller.openPopup();
    await settle();
    expect(state.popupOpen, isTrue);
    expect(state.listening, isTrue);
    expect(await shell.popupVisible, isTrue);

    await controller.closePopup();
    await settle();
    expect(state.popupOpen, isFalse);
    expect(await shell.popupVisible, isFalse);
  });

  test('closing the window hides to the tray instead of quitting', () async {
    await settle();
    await controller.minimizeToTray();
    await settle();

    expect(state.popupOpen, isFalse);
    expect(shell.minimizeCount, 1);
    expect(shell.quitCount, 0, reason: 'quit is only ever an explicit menu choice');
  });

  test('platformLabel reports the host OS', () {
    expect(controller.platformLabel, anyOf('windows', 'macos', 'linux'));
  });
}

/// Device probe that returns a scripted status and never touches the `record` plugin.
class _ScriptedDevices implements DeviceAvailabilityService {
  DeviceStatus status = DeviceStatus(
    microphone: DeviceAvailability.available,
    camera: DeviceAvailability.available,
    checkedAt: DateTime.utc(2026, 10, 1, 9),
  );

  @override
  Future<DeviceStatus> probe() async => status;

  @override
  Stream<DeviceStatus> get changes => const Stream<DeviceStatus>.empty();

  @override
  Future<void> dispose() async {}
}

/// Autostart integration that records calls instead of touching the registry/login items.
class _RecordingAutostart implements AutostartService {
  bool enabled = true;
  int setCalls = 0;

  @override
  Future<bool> get isEnabled async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    setCalls++;
    enabled = value;
  }

  @override
  Future<void> dispose() async {}
}
