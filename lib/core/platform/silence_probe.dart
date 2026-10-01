// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Reports whether the OS is currently silencing alerts (Do Not Disturb / silent switch).
///
/// A.R.M.X never overrides a user's OS-level silence: when the probe reports `true` an
/// incoming announcement still shows the full visual overlay and still writes the activity
/// log entry, it simply does not play audio.
///
/// No cross-platform Flutter package exposes DND state, so this is an interface with two
/// implementations:
/// * [AlwaysAudibleProbe] — the default (and what tests use);
/// * the platform probes listed in `docs/desktop-mode.md` § Do Not Disturb, to be wired
///   with the native calls documented there (Windows `SHQueryUserNotificationState`,
///   macOS `NSUserDefaults` `com.apple.notificationcenterui`, Android
///   `AudioManager.ringerMode`, Linux `org.freedesktop.Notifications` inhibition).
abstract interface class SilenceProbe {
  /// True when the OS would suppress a notification sound.
  Future<bool> get isSilenced;

  /// Releases listeners/timers.
  Future<void> dispose();
}

/// Reports "not silenced" always: used on platforms without a probe and in tests.
class AlwaysAudibleProbe implements SilenceProbe {
  /// Creates the always-audible probe.
  const AlwaysAudibleProbe();

  @override
  Future<bool> get isSilenced async => false;

  @override
  Future<void> dispose() async {}
}
