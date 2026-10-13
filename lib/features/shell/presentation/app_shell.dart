// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_brand.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../features/auth/data/auth_models.dart';
import 'nav_destinations.dart';
import 'widgets/connection_indicator.dart';
import 'widgets/kill_switch_button.dart';

/// The persistent frame around every primary destination.
///
/// One codebase, three navigation patterns, chosen purely from the available width (§2):
///
/// * **compact** (`< 600 dp`) — bottom navigation bar with the four most-used surfaces and
///   a **More** sheet holding the rest, plus full-screen pages. Nothing is unreachable.
/// * **medium** (`600 – 1024 dp`) — a collapsible `NavigationRail` that the user can
///   collapse to icons to buy back ~140 dp for content.
/// * **expanded** (`>= 1024 dp`) — a persistent sidebar with grouped sections, a brand
///   header, the connection indicator and the account footer.
///
/// The content column is capped and centred inside the shell, so on a 2560 dp monitor the
/// sidebar stays pinned to the window edge while the reading column stays readable.
class AppShell extends ConsumerStatefulWidget {
  /// Creates the shell around the current branch.
  const AppShell({required this.navigationShell, super.key});

  /// go_router's stateful navigation shell, one branch per destination.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => AppShellState();
}

/// State for [AppShell].
///
/// Public so a widget test can drive the layout switch without pumping the whole router.
class AppShellState extends ConsumerState<AppShell> {
  bool _moreSheetOpen = false;
  bool? _railCollapsedOverride;

  UserRole get _role => ref.watch(authControllerProvider).role;

  void _select(String path) {
    final List<NavDestination> destinations = NavDestinations.forRole(_role);
    final int index = destinations.indexWhere((NavDestination d) => d.path == path);
    if (index < 0) {
      return;
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final UserRole role = _role;
    final List<NavDestination> destinations = NavDestinations.forRole(role);
    final int currentIndex = widget.navigationShell.currentIndex;
    final NavDestination? active =
        currentIndex >= 0 && currentIndex < destinations.length
            ? destinations[currentIndex]
            : null;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Breakpoint breakpoint = Breakpoint.fromWidth(constraints.maxWidth);
        final Widget body = widget.navigationShell;

        return Scaffold(
          backgroundColor: colors.background,
          drawer: breakpoint == Breakpoint.compact
              ? _ShellDrawer(
                  role: role,
                  destinations: destinations,
                  activePath: active?.path,
                  onSelect: (String path) {
                    Navigator.of(context).pop();
                    _select(path);
                  },
                )
              : null,
          body: switch (breakpoint) {
            Breakpoint.compact => body,
            Breakpoint.medium => Row(
                children: <Widget>[
                  _MediumRail(
                    destinations: destinations,
                    currentIndex: currentIndex,
                    collapsed: _railCollapsedOverride ??
                        ref.watch(preferencesProvider).railCollapsed,
                    onToggle: () {
                      final bool next = !(_railCollapsedOverride ??
                          ref.watch(preferencesProvider).railCollapsed);
                      setState(() => _railCollapsedOverride = next);
                      // Persist in the background; the UI has already responded.
                      unawaited(
                        ref
                            .read(preferencesProvider.notifier)
                            .setRailCollapsed(collapsed: next),
                      );
                    },
                    onSelect: _select,
                    activeLabel: active?.label(context),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            Breakpoint.expanded => Row(
                children: <Widget>[
                  _ExpandedSidebar(
                    role: role,
                    destinations: destinations,
                    currentIndex: currentIndex,
                    onSelect: _select,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
          },
          bottomNavigationBar: breakpoint == Breakpoint.compact
              ? _CompactNavBar(
                  role: role,
                  currentIndex: currentIndex,
                  onSelect: _select,
                  onMore: _openMoreSheet,
                )
              : null,
        );
      },
    );
  }

  Future<void> _openMoreSheet() async {
    if (_moreSheetOpen) {
      return;
    }
    _moreSheetOpen = true;
    final UserRole role = _role;
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _MoreSheet(role: role),
    );
    _moreSheetOpen = false;
    if (selected != null && mounted) {
      _select(selected);
    }
  }
}

/// The compact bottom bar: four primary destinations plus **More**.
///
/// The bar never silently drops a destination — anything not in the four is in the sheet,
/// so every screen stays reachable on a phone.
class _CompactNavBar extends StatelessWidget {
  const _CompactNavBar({
    required this.role,
    required this.currentIndex,
    required this.onSelect,
    required this.onMore,
  });

  final UserRole role;
  final int currentIndex;
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final List<NavDestination> primary = NavDestinations.mobilePrimaryForRole(role);
    final List<NavDestination> overflow = NavDestinations.overflowForRole(role);
    final List<NavDestination> all = NavDestinations.forRole(role);
    // "More" counts as selected when the active branch lives in the sheet, so the bar
    // always shows where you are.
    final bool moreSelected = currentIndex >= primary.length;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(top: BorderSide(color: colors.hairline)),
      ),
      child: NavigationBar(
        selectedIndex: moreSelected
            ? primary.length
            : (currentIndex < primary.length ? currentIndex : 0),
        onDestinationSelected: (int index) {
          if (index >= primary.length) {
            onMore();
            return;
          }
          onSelect(primary[index].path);
        },
        destinations: <Widget>[
          for (final NavDestination destination in primary)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label(context),
              tooltip: destination.label(context),
            ),
          if (overflow.isNotEmpty)
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_rounded),
              selectedIcon: const Icon(Icons.more_horiz_rounded),
              label: context.l10n.navMore,
              tooltip: all.length > primary.length
                  ? context.l10n.navMore
                  : context.l10n.navMore,
            ),
        ],
      ),
    );
  }
}

