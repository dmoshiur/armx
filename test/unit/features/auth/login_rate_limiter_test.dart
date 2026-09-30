// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/features/auth/session/login_rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The login form must never offer an unlimited guessing button: five failures
/// arm an exponential backoff that only a success clears.
void main() {
  final now = DateTime.utc(2026, 9, 30, 12);

  group('LoginRateLimiter', () {
    test('the first four failures do not block the form', () {
      final limiter = LoginRateLimiter();
      for (var i = 0; i < 4; i++) {
        limiter.recordFailure(now);
        expect(limiter.remaining(now), isNull, reason: 'failure ${i + 1} of 4');
      }
      expect(limiter.failures, 4);
    });

    test('the fifth failure arms a 30 second backoff', () {
      final limiter = LoginRateLimiter();
      for (var i = 0; i < 5; i++) {
        limiter.recordFailure(now);
      }
      expect(limiter.remaining(now), const Duration(seconds: 30));
      expect(limiter.remaining(now.add(const Duration(seconds: 29))),
          const Duration(seconds: 1));
    });

    test('further failures double the window and then cap at the maximum', () {
      final limiter = LoginRateLimiter();
      for (var i = 0; i < 5; i++) {
        limiter.recordFailure(now);
      }
      limiter.recordFailure(now); // 6th → 60 s
      expect(limiter.remaining(now), const Duration(seconds: 60));
      limiter.recordFailure(now); // 7th → 120 s
      expect(limiter.remaining(now), const Duration(seconds: 120));
      for (var i = 0; i < 20; i++) {
        limiter.recordFailure(now);
      }
      expect(limiter.remaining(now), const Duration(minutes: 5));
    });

    test('an expired window lets the form through again', () {
      final limiter = LoginRateLimiter();
      for (var i = 0; i < 5; i++) {
        limiter.recordFailure(now);
      }
      // A beat past the boundary: the window flips to `null` only once fully
      // elapsed (exactly-at-boundary returns a zero duration).
      expect(
        limiter.remaining(now.add(const Duration(seconds: 31))),
        isNull,
      );
    });

    test('a success resets both the counter and the window', () {
      final limiter = LoginRateLimiter();
      for (var i = 0; i < 6; i++) {
        limiter.recordFailure(now);
      }
      limiter.recordSuccess();
      expect(limiter.failures, 0);
      expect(limiter.remaining(now), isNull);
      // And the ladder starts over at 30 s, not 60 s.
      for (var i = 0; i < 5; i++) {
        limiter.recordFailure(now);
      }
      expect(limiter.remaining(now), const Duration(seconds: 30));
    });
  });
}
