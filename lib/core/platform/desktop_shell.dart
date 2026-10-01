// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// What the tray icon currently communicates.
///
/// The tray is the *always visible* part of A.R.M.X: a user who never opens the window can
/// still tell at a glance whether the assistant is idle, listening, thinking, paused or
/// hard-stopped. Every value has a distinct colour so the states are distinguishable
/// without reading the tooltip (and for colour-blind users the shape differs too — see
/// `assets/tray/README.md`).
enum TrayVisualState {
  /// Ready, not listening.
  idle,

  /// Wake-word or push-to-talk capture is running.
  listening,

  /// A reply is streaming or a tool call is executing.
  thinking,

  /// Listening paused by the user (still connected).
  muted,

  /// Kill-switch engaged: everything stopped, red/locked icon.
  killed,
}

/// One row of the tray / menu-bar menu.
@immutable
class TrayMenuItem {
  /// Creates a menu row.
  const TrayMenuItem({
    required this.id,
    required this.label,
    this.enabled = true,
    this.destructive = false,
  });

  /// Stable identifier delivered back through [DesktopShellCallbacks.onMenuCommand].
  final String id;

  /// Localized label shown to the user.
  final String label;

  /// False renders the row greyed out (for example "Pause listening" while killed).
  final bool enabled;

  /// True renders the row in the danger colour ("KILL-SWITCH", "Quit").
  final bool destructive;

  /// JSON form used by the fake shell in tests.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'enabled': enabled,
        'destructive': destructive,
      };

  @override
  bool operator ==(Object other) =>
      other is TrayMenuItem &&
      other.id == id &&
      other.label == label &&
      other.enabled == enabled &&
      other.destructive == destructive;

  @override
  int get hashCode => Object.hash(id, label, enabled, destructive);
}

/// A global hotkey, stored and compared by its *labels* rather than plugin key codes.
///
/// Persisting labels keeps the value readable in the preferences table, portable across
/// the three desktop plugins and trivially testable; `toHotkey()` translates it into the
/// native plugin's key codes and returns `null` when the label is unknown.
@immutable
class HotkeyDescriptor {
  /// Creates a descriptor for [keyLabel] plus [modifiers].
  const HotkeyDescriptor({
    required this.keyLabel,
    this.modifiers = const <String>[],
    this.systemWide = true,
  });

  /// Default per OS, chosen to avoid known reserved/system combos.
  ///
  /// * Windows — `Ctrl+Alt+Space` (never `Win+*`, `Ctrl+Alt+Del`, `Ctrl+Shift+Esc`).
  /// * macOS — `Cmd+Shift+Space` (never `Cmd+Space` Spotlight, `Cmd+Tab`, screenshot combos).
  /// * Linux — `Ctrl+Alt+A`; `Super+Space` is offered as an alternative but is reserved by
  ///   several distributions (Pop!_OS, some GNOME builds) and by KDE's launcher family.
  factory HotkeyDescriptor.defaultFor(String platform) => switch (platform) {
        'windows' => const HotkeyDescriptor(keyLabel: 'space', modifiers: <String>['ctrl', 'alt']),
        'macos' => const HotkeyDescriptor(keyLabel: 'space', modifiers: <String>['meta', 'shift']),
        _ => const HotkeyDescriptor(keyLabel: 'a', modifiers: <String>['ctrl', 'alt']),
      };

  /// Lower-case key label, for example `space`, `a`, `f7`.
  final String keyLabel;

  /// Lower-case modifier labels in canonical order: `ctrl`, `alt`, `shift`, `meta`.
  final List<String> modifiers;

  /// False restricts the hotkey to this app (still global to the process, but the OS
  /// cannot steal it while another window has focus).
  final bool systemWide;

  /// Human readable form, e.g. `Ctrl + Alt + Space`.
  String describe() {
    final parts = <String>[...modifiers, keyLabel].map(_prettyLabel);
    return parts.join(' + ');
  }

  static String _prettyLabel(String label) => switch (label) {
        'ctrl' || 'control' => 'Ctrl',
        'alt' || 'option' => 'Alt',
        'shift' => 'Shift',
        'meta' || 'cmd' || 'command' || 'super' || 'win' => 'Meta',
        'space' => 'Space',
        'enter' || 'return' => 'Enter',
        'esc' || 'escape' => 'Esc',
        'tab' => 'Tab',
        'up' => 'Up',
        'down' => 'Down',
        'left' => 'Left',
        'right' => 'Right',
        final String other => other.length == 1 ? other.toUpperCase() : other,
      };

