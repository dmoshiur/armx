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
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../core/providers.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_scaffold.dart';

/// Completes a password reset from an emailed link.
///
/// The token is validated **before** the form is shown, so an expired or already-used link
/// gets its own explanatory screen instead of a form that fails on submit. Without a token
/// in the URL the screen states that the link is incomplete rather than rendering an empty
/// form.
class ResetPasswordPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const ResetPasswordPage({required this.token, super.key});

  /// Token from the deep link / web route. `null` when the link was incomplete.
  final String? token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  TokenValidity? _validity;
  bool _checking = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final String? token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _validity = TokenValidity.invalid;
        _checking = false;
      });
      return;
    }
    try {
      final TokenValidity validity =
          await ref.read(armxApiProvider).checkResetToken(token: token);
      if (mounted) {
        setState(() {
          _validity = validity;
          _checking = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _validity = TokenValidity.invalid;
          _checking = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool ok = await ref.read(authControllerProvider.notifier).resetPassword(
          token: widget.token ?? '',
          newPassword: _password.text,
        );
    if (ok && mounted) {
      setState(() => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return AuthScaffold(
        title: context.l10n.authResetTitle,
        subtitle: context.l10n.authResetSubtitle,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: Insets.xl),
          child: ArmxSkeletonCard(lines: 3, showAction: true),
        ),
      );
    }

    if (_done) {
      return AuthScaffold(
        title: context.l10n.authResetDoneTitle,
        subtitle: context.l10n.authResetDoneBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ArmxNotice(
              tone: ArmxBadgeToneLike.success,
              title: context.l10n.authResetDoneTitle,
              message: context.l10n.authSignOutEverywhere,
            ),
            const SizedBox(height: Insets.xl),
            ArmxButton(
              label: context.l10n.authSignInAction,
              onPressed: () => context.go(Routes.login),
              expand: true,
            ),
          ],
        ),
      );
    }

    if (_validity != TokenValidity.valid) {
      final bool expired = _validity == TokenValidity.expired;
      return AuthScaffold(
        title: expired
            ? context.l10n.authResetExpiredTitle
            : context.l10n.authResetInvalidTitle,
        subtitle: expired
            ? context.l10n.authResetExpiredBody
            : context.l10n.authResetInvalidBody,
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ArmxNotice(
              tone: expired ? ArmxBadgeToneLike.warning : ArmxBadgeToneLike.danger,
              message: expired
                  ? context.l10n.authResetExpiredBody
                  : context.l10n.authResetInvalidBody,
            ),
            const SizedBox(height: Insets.xl),
            ArmxButton(
              label: context.l10n.authResetRequestNew,
              onPressed: () => context.go(Routes.forgotPassword),
              expand: true,
              icon: Icons.outgoing_mail_rounded,
            ),
            const SizedBox(height: Insets.sm),
            ArmxButton(
              label: context.l10n.authVerifyBackToSignIn,
              onPressed: () => context.go(Routes.login),
              variant: ArmxButtonVariant.ghost,
              expand: true,
            ),
          ],
        ),
      );
    }

    final AuthState auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: context.l10n.authResetTitle,
      subtitle: context.l10n.authResetSubtitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
              label: context.l10n.authResetAction,
              onPressed: _submit,
              loading: auth.busy,
              expand: true,
              icon: Icons.lock_reset_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
