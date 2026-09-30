// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/bootstrap/bootstrap_gate.dart';
import '../../features/common/placeholder_page.dart';
import '../../features/dev/design_system_page.dart';
import '../../features/settings/about_page.dart';
import '../../features/settings/diagnostics_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/app_shell.dart';
import 'routes.dart';

part 'app_router.g.dart';

/// Builds the app router.
///
/// The five primary tabs live inside a `StatefulShellRoute.indexedStack` so each keeps its
/// own state; everything else (login, pairing, vision, unlock, settings and the dev
/// gallery) is pushed on top of the shell.
///
/// Auth gating is deliberately absent in step 1: the redirect that forces login lands with
/// the auth feature in step 2, together with session restore in the bootstrap provider.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const BootstrapGate(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const PlaceholderPage(
          title: 'Sign in',
          step: 2,
          icon: Icons.login_rounded,
        ),
      ),
      GoRoute(
        path: AppRoutes.pairing,
        name: 'pairing',
        builder: (context, state) => const PlaceholderPage(
          title: 'Pair this device',
          step: 2,
          icon: Icons.qr_code_2_rounded,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.dashboard,
                name: 'dashboard',
                builder: (context, state) => const PlaceholderPage(
                  title: 'Dashboard',
                  step: 5,
                  icon: Icons.dashboard_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.chat,
                name: 'chat',
                builder: (context, state) => const PlaceholderPage(
                  title: 'Assistant chat',
                  step: 3,
                  icon: Icons.forum_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.devices,
                name: 'devices',
                builder: (context, state) => const PlaceholderPage(
                  title: 'Devices',
                  step: 5,
                  icon: Icons.memory_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.activity,
                name: 'activity',
                builder: (context, state) => const PlaceholderPage(
                  title: 'Activity & rules',
                  step: 8,
                  icon: Icons.directions_walk_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.admin,
                name: 'admin',
                builder: (context, state) => const PlaceholderPage(
                  title: 'Admin',
                  step: 6,
                  icon: Icons.admin_panel_settings_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.vision,
        name: 'vision',
        builder: (context, state) => const PlaceholderPage(
          title: 'Vision',
          step: 7,
          icon: Icons.visibility_rounded,
        ),
      ),
      GoRoute(
        path: AppRoutes.unlock,
        name: 'unlock',
        builder: (context, state) => const PlaceholderPage(
          title: 'Unlock',
          step: 9,
          icon: Icons.lock_open_rounded,
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'about',
            name: 'about',
            builder: (context, state) => const AboutPage(),
          ),
          GoRoute(
            path: 'diagnostics',
            name: 'diagnostics',
            builder: (context, state) => const DiagnosticsPage(),
          ),
          GoRoute(
            path: 'design-system',
            name: 'designSystem',
            builder: (context, state) => const DesignSystemPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppRouteErrorPage(message: state.error?.toString()),
  );
}

/// Fallback screen for an unknown or malformed route.
class AppRouteErrorPage extends StatelessWidget {
  /// Creates the error page.
  const AppRouteErrorPage({this.message, super.key});

  /// Diagnostic message from go_router.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('A.R.M.X')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_outlined, size: 44),
              const SizedBox(height: 12),
              const Text('This route does not exist.'),
              if (message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Go to dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
