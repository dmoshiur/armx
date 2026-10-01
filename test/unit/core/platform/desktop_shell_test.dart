// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/platform/desktop_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HotkeyDescriptor', () {
    test('platform defaults match the specification', () {
      expect(HotkeyDescriptor.defaultFor('windows').describe(), 'Ctrl + Alt + Space');
      expect(HotkeyDescriptor.defaultFor('macos').describe(), '⌘ + Shift + Space');
      expect(HotkeyDescriptor.defaultFor('linux').describe(), 'Ctrl + Alt + A');
    });

    test('unknown platform falls back to the Linux binding', () {
      expect(HotkeyDescriptor.defaultFor('ios'), HotkeyDescriptor.defaultFor('linux'));
    });

    test('round-trips through JSON', () {
      const descriptor = HotkeyDescriptor(
        keyLabel: 'f7',
        modifiers: <String>['shift', 'ctrl'],
      );
      final restored = HotkeyDescriptor.fromJson(descriptor.toJson(), platform: 'windows');
      expect(restored, descriptor);
    });

    test('round-trips through the compact persisted form', () {
      final descriptor = HotkeyDescriptor.fromString('meta+shift+space', platform: 'macos');
      expect(descriptor.keyLabel, 'space');
      expect(descriptor.modifiers, <String>['meta', 'shift']);
    });

    test('a corrupted preference falls back to the platform default', () {
      expect(HotkeyDescriptor.fromJson('nonsense', platform: 'windows'),
          HotkeyDescriptor.defaultFor('windows'));
      expect(HotkeyDescriptor.fromJson(<String, Object?>{}, platform: 'macos'),
          HotkeyDescriptor.defaultFor('macos'));
      expect(HotkeyDescriptor.fromJson(<String, Object?>{'key': ''}, platform: 'linux'),
          HotkeyDescriptor.defaultFor('linux'));
    });

    test('modifier order is normalised so equal bindings compare equal', () {
      const a = HotkeyDescriptor(keyLabel: 'q', modifiers: <String>['alt', 'ctrl']);
      const b = HotkeyDescriptor(keyLabel: 'q', modifiers: <String>['ctrl', 'alt']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('the compact storage form round-trips', () {
      const descriptor = HotkeyDescriptor(
        keyLabel: 'space',
        modifiers: <String>['meta', 'shift'],
      );
      expect(descriptor.storageKey, 'meta+shift+space');
      expect(
        HotkeyDescriptor.fromString(descriptor.storageKey, platform: 'macos'),
        descriptor,
      );
    });

    test('a refused registration keeps the previous binding', () async {
      const shell = NoopDesktopShell();
      final first = HotkeyDescriptor.defaultFor('windows');
      expect(await shell.registerHotkey(first), isTrue);

      shell.registrationResult = false;
      expect(
        await shell.registerHotkey(
          const HotkeyDescriptor(keyLabel: 'f7', modifiers: <String>['ctrl']),
        ),
        isFalse,
      );
      expect(shell.hotkey, first, reason: 'the working binding is not thrown away');
    });

    test('unknown modifiers are dropped instead of producing a dead binding', () {
      final descriptor = HotkeyDescriptor.fromString('hyper+ctrl+x', platform: 'linux');
      expect(descriptor.modifiers, <String>['ctrl']);
      expect(descriptor.keyLabel, 'x');
    });
  });

  group('TrayMenuItem', () {
    test('value equality and JSON', () {
      const item = TrayMenuItem(id: 'kill', label: 'KILL-SWITCH', destructive: true);
      expect(item, const TrayMenuItem(id: 'kill', label: 'KILL-SWITCH', destructive: true));
      expect(item.toJson(), <String, Object?>{
        'id': 'kill',
        'label': 'KILL-SWITCH',
        'enabled': true,
        'destructive': true,
      });
    });
  });

  group('NoopDesktopShell', () {
    test('records the tray state it was last given', () async {
      const shell = NoopDesktopShell();
      await shell.start(_RecordingCallbacks());
      await shell.updateTray(
        state: TrayVisualState.killed,
        darkIcon: true,
        tooltip: 'A.R.M.X — KILL-SWITCH ENGAGED',
        menu: const <TrayMenuItem>[TrayMenuItem(id: 'quit', label: 'Quit')],
      );
      expect(shell.state, TrayVisualState.killed);
      expect(shell.updates, 1);
      expect(shell.isStarted, isTrue);
      await shell.stop();
      expect(shell.isStarted, isFalse);
    });

    test('hotkey registration and popup visibility', () async {
      const shell = NoopDesktopShell();
      expect(await shell.registerHotkey(HotkeyDescriptor.defaultFor('windows')), isTrue);
      expect(shell.hotkey, HotkeyDescriptor.defaultFor('windows'));
      expect(await shell.popupVisible, isFalse);
      await shell.showPopup(nearCursor: true);
      expect(await shell.popupVisible, isTrue);
      await shell.hidePopup();
      expect(await shell.popupVisible, isFalse);
      await shell.clearHotkey();
      expect(shell.hotkey, isNull);
    });
  });
}

class _RecordingCallbacks implements DesktopShellCallbacks {
  final List<String> commands = <String>[];
  int hotkeyCount = 0;
  int dismissed = 0;
  int closeRequests = 0;

  @override
  void onMenuCommand(String id) => commands.add(id);

  @override
  void onHotkey() => hotkeyCount++;

  @override
  void onPopupDismissed() => dismissed++;

  @override
  void onWindowCloseRequested() => closeRequests++;
}
