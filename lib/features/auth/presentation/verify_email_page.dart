// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';

/// Holds an unverified account: explains the email, offers a resend with a countdown, and
/// exposes the token hand-off for a deep link.
class VerifyEmailPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const VerifyEmailPage({this.email, this.token, super.key});

  /// Address the mail went to, when known.
  final String? email;

  /// Token supplied by a deep link, when the link landed in this app.
  final String? token;

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  Timer? _ticker;
  int _resendIn = 0;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    final String? token = widget.token;
    if (token != null && token.isNotEmpty) {
      // Arriving with a token means the user followed the link; consume it immediately so
      // the flow completes without an extra tap.
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(token));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _verify(String token) async {
    final bool ok =
        await ref.read(authControllerProvider.notifier).verifyEmail(token: token);
    if (!ok && mounted && context.mounted) {
      // A failed token leaves the resend affordance in place; the router keeps the user
      // here until a session actually exists.
      setState(() {});
    }
  }

  void _startCountdown(int seconds) {
    _ticker?.cancel();
    setState(() {
      _resendIn = seconds;
      _resent = true;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendIn = _resendIn <= 1 ? 0 : _resendIn - 1;
      });
      if (_resendIn == 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _resend() async {
    await ref
        .read(authControllerProvider.notifier)
        .resendVerification(email: widget.email ?? ref.read(authControllerProvider).pendingEmail);
    _startCountdown(60);
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);
    final String? failure = authFailureMessage(context, auth.failure);
    final String email = widget.email ?? auth.pendingEmail ?? '';

    return AuthScaffold(
      title: context.l10n.authVerifyTitle,
      subtitle: context.l10n.authVerifyBody(email),
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ArmxNotice(
            tone: ArmxBadgeToneLike.info,
            title: context.l10n.authVerifyTitle,
            message: context.l10n.authVerifyBody(email),
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            ArmxNotice(
              tone: ArmxBadgeToneLike.danger,
              message: failure,
            ),
          ],
          if (_resent) ...<Widget>[
            const SizedBox(height: Insets.md),
            ArmxNotice(
              tone: ArmxBadgeToneLike.success,
              message: context.l10n.authVerifyResent,
            ),
          ],
          const SizedBox(height: Insets.xl),
          ArmxButton(
            label: _resendIn > 0
                ? context.l10n.authVerifyResendWait(_resendIn)
                : context.l10n.authVerifyResend,
            onPressed: _resendIn > 0 ? null : _resend,
            loading: auth.busy,
            expand: true,
            icon: Icons.mark_email_unread_outlined,
          ),
          const SizedBox(height: Insets.sm),
          ArmxButton(
            label: context.l10n.authVerifyBackToSignIn,
            onPressed: () => context.go(Routes.login),
            variant: ArmxButtonVariant.ghost,
            expand: true,
          ),
          const SizedBox(height: Insets.xl),
          ArmxCard(
            dense: true,
            tone: ArmxCardTone.raised,
            child: Text(
              context.l10n.authPreviousPassword,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
