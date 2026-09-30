// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Client-side backoff for the login form.
///
/// Defense in depth: the server throttles too, but the UI must never offer an
/// unlimited guessing button. After [maxFailures] consecutive failures the form is
/// blocked for an exponentially growing window (30 s, 60 s, 120 s, … capped at
/// [maxDelay]); any success resets the counter.
class LoginRateLimiter {
  /// Creates a limiter with the documented thresholds.
  LoginRateLimiter({
    this.maxFailures = 5,
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(minutes: 5),
  });

  /// Consecutive failures allowed before the first lockout.
  final int maxFailures;

  /// Delay after the first lockout; doubles on every further failure.
  final Duration baseDelay;

  /// Upper bound for the doubling delay.
  final Duration maxDelay;

  int _failures = 0;
  DateTime? _blockedUntil;

  /// Consecutive failures recorded (tests and diagnostics).
  int get failures => _failures;

  /// Remaining lockout, or `null` when the form may be submitted.
  Duration? remaining(DateTime now) {
    final until = _blockedUntil;
    if (until == null) {
      return null;
    }
    final left = until.difference(now);
    return left.isNegative ? null : left;
  }

  /// Records a failed attempt, arming the backoff once [maxFailures] is reached.
  void recordFailure(DateTime now) {
    _failures += 1;
    if (_failures < maxFailures) {
      return;
    }
    final steps = _failures - maxFailures;
    var delay = baseDelay * (1 << steps);
    if (delay > maxDelay) {
      delay = maxDelay;
    }
    final candidate = now.add(delay);
    final until = _blockedUntil;
    if (until == null || candidate.isAfter(until)) {
      _blockedUntil = candidate;
    }
  }

  /// Clears the counter and any lockout after a successful sign-in.
  void recordSuccess() {
    _failures = 0;
    _blockedUntil = null;
  }
}
