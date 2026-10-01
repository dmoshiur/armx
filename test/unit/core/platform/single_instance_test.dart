// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:io';

import 'package:armx_ai/core/platform/single_instance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('armx_single_instance_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('the first process is primary and holds the lock file', () async {
    final path = '${tempDir.path}/armx.lock';
    final guard = await SingleInstanceGuard.acquire(path);

    expect(guard.isPrimary, isTrue);
    expect(File(path).existsSync(), isTrue);
    await guard.release();
  });

  test('a second launch is told to activate the first, then exits', () async {
    final path = '${tempDir.path}/armx.lock';
    final first = await SingleInstanceGuard.acquire(path);

    var activated = 0;
    SingleInstance.onActivate = () => activated++;

    final second = await SingleInstanceGuard.acquire(path);
    expect(second.isPrimary, isFalse);
    expect(second.sendActivate(), completes);

    // The message is delivered over loopback, so give the server a moment to read it.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(activated, greaterThan(0));

    SingleInstance.onActivate = null;
    await first.release();
    await second.release();
  });

  test('a stale lock file (no listener) degrades to primary instead of blocking startup',
      () async {
    final path = '${tempDir.path}/armx.lock';
    File(path).writeAsStringSync('{"port": 1}');

    final guard = await SingleInstanceGuard.acquire(path);
    expect(guard.isPrimary, isTrue, reason: 'port 1 is closed, so nobody else is running');
    await guard.release();
  });

  test('a corrupted lock file is ignored and the app still starts', () async {
    final path = '${tempDir.path}/armx.lock';
    File(path).writeAsStringSync('not json at all');

    final guard = await SingleInstanceGuard.acquire(path);
    expect(guard.isPrimary, isTrue);
    await guard.release();
  });

  test('release lets the next process take over', () async {
    final path = '${tempDir.path}/armx.lock';
    final first = await SingleInstanceGuard.acquire(path);
    await first.release();

    final second = await SingleInstanceGuard.acquire(path);
    expect(second.isPrimary, isTrue);
    await second.release();
  });
}