/// Destinations that do not fit in the compact bar.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final List<NavDestination> overflow = NavDestinations.overflowForRole(role);
    final String location = GoRouterState.of(context).uri.path;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: Text(
                context.l10n.navMore,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final NavDestination destination in overflow)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: ArmxCard(
                  dense: true,
                  tone: location == destination.path
                      ? ArmxCardTone.tinted
                      : ArmxCardTone.raised,
                  onTap: () => Navigator.of(context).pop(destination.path),
                  semanticLabel: destination.label(context),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        location == destination.path
                            ? destination.selectedIcon
                            : destination.icon,
                        size: 22,
                        color: location == destination.path
                            ? ArmxColors.of(context).accentText
                            : ArmxColors.of(context).textMuted,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          destination.label(context),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Insets.sm),
            const ConnectionIndicator(compact: true),
          ],
        ),
      ),
    );
  }
}

/// The medium-layout rail, collapsible to icons.
class _MediumRail extends StatefulWidget {
  const _MediumRail({
    required this.destinations,
    required this.currentIndex,
    required this.collapsed,
    required this.onToggle,
    required this.onSelect,
    required this.activeLabel,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;
  final String? activeLabel;

  @override
  State<_MediumRail> createState() => _MediumRailState();
}

class _MediumRailState extends State<_MediumRail> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Container(
      width: widget.collapsed ? 76 : 220,
      color: colors.surface,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.lg,
              ),
              child: Row(
                children: <Widget>[
                  if (!widget.collapsed)
                    const Expanded(child: ArmxWordmark(size: 20))
                  else
                    const Spacer(),
                  ArmxIconButton(
                    icon: widget.collapsed
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    semanticLabel: widget.collapsed
                        ? context.l10n.navExpandRail
                        : context.l10n.navCollapseRail,
                    onPressed: widget.onToggle,
                  ),
                ],
              ),
            ),
            // The rail scrolls: with ten destinations and a large text scale an unscrolled
            // column would overflow.
            Expanded(
              child: NavigationRail(
                extended: !widget.collapsed,
                selectedIndex: widget.currentIndex,
                onDestinationSelected: (int index) =>
                    widget.onSelect(widget.destinations[index].path),
                labelType: widget.collapsed
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                scrollController: _controller,
                destinations: <NavigationRailDestination>[
                  for (final NavDestination destination in widget.destinations)
                    NavigationRailDestination(
                      icon: Tooltip(
                        message: destination.label(context),
                        child: Icon(destination.icon),
                      ),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label(context)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.sm),
              // The label stays in both states: a dot alone would make connectivity a
              // colour-only signal, which is exactly what this project forbids.
              child: const ConnectionIndicator(compact: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// The expanded-layout sidebar: grouped destinations, brand header, account footer.
class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.role,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final UserRole role;
  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Container(
      width: 264,
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(Insets.lg, Insets.xl, Insets.lg, Insets.lg),
              child: ArmxWordmark(size: 22),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.lg),
              child: ConnectionIndicator(),
            ),
            const SizedBox(height: Insets.lg),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                children: <Widget>[
                  for (final NavGroup group in NavGroup.values)
                    ..._group(context, group),
                ],
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.all(Insets.md),
              child: KillSwitchButton(compact: true),
            ),
            _AccountFooter(role: role),
          ],
        ),
      ),
    );
  }

  List<Widget> _group(BuildContext context, NavGroup group) {
    final List<NavDestination> items = destinations
        .where((NavDestination d) => d.group == group)
        .toList(growable: false);
    if (items.isEmpty) {
      return const <Widget>[];
    }
    final String? heading = switch (group) {
      NavGroup.primary => null,
      NavGroup.capability => context.l10n.navMore,
      NavGroup.system => context.l10n.settingsTitle,
    };
    // The group's active index inside the branch list, so the highlight matches the rail.
    return <Widget>[
      if (heading != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.lg, Insets.md, Insets.sm),
          child: Text(
            heading,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      for (final NavDestination destination in items)
        _SidebarTile(
          destination: destination,
          selected: destinations.indexOf(destination) == currentIndex,
          onTap: () => onSelect(destination.path),
        ),
    ];
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final String label = destination.label(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? colors.accent.withValues(alpha: colors.isDark ? 0.18 : 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: colors.accent.withValues(alpha: 0.07),
            focusColor: colors.accent.withValues(alpha: 0.14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Insets.minTouchTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 20,
                      color: selected ? colors.accentText : colors.textMuted,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: selected ? colors.accentText : colors.text,
                            ),
                      ),
                    ),
                    if (destination.minimumRole == UserRole.admin)
                      ArmxBadge(
                        label: context.l10n.roleAdmin,
                        tone: ArmxBadgeTone.secondary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountFooter extends ConsumerWidget {
  const _AccountFooter({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArmxColors colors = ArmxColors.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final AuthUser? user = auth.user;

    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.accent.withValues(alpha: 0.22),
            child: Text(
              (user?.displayName.isNotEmpty ?? false)
                  ? user!.displayName.characters.first.toUpperCase()
                  : '?',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.accentText,
                  ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  user?.displayName ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ArmxBadge(
                  label: switch (role) {
                    UserRole.admin => context.l10n.roleAdmin,
                    UserRole.vip => context.l10n.roleVip,
                    UserRole.user => context.l10n.roleUser,
                  },
                  tone: ArmxBadge.toneForRole(role.wire),
                ),
              ],
            ),
          ),
          ArmxIconButton(
            icon: Icons.logout_rounded,
            semanticLabel: context.l10n.shellLogout,
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(context.l10n.shellLogoutConfirmTitle),
        content: Text(context.l10n.shellLogoutConfirmBody),
        actions: <Widget>[
          ArmxButton(
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            variant: ArmxButtonVariant.secondary,
          ),
          ArmxButton(
            label: context.l10n.shellLogout,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            variant: ArmxButtonVariant.destructive,
          ),
        ],
      ),
    );
    if (confirmed) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

/// The shell's slide-out drawer, used on compact layouts when a destination list is
/// needed without leaving the page (the bottom bar covers the common case).
class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.role,
    required this.destinations,
    required this.activePath,
    required this.onSelect,
  });

  final UserRole role;
  final List<NavDestination> destinations;
  final String? activePath;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Drawer(
      backgroundColor: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(Insets.lg),
              child: ArmxWordmark(size: 22),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.lg),
              child: ConnectionIndicator(),
            ),
            const SizedBox(height: Insets.md),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                children: <Widget>[
                  for (final NavDestination destination in destinations)
                    _SidebarTile(
                      destination: destination,
                      selected: destination.path == activePath,
                      onTap: () => onSelect(destination.path),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(Insets.md),
              child: KillSwitchButton(),
            ),
          ],
        ),
      ),
    );
  }
}
