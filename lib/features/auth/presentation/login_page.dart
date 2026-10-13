// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../core/utils/validators.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';
import 'widgets/google_sign_in_button.dart';

/// Email + password sign-in, with the two failures the spec calls out surfaced
/// specifically: wrong credentials, and a valid password on an unverified address.
class LoginPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
    // The router's redirect moves a successful sign-in to the shell; nothing is
    // navigated here, so a failure cannot accidentally leave the screen.
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);
    final String? failure = authFailureMessage(context, auth.failure);

    return AuthScaffold(
      title: context.l10n.authLoginTitle,
      subtitle: context.l10n.authLoginSubtitle,
      footer: _Footer(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (auth.phase == AuthPhase.sessionExpired) ...<Widget>[
              ArmxNotice(
                tone: ArmxBadgeToneLike.warning,
                title: context.l10n.errorUnauthorizedTitle,
                message: context.l10n.errorUnauthorizedBody,
              ),
              const SizedBox(height: Insets.lg),
            ],
            if (failure != null) ...<Widget>[
              ArmxNotice(
                tone: ArmxBadgeToneLike.danger,
                title: context.l10n.errorGenericTitle,
                message: failure,
                action: auth.failure == AuthFailureReason.emailNotVerified
                    ? ArmxButton(
                        label: context.l10n.authVerifyTitle,
                        onPressed: () => context.go(
                          '${Routes.verifyEmail}?email=${Uri.encodeQueryComponent(_email.text.trim())}',
                        ),
                        variant: ArmxButtonVariant.ghost,
                        size: ArmxButtonSize.small,
                      )
                    : null,
              ),
              const SizedBox(height: Insets.lg),
            ],
            ArmxTextField(
              label: context.l10n.authEmailLabel,
              hint: context.l10n.authEmailHint,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
              validator: (String? value) => Validators.email(value, context.l10n),
              required: true,
              onChanged: (_) => ref.read(authControllerProvider.notifier).clearFailure(),
            ),
            const SizedBox(height: Insets.lg),
            ArmxTextField(
              label: context.l10n.authPasswordLabel,
              controller: _password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              validator: (String? value) => Validators.password(value, context.l10n),
              required: true,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => ref.read(authControllerProvider.notifier).clearFailure(),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ArmxButton(
                label: context.l10n.authForgotPassword,
                onPressed: () => context.go(Routes.forgotPassword),
                variant: ArmxButtonVariant.ghost,
                size: ArmxButtonSize.small,
              ),
            ),
            const SizedBox(height: Insets.md),
            ArmxButton(
              label: context.l10n.authSignInAction,
              onPressed: _submit,
              loading: auth.busy,
              expand: true,
              icon: Icons.login_rounded,
            ),
            const SizedBox(height: Insets.lg),
            _OrDivider(),
            const SizedBox(height: Insets.lg),
            const GoogleSignInButton(),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Text(context.l10n.authOrDivider, style: theme.textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Text(
            context.l10n.authNoAccount,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        ArmxButton(
          label: context.l10n.authCreateAccount,
          onPressed: () => context.go(Routes.signup),
          variant: ArmxButtonVariant.ghost,
          size: ArmxButtonSize.small,
        ),
      ],
    );
  }
}
