// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_page.dart';
import '../../features/admin/presentation/audit_log_page.dart';
import '../../features/admin/presentation/tool_toggles_page.dart';
import '../../features/alarms/presentation/alarm_editor_page.dart';
import '../../features/alarms/presentation/alarms_page.dart';
import '../../features/assistant/presentation/assistant_page.dart';
import '../../features/greeter/presentation/guest_enrollment_page.dart';
import '../../features/greeter/presentation/guest_greeter_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/linked/presentation/linked_devices_page.dart';
import '../../features/messaging/presentation/messaging_page.dart';
import '../../features/overlay/presentation/overlay_permission_page.dart';
import '../../features/settings/presentation/settings_about_page.dart';
import '../../features/settings/presentation/settings_account_page.dart';
import '../../features/settings/presentation/settings_design_system_page.dart';
import '../../features/settings/presentation/settings_diagnostics_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/settings/presentation/settings_permissions_page.dart';
import '../../features/settings/presentation/settings_preferences_page.dart';
import '../../features/smarthome/presentation/device_detail_page.dart';
import '../../features/smarthome/presentation/smart_home_page.dart';
import '../../features/web_builder/presentation/web_builder_page.dart';
import 'routes.dart';

/// One screen the router knows how to build, with the role it requires.
///
/// ## Why a registry rather than a literal route tree
///
/// The role guard (`redirect` in `app_router.dart`) and the route table must agree on
/// which role reaches which screen. Declaring a route twice — once to build it, once to
/// guard it — is how a guard silently drifts from reality. Here the guard *reads the route
/// table*: [ScreenRegistry.match] returns the spec that owns a location and its
/// `minimumRole` is what the redirect enforces.
///
/// The order of [shellScreens] is the order of the shell's branches, so it must stay in
/// step with [NavDestinations.all]; `tool/static_checks.py` asserts that they match.
@immutable
class ScreenSpec {
  /// Creates a spec.
  const ScreenSpec({
    required this.path,
    required this.builder,
    this.relativePath,
    this.minimumRole = UserRole.user,
    this.children = const <ScreenSpec>[],
  });

  /// Absolute path, e.g. `/smart-home`.
  final String path;

  /// Path relative to the parent route, used only for children.
  final String? relativePath;

  /// Builds the screen.
  final Widget Function(BuildContext context, GoRouterState state) builder;

  /// The lowest role allowed to reach this path.
  final UserRole minimumRole;

  /// Nested routes (a detail page under its list, for example).
  final List<ScreenSpec> children;
}

/// The app's route table, in one place.
abstract final class ScreenRegistry {
  /// Destinations that live inside the shell (each becomes a `StatefulShellBranch`).
  ///
  /// Order matters: it is the branch index order the shell and the navigation rail use.
  static const List<ScreenSpec> shellScreens = <ScreenSpec>[
    ScreenSpec(path: Routes.home, builder: _home),
    ScreenSpec(path: Routes.assistant, builder: _assistant),
    ScreenSpec(
      path: Routes.smartHome,
      builder: _smartHome,
      children: <ScreenSpec>[
        ScreenSpec(
          path: Routes.deviceDetail,
          relativePath: ':id',
          builder: _deviceDetail,
        ),
      ],
    ),
    ScreenSpec(
      path: Routes.alarms,
      builder: _alarms,
      children: <ScreenSpec>[
        ScreenSpec(
          path: Routes.alarmEditor,
          relativePath: ':id',
          builder: _alarmEditor,
        ),
      ],
    ),
    ScreenSpec(path: Routes.linkedDevices, builder: _linkedDevices),
    ScreenSpec(
      path: Routes.guestGreeter,
      builder: _guestGreeter,
      children: <ScreenSpec>[
        ScreenSpec(
          path: Routes.guestEnrollment,
          relativePath: 'enrollment',
          builder: _guestEnrollment,
        ),
      ],
    ),
    ScreenSpec(
      path: Routes.webBuilder,
      builder: _webBuilder,
      // Creating and publishing live sites is not a regular-user capability.
      minimumRole: UserRole.vip,
    ),
    ScreenSpec(path: Routes.messaging, builder: _messaging),
    ScreenSpec(
      path: Routes.admin,
      builder: _admin,
      minimumRole: UserRole.admin,
      children: <ScreenSpec>[
        ScreenSpec(
          path: Routes.adminAudit,
          relativePath: 'audit',
          builder: _auditLog,
          minimumRole: UserRole.admin,
        ),
        ScreenSpec(
          path: Routes.adminTools,
          relativePath: 'tools',
          builder: _toolToggles,
          minimumRole: UserRole.admin,
        ),
      ],
    ),
    ScreenSpec(
      path: Routes.settings,
      builder: _settings,
      children: <ScreenSpec>[
        ScreenSpec(
          path: Routes.settingsPreferences,
          relativePath: 'preferences',
          builder: _settingsPreferences,
        ),
        ScreenSpec(
          path: Routes.settingsPermissions,
          relativePath: 'permissions',
          builder: _settingsPermissions,
        ),
        ScreenSpec(
          path: Routes.settingsAccount,
          relativePath: 'account',
          builder: _settingsAccount,
        ),
        ScreenSpec(
          path: Routes.settingsDesignSystem,
          relativePath: 'design-system',
          builder: _settingsDesignSystem,
        ),
        ScreenSpec(
          path: Routes.settingsDiagnostics,
          relativePath: 'diagnostics',
          builder: _settingsDiagnostics,
        ),
        ScreenSpec(
          path: Routes.settingsAbout,
          relativePath: 'about',
          builder: _settingsAbout,
        ),
      ],
    ),
  ];

