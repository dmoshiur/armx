// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_models.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/reset_password_page.dart';
import '../../features/auth/presentation/signup_page.dart';
import '../../features/auth/presentation/verify_email_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../errors/app_exception.dart';
import '../l10n/l10n.dart';
import 'routes.dart';
import 'screen_registry.dart';

/// Builds the app router, including the guards.
///
/// ## Guarding rules
///
/// 1. **Splash** owns the launch; the redirect never pulls it away mid-restore.
/// 2. **Signed out** → [Routes.login], remembering where the user was headed so sign-in
///    lands them there.
/// 3. **Unverified** → [Routes.verifyEmail]. An unverified account is *not* signed in and
///    cannot reach the assistant.
/// 4. **Role** → a route declaring `minimumRole` past the user's role redirects to
///    [Routes.home]. Unauthorised access is a **redirect, not a hidden button**: typing
///    `/admin` as a regular user must not render the dashboard for a frame.
/// 5. The reset-password route stays reachable while signed out — it is reached from an
///    email, so it cannot require a session.
///
/// The router itself performs no I/O; it reads session state that [AuthController] has
/// already resolved.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      final AuthState auth = ref.read(authControllerProvider);

      // 1. The splash runs the bootstrap; never interrupt it.
      if (location == Routes.splash) {
        return null;
      }

      // Routes that must stay reachable with no session, because the user arrives from a
      // link rather than from inside the app.
      const Set<String> publicRoutes = <String>{
        Routes.login,
        Routes.signup,
        Routes.forgotPassword,
        Routes.resetPassword,
      };

      // 2. Restoring: hold the user on the splash rather than flashing sign-in.
      if (auth.isRestoring) {
        return Routes.splash;
      }

      final bool signedIn = auth.isSignedIn;

      // 3. Unverified accounts are held on the verification screen.
      if (auth.phase == AuthPhase.awaitingEmailVerification) {
        return location == Routes.verifyEmail ? null : Routes.verifyEmail;
      }

      if (!signedIn) {
        if (publicRoutes.contains(location)) {
          return null;
        }
        // Remember the intent so the post-sign-in redirect is where they wanted to go.
        final String? from = state.uri.toString();
        if (from.isNotEmpty && from != Routes.login) {
          return Uri(
            path: Routes.login,
            queryParameters: <String, String>{'next': from},
          ).toString();
        }
        return Routes.login;
      }

      // A signed-in user has no business on the auth screens.
      if (publicRoutes.contains(location)) {
        final String? next = state.uri.queryParameters['next'];
        return next != null && next.isNotEmpty ? next : Routes.home;
      }

      // 4. Role guard. `ScreenSpec.minimumRole` is the single source of truth for which
      // role a screen needs, so navigation and the guard can never disagree.
      final ScreenSpec? spec = ScreenRegistry.match(location);
      if (spec != null && !auth.role.satisfies(spec.minimumRole)) {
        return Routes.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        name: Routes.nameOf(Routes.splash),
        builder: (BuildContext context, GoRouterState state) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.login,
        name: Routes.nameOf(Routes.login),
        builder: (BuildContext context, GoRouterState state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.signup,
        name: Routes.nameOf(Routes.signup),
        builder: (BuildContext context, GoRouterState state) => const SignupPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: Routes.nameOf(Routes.forgotPassword),
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        name: Routes.nameOf(Routes.resetPassword),
        builder: (BuildContext context, GoRouterState state) => ResetPasswordPage(
          // The token may arrive as a query parameter (web) or a path fragment (a deep
          // link that was rewritten); both are accepted, and its absence is a state the
          // screen renders rather than a crash.
          token: state.uri.queryParameters['token'] ?? state.pathParameters['token'],
        ),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        name: Routes.nameOf(Routes.verifyEmail),
        builder: (BuildContext context, GoRouterState state) => VerifyEmailPage(
          email: state.uri.queryParameters['email'],
          token: state.uri.queryParameters['token'],
        ),
      ),

      // ---- The shell: every destination keeps its own state ------------------
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          for (final ScreenSpec spec in ScreenRegistry.shellScreens)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: spec.path,
                  name: Routes.nameOf(spec.path),
                  builder: spec.builder,
                  routes: <RouteBase>[
                    for (final ScreenSpec child in spec.children)
                      GoRoute(
                        path: child.relativePath,
                        name: Routes.nameOf(child.path),
                        builder: child.builder,
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),

      // ---- Pushed screens (settings, about, diagnostics) --------------------
      for (final ScreenSpec spec in ScreenRegistry.pushedScreens)
        GoRoute(
          path: spec.path,
          name: Routes.nameOf(spec.path),
          builder: spec.builder,
        ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        RouteErrorPage(message: state.error?.toString()),
  );

  // go_router re-evaluates `redirect` on navigation, so every change to the session must
  // refresh it — otherwise signing out would leave the shell rendered until the next tap.
  ref.listen<AuthState>(authControllerProvider, (AuthState? previous, AuthState next) {
    if (previous?.phase != next.phase || previous?.role != next.role) {
      router.refresh();
    }
  });

  ref.onDispose(router.dispose);
  return router;
});

/// Shown for an unknown route or a malformed deep link.
///
/// Renders the same error chrome as the rest of the app, with a labelled, focusable escape
/// hatch instead of a bare string.
class RouteErrorPage extends StatelessWidget {
  /// Creates the page.
  const RouteErrorPage({this.message, super.key});

  /// Diagnostic detail from go_router.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ArmxErrorState(
          error: UnknownException(
            message: message ?? 'No route matched this address.',
            code: 'route_not_found',
          ),
          onRetry: () => GoRouter.of(context).go(Routes.home),
        ),
      ),
    );
  }
}
