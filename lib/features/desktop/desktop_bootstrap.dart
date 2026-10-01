// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale, PlatformDispatcher;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/platform/single_instance.dart';
import '../../core/providers.dart';
import '../../core/utils/clock.dart';
import '../../data/db/armx_database.dart';
import 'desktop_controller.dart';
import 'desktop_state.dart';
import 'desktop_menu_labels.dart';

/// Boots the desktop shell: single instance, tray, hotkey, autostart, device probe.
///
/// Order matters and is the documented startup contract (`docs/desktop-mode.md`):
/// 1. **single instance first** — if another A.R.M.X already owns the lock file this
///    process tells it to show the popup and then exits, so a hotkey press can never leave
///    a second, invisible copy running;
/// 2. **tray** — the visible off-switch. Nothing else is registered until the tray is
///    live, because a background process with no tray icon is indistinguishable from
///    malware and gets quarantined by Gatekeeper/SmartScreen;
/// 3. **hotkey + autostart** — re-registered from persisted preferences on every start, so
///    a rebind or a toggle in Settings survives a restart;
/// 4. **device probe** — fills the tooltip and decides typed-input mode.
Future<void> bootstrapDesktopShell(
  ProviderContainer container, {
  required AppConfig config,
  required ArmxDatabase database,
  required Clock clock,
}) async {
  if (kIsWeb || !_isDesktop) {
    return;
  }
  config; // reserved for the future real transport; keeps the signature honest.
  database; // owned by the container.
  clock; // owned by the container.

  final lockPath = '${Directory.systemTemp.path}/armx_desktop.lock';
  final instance = await SingleInstanceGuard.acquire(lockPath);
  if (!instance.isPrimary) {
    // A second launch is a request to show the first one. Exit without touching the tray.
    instance.sendActivate();
    await _exitProcess();
    return;
  }
  SingleInstance.onActivate = () =>
      unawaited(container.read(desktopControllerProvider.notifier).openPopup());

  final controller = container.read(desktopControllerProvider.notifier);
  final preferences = container.read(preferencesRepositoryProvider);
  final hotkey = controller.state.hotkey;

  final locale = await _resolveLocale(container);
  controller.setMenuLabels(await DesktopMenuLabels.forLocale(locale));

  await controller.initializeShell();
  controller.onKillSwitchChanged((bool engaged) {
    // The kill-switch stops listening and closes the socket exactly as on mobile; the tray
    // icon turns red and the popup is read-only until the app window re-enables it.
    container.read(appLoggerProvider).w('kill-switch ${engaged ? 'engaged' : 'released'}');
  });
  controller.onConnectionChanged((bool connected) {
    container.read(appLoggerProvider).d('desktop shell connection: $connected');
  });

  final stored = await preferences.load();
  await controller.setLaunchAtLogin(stored.autostartEnabled);

  // Re-register the persisted hotkey so a rebind survives a restart.
  final status = await controller.rebindHotkey(hotkey);
  if (status != HotkeyStatus.registered) {
    container.read(appLoggerProvider).w('hotkey ${hotkey.describe()} is unavailable');
  }

  await controller.refreshDevices();
  debugPrint('armx: desktop shell ready (tray + ${hotkey.describe()})');
}

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Stored language preference, or the platform locale when the user chose "system".
Future<Locale?> _resolveLocale(ProviderContainer container) async {
  final stored = (await container.read(preferencesRepositoryProvider).load()).language;
  if (stored == 'en' || stored == 'bn') {
    return Locale(stored);
  }
  return PlatformDispatcher.instance.locale;
}

Future<void> _exitProcess() async {
  // Give the OS a moment to deliver the IPC message before this process goes away.
  await Future<void>.delayed(const Duration(milliseconds: 120));
  exit(0);
}