  /// Canonical form used for equality and persistence.
  Map<String, Object?> toJson() => <String, Object?>{
        'key': keyLabel,
        'modifiers': modifiers,
        'systemWide': systemWide,
      };

  /// Compact form used for the stored preference: `ctrl+alt+space`.
  ///
  /// [HotkeyDescriptor.fromString] reads exactly this back, so a rebind survives a restart
  /// without persisting a Dart `Map.toString()`.
  String get storageKey => <String>[...modifiers, keyLabel].join('+');

  /// Parses a stored descriptor; falls back to the Linux default when unusable.
  factory HotkeyDescriptor.fromJson(Object? raw, {String platform = 'linux'}) {
    if (raw is String && raw.isNotEmpty) {
      try {
        return HotkeyDescriptor.fromJson(jsonDecode(raw), platform: platform);
      } on FormatException {
        // The preference is stored in the compact, human-readable form `ctrl+alt+space`
        // (see `PreferencesRepository.setDesktopHotkey`), so parse that too.
        return fromString(raw, platform: platform);
      }
    }
    if (raw is! Map) {
      return HotkeyDescriptor.defaultFor(platform);
    }
    final key = raw['key'];
    if (key is! String || key.isEmpty) {
      return HotkeyDescriptor.defaultFor(platform);
    }
    final modifiers = <String>[];
    for (final entry in (raw['modifiers'] as List<Object?>? ?? const <Object?>[])) {
      if (entry is String && entry.isNotEmpty) {
        modifiers.add(entry.toLowerCase());
      }
    }
    return HotkeyDescriptor(
      keyLabel: key.toLowerCase(),
      modifiers: _ordered(modifiers),
      systemWide: raw['systemWide'] != false,
    );
  }

  /// Parses the compact persisted form `ctrl+alt+space` / `meta+shift+space`.
  ///
  /// Falls back to the platform default when the string is unusable, so a corrupted
  /// preference can never leave the app without a working hotkey.
  factory HotkeyDescriptor.fromString(String raw, {String platform = 'linux'}) {
    final parts = raw.toLowerCase().split('+').where((String p) => p.isNotEmpty).toList();
    if (parts.length < 2) {
      return HotkeyDescriptor.defaultFor(platform);
    }
    final key = parts.removeLast();
    return HotkeyDescriptor(keyLabel: key, modifiers: _ordered(parts));
  }

  static List<String> _ordered(List<String> modifiers) {
    const order = <String>['ctrl', 'alt', 'shift', 'meta'];
    final known = modifiers.where(order.contains).toSet();
    return order.where(known.contains).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is HotkeyDescriptor &&
      other.keyLabel == keyLabel &&
      listEquals(other.modifiers, modifiers) &&
      other.systemWide == systemWide;

  @override
  int get hashCode => Object.hash(keyLabel, Object.hashAll(modifiers), systemWide);

  @override
  String toString() => 'HotkeyDescriptor(${describe()})';
}

/// Commands the tray menu can raise. The controller owns the behaviour; the shell only
/// reports which row was activated.
abstract interface class DesktopShellCallbacks {
  /// A menu row with [id] was activated.
  void onMenuCommand(String id);

  /// The global hotkey fired.
  void onHotkey();

  /// The popup was dismissed (Esc, click-outside or focus loss).
  void onPopupDismissed();

  /// The user asked to close the main window; the app hides to tray instead of quitting.
  void onWindowCloseRequested();
}

/// Everything the app needs from the host OS: tray, hotkey and popup window.
///
/// Two implementations exist: [NoopDesktopShell] (mobile, CI and unit tests) and the native
/// adapter in `desktop_shell_native.dart` that talks to `tray_manager`, `hotkey_manager`
/// and `window_manager`. Keeping the plugins behind this interface means the tray state
/// machine, the hotkey conflict handling and the readiness checklist are all pure Dart and
/// therefore unit-testable.
abstract interface class DesktopShell {
  /// Starts the tray, the popup window and (if [callbacks.onHotkey] is wired) the hotkey.
  Future<void> start(DesktopShellCallbacks callbacks);