  /// Screens pushed **over** the shell, so they are not navigation destinations.
  ///
  /// Currently the overlay-permission explainer: it is a one-time Android flow reached
  /// from settings and from the assistant, and showing the navigation bar behind it would
  /// imply the user can navigate away mid-grant.
  static const List<ScreenSpec> pushedScreens = <ScreenSpec>[
    ScreenSpec(path: Routes.overlayPermission, builder: _overlayPermission),
  ];

  /// The spec that owns [location], or `null` when nothing matches.
  ///
  /// Longest match wins, so `/smart-home/kitchen-lamp` resolves to the device detail —
  /// and, more importantly, so `/admin/audit` cannot be mistaken for a path the admin
  /// guard does not cover.
  static ScreenSpec? match(String location) {
    ScreenSpec? best;
    for (final ScreenSpec spec in _all) {
      if (spec.path == location || location.startsWith('${spec.path}/')) {
        if (best == null || spec.path.length > best.path.length) {
          best = spec;
        }
      }
    }
    return best;
  }

  /// Every spec, flattened, including children.
  static Iterable<ScreenSpec> get _all sync* {
    for (final ScreenSpec spec in <ScreenSpec>[...shellScreens, ...pushedScreens]) {
      yield spec;
      yield* _descendants(spec);
    }
  }

  static Iterable<ScreenSpec> _descendants(ScreenSpec spec) sync* {
    for (final ScreenSpec child in spec.children) {
      yield child;
      yield* _descendants(child);
    }
  }
}

// Builders are top-level functions so the registry can stay `const`.
Widget _home(BuildContext context, GoRouterState state) => const HomePage();
Widget _assistant(BuildContext context, GoRouterState state) => const AssistantPage();
Widget _smartHome(BuildContext context, GoRouterState state) => const SmartHomePage();
Widget _deviceDetail(BuildContext context, GoRouterState state) =>
    DeviceDetailPage(deviceId: state.pathParameters['id'] ?? '');
Widget _alarms(BuildContext context, GoRouterState state) => const AlarmsPage();
Widget _alarmEditor(BuildContext context, GoRouterState state) =>
    AlarmEditorPage(alarmId: state.pathParameters['id'] ?? 'new');
Widget _linkedDevices(BuildContext context, GoRouterState state) =>
    const LinkedDevicesPage();
Widget _guestGreeter(BuildContext context, GoRouterState state) =>
    const GuestGreeterPage();
Widget _guestEnrollment(BuildContext context, GoRouterState state) =>
    const GuestEnrollmentPage();
Widget _webBuilder(BuildContext context, GoRouterState state) => const WebBuilderPage();
Widget _messaging(BuildContext context, GoRouterState state) => const MessagingPage();
Widget _admin(BuildContext context, GoRouterState state) => const AdminPage();
Widget _auditLog(BuildContext context, GoRouterState state) => const AuditLogPage();
Widget _toolToggles(BuildContext context, GoRouterState state) =>
    const ToolTogglesPage();
Widget _settings(BuildContext context, GoRouterState state) => const SettingsPage();
Widget _settingsPreferences(BuildContext context, GoRouterState state) =>
    const SettingsPreferencesPage();
Widget _settingsPermissions(BuildContext context, GoRouterState state) =>
    const SettingsPermissionsPage();
Widget _settingsAccount(BuildContext context, GoRouterState state) =>
    const SettingsAccountPage();
Widget _settingsDesignSystem(BuildContext context, GoRouterState state) =>
    const SettingsDesignSystemPage();
Widget _settingsDiagnostics(BuildContext context, GoRouterState state) =>
    const SettingsDiagnosticsPage();
Widget _settingsAbout(BuildContext context, GoRouterState state) =>
    const SettingsAboutPage();
Widget _overlayPermission(BuildContext context, GoRouterState state) =>
    const OverlayPermissionPage();
