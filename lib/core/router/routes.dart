// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// Every route path in the app, in one place.
///
/// Screens are addressed by these constants (never by string literals) so a rename is a
/// single-file change and `go_router` diagnostics stay readable.
abstract final class AppRoutes {
  /// Bootstrap/splash route.
  static const String splash = '/';

  /// Sign-in screen.
  static const String login = '/login';

  /// Device pairing screen (server URL + device key + key fingerprint).
  static const String pairing = '/pairing';

  /// App-lock gate (biometrics / device PIN / app PIN) shown on cold start
  /// with a restored session and on resume past the auto-lock timeout.
  static const String lock = '/lock';

  /// Assistant dashboard.
  static const String dashboard = '/dashboard';

  /// Assistant chat with tool approvals.
  static const String chat = '/chat';

  /// ESP32 device list, relays, sensors and scenes.
  static const String devices = '/devices';

  /// Activity, geofences and the WHEN/THEN rule builder.
  static const String activity = '/activity';

  /// Admin panel: tools, audit log, revocation and the kill-switch.
  static const String admin = '/admin';

  /// Vision module: enrolment, verification, liveness, palm gesture.
  static const String vision = '/vision';

  /// Client-side unlock flow and paired machines.
  static const String unlock = '/unlock';

  /// Settings root.
  static const String settings = '/settings';

  /// About + credit + licences.
  static const String about = '/settings/about';

  /// Diagnostics (config summary and recent log lines).
  static const String diagnostics = '/settings/diagnostics';

  /// Design-system gallery (tokens, orb states, chips, panels).
  static const String designSystem = '/settings/design-system';

  /// Route name for a not-yet-implemented screen, parameterised by delivery step.
  static String placeholderName(int step) => 'placeholder_step_$step';
}
