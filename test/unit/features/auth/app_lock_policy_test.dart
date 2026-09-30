// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/features/auth/lock/app_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// The auto-lock timeout is a pure decision — these tests are its specification:
/// grace periods, the "immediately" option and the fail-closed clock rule.
void main() {
  final now = DateTime.utc(2026, 9, 30, 12);

  group('AppLockPolicy.shouldLockOnResume', () {
    test('a disabled setting never locks on resume', () {
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: false,
          timeoutSeconds: 0,
          backgroundedAt: now.subtract(const Duration(hours: 3)),
          now: now,
        ),
        isFalse,
      );
    });

    test('never backgrounded means nothing to evaluate', () {
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: true,
          timeoutSeconds: 30,
          backgroundedAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('timeout 0 locks the instant the app is backgrounded', () {
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: true,
          timeoutSeconds: 0,
          backgroundedAt: now.subtract(const Duration(milliseconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('inside the grace period the session stays open', () {
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: true,
          timeoutSeconds: 30,
          backgroundedAt: now.subtract(const Duration(seconds: 29)),
          now: now,
        ),
        isFalse,
      );
    });

    test('the moment the timeout elapses the gate re-locks', () {
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: true,
          timeoutSeconds: 30,
          backgroundedAt: now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        isTrue,
      );
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: true,
          timeoutSeconds: 60,
          backgroundedAt: now.subtract(const Duration(minutes: 2)),
          now: now,
        ),
        isTrue,
      );
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: true,
          timeoutSeconds: 300,
          backgroundedAt: now.subtract(const Duration(minutes: 5, seconds: 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a clock that moved backwards fails closed (locks)', () {
      expect(
        AppLockPolicy.shouldLockOnResume(
          enabled: true,
          timeoutSeconds: 300,
          backgroundedAt: now.add(const Duration(minutes: 10)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
