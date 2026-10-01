// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_shell.dart';

/// Native implementation of [DesktopShell] for Windows, macOS and Linux.
///
/// Pinned plugin versions (see `pubspec.yaml` and `docs/decisions/0002-dependency-pins.md`):
/// * `tray_manager: 0.5.3` — the classic `trayManager` + `TrayListener` API. Version 0.7.0
///   rewrites the plugin on top of `libnativeapi`; when that release lands on pub.dev this
///   adapter moves to the new API and nothing else in the app changes.
/// * `hotkey_manager: 0.2.3` — `HotKey`/`HotKeyModifier` + `hotKeyManager.register`.
/// * `window_manager: 0.5.2` — frameless, always-on-top, position, prevent-close.
///
/// Every plugin call is confined to this file on purpose: the tray state machine, the
/// hotkey conflict handling and the readiness checklist stay in pure Dart so they can be
/// unit-tested without a desktop host.
class NativeDesktopShell implements DesktopShell {
  /// Creates the native shell over [iconDirectory] (where the generated tray PNGs live).
  NativeDesktopShell({required this.iconDirectory});

  /// Directory holding the generated tray icons, e.g. `assets/tray`.
  final String iconDirectory;

  DesktopShellCallbacks? _callbacks;
  final _TrayBridge _tray = _TrayBridge();
  bool _started = false;
  HotkeyDescriptor? _registered;
  Size? _normalSize;
  Offset? _normalPosition;
  bool _popupMode = false;

  static const Size _popupSize = Size(440, 640);

  @override
  Future<void> start(DesktopShellCallbacks callbacks) async {
    _callbacks = callbacks;
    if (!_isDesktop) {
      return;
    }
    await trayManager.setIcon(_iconPath(TrayVisualState.idle));
    await trayManager.setToolTip('A.R.M.X AI');
    trayManager.addListener(_tray);
    _tray.onActivate = _onActivate;
    // A previous hot reload or crash may still own the binding.
    await hotKeyManager.unregisterAll();
    _started = true;
  }

  @override
  Future<void> stop() async {
    if (!_started) {
      return;
    }
    await clearHotkey();
    trayManager.removeListener(_tray);
    await trayManager.destroy();
    _started = false;
  }

  @override
  Future<void> updateTray({
    required TrayVisualState state,
    required bool darkIcon,
    required String tooltip,
    required List<TrayMenuItem> menu,
  }) async {
    if (!_started) {
      return;
    }
    // macOS renders template (monochrome) images so the icon follows the menu-bar
    // appearance; the state is still distinguishable by shape and tooltip. Windows and
    // Linux keep the coloured icon. See docs/desktop-mode.md § Tray icon states.
    await trayManager.setIcon(_iconPath(state, darkIcon: darkIcon), isTemplate: Platform.isMacOS);
    await trayManager.setToolTip(tooltip);
    await trayManager.setContextMenu(_buildMenu(menu));
  }

  Menu _buildMenu(List<TrayMenuItem> items) {
    final menu = Menu();
    menu.items = <MenuItem>[
      for (final item in items)
        MenuItem(
          label: item.label,
          disabled: !item.enabled,
          onClick: (_) => _callbacks?.onMenuCommand(item.id),
        ),
    ];
    return menu;
  }

