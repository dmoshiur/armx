// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Injectable time source.
///
/// Every verification-expiry decision (60 s window) and every unlock token (`exp <= 30 s`)
/// is decided through a [Clock] so unit tests can move time deterministically instead of
/// sleeping.
abstract interface class Clock {
  /// Current instant.
  DateTime now();
}

/// [Clock] backed by the system wall clock.
class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// [Clock] whose time only moves when a test asks it to.
class FixedClock implements Clock {
  /// Creates a fixed clock pinned to [instant].
  FixedClock(this._instant);

  DateTime _instant;

  /// Current fixed instant.
  DateTime get instant => _instant;

  @override
  DateTime now() => _instant;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) => _instant = _instant.add(duration);

  /// Jumps to an absolute [instant].
  void set(DateTime instant) => _instant = instant;
}

/// Monotonic stopwatch used for latency badges; independent from wall-clock changes.
class StopwatchClock {
  final Stopwatch _stopwatch = Stopwatch();

  /// Starts (or restarts) the measurement.
  void start() => _stopwatch
    ..reset()
    ..start();

  /// Elapsed time since [start].
  Duration get elapsed => _stopwatch.elapsed;

  /// Stops the measurement.
  void stop() => _stopwatch.stop();
}
