// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/security/secure_screen.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/armx_controls.dart';
import '../../../core/widgets/glass_panel.dart';
import '../session/auth_controller.dart';

/// Step 2 sign-in screen for the single owner account.
///
/// Distinct localized failures: invalid credentials, locked account, unpaired/revoked
/// device, network error and unreachable server — plus the client-side backoff after
/// five failed attempts ([LoginRateLimiter], owned by [AuthController]).
class LoginPage extends ConsumerStatefulWidget {
  /// Creates the login screen.
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final bool _remember;
  ValidationIssue? _usernameIssue;
  ValidationIssue? _passwordIssue;
  String? _formError;
  var _submitting = false;
  Timer? _backoffTimer;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _remember = ref.read(authControllerProvider).rememberDevice;
  }

  @override
  void dispose() {
    _backoffTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final auth = ref.watch(authControllerProvider);
    final backoff = ref.read(authControllerProvider.notifier).loginBackoff;
    final backoffActive = backoff != null && backoff > Duration.zero;
    final notice = backoffActive
        ? l10n.loginRateLimited(seconds: backoff.inSeconds + 1)
        : _formError ??
            (auth.phase == AuthPhase.sessionExpired ? l10n.loginSessionExpiredNotice : null);

    return SecureScreen(
      security: ref.watch(screenSecurityProvider),
      child: Scaffold(
        appBar: ArmxAppBar(title: l10n.loginTitle, subtitle: l10n.loginSubtitle),
        body: ArmxBackground(
          child: ArmxPageBody(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (notice != null) ...<Widget>[
                        Semantics(
                          liveRegion: true,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(
                                backoffActive
                                    ? Icons.hourglass_bottom_rounded
                                    : Icons.error_outline_rounded,
                                size: 18,
                                color: colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notice,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.amber),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ArmxTextField(
                        controller: _usernameController,
                        label: l10n.loginUsernameLabel,
                        errorText: _usernameIssue == null
                            ? null
                            : context.validationMessage(_usernameIssue!),
                        enabled: !_submitting,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autofillHints: const <String>[AutofillHints.username],
                        onChanged: (_) {
                          if (_usernameIssue != null) {
                            setState(() => _usernameIssue = null);
                          }
                        },
                      ),
                      ArmxTextField(
                        controller: _passwordController,
                        label: l10n.loginPasswordLabel,
                        obscure: true,
                        errorText: _passwordIssue == null
                            ? null
                            : context.validationMessage(_passwordIssue!),
                        enabled: !_submitting,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const <String>[AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        onChanged: (_) {
                          if (_passwordIssue != null) {
                            setState(() => _passwordIssue = null);
                          }
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.loginRememberDevice,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: _remember,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _remember = value),
                      ),
                      const SizedBox(height: 8),
                      ArmxButton(
                        label: l10n.loginSubmit,
                        icon: Icons.login_rounded,
                        loading: _submitting,
                        expanded: true,
                        onPressed: (_submitting || backoffActive) ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    final backoff = controller.loginBackoff;
    if (backoff != null && backoff > Duration.zero) {
      _startBackoffTimer();
      setState(() {});
      return;
    }

    final usernameIssue = Validators.nonEmpty(_usernameController.text);
    final passwordIssue = Validators.nonEmpty(_passwordController.text);
    if (usernameIssue != null || passwordIssue != null) {
      setState(() {
        _usernameIssue = usernameIssue;
        _passwordIssue = passwordIssue;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      await controller.signIn(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        rememberDevice: _remember,
      );
      if (!mounted) {
        return;
      }
      final intent = controller.consumePendingIntent();
      context.go(intent ?? AppRoutes.dashboard);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _formError = _messageFor(error);
      });
      _startBackoffTimer();
    }
  }

  /// One localized line per failure class — never a raw server string.
  String _messageFor(AppException error) {
    final l10n = context.l10n;
    return switch (error) {
      AuthException(reason: AuthFailureReason.invalidCredentials) =>
        l10n.loginErrorInvalidCredentials,
      AuthException(reason: AuthFailureReason.accountLocked) =>
        l10n.loginErrorAccountLocked,
      AuthException(reason: AuthFailureReason.pairingRejected) =>
        l10n.loginErrorNotPaired,
      AuthException(reason: AuthFailureReason.deviceRevoked) =>
        l10n.loginErrorDeviceRevoked,
      NetworkException() => l10n.loginErrorNetwork,
      RequestTimeoutException() => l10n.loginErrorServerUnreachable,
      ApiException() => l10n.loginErrorServerUnreachable,
      _ => context.errorBody(error),
    };
  }

  void _startBackoffTimer() {
    final backoff = ref.read(authControllerProvider.notifier).loginBackoff;
    if (backoff == null || backoff <= Duration.zero) {
      _backoffTimer?.cancel();
      _backoffTimer = null;
      return;
    }
    _backoffTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final remaining =
          ref.read(authControllerProvider.notifier).loginBackoff;
      if (remaining == null || remaining <= Duration.zero) {
        _backoffTimer?.cancel();
        _backoffTimer = null;
        setState(() {});
      } else {
        setState(() {});
      }
    });
  }
}
