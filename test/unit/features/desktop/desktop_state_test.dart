// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/platform/desktop_shell.dart';
import 'package:armx_ai/core/platform/device_availability.dart';
import 'package:armx_ai/features/desktop/desktop_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hotkey = HotkeyDescriptor(keyLabel: 'space', modifiers: <String>['ctrl', 'alt']);
  final checkedAt = DateTime.utc(2026, 10, 1, 9);
  final pausedUntil = DateTime.now().toUtc().add(const Duration(minutes: 15));

  DesktopState state({
    bool started = true,
    bool listening = false,
    bool killed = false,
    DateTime? mutedUntil,
    HotkeyStatus hotkeyStatus = HotkeyStatus.registered,
    bool launchAtLogin = true,
    bool serverConnected = true,
    DeviceStatus? devices,
  }) =>
      DesktopState(
        hotkey: hotkey,
        started: started,
        listening: listening,
        killed: killed,
        mutedUntil: mutedUntil,
        hotkeyStatus: hotkeyStatus,
        launchAtLogin: launchAtLogin,
        serverConnected: serverConnected,
        devices: devices ?? DeviceStatus(
          microphone: DeviceAvailability.available,
          camera: DeviceAvailability.available,
          checkedAt: checkedAt,
        ),
      );

  group('tray state machine', () {
    test('kill-switch wins over every other state', () {
      expect(state(killed: true, listening: true).visualState, TrayVisualState.killed);
    });

    test('a pause is shown as muted', () {
      expect(state(mutedUntil: pausedUntil, listening: true).visualState, TrayVisualState.muted);
      expect(state(mutedUntil: pausedUntil).isMuted, isTrue);
    });

    test('an expired pause stops being muted', () {
      final expired = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      expect(state(mutedUntil: expired).isMuted, isFalse);
      expect(state(mutedUntil: expired, listening: true).visualState, TrayVisualState.listening);
    });

    test('listening and idle round out the machine', () {
      expect(state(listening: true).visualState, TrayVisualState.listening);
      expect(state().visualState, TrayVisualState.idle);
    });

    test('every tray state has a distinct icon token', () {
      expect(
        TrayVisualState.values.toSet().length,
        TrayVisualState.values.length,
        reason: 'idle / listening / thinking / muted / killed must be five distinct icons',
      );
    });
  });

  group('readiness checklist', () {
    test('a fully ready desktop reports no failing rows', () {
      final result = state();
      expect(result.isReady, isTrue);
      expect(result.readiness.map((ReadinessItem r) => r.id), <String>[
        'autostart',
        'tray',
        'hotkey',
        'microphone',
        'camera',
      ]);
      for (final item in result.readiness) {
        expect(item.ok, isTrue, reason: '${item.id} should be green');
        expect(item.actionId, isNull, reason: 'a green row has no fix action');
      }
    });

    test('a hotkey conflict is red, actionable and explained', () {
      final result = state(hotkeyStatus: HotkeyStatus.conflict);
      final hotkeyRow = result.readiness.firstWhere((ReadinessItem r) => r.id == 'hotkey');
      expect(hotkeyRow.ok, isFalse);
      expect(hotkeyRow.actionId, 'hotkey');
      expect(hotkeyRow.summary, contains('in use'));
      expect(result.isReady, isFalse);
    });

    test('autostart off is red with a fix action', () {
      final result = state(launchAtLogin: false);
      final row = result.readiness.firstWhere((ReadinessItem r) => r.id == 'autostart');
      expect(row.ok, isFalse);
      expect(row.actionId, 'autostart');
    });

    test('a stopped tray is red', () {
      final row = state(started: false).readiness.firstWhere((ReadinessItem r) => r.id == 'tray');
      expect(row.ok, isFalse);
      expect(row.actionId, 'restart');
    });

    test('a missing microphone is red but the app still works typed', () {
      final result = state(
        devices: DeviceStatus(
          microphone: DeviceAvailability.missing,
          camera: DeviceAvailability.available,
          checkedAt: checkedAt,
        ),
      );
      final row = result.readiness.firstWhere((ReadinessItem r) => r.id == 'microphone');
      expect(row.ok, isFalse);
      expect(row.summary, 'missing');
      expect(result.voiceUnavailable, isTrue);
      expect(result.isReady, isFalse);
    });

    test('a missing camera is red and labelled for the fallback', () {
      final result = state(
        devices: DeviceStatus(
          microphone: DeviceAvailability.available,
          camera: DeviceAvailability.missing,
          checkedAt: checkedAt,
        ),
      );
      final row = result.readiness.firstWhere((ReadinessItem r) => r.id == 'camera');
      expect(row.ok, isFalse);
      expect(row.actionId, 'camera-settings');
    });
  });

  group('copyWith', () {
    test('keeps untouched fields and clears an issue explicitly', () {
      final before = state();
      final after = before.copyWith(listening: true, issue: DesktopIssue.none);
      expect(after.listening, isTrue);
      expect(after.hotkey, hotkey);
      expect(after.issue, DesktopIssue.none);
    });

    test('records a hotkey conflict as a localizable issue, not a raw string', () {
      final after = state().copyWith(issue: DesktopIssue.hotkeyConflict);
      expect(after.issue, DesktopIssue.hotkeyConflict);
      expect(after.issue.runtimeType, isNot(String));
    });
  });
}
