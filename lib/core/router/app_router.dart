// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/lock/app_lock_controller.dart';
import '../../features/auth/lock/lock_page.dart';
import '../../features/auth/login/login_page.dart';
import '../../features/auth/pairing/pairing_controller.dart';
import '../../features/auth/pairing/pairing_page.dart';
import '../../features/auth/session/auth_controller.dart';
import '../../features/bootstrap/bootstrap_gate.dart';
import '../../features/chat/chat_page.dart';
import '../../features/common/placeholder_page.dart';
import '../../features/desktop/popup/desktop_popup_page.dart';
import '../../features/desktop/widgets/background_readiness_page.dart';
import '../../features/intercom/admin_talk_page.dart';
import '../../features/intercom/intercom_activity_page.dart';
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
/// own state; everything else (login, pairing, lock, vision, unlock, settings and the dev
/// gallery) is pushed on top of the shell.
///
/// Step-2 gating (redirect, evaluated on every navigation and re-evaluated whenever the
/// pairing, auth or app-lock controllers change):
///
/// 1. splash / `AuthPhase.restoring` — untouched; the bootstrap gate owns the launch.
/// 2. not paired — always [AppRoutes.pairing] (pending and rejected live there too).
/// 3. paired + signed out (or `sessionExpired`) — [AppRoutes.login], capturing the
///    current location as the pending intent so the next sign-in lands where the user
///    was headed.
/// 4. paired + signed in + `lockDue` — [AppRoutes.lock], likewise capturing intent for
///    the post-unlock redirect.
/// 5. otherwise — the requested route (step-1 routes keep working unchanged).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final location = state.matchedLocation;

      // The splash runs the bootstrap sequence; never pull it away mid-restore.
      if (location == AppRoutes.splash) {
        return null;
      }

      final auth = ref.read(authControllerProvider);
      if (auth.phase == AuthPhase.restoring) {
        return null;
      }

      // Gate 1: pairing. Approved is the only state that leaves the screen;
      // pending and rejected stay there by design (their retry UIs live on it).
      final pairing = ref.read(pairingControllerProvider);
      if (!pairing.paired) {
        return location == AppRoutes.pairing ? null : AppRoutes.pairing;
      }

      // Gate 2: session. `sessionExpired` is a signed-out state that still
      // carries the localized "your session expired" notice into login.
      if (auth.phase == AuthPhase.signedOut ||
          auth.phase == AuthPhase.sessionExpired) {
        if (location == AppRoutes.login) {
          return null;
        }
        // Preserve the interrupted navigation across the login round-trip
        // (the lock route re-enters through the normal rule below instead).
        if (location != AppRoutes.lock) {
          ref.read(authControllerProvider.notifier).setPendingIntent(location);
        }
        return AppRoutes.login;
      }

      // Gate 3: LOW-tier app lock (see AppLockController for the tier note).
      final lock = ref.read(appLockControllerProvider);
      if (lock.lockDue && location != AppRoutes.lock) {
        ref.read(authControllerProvider.notifier).setPendingIntent(location);
        return AppRoutes.lock;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const BootstrapGate(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.pairing,
        name: 'pairing',
        builder: (context, state) => const PairingPage(),
      ),
      GoRoute(
        path: AppRoutes.lock,
        name: 'lock',
        builder: (context, state) => const LockPage(),
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
                builder: (context, state) => const ChatPage(),
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
        path: AppRoutes.desktopPopup,
        name: 'desktopPopup',
        builder: (context, state) => const DesktopPopupPage(),
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
          GoRoute(
            path: 'desktop-readiness',
            name: 'desktopReadiness',
            builder: (context, state) => const BackgroundReadinessPage(),
          ),
          GoRoute(
            path: 'talk',
            name: 'intercomTalk',
            builder: (context, state) => const AdminTalkPage(),
          ),
          GoRoute(
            path: 'intercom-activity',
            name: 'intercomActivity',
            builder: (context, state) => const IntercomActivityPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppRouteErrorPage(message: state.error?.toString()),
  );

  // The redirect above reads plain Riverpod state, so every change to those
  // controllers must re-evaluate it (go_router only re-runs redirects on
  // navigation or refresh).
  ref.listen<PairingFlowState>(
    pairingControllerProvider,
    (previous, next) => router.refresh(),
  );
  ref.listen<AuthState>(
    authControllerProvider,
    (previous, next) => router.refresh(),
  );
  ref.listen<AppLockState>(
    appLockControllerProvider,
    (previous, next) => router.refresh(),
  );
  return router;
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
