// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/theme/armx_theme.dart';

/// One entry of the primary navigation.
class ShellDestination {
  /// Creates a destination.
  const ShellDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  /// Route path pushed when selected. The visible label is localized at build time in
  /// `AppShell._labels`, because it depends on the active locale.
  final String path;

  /// Unselected icon.
  final IconData icon;

  /// Selected icon.
  final IconData selectedIcon;
}

/// The persistent navigation shell: bottom bar on phones, rail on desktop.
///
/// Uses `go_router`'s indexed stack so each tab keeps its own scroll position and state.
class AppShell extends StatelessWidget {
  /// Creates the shell around the current [navigationShell].
  const AppShell({required this.navigationShell, super.key});

  /// go_router's stateful navigation shell (one branch per destination).
  final StatefulNavigationShell navigationShell;

  /// Primary destinations, in bar order.
  static const List<ShellDestination> destinations = <ShellDestination>[
    ShellDestination(
      path: AppRoutes.dashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    ShellDestination(
      path: AppRoutes.chat,
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
    ),
    ShellDestination(
      path: AppRoutes.devices,
      icon: Icons.memory_outlined,
      selectedIcon: Icons.memory_rounded,
    ),
    ShellDestination(
      path: AppRoutes.activity,
      icon: Icons.directions_walk_outlined,
      selectedIcon: Icons.directions_walk_rounded,
    ),
    ShellDestination(
      path: AppRoutes.admin,
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings_rounded,
    ),
  ];

  void _onSelect(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Localized labels, resolved per build because they depend on the active locale.
  List<String> _labels(BuildContext context) => <String>[
        context.l10n.navDashboard,
        context.l10n.navChat,
        context.l10n.navDevices,
        context.l10n.navActivity,
        context.l10n.navAdmin,
      ];

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    final labels = _labels(context);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              backgroundColor: colors.panel,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _onSelect(context, index),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: IconButton(
                  tooltip: context.l10n.navSettings,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push(AppRoutes.settings),
                ),
              ),
              destinations: <NavigationRailDestination>[
                for (var i = 0; i < destinations.length; i++)
                  NavigationRailDestination(
                    icon: Icon(destinations[i].icon),
                    selectedIcon: Icon(destinations[i].selectedIcon),
                    label: Text(labels[i]),
                  ),
              ],
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => _onSelect(context, index),
          destinations: <Widget>[
            for (var i = 0; i < destinations.length; i++)
              NavigationDestination(
                icon: Icon(destinations[i].icon),
                selectedIcon: Icon(destinations[i].selectedIcon),
                label: labels[i],
                tooltip: labels[i],
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: context.l10n.navSettings,
        backgroundColor: colors.panel2,
        foregroundColor: colors.cyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArmxTheme.panelRadius),
          side: BorderSide(color: colors.border),
        ),
        onPressed: () => context.push(AppRoutes.settings),
        child: const Icon(Icons.settings_outlined),
      ),
    );
  }
}
