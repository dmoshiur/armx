// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_brand.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../auth/application/auth_controller.dart';

/// The bootstrap screen.
///
/// It does exactly two things, in order, and then leaves: load preferences (so the first
/// themed frame is correct rather than flashing the wrong theme) and restore the session.
///
/// The third thing it does is the important one: **if bootstrap fails, it says so and offers
/// a retry**. It never falls through to the sign-in screen on a network error, because
/// "you are signed out" and "we could not ask" are different facts, and confusing them
/// makes people re-enter passwords for no reason.
class SplashPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Future<void>? _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _run();
  }

  Future<void> _run() async {
    // Preferences first: the theme and locale must be known before the shell renders.
    await ref.read(preferencesProvider.notifier).load();
    await ref.read(authControllerProvider.notifier).restore();
  }

  void _retry() => setState(() => _bootstrap = _run());

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final AuthState auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: FutureBuilder<void>(
            future: _bootstrap,
            builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: ArmxErrorState(
                    error: snapshot.error,
                    onRetry: _retry,
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.done) {
                // Bootstrap finished: hand over to the router, which now has a phase and a
                // role to reason about.
                WidgetsBinding.instance.addPostFrameCallback((_) => _leave(auth));
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const ArmxOrb(size: 96, active: true),
                  const SizedBox(height: Insets.xl),
                  const ArmxWordmark(size: 30),
                  const SizedBox(height: Insets.sm),
                  Text(
                    context.l10n.settingsAboutTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: Insets.xxl),
                  SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: colors.surfaceAlt,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    auth.isRestoring
                        ? context.l10n.commonLoading
                        : context.l10n.splashPreparing,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _leave(AuthState auth) {
    if (!mounted) {
      return;
    }
    // The route is resolved here rather than in the redirect so the splash can show its own
    // progress until it has an answer worth acting on.
    final String destination = switch (auth.phase) {
      AuthPhase.signedIn => Routes.home,
      AuthPhase.awaitingEmailVerification => Routes.verifyEmail,
      AuthPhase.signedOut || AuthPhase.sessionExpired => Routes.login,
    };
    context.go(destination);
  }
}
