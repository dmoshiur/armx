// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/db/armx_database.dart';
import 'package:armx_ai/data/models/preferences.dart';
import 'package:armx_ai/data/repositories/preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ArmxDatabase database;
  late PreferencesRepository repository;

  setUp(() {
    database = ArmxDatabase(NativeDatabase.memory());
    repository = PreferencesRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('the login toggle defaults to ON (background mode must survive a restart)', () async {
    final prefs = await repository.load();
    expect(prefs.autostartEnabled, isTrue);
  });

  test('turning it off persists and is re-read on the next launch', () async {
    await repository.setAutostartEnabled(false);
    expect((await repository.load()).autostartEnabled, isFalse);

    // A "restart" is a fresh repository over the same database file.
    final reloaded = PreferencesRepository(database);
    expect((await reloaded.load()).autostartEnabled, isFalse);
  });

  test('turning it back on persists too', () async {
    await repository.setAutostartEnabled(false);
    await repository.setAutostartEnabled(true);
    expect((await repository.load()).autostartEnabled, isTrue);
  });

  test('the preference is reactive so the settings switch stays in sync', () async {
    final stream = repository.watch();
    final first = await stream.first;
    expect(first.autostartEnabled, isTrue);

    await repository.setAutostartEnabled(false);
    final second = await stream.firstWhere(
      (AppPreferences prefs) => prefs.autostartEnabled != first.autostartEnabled,
    );
    expect(second.autostartEnabled, isFalse);
  });

  test('the stored hotkey survives a restart and round-trips to a descriptor', () async {
    await repository.setDesktopHotkey('meta+shift+space');
    expect((await repository.load()).desktopHotkey, 'meta+shift+space');
  });

  test('a corrupted hotkey preference falls back to the default, not to a crash', () async {
    await repository.setDesktopHotkey('');
    expect((await repository.load()).desktopHotkey, 'ctrl+alt+space');
  });

  test('intercom consent defaults OFF and cannot be set remotely by a missing row', () async {
    final prefs = await repository.load();
    expect(prefs.intercomConsent, isFalse);
    expect(prefs.intercomConsentLocked, isFalse);
    expect(prefs.intercomEnabled, isFalse);
  });

  test('intercom consent is persisted and revocable', () async {
    await repository.setIntercomConsent(true);
    await repository.setIntercomConsentLocked(true);
    expect((await repository.load()).intercomConsent, isTrue);
    expect((await repository.load()).intercomConsentLocked, isTrue);

    await repository.setIntercomConsent(false);
    expect((await repository.load()).intercomConsent, isFalse);
  });

  test('resetAll clears the desktop and intercom switches back to their defaults', () async {
    await repository.setAutostartEnabled(false);
    await repository.setIntercomConsent(true);
    await repository.resetAll();

    final prefs = await repository.load();
    expect(prefs.autostartEnabled, isTrue);
    expect(prefs.intercomConsent, isFalse);
  });
}
