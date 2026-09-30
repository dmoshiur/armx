// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/security/secure_screen.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/armx_controls.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/state_views.dart';
import '../session/auth_controller.dart';
import 'app_lock_controller.dart';

/// How the lock screen is currently challenging the user.
enum _LockMode {
  /// Probing device capabilities (brief).
  checking,

  /// System biometric / device-PIN prompt path.
  system,

  /// Verifying the Argon2id-hashed app PIN.
  pinVerify,

  /// First-run app-PIN creation (no system authenticator available).
  pinSetup,
}

/// Step 2 app-lock screen: LOW-tier gate (see [AppLockController]).
///
/// Shown on cold start with a restored session and on resume past the
/// auto-lock timeout. Prefers the system authenticator and falls back to the
/// app-level PIN when the device offers no biometrics and no screen PIN.
class LockPage extends ConsumerStatefulWidget {
  /// Creates the app-lock screen.
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  late final TextEditingController _pinController;
  late final TextEditingController _confirmController;
  var _mode = _LockMode.checking;
  var _systemAvailable = false;
  var _busy = false;
  String? _error;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    _confirmController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);

    return SecureScreen(
      security: ref.watch(screenSecurityProvider),
      child: Scaffold(
        appBar: ArmxAppBar(title: l10n.appLockTitle),
        body: ArmxBackground(
          child: ArmxPageBody(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: GlassPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Icon(
                          Icons.fingerprint_rounded,
                          size: 56,
                          color: colors.cyan,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...<Widget>[
                        _noticeRow(),
                        const SizedBox(height: 16),
                      ],
                      ..._body(l10n),
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

  List<Widget> _body(AppLocalizations l10n) => switch (_mode) {
        _LockMode.checking => <Widget>[
            Center(child: LoadingView(message: l10n.appLockChecking)),
          ],
        _LockMode.system => <Widget>[
            ArmxButton(
              label: l10n.appLockUnlockAction,
              icon: Icons.lock_open_rounded,
              expanded: true,
              loading: _busy,
              onPressed: _busy ? null : _runSystemAuth,
            ),
            if (ref.watch(appLockControllerProvider).pinConfigured) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _mode = _LockMode.pinVerify;
                          _error = null;
                        }),
                child: Text(l10n.appLockUsePin),
              ),
            ],
          ],
        _LockMode.pinVerify => <Widget>[
            ArmxTextField(
              controller: _pinController,
              label: l10n.appLockPinEntryLabel,
              obscure: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              onSubmitted: (_) => _verifyPin(),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 16),
            ArmxButton(
              label: l10n.appLockUnlockAction,
              icon: Icons.lock_open_rounded,
              expanded: true,
              loading: _busy,
              onPressed: _busy ? null : _verifyPin,
            ),
            if (_systemAvailable) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _switchToSystem,
                child: Text(l10n.appLockUseSystem),
              ),
            ],
          ],
        _LockMode.pinSetup => <Widget>[
            Text(
              l10n.appLockPinSetupTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.appLockPinSetupBody,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ArmxColors.of(context).muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ArmxTextField(
              controller: _pinController,
              label: l10n.appLockPinEntryLabel,
              obscure: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            ArmxTextField(
              controller: _confirmController,
              label: l10n.appLockPinConfirmLabel,
              obscure: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              onSubmitted: (_) => _savePin(),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 16),
            ArmxButton(
              label: l10n.appLockPinSave,
              icon: Icons.password_rounded,
              expanded: true,
              loading: _busy,
              onPressed: _busy ? null : _savePin,
            ),
          ],
      };

  Widget _noticeRow() {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: ArmxColors.of(context).amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: ArmxColors.of(context).amber),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    if (_started) {
      return;
    }
    _started = true;
    final lock = ref.read(appLockControllerProvider);
    if (!lock.lockDue) {
      _finish();
      return;
    }
    final available = await ref.read(systemAuthenticatorProvider).isAvailable();
    if (!mounted) {
      return;
    }
    if (available) {
      setState(() {
        _systemAvailable = true;
        _mode = _LockMode.system;
      });
      await _runSystemAuth();
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _systemAvailable = false;
      _mode = lock.pinConfigured ? _LockMode.pinVerify : _LockMode.pinSetup;
      _error = lock.pinConfigured ? null : l10n.appLockNoSystem;
    });
  }

  Future<void> _switchToSystem() async {
    setState(() {
      _mode = _LockMode.system;
      _error = null;
    });
    await _runSystemAuth();
  }

  Future<void> _runSystemAuth() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final passed = await ref
          .read(appLockControllerProvider.notifier)
          .systemUnlock(l10n.appLockPrompt);
      if (!mounted) {
        return;
      }
      if (passed) {
        _finish();
        return;
      }
      setState(() {
        _busy = false;
        _error = l10n.appLockFailed;
      });
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.reason == AuthFailureReason.biometricUnavailable) {
        final lock = ref.read(appLockControllerProvider);
        setState(() {
          _busy = false;
          _mode = lock.pinConfigured ? _LockMode.pinVerify : _LockMode.pinSetup;
          _error = lock.pinConfigured ? null : l10n.appLockNoSystem;
        });
        return;
      }
      setState(() {
        _busy = false;
        _error = l10n.appLockFailed;
      });
    } on AppException {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = l10n.appLockFailed;
      });
    }
  }

  Future<void> _verifyPin() async {
    final l10n = context.l10n;
    final pin = _pinController.text;
    if (!_looksLikePin(pin)) {
      setState(() => _error = l10n.appLockPinInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final passed =
          await ref.read(appLockControllerProvider.notifier).pinUnlock(pin);
      if (!mounted) {
        return;
      }
      if (passed) {
        _finish();
        return;
      }
      _pinController.clear();
      setState(() {
        _busy = false;
        _error = l10n.appLockWrongPin;
      });
    } on AppException {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = l10n.appLockFailed;
      });
    }
  }

  Future<void> _savePin() async {
    final l10n = context.l10n;
    final pin = _pinController.text;
    if (!_looksLikePin(pin)) {
      setState(() => _error = l10n.appLockPinInvalid);
      return;
    }
    if (pin != _confirmController.text) {
      setState(() => _error = l10n.appLockPinMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(appLockControllerProvider.notifier).configurePin(pin);
      if (!mounted) {
        return;
      }
      _finish();
    } on AppException {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = l10n.appLockFailed;
      });
    }
  }

  bool _looksLikePin(String value) => RegExp(r'^[0-9]{4,8}$').hasMatch(value);

  void _finish() {
    final intent = ref.read(authControllerProvider.notifier).consumePendingIntent();
    context.go(intent ?? AppRoutes.dashboard);
  }
}
