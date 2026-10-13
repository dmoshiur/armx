// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/breakpoints.dart';

/// Where a destination sits in the navigation hierarchy.
enum NavGroup {
  /// Day-to-day surfaces: home, assistant, smart home, alarms, linked devices.
  primary,

  /// Capability surfaces the owner opens deliberately: guest greeter, web builder,
  /// messaging.
  capability,

  /// Administration and configuration: admin, settings.
  system,
}

/// One navigable surface.
///
/// Destinations are declared **once**, here, and every navigation pattern (bottom bar,
/// rail, sidebar, the compact "More" sheet) renders from this same list. Adding a screen is
/// therefore a one-line change that automatically appears in all three layouts.
@immutable
class NavDestination {
  /// Creates a destination.
  const NavDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.labelKey,
    this.group = NavGroup.primary,
    this.minimumRole = UserRole.user,
    this.mobilePrimary = false,
  });

  /// Route this destination navigates to.
  final String path;

  /// Glyph when unselected.
  final IconData icon;

  /// Glyph when selected.
  final IconData selectedIcon;

  /// Selects the localized label, resolved per build because it follows the locale.
  final String Function(BuildContext context) labelKey;

  /// Section the destination belongs to on the desktop sidebar.
  final NavGroup group;

  /// The lowest role that may see and reach this destination.
  ///
  /// Hiding is **not** the security boundary: `go_router`'s redirect refuses the route as
  /// well (see `app_router.dart`), so a user who types `/admin` is sent back.
  final UserRole minimumRole;

  /// Whether the destination appears in the compact bottom bar.
  ///
  /// Only the four most-used surfaces do; everything else is one tap away in "More".
  final bool mobilePrimary;

  /// Resolves the localized label.
  String label(BuildContext context) => labelKey(context);

  /// True when [role] may see this destination.
  bool isVisibleTo(UserRole role) => role.satisfies(minimumRole);
}

/// The complete destination table.
abstract final class NavDestinations {
  /// All destinations, in display order.
  static const List<NavDestination> all = <NavDestination>[
    NavDestination(
      path: Routes.home,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      labelKey: _homeLabel,
      group: NavGroup.primary,
      mobilePrimary: true,
    ),
    NavDestination(
      path: Routes.assistant,
      icon: Icons.graphic_eq_outlined,
      selectedIcon: Icons.graphic_eq_rounded,
      labelKey: _assistantLabel,
      group: NavGroup.primary,
      mobilePrimary: true,
    ),
    NavDestination(
      path: Routes.smartHome,
      icon: Icons.lightbulb_outline_rounded,
      selectedIcon: Icons.lightbulb_rounded,
      labelKey: _smartHomeLabel,
      group: NavGroup.primary,
      mobilePrimary: true,
    ),
    NavDestination(
      path: Routes.alarms,
      icon: Icons.alarm_outlined,
      selectedIcon: Icons.alarm_rounded,
      labelKey: _alarmsLabel,
      group: NavGroup.primary,
      mobilePrimary: true,
    ),
    NavDestination(
      path: Routes.linkedDevices,
      icon: Icons.devices_other_outlined,
      selectedIcon: Icons.devices_other_rounded,
      labelKey: _linkedDevicesLabel,
    ),
    NavDestination(
      path: Routes.guestGreeter,
      icon: Icons.doorbell_outlined,
      selectedIcon: Icons.doorbell_rounded,
      labelKey: _guestGreeterLabel,
      group: NavGroup.capability,
    ),
    NavDestination(
      path: Routes.webBuilder,
      icon: Icons.code_outlined,
      selectedIcon: Icons.code_rounded,
      labelKey: _webBuilderLabel,
      group: NavGroup.capability,
      minimumRole: UserRole.vip,
    ),
    NavDestination(
      path: Routes.messaging,
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      labelKey: _messagingLabel,
      group: NavGroup.capability,
    ),
    NavDestination(
      path: Routes.admin,
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings_rounded,
      labelKey: _adminLabel,
      group: NavGroup.system,
      minimumRole: UserRole.admin,
    ),
    NavDestination(
      path: Routes.settings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      labelKey: _settingsLabel,
      group: NavGroup.system,
    ),
  ];

  /// Destinations visible to [role].
  static List<NavDestination> forRole(UserRole role) =>
      all.where((NavDestination d) => d.isVisibleTo(role)).toList(growable: false);

  /// Destinations visible to [role] in [group].
  static List<NavDestination> groupForRole(UserRole role, NavGroup group) =>
      forRole(role).where((NavDestination d) => d.group == group).toList(growable: false);

  /// The compact bottom-bar destinations for [role].
  static List<NavDestination> mobilePrimaryForRole(UserRole role) =>
      forRole(role).where((NavDestination d) => d.mobilePrimary).toList(growable: false);

  /// The overflow destinations for [role], shown in the compact "More" sheet.
  static List<NavDestination> overflowForRole(UserRole role) {
    final Set<String> primary = mobilePrimaryForRole(role)
        .map((NavDestination d) => d.path)
        .toSet();
    return forRole(role)
        .where((NavDestination d) => !primary.contains(d.path))
        .toList(growable: false);
  }

  /// Resolves the destination that owns [location].
  ///
  /// Matching is by longest prefix so a deep route such as `/smart-home/kitchen-lamp`
  /// still highlights "Smart home", and `/admin/audit` highlights "Admin". A location that
  /// matches nothing returns `null` and the shell simply highlights nothing — it never
  /// guesses.
  static NavDestination? activeFor(String location, UserRole role) {
    NavDestination? best;
    for (final NavDestination destination in forRole(role)) {
      if (location == destination.path || location.startsWith('${destination.path}/')) {
        if (best == null || destination.path.length > best.path.length) {
          best = destination;
        }
      }
    }
    return best;
  }

  /// True when the current layout should collapse the rail. Persisted by the user's
  /// preference; the shell reads it, the widget does not.
  static bool railCollapsedByDefault(Breakpoint breakpoint) =>
      breakpoint == Breakpoint.medium;
}

// Label resolvers live as top-level functions so the destination table can stay `const`
// while the strings still come from the active locale at build time.
String _homeLabel(BuildContext context) => context.l10n.navDashboard;
String _assistantLabel(BuildContext context) => context.l10n.navAssistant;
String _smartHomeLabel(BuildContext context) => context.l10n.navSmartHome;
String _alarmsLabel(BuildContext context) => context.l10n.navAlarms;
String _linkedDevicesLabel(BuildContext context) => context.l10n.navLinkedDevices;
String _guestGreeterLabel(BuildContext context) => context.l10n.navGuestGreeter;
String _webBuilderLabel(BuildContext context) => context.l10n.navWebBuilder;
String _messagingLabel(BuildContext context) => context.l10n.navMessaging;
String _adminLabel(BuildContext context) => context.l10n.navAdmin;
String _settingsLabel(BuildContext context) => context.l10n.navSettings;
