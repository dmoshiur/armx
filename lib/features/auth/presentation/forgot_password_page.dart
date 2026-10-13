// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';

/// Requests a reset link.
///
/// The confirmation says "**if** an account exists", and the same success state is shown
/// for an unknown address. That is deliberate: a screen that says "no account with that
/// email" turns this endpoint into an account-enumeration oracle.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: _email.text);
    if (mounted) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);

    if (_sent) {
      return AuthScaffold(
        title: context.l10n.authForgotSentTitle,
        subtitle: context.l10n.authForgotSentBody(_email.text.trim()),
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ArmxNotice(
              tone: ArmxBadgeToneLike.success,
              message: context.l10n.authForgotSentBody(_email.text.trim()),
            ),
            const SizedBox(height: Insets.xl),
            ArmxButton(
              label: context.l10n.authVerifyBackToSignIn,
              onPressed: () => context.go(Routes.login),
              expand: true,
              variant: ArmxButtonVariant.secondary,
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: context.l10n.authForgotTitle,
      subtitle: context.l10n.authForgotSubtitle,
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (auth.failure == AuthFailureReason.network) ...<Widget>[
              ArmxNotice(
                tone: ArmxBadgeToneLike.danger,
                title: context.l10n.errorNetworkTitle,
                message: context.l10n.errorNetworkBody,
              ),
              const SizedBox(height: Insets.lg),
            ],
            ArmxTextField(
              label: context.l10n.authEmailLabel,
              hint: context.l10n.authEmailHint,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.email],
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
              validator: (String? value) => Validators.email(value, context.l10n),
              required: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Insets.xl),
            ArmxButton(
              label: context.l10n.authForgotAction,
              onPressed: _submit,
              loading: auth.busy,
              expand: true,
              icon: Icons.outgoing_mail_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