  @override
  Future<bool> registerHotkey(HotkeyDescriptor descriptor) async {
    if (!_started) {
      return true;
    }
    final hotKey = _toHotKey(descriptor);
    if (hotKey == null) {
      // Unknown key label: refuse rather than silently binding something else.
      return false;
    }
    await hotKeyManager.unregisterAll();
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: _onHotkeyFired,
      );
    } on Object {
      // The OS already owns that combination. Restore whatever binding we had before so the
      // app never ends up with no hotkey at all.
      final previous = _registered;
      if (previous != null) {
        final restore = _toHotKey(previous);
        if (restore != null) {
          await hotKeyManager.register(restore, keyDownHandler: _onHotkeyFired);
        }
      }
      return false;
    }
    _registered = descriptor;
    return true;
  }

  void _onHotkeyFired() => _callbacks?.onHotkey();

  @override
  Future<void> clearHotkey() async {
    if (!_started) {
      return;
    }
    await hotKeyManager.unregisterAll();
    _registered = null;
  }

  @override
  Future<void> showPopup({required bool nearCursor}) async {
    if (!_started) {
      return;
    }
    if (!_popupMode) {
      _normalSize = await windowManager.getSize();
      _normalPosition = await windowManager.getPosition();
      _popupMode = true;
    }
    await windowManager.setResizable(false);
    await windowManager.setMovable(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setMinimumSize(_popupSize);
    await windowManager.setSize(_popupSize);
    // The popup anchors to the bottom-right of the main window: window_manager exposes no
    // cursor query, and a per-OS native cursor read (GetCursorPos / NSEvent.mouseLocation /
    // XQueryPointer) is a documented follow-up in docs/desktop-mode.md.
    final anchor = _normalPosition ?? const Offset(0, 0);
    final normal = _normalSize ?? const Size(1280, 800);
    await windowManager.setPosition(Offset(
      anchor.dx + (normal.width - _popupSize.width),
      anchor.dy + (normal.height - _popupSize.height),
    ));
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hidePopup() async {
    if (!_started) {
      return;
    }
    if (_popupMode) {
      _popupMode = false;
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setMinimumSize(const Size(720, 560));
      await windowManager.setResizable(true);
      if (_normalSize != null) {
        await windowManager.setSize(_normalSize!);
      }
      if (_normalPosition != null) {
        await windowManager.setPosition(_normalPosition!);
      }
      await windowManager.setBackgroundColor(const Color(0xFF0B0F14));
    }
    await windowManager.hide();
  }

  @override
  Future<bool> get popupVisible async => _popupMode;

  @override
  Future<void> focusMainWindow() async {
    if (!_started) {
      return;
    }
    if (_popupMode) {
      await hidePopup();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> minimizeToTray() async {
    if (!_started) {
      return;
    }
    await windowManager.hide();
  }

  @override
  Future<void> quit() async {
    await stop();
    await windowManager.setPreventClose(false);
    await windowManager.close();
    exit(0);
  }

  void _onActivate() {
    // A left click on the tray icon opens the main window; the hotkey handler owns the
    // popup toggle so both paths stay in sync.
    _callbacks?.onMenuCommand('open');
  }

  /// `assets/tray/tray_<state>[_dark]_64.png`.
  ///
  /// Both variants are committed at 32 and 64 px so the icon stays crisp on a HiDPI taskbar
  /// without the app having to generate it at runtime.
  String _iconPath(TrayVisualState state, {required bool darkIcon}) {
    final name = switch (state) {
      TrayVisualState.idle => 'idle',
      TrayVisualState.listening => 'listening',
      TrayVisualState.thinking => 'thinking',
      TrayVisualState.muted => 'muted',
      TrayVisualState.killed => 'killed',
    };
    final variant = darkIcon ? '' : '_dark';
    return '$iconDirectory/tray_${name}${variant}_64.png';
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Translates labels into plugin key codes; `null` when the label is unknown.
  static HotKey? _toHotKey(HotkeyDescriptor descriptor) {
    final key = _keyFor(descriptor.keyLabel);
    if (key == null) {
      return null;
    }
    final modifiers = <HotKeyModifier>[
      for (final modifier in descriptor.modifiers)
        switch (modifier) {
          'ctrl' || 'control' => HotKeyModifier.control,
          'alt' || 'option' => HotKeyModifier.alt,
          'shift' => HotKeyModifier.shift,
          'meta' || 'cmd' || 'command' || 'super' || 'win' => HotKeyModifier.meta,
          _ => HotKeyModifier.control,
        },
    ];
    return HotKey(
      key: key,
      modifiers: modifiers,
      scope: descriptor.systemWide ? HotKeyScope.system : HotKeyScope.inapp,
    );
  }

  static const Map<String, PhysicalKeyboardKey> _namedKeys = <String, PhysicalKeyboardKey>{
    'space': PhysicalKeyboardKey.space,
    'enter': PhysicalKeyboardKey.enter,
    'return': PhysicalKeyboardKey.enter,
    'esc': PhysicalKeyboardKey.escape,
    'escape': PhysicalKeyboardKey.escape,
    'tab': PhysicalKeyboardKey.tab,
    'backspace': PhysicalKeyboardKey.backspace,
    'delete': PhysicalKeyboardKey.delete,
    'insert': PhysicalKeyboardKey.insert,
    'home': PhysicalKeyboardKey.home,
    'end': PhysicalKeyboardKey.end,
    'pageup': PhysicalKeyboardKey.pageUp,
    'pagedown': PhysicalKeyboardKey.pageDown,
    'up': PhysicalKeyboardKey.arrowUp,
    'down': PhysicalKeyboardKey.arrowDown,
    'left': PhysicalKeyboardKey.arrowLeft,
    'right': PhysicalKeyboardKey.arrowRight,
    'slash': PhysicalKeyboardKey.slash,
    'minus': PhysicalKeyboardKey.minus,
    'equal': PhysicalKeyboardKey.equal,
    'comma': PhysicalKeyboardKey.comma,
    'period': PhysicalKeyboardKey.period,
    'semicolon': PhysicalKeyboardKey.semicolon,
    'quote': PhysicalKeyboardKey.quote,
    'backquote': PhysicalKeyboardKey.backquote,
    'backslash': PhysicalKeyboardKey.backslash,
    'bracketleft': PhysicalKeyboardKey.bracketLeft,
    'bracketright': PhysicalKeyboardKey.bracketRight,
  };

  /// Resolves a label to a physical key.
  ///
  /// Letters, digits and function keys are computed from the USB HID usage table Flutter
  /// uses (`keyA` = 0x00070004), so the table above only has to cover the punctuation and
  /// navigation keys.
  static PhysicalKeyboardKey? _keyFor(String label) {
    final named = _namedKeys[label];
    if (named != null) {
      return named;
    }
    if (label.length == 1) {
      final code = label.codeUnitAt(0);
      if (code >= 0x61 && code <= 0x7a) {
        return PhysicalKeyboardKey.fromKeyId(0x00070000 | (code - 0x61 + 0x04));
      }
      if (code >= 0x30 && code <= 0x39) {
        return PhysicalKeyboardKey.fromKeyId(0x00070000 | (code - 0x30 + 0x27));
      }
    }
    final functionKey = RegExp(r'^f(\d{1,2})$').firstMatch(label);
    if (functionKey != null) {
      final number = int.parse(functionKey.group(1)!);
      if (number >= 1 && number <= 24) {
        return PhysicalKeyboardKey.fromKeyId(0x00070000 | (number - 1 + 0x3a));
      }
    }
    return null;
  }
}

/// Bridges [TrayListener] callbacks to the shell's owner.
///
/// Menu rows are wired directly in `_buildMenu`, so this listener only has to translate a
/// plain left click on the icon (which the OS does not turn into a menu event).
class _TrayBridge extends TrayListener {
  /// Raised for a plain (left) click on the tray icon.
  VoidCallback? onActivate;

  @override
  void onTrayIconMouseDown() {
    onActivate?.call();
  }
}