  /// Releases every native resource.
  Future<void> stop();

  /// Refreshes icon, tooltip and menu. Cheap enough to call on every state change.
  ///
  /// [darkIcon] is true when the OS taskbar / menu bar is dark, which selects the bright
  /// icon variant (`tray_idle_64.png`); a light taskbar gets the dark variant
  /// (`tray_idle_dark_64.png`). macOS ignores the choice and renders the icon as a template.
  Future<void> updateTray({
    required TrayVisualState state,
    required bool darkIcon,
    required String tooltip,
    required List<TrayMenuItem> menu,
  });

  /// Registers [descriptor]; returns false when the OS already owns that combination.
  ///
  /// A conflict is a normal, expected outcome (another app grabbed the hotkey first), not
  /// an error: the caller keeps the previous binding and tells the user.
  Future<bool> registerHotkey(HotkeyDescriptor descriptor);

  /// Unregisters every hotkey this app owns.
  Future<void> clearHotkey();

  /// Shows the popup, optionally near the cursor/tray icon.
  Future<void> showPopup({required bool nearCursor});

  /// Hides the popup without stopping the background work.
  Future<void> hidePopup();

  /// True while the popup is on screen.
  Future<bool> get popupVisible;

  /// Brings the main window forward (tray "Open A.R.M.X").
  Future<void> focusMainWindow();

  /// Hides the main window to the tray instead of terminating the process.
  Future<void> minimizeToTray();

  /// Fully exits the process (tray "Quit").
  Future<void> quit();
}

/// Does-nothing shell: no tray, no hotkey, no popup.
///
/// Used on mobile (where the Android foreground service from step 2 owns background mode),
/// in unit tests and whenever the desktop plugins are unavailable.
class NoopDesktopShell implements DesktopShell {
  /// Creates the no-op shell.
  const NoopDesktopShell();

  TrayVisualState _state = TrayVisualState.idle;
  HotkeyDescriptor? _hotkey;
  bool _popupVisible = false;
  bool _started = false;

  /// Last visual state handed to [updateTray] (asserted by tests).
  TrayVisualState get state => _state;

  /// Hotkey currently "registered" (asserted by tests).
  HotkeyDescriptor? get hotkey => _hotkey;

  /// Number of [updateTray] calls (asserted by tests).
  int updates = 0;

  /// Last menu handed to [updateTray], so tests can prove the off-switch is always there.
  List<TrayMenuItem> lastMenu = const <TrayMenuItem>[];

  /// Last tooltip handed to [updateTray].
  String? lastTooltip;

  /// How many times the window was hidden to the tray (never a quit).
  int minimizeCount = 0;

  /// How many times the process was asked to exit (explicit Quit only).
  int quitCount = 0;

  /// What [registerHotkey] reports; `false` simulates "another app owns this combination".
  bool registrationResult = true;

  @override
  Future<void> start(DesktopShellCallbacks callbacks) async {
    _started = true;
  }

  @override
  Future<void> stop() async {
    _started = false;
    _hotkey = null;
  }

  @override
  Future<void> updateTray({
    required TrayVisualState state,
    required bool darkIcon,
    required String tooltip,
    required List<TrayMenuItem> menu,
  }) async {
    _state = state;
    updates++;
    lastMenu = menu;
    lastTooltip = tooltip;
  }

  @override
  Future<bool> registerHotkey(HotkeyDescriptor descriptor) async {
    if (!registrationResult) {
      // A refused binding keeps the previous one active, exactly like the native adapter.
      return false;
    }
    _hotkey = descriptor;
    return true;
  }

  @override
  Future<void> clearHotkey() async {
    _hotkey = null;
  }

  @override
  Future<void> showPopup({required bool nearCursor}) async {
    _popupVisible = true;
  }

  @override
  Future<void> hidePopup() async {
    _popupVisible = false;
  }

  @override
  Future<bool> get popupVisible async => _popupVisible;

  @override
  Future<void> focusMainWindow() async {}

  @override
  Future<void> minimizeToTray() async {
    minimizeCount++;
  }

  @override
  Future<void> quit() async {
    quitCount++;
  }

  /// True after [start] (asserted by tests).
  bool get isStarted => _started;
}
