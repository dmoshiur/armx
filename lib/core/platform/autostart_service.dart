// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

/// Registers (or removes) the app from the OS login sequence.
///
/// Per-platform mechanics, all handled by `launch_at_startup: 0.5.1`:
/// * **Windows** — `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` value pointing at
///   the executable. No admin rights needed, visible in Task Manager → Startup apps and
///   in Settings → Apps → Startup, and removable by the user there as well as in-app.
/// * **macOS** — a login item through the bundled `LaunchAtLogin` helper, which uses
///   `SMAppService.mainAppService` on macOS 13+. The item shows up in System Settings →
///   General → Login Items, exactly as the user expects. Requires the one-time Xcode setup
///   documented in the package README and repeated in `docs/desktop-mode.md`.
/// * **Linux** — `~/.config/autostart/armx-ai.desktop` following the XDG autostart spec,
///   honoured by GNOME (Tweaks → Startup Applications), KDE and every other freedesktop
///   session.
abstract interface class AutostartService {
  /// Prepares the plugin (executable path, app name). Must run before the other calls.
  Future<void> setup();

  /// Whether the login entry currently exists.
  Future<bool> get isEnabled;

  /// Creates or removes the login entry.
  Future<void> setEnabled(bool enabled);
}

/// `launch_at_startup`-backed implementation for the three desktop targets.
class LaunchAtStartupService implements AutostartService {
  /// Creates the service for [appName].
  LaunchAtStartupService({this.appName = 'A.R.M.X AI'});

  /// Name written into the registry value / .desktop file.
  final String appName;

  bool _ready = false;

  @override
  Future<void> setup() async {
    if (_ready) {
      return;
    }
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return;
    }
    launchAtStartup.setup(appName: appName, appPath: Platform.resolvedExecutable);
    _ready = true;
  }

  @override
  Future<bool> get isEnabled async {
    try {
      await setup();
      return await launchAtStartup.isEnabled();
    } on Object {
      // A read-only home or a missing helper must not crash the settings screen.
      debugPrint('autostart: isEnabled failed');
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await setup();
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } on Object catch (error) {
      debugPrint('autostart: setEnabled($enabled) failed: $error');
    }
  }
}

/// No-op service: mobile, web and tests.
class NoopAutostartService implements AutostartService {
  /// Creates the no-op service.
  const NoopAutostartService();

  bool _enabled = true;

  @override
  Future<void> setup() async {}

  @override
  Future<bool> get isEnabled async => _enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
  }
}
