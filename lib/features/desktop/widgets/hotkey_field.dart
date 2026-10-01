// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/platform/desktop_shell.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/widgets/armx_controls.dart';
import '../../../core/widgets/armx_tile.dart';
import '../../../core/widgets/status_pill.dart';

/// Records a new global hotkey and proves the OS accepts it before committing.
///
/// A combination already owned by another application is rejected with "already in use"
/// and the recorder stays open, instead of silently doing nothing the next time the user
/// presses it. At least one modifier is required so a plain letter can never be stolen.
class HotkeyRecorderField extends StatefulWidget {
  /// Creates the recorder for [current].
  const HotkeyRecorderField({
    required this.current,
    required this.onRecorded,
    super.key,
  });

  /// Descriptor currently in force (already rendered as `Ctrl + Alt + Space`).
  final String current;

  /// Commits [descriptor]; returns false when the OS refused the combination.
  final Future<bool> Function(HotkeyDescriptor descriptor) onRecorded;

  @override
  State<HotkeyRecorderField> createState() => _HotkeyRecorderFieldState();
}

class _HotkeyRecorderFieldState extends State<HotkeyRecorderField> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'hotkey-recorder');
  bool _recording = false;
  String? _preview;
  bool _conflict = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final label = _recording ? (_preview ?? l10n.desktopHotkeyListening) : widget.current;

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: _recording,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ArmxTile(
            title: l10n.desktopHotkeyTitle,
            subtitle: label,
            leading: Icon(
              _recording ? Icons.keyboard_alt_outlined : Icons.keyboard_command_key_rounded,
              color: _recording ? colors.cyan : colors.muted,
            ),
            accent: _recording ? colors.cyan : null,
            trailing: StatusPill(
              label: _recording ? l10n.desktopHotkeyRecording : l10n.desktopHotkeyChange,
              tone: _recording ? SeverityTone.info : SeverityTone.neutral,
              compact: true,
            ),
            onTap: _toggleRecording,
          ),
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
              child: Text(
                l10n.desktopHotkeyHint,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
              ),
            ),
          if (_conflict)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.error_outline, size: 14, color: colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.desktopHotkeyConflict,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _toggleRecording() {
    setState(() {
      _recording = !_recording;
      _preview = null;
      _conflict = false;
    });
    if (_recording) {
      _focusNode.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_recording || event is! KeyDownEvent || event is KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final modifiers = <String>[
      if (keyboard.isControlPressed) 'ctrl',
      if (keyboard.isAltPressed) 'alt',
      if (keyboard.isShiftPressed) 'shift',
      if (keyboard.isMetaPressed) 'meta',
    ];
    if (modifiers.isEmpty) {
      // Never bind a bare key: it would break typing everywhere.
      return KeyEventResult.ignored;
    }
    final label = _labelFor(event.physicalKey);
    if (label == null) {
      return KeyEventResult.ignored;
    }
    unawaited(_commit(HotkeyDescriptor(keyLabel: label, modifiers: modifiers)));
    return KeyEventResult.handled;
  }

  Future<void> _commit(HotkeyDescriptor descriptor) async {
    setState(() => _preview = descriptor.describe());
    final accepted = await widget.onRecorded(descriptor);
    if (!mounted) {
      return;
    }
    setState(() {
      _recording = !accepted;
      _conflict = !accepted;
    });
  }

  /// `PhysicalKeyboardKey.debugName` → descriptor label (`Key A` → `a`).
  static String? _labelFor(PhysicalKeyboardKey key) {
    final name = key.debugName?.toLowerCase();
    if (name == null || name.isEmpty) {
      return null;
    }
    final named = <String, String>{
      'space': 'space',
      'escape': 'esc',
      'enter': 'enter',
      'tab': 'tab',
      'backspace': 'backspace',
      'delete': 'delete',
      'insert': 'insert',
      'home': 'home',
      'end': 'end',
      'page up': 'pageup',
      'page down': 'pagedown',
      'arrow up': 'up',
      'arrow down': 'down',
      'arrow left': 'left',
      'arrow right': 'right',
      'minus': 'minus',
      'equal': 'equal',
      'comma': 'comma',
      'period': 'period',
      'slash': 'slash',
      'semicolon': 'semicolon',
      'quote': 'quote',
      'bracket left': 'bracketleft',
      'bracket right': 'bracketright',
      'backslash': 'backslash',
      'backquote': 'backquote',
    };
    if (named.containsKey(name)) {
      return named[name];
    }
    if (name.startsWith('key ') && name.length == 5) {
      return name.substring(4);
    }
    if (name.startsWith('digit ') && name.length == 7) {
      return name.substring(6);
    }
    if (RegExp(r'^f\d{1,2}$').hasMatch(name)) {
      return name;
    }
    return null;
  }
}
