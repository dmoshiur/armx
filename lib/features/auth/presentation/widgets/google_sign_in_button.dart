// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../core/widgets/armx_empty_state.dart';
import '../../application/auth_controller.dart';

/// "Continue with Google".
///
/// ## Why there is no client secret here (§8)
///
/// A Flutter app cannot keep a client secret, so this button must never perform a token
/// exchange itself. The production flow is: open the system browser (or a web view) at the
/// backend's `/auth/google/start` endpoint, let the backend do the OpenID Connect code
/// exchange with its own secret, receive an id token, and hand that token to
/// `signInWithGoogle`. Nothing secret is shipped in the binary.
///
/// Until the backend publishes that endpoint, the button is explicitly disabled and
/// labelled as unconfigured. It does **not** fake a sign-in — a fake success here would be
/// the worst possible failure mode, because the user would appear signed in with no
/// session.
class GoogleSignInButton extends ConsumerWidget {
  /// Creates the button.
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ArmxColors colors = ArmxColors.of(context);
    final AuthState auth = ref.watch(authControllerProvider);
    final bool configured = GoogleAuthFlow.isConfigured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ArmxButton(
          label: context.l10n.authContinueWithGoogle,
          icon: Icons.g_mobiledata_rounded,
          variant: ArmxButtonVariant.secondary,
          expand: true,
          loading: auth.busy && auth.failure == AuthFailureReason.googleFailed,
          onPressed: configured ? () => _start(context, ref) : null,
          tooltip: configured ? null : context.l10n.authGoogleNotConfigured,
        ),
        if (!configured) ...<Widget>[
          const SizedBox(height: Insets.sm),
          ArmxNotice(
            tone: ArmxBadgeToneLike.info,
            icon: Icons.construction_outlined,
            message: context.l10n.authGoogleStubNotice,
          ),
        ],
        if (auth.failure == AuthFailureReason.googleCancelled ||
            auth.failure == AuthFailureReason.googleFailed) ...<Widget>[
          const SizedBox(height: Insets.sm),
          ArmxNotice(
            tone: ArmxBadgeToneLike.danger,
            message: context.l10n.authErrorGoogleFailed,
          ),
        ],
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 14, color: colors.textMuted),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                context.l10n.authRolePendingNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final String? idToken = await GoogleAuthFlow.requestIdToken();
    if (idToken == null) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle(idToken: idToken);
  }
}

/// The seam the real Google flow plugs into.
///
/// [isConfigured] is `false` for now, which is the honest state of the build: the backend
/// OIDC start endpoint does not exist yet. When it lands, wire
/// `url_launcher`/`flutter_appauth` here and flip the flag — the UI and the controller
/// above need no change.
abstract final class GoogleAuthFlow {
  /// True when a real provider flow is available in this build.
  static bool get isConfigured => false;

  /// Runs the browser flow and returns the provider's id token, or `null` when the user
  /// cancelled.
  static Future<String?> requestIdToken() async => null;
}

/// A compact role chip used by the sign-up screen to explain what a new account gets.
class PendingRoleBadge extends StatelessWidget {
  /// Creates the badge row.
  const PendingRoleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ArmxCard(
      dense: true,
      tone: ArmxCardTone.raised,
      child: Row(
        children: <Widget>[
          const ArmxBadge(label: 'User', tone: ArmxBadgeTone.neutral),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              context.l10n.authRolePendingNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
