// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../db/armx_database.dart';
import '../models/preferences.dart';

/// Reads and writes the user's app preferences.
///
/// All values are non-secret, so they live in the drift database. Parsing is defensive:
/// a corrupted row falls back to its default instead of breaking the launch sequence.
class PreferencesRepository {
  /// Creates the repository over [database].
  PreferencesRepository(this._database);

  final ArmxDatabase _database;

  /// Loads the current preferences.
  Future<AppPreferences> load() async => _map(await _database.readAllSettings());

  /// Reacts to preference changes (drives theme, locale and the settings screen).
  Stream<AppPreferences> watch() =>
      _database.select(_database.settingsEntries).watch().map((rows) {
        return _map(<String, String>{for (final row in rows) row.key: row.value});
      });

  /// Persists several keys at once.
  Future<void> writeAll(Map<String, String> values) async {
    for (final entry in values.entries) {
      await _database.writeSetting(entry.key, entry.value);
    }
  }

  /// Sets the theme mode preference (`system`/`light`/`dark`).
  Future<void> setThemeMode(String value) =>
      _database.writeSetting(PreferenceKeys.themeMode, value);

  /// Sets the language preference (`system`/`en`/`bn`).
  Future<void> setLanguage(String code) =>
      _database.writeSetting(PreferenceKeys.language, code);

  /// Enables or disables wake-word listening.
  Future<void> setWakeWordEnabled(bool enabled) =>
      _database.writeSetting(PreferenceKeys.wakeWordEnabled, enabled.toString());

  /// Sets the wake word phrase (default `Armex`).
  Future<void> setWakeWordPhrase(String phrase) =>
      _database.writeSetting(PreferenceKeys.wakeWordPhrase, phrase);

  /// Sets wake-word sensitivity (0.0–1.0).
  Future<void> setWakeWordSensitivity(double value) => _database.writeSetting(
        PreferenceKeys.wakeWordSensitivity,
        value.clamp(0.0, 1.0).toString(),
      );

  /// Sets the face-match threshold used by the vision module.
  Future<void> setFaceMatchThreshold(double value) => _database.writeSetting(
        PreferenceKeys.faceMatchThreshold,
        value.clamp(0.10, 0.99).toString(),
      );

  /// Enables or disables the palm-open gesture.
  Future<void> setPalmGestureEnabled(bool enabled) =>
      _database.writeSetting(PreferenceKeys.palmGestureEnabled, enabled.toString());

  /// One-tap camera privacy switch.
  Future<void> setCameraEnabled(bool enabled) =>
      _database.writeSetting(PreferenceKeys.cameraEnabled, enabled.toString());

  /// Microphone privacy switch.
  Future<void> setMicrophoneEnabled(bool enabled) =>
      _database.writeSetting(PreferenceKeys.microphoneEnabled, enabled.toString());

  /// Whether assistant replies are spoken automatically.
  Future<void> setTtsAutoSpeak(bool enabled) =>
      _database.writeSetting(PreferenceKeys.ttsAutoSpeak, enabled.toString());

  /// Haptic feedback for approvals and the kill-switch.
  Future<void> setHapticsEnabled(bool enabled) =>
      _database.writeSetting(PreferenceKeys.hapticsEnabled, enabled.toString());

  /// Whether the app requires biometric/PIN unlock on launch.
  Future<void> setAppLockEnabled(bool enabled) =>
      _database.writeSetting(PreferenceKeys.appLockEnabled, enabled.toString());

  /// Whether background activity recognition may run.
  Future<void> setActivityRecognitionEnabled(bool enabled) =>
      _database.writeSetting(PreferenceKeys.activityRecognitionEnabled, enabled.toString());

  /// Remembers the last server URL so the pairing form is prefilled next time.
  Future<void> setLastServerUrl(String url) =>
      _database.writeSetting(PreferenceKeys.lastServerUrl, url);

  /// Erases every preference row (used by the privacy "reset app" action).
  Future<void> resetAll() async {
    final keys = await _database.readAllSettings();
    for (final key in keys.keys) {
      await _database.deleteSetting(key);
    }
  }

  AppPreferences _map(Map<String, String> raw) => AppPreferences(
        themeMode: _string(raw, PreferenceKeys.themeMode, 'system'),
        language: _string(raw, PreferenceKeys.language, 'system'),
        wakeWordEnabled: _bool(raw, PreferenceKeys.wakeWordEnabled, false),
        wakeWordPhrase: _string(raw, PreferenceKeys.wakeWordPhrase, 'Armex'),
        wakeWordSensitivity: _double(raw, PreferenceKeys.wakeWordSensitivity, 0.6),
        faceMatchThreshold: _double(
          raw,
          PreferenceKeys.faceMatchThreshold,
          AppPreferences().faceMatchThreshold,
        ),
        palmGestureEnabled: _bool(raw, PreferenceKeys.palmGestureEnabled, true),
        cameraEnabled: _bool(raw, PreferenceKeys.cameraEnabled, false),
        microphoneEnabled: _bool(raw, PreferenceKeys.microphoneEnabled, false),
        ttsAutoSpeak: _bool(raw, PreferenceKeys.ttsAutoSpeak, true),
        hapticsEnabled: _bool(raw, PreferenceKeys.hapticsEnabled, true),
        appLockEnabled: _bool(raw, PreferenceKeys.appLockEnabled, true),
        activityRecognitionEnabled: _bool(raw, PreferenceKeys.activityRecognitionEnabled, false),
        lastServerUrl: _string(raw, PreferenceKeys.lastServerUrl, ''),
      );

  static String _string(Map<String, String> raw, String key, String fallback) {
    final value = raw[key];
    return value == null || value.isEmpty ? fallback : value;
  }

  static bool _bool(Map<String, String> raw, String key, bool fallback) =>
      switch (raw[key]) {
        'true' => true,
        'false' => false,
        _ => fallback,
      };

  static double _double(Map<String, String> raw, String key, double fallback) =>
      double.tryParse(raw[key] ?? '') ?? fallback;
}
