// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

/// The role values the backend uses, as a closed set.
///
/// Roles are the authorisation axis of the whole app: navigation, admin screens and the
/// kill-switch are all filtered by them, and `go_router`'s redirect refuses a route the
/// current role may not reach rather than merely hiding a button.
enum UserRole {
  /// Full control, including users, tool toggles and the kill-switch.
  admin,

  /// Everything a regular user has, plus guest-greeter and web-builder limits raised.
  vip,

  /// The default. Assistant, smart home, alarms, linked devices, own settings.
  user;

  /// Parses a wire value without guessing: anything unrecognised becomes [user], the
  /// least-privileged role.
  static UserRole fromWire(String? value) => switch (value?.toLowerCase().trim()) {
        'admin' || 'owner' => UserRole.admin,
        'vip' => UserRole.vip,
        _ => UserRole.user,
      };

  /// The wire value.
  String get wire => name;

  /// True when this role may reach admin-only routes.
  bool get canAdminister => this == UserRole.admin;

  /// True when this role may reach VIP-and-above routes.
  bool get isVipOrAbove => this == UserRole.vip || this == UserRole.admin;

  /// True when [required] is satisfied by this role.
  bool satisfies(UserRole required) {
    if (required == UserRole.user) {
      return true;
    }
    if (required == UserRole.vip) {
      return isVipOrAbove;
    }
    return canAdminister;
  }
}

/// Every route path in the app, in one place.
///
/// Screens address routes through these constants, never through string literals, so a
/// rename is a one-file change and `go_router` diagnostics stay readable.
abstract final class Routes {
  /// Splash / session bootstrap. The app's initial location.
  static const String splash = '/';

  // ---- Auth ----------------------------------------------------------------
  /// Sign-in.
  static const String login = '/login';

  /// Account creation.
  static const String signup = '/signup';

  /// Request a password-reset email.
  static const String forgotPassword = '/forgot-password';

  /// Complete a reset using the token from the emailed link.
  ///
  /// Reachable only with `?token=…`; without a token the screen shows the invalid-token
  /// state rather than an empty form.
  static const String resetPassword = '/reset-password';

  /// "Check your inbox" confirmation after sign-up.
  static const String verifyEmail = '/verify-email';

  /// Explains and requests the Android overlay permission (one-time).
  static const String overlayPermission = '/overlay-permission';

  // ---- Primary shell destinations ------------------------------------------
  /// Home: greeting, live status, quick actions.
  static const String home = '/home';

  /// Assistant conversation: transcript, voice, tool cards.
  static const String assistant = '/assistant';

  /// Smart home: rooms, lights, fans, sensors.
  static const String smartHome = '/smart-home';

  /// Device detail. `:id` is the device id.
  static const String deviceDetail = '/smart-home/:id';

  /// Alarms: list and editor.
  static const String alarms = '/alarms';

  /// Create or edit an alarm. `:id` is `new` for the create flow.
  static const String alarmEditor = '/alarms/:id';

  /// Linked devices: pairing, list, unlink.
  static const String linkedDevices = '/linked-devices';

  /// Guest greeter: preview, kill switch, enrollment.
  static const String guestGreeter = '/guest-greeter';

  /// Guest greeter opt-in enrollment sub-flow.
  static const String guestEnrollment = '/guest-greeter/enrollment';

  /// Web builder: prompt, preview, confirm-and-deploy.
  static const String webBuilder = '/web-builder';

  /// Messaging personality: per-contact tone profiles.
  static const String messaging = '/messaging';

  /// Admin dashboard: users, audit, tool toggles, kill-switch.
  static const String admin = '/admin';

  /// Admin audit log.
  static const String adminAudit = '/admin/audit';

  /// Admin tool toggles.
  static const String adminTools = '/admin/tools';

  // ---- Settings ------------------------------------------------------------
  /// Settings root.
  static const String settings = '/settings';

  /// Language, theme and notification preferences.
  static const String settingsPreferences = '/settings/preferences';

  /// Device permissions overview (camera, mic, overlay, background).
  static const String settingsPermissions = '/settings/permissions';

  /// Account and active sessions.
  static const String settingsAccount = '/settings/account';

  /// Design-system gallery: tokens, widgets, live contrast ratios.
  static const String settingsDesignSystem = '/settings/design-system';

  /// Diagnostics: configuration summary, socket state, dropped frames.
  static const String settingsDiagnostics = '/settings/diagnostics';

  /// About, credits and licences.
  static const String settingsAbout = '/settings/about';

  // ---- Helpers -------------------------------------------------------------

  /// The device-detail path for [deviceId].
  static String deviceFor(String deviceId) => '/smart-home/$deviceId';

  /// The alarm-editor path for [alarmId] (or `new`).
  static String alarmFor(String alarmId) => '/alarms/$alarmId';

  /// The reset-password path carrying [token].
  static String resetPasswordWith(String token) =>
      '$resetPassword?token=${Uri.encodeQueryComponent(token)}';

  /// Flattens a path to a stable route name (`/smart-home/:id` → `smartHomeId`).
  ///
  /// Used by the navigation shell to decide which tab a deep route belongs to, so an
  /// unknown path can never make the highlight disappear.
  static String nameOf(String path) {
    final String cleaned = path.replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ').trim();
    if (cleaned.isEmpty) {
      return 'root';
    }
    final List<String> parts = cleaned.split(' ');
    return parts.first.toLowerCase() +
        parts.skip(1).map((String part) => part[0].toUpperCase() + part.substring(1)).join();
  }
}
