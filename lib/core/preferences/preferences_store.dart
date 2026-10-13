// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret user preferences.
///
/// ## Why this is separate from `TokenStore`
///
/// Nothing in this class is a credential, so it lives in `SharedPreferences` where it can
/// be read synchronously at launch. Tokens live in `flutter_secure_storage` and nowhere
/// else (§5). Keeping the two apart is what makes "never store tokens in SharedPreferences
/// in plaintext" a structural property rather than a rule someone has to remember.
@immutable
class AppPreferences {
  /// Creates a preferences snapshot.
  const AppPreferences({
    this.themeMode = ThemeMode.dark,
    this.localeCode = 'en',
    this.railCollapsed = false,
    this.notifyAlarms = true,
    this.notifyToolCalls = true,
    this.notifyDeployments = true,
    this.autoSendDefault = false,
    this.guestGreeterKillEngaged = false,
  });

  /// Dark is the product default (§3).
  final ThemeMode themeMode;

  /// `en` or `bn`.
  final String localeCode;

  /// Whether the tablet rail starts collapsed. The user's choice persists; the breakpoint
  /// only supplies the *initial* value.
  final bool railCollapsed;

  /// Notify when an alarm fires on any device.
  final bool notifyAlarms;

  /// Notify when a MEDIUM/HIGH-risk tool call needs a decision.
  final bool notifyToolCalls;

  /// Notify when a web deployment finishes.
  final bool notifyDeployments;

  /// Default for the messaging auto-send switch on a newly added contact. Defaults to
  /// **false** (draft only), because auto-sending on someone's behalf is the riskier
  /// default.
  final bool autoSendDefault;

  /// Whether the guest-greeter camera kill-switch is engaged. Persisted so a restart does
  /// not silently re-enable a camera the owner switched off.
  final bool guestGreeterKillEngaged;

  /// Copy with changes.
  AppPreferences copyWith({
    ThemeMode? themeMode,
    String? localeCode,
    bool? railCollapsed,
    bool? notifyAlarms,
    bool? notifyToolCalls,
    bool? notifyDeployments,
    bool? autoSendDefault,
    bool? guestGreeterKillEngaged,
  }) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        localeCode: localeCode ?? this.localeCode,
        railCollapsed: railCollapsed ?? this.railCollapsed,
        notifyAlarms: notifyAlarms ?? this.notifyAlarms,
        notifyToolCalls: notifyToolCalls ?? this.notifyToolCalls,
        notifyDeployments: notifyDeployments ?? this.notifyDeployments,
        autoSendDefault: autoSendDefault ?? this.autoSendDefault,
        guestGreeterKillEngaged:
            guestGreeterKillEngaged ?? this.guestGreeterKillEngaged,
      );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.themeMode == themeMode &&
      other.localeCode == localeCode &&
      other.railCollapsed == railCollapsed &&
      other.notifyAlarms == notifyAlarms &&
      other.notifyToolCalls == notifyToolCalls &&
      other.notifyDeployments == notifyDeployments &&
      other.autoSendDefault == autoSendDefault &&
      other.guestGreeterKillEngaged == guestGreeterKillEngaged;

  @override
  int get hashCode => Object.hash(
        themeMode,
        localeCode,
        railCollapsed,
        notifyAlarms,
        notifyToolCalls,
        notifyDeployments,
        autoSendDefault,
        guestGreeterKillEngaged,
      );
}

/// Reads and writes [AppPreferences].
abstract interface class PreferencesStore {
  /// Loads the current preferences, applying defaults for anything absent.
  Future<AppPreferences> load();

  /// Persists [preferences].
  Future<void> save(AppPreferences preferences);
}

/// `shared_preferences`-backed store.
class SharedPreferencesStore implements PreferencesStore {
  /// Creates a store.
  const SharedPreferencesStore();

  static const String _theme = 'armx.prefs.theme';
  static const String _locale = 'armx.prefs.locale';
  static const String _rail = 'armx.prefs.railCollapsed';
  static const String _notifyAlarms = 'armx.prefs.notify.alarms';
  static const String _notifyTools = 'armx.prefs.notify.tools';
  static const String _notifyDeploys = 'armx.prefs.notify.deploys';
  static const String _autoSend = 'armx.prefs.messaging.autoSend';
  static const String _guestKill = 'armx.prefs.guest.kill';

  @override
  Future<AppPreferences> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return AppPreferences(
      themeMode: _themeFrom(prefs.getString(_theme)),
      localeCode: _localeFrom(prefs.getString(_locale)),
      railCollapsed: prefs.getBool(_rail) ?? false,
      notifyAlarms: prefs.getBool(_notifyAlarms) ?? true,
      notifyToolCalls: prefs.getBool(_notifyTools) ?? true,
      notifyDeployments: prefs.getBool(_notifyDeploys) ?? true,
      autoSendDefault: prefs.getBool(_autoSend) ?? false,
      guestGreeterKillEngaged: prefs.getBool(_guestKill) ?? false,
    );
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_theme, preferences.themeMode.name);
    await prefs.setString(_locale, preferences.localeCode);
    await prefs.setBool(_rail, preferences.railCollapsed);
    await prefs.setBool(_notifyAlarms, preferences.notifyAlarms);
    await prefs.setBool(_notifyTools, preferences.notifyToolCalls);
    await prefs.setBool(_notifyDeploys, preferences.notifyDeployments);
    await prefs.setBool(_autoSend, preferences.autoSendDefault);
    await prefs.setBool(_guestKill, preferences.guestGreeterKillEngaged);
  }

  static ThemeMode _themeFrom(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  /// Only the two shipped languages are accepted; an unknown value falls back to English
  /// rather than to a locale with no ARB file (which would render raw keys).
  static String _localeFrom(String? raw) =>
      raw == 'bn' || raw == 'en' ? raw! : 'en';
}

/// In-memory store for tests.
class InMemoryPreferencesStore implements PreferencesStore {
  /// Creates a store seeded with [initial].
  InMemoryPreferencesStore([this._values = const AppPreferences()]);

  AppPreferences _values;

  /// The current values, for assertions.
  AppPreferences get values => _values;

  @override
  Future<AppPreferences> load() async => _values;

  @override
  Future<void> save(AppPreferences preferences) async => _values = preferences;
}
