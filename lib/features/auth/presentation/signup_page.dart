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
import '../../../data/api/auth_session.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';
import 'widgets/google_sign_in_button.dart';

/// Account creation with inline validation and a success state that explains the
/// verification email rather than pretending the user is signed in.
class SignupPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  SignupReceipt? _receipt;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final SignupReceipt? receipt =
        await ref.read(authControllerProvider.notifier).signUp(
              email: _email.text,
              password: _password.text,
              displayName: _name.text,
            );
    if (receipt != null && mounted) {
      setState(() => _receipt = receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);
    final String? failure = authFailureMessage(context, auth.failure);

    // Success state: the account exists but is **not** signed in. Saying "welcome" here
    // would be a fake success.
    final SignupReceipt? receipt = _receipt;
    if (receipt != null) {
      return AuthScaffold(
        title: context.l10n.authVerifyTitle,
        subtitle: context.l10n.authVerifyBody(receipt.email),
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ArmxNotice(
              tone: ArmxBadgeToneLike.success,
              title: context.l10n.authVerifyTitle,
              message: context.l10n.authVerifyBody(receipt.email),
            ),
            const SizedBox(height: Insets.lg),
            const PendingRoleBadge(),
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
      title: context.l10n.authSignupTitle,
      subtitle: context.l10n.authSignupSubtitle,
      showBackButton: true,
      child: Form(
        key: _formKey,
        child: AutovalidateMode.always == AutovalidateMode.disabled
            ? _form(auth, failure)
            : _form(auth, failure),
      ),
    );
  }

  Widget _form(AuthState auth, String? failure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (failure != null) ...<Widget>[
          ArmxNotice(
            tone: ArmxBadgeToneLike.danger,
            title: context.l10n.errorGenericTitle,
            message: failure,
          ),
          const SizedBox(height: Insets.lg),
        ],
        ArmxTextField(
          label: context.l10n.authNameLabel,
          controller: _name,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.name],
          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
          validator: (String? value) => Validators.displayName(value, context.l10n),
          required: true,
          onChanged: (_) => ref.read(authControllerProvider.notifier).clearFailure(),
        ),
        const SizedBox(height: Insets.lg),
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
          helper: context.l10n.authPasswordRule,
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.newPassword],
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          validator: (String? value) => Validators.strongPassword(value, context.l10n),
          required: true,
        ),
        const SizedBox(height: Insets.lg),
        ArmxTextField(
          label: context.l10n.authConfirmPasswordLabel,
          controller: _confirm,
          obscureText: true,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
          validator: (String? value) =>
              Validators.confirmPassword(value, _password.text, context.l10n),
          required: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Insets.xl),
        ArmxButton(
          label: context.l10n.authSignUpAction,
          onPressed: _submit,
          loading: auth.busy,
          expand: true,
          icon: Icons.person_add_alt_1_rounded,
        ),
        const SizedBox(height: Insets.lg),
        const PendingRoleBadge(),
        const SizedBox(height: Insets.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                context.l10n.authHaveAccount,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ArmxButton(
              label: context.l10n.authSignInLink,
              onPressed: () => context.go(Routes.login),
              variant: ArmxButtonVariant.ghost,
              size: ArmxButtonSize.small,
            ),
          ],
        ),
      ],
    );
  }
}
