// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/security/security_constants.dart';
import 'app_pin_store.dart';
import 'system_authenticator.dart';

part 'app_lock_controller.g.dart';

/// Platform authenticator used by the app-lock gate; overridable in tests.
@Riverpod(keepAlive: true)
SystemAuthenticator systemAuthenticator(Ref ref) => LocalSystemAuthenticator();

/// Pure auto-lock decision, kept free of I/O so unit tests can drive it with a
/// fixed-clock timeline (see `core/utils/clock.dart`).
abstract final class AppLockPolicy {
  /// Whether the app must re-lock when it returns to the foreground.
  ///
  /// * [enabled] is the "Require unlock to open A.R.M.X" setting.
  /// * [timeoutSeconds] is the background grace period (`0` = immediately).
  /// * [backgroundedAt] is when the app was paused (missing ⇒ never
  ///   backgrounded ⇒ nothing to evaluate).
  ///
  /// Fails closed: a clock that moved backwards (device time changed while
  /// backgrounded) locks instead of granting a grace period.
  static bool shouldLockOnResume({
    required bool enabled,
    required int timeoutSeconds,
    required DateTime? backgroundedAt,
    required DateTime now,
  }) {
    if (!enabled || backgroundedAt == null) {
      return false;
    }
    if (timeoutSeconds <= 0) {
      return true;
    }
    if (now.isBefore(backgroundedAt)) {
      return true;
    }
    return now.difference(backgroundedAt) >= Duration(seconds: timeoutSeconds);
  }
}

/// Snapshot of the app-lock gate as the router and the lock screen see it.
@immutable
class AppLockState {
  /// Creates an app-lock state.
  const AppLockState({
    this.enabled = true,
    this.timeoutSeconds = SecurityConstants.defaultAutoLockSeconds,
    this.lockDue = false,
    this.pinConfigured = false,
  });

  /// "Require unlock to open A.R.M.X" setting (default ON per spec).
  final bool enabled;

  /// Background grace period before a resume re-locks (`0` = immediately).
  final int timeoutSeconds;

  /// Router gate: `paired && signedIn && lockDue ⇒ /lock`.
  final bool lockDue;

  /// Whether [AppPinStore] already holds an app PIN (fallback readiness).
  final bool pinConfigured;

  /// Copies selected fields.
  AppLockState copyWith({
    bool? enabled,
    bool? lockDue,
    bool? pinConfigured,
    int? timeoutSeconds,
  }) =>
      AppLockState(
        enabled: enabled ?? this.enabled,
        lockDue: lockDue ?? this.lockDue,
        pinConfigured: pinConfigured ?? this.pinConfigured,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      );
}

/// Owns the step-2 **LOW-tier app-lock gate**: cold start + resume re-locking,
/// the system biometric/device-PIN challenge, and the app-PIN fallback.
///
/// ## LOW-tier gate vs `RiskPolicy` (MEDIUM/HIGH)
///
/// This gate is deliberately *not* a `RiskPolicy` verification step. It answers
/// only "may the A.R.M.X UI be shown on this device right now?" (spec tier
/// **LOW**): the gate is unlocked by the platform authenticator — device
/// biometrics or device PIN — or by the Argon2id-hashed app PIN, on cold start
/// or on resume past the auto-lock timeout. It runs entirely on-device, issues
/// no `VerificationEvidence`, and therefore can never satisfy (or be
/// substituted for) the `RiskPolicy` **MEDIUM/HIGH** checks in
/// `core/security/risk_policy.dart`, which demand fresh face/voice/system
/// verification before privileged *actions*. Unlocking the app must never be
/// recorded as action verification evidence, and vice versa.
///
/// Lifecycle: `bootstrap` calls [restore] after the auth restore (phase 5);
/// Settings drives [configure]; a successful sign-in calls [unlock].
@Riverpod(keepAlive: true)
class AppLockController extends _$AppLockController with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _restored = false;

  @override
  AppLockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return const AppLockState();
  }

  /// Restores the persisted lock configuration (called once from the bootstrap
  /// gate, after the auth restore).
  ///
  /// With [sessionRestored] (a usable session came back from storage) and the
  /// setting ON, the gate starts **locked**: that is the whole point of
  /// "require unlock to open". A signed-out start stays unlocked because the
  /// router routes to the login screen first and [unlock] runs on sign-in.
  ///
  /// Preference read failures fail **closed** (setting stays ON with the
  /// default timeout).
  Future<void> restore({required bool sessionRestored}) async {
    if (_restored) {
      return;
    }
    _restored = true;

    var enabled = true;
    var timeoutSeconds = SecurityConstants.defaultAutoLockSeconds;
    try {
      final prefs = await ref.read(preferencesRepositoryProvider).load();
      enabled = prefs.appLockEnabled;
      timeoutSeconds = prefs.autoLockTimeoutSeconds;
    } on Object {
      enabled = true;
      timeoutSeconds = SecurityConstants.defaultAutoLockSeconds;
    }

    var pinConfigured = false;
    try {
      pinConfigured = await ref.read(appPinStoreProvider).isConfigured;
    } on Object {
      pinConfigured = false;
    }

    state = state.copyWith(
      enabled: enabled,
      timeoutSeconds: timeoutSeconds,
      pinConfigured: pinConfigured,
      lockDue: enabled && sessionRestored,
    );
  }

  /// Applies the Settings toggles without waiting for the next cold start.
  ///
  /// Disabling drops any pending lock immediately. Enabling does **not**
  /// hijack the current foreground session — the gate engages at the next
  /// cold start or resume, which is what "require unlock to open" promises.
  Future<void> configure({
    required bool enabled,
    required int timeoutSeconds,
  }) async {
    state = state.copyWith(
      enabled: enabled,
      timeoutSeconds: timeoutSeconds,
      lockDue: enabled ? state.lockDue : false,
    );
  }

  /// Releases the gate (successful sign-in, or a satisfied lock screen).
  void unlock() {
    _backgroundedAt = null;
    if (state.lockDue) {
      state = state.copyWith(lockDue: false);
    }
  }

  /// Runs the system biometric/device-PIN challenge with [localizedReason].
  ///
  /// Returns `true` (and releases the gate) only when the user passed it.
  /// Throws [AuthException] with `biometricUnavailable` when the device
  /// offers no system challenge (caller should switch to the app-PIN path) or
  /// `appLockFailed` on platform errors; a failed/dismissed challenge simply
  /// returns `false`.
  Future<bool> systemUnlock(String localizedReason) async {
    final authenticator = ref.read(systemAuthenticatorProvider);
    if (!await authenticator.isAvailable()) {
      throw const AuthException(AuthFailureReason.biometricUnavailable);
    }
    try {
      final passed = await authenticator.authenticate(localizedReason);
      if (passed) {
        unlock();
      }
      return passed;
    } on AuthException {
      rethrow;
    } on AppException {
      rethrow;
    } on Object {
      // local_auth 3.x surfaces LocalAuthException (userCanceled, deviceError,
      // …) — normalize so the lock screen only ever deals in AuthException.
      throw const AuthException(AuthFailureReason.appLockFailed);
    }
  }

  /// Verifies the app-level PIN (fallback path) and releases the gate on match.
  Future<bool> pinUnlock(String pin) async {
    final passed = await ref.read(appPinStoreProvider).verify(pin);
    if (passed) {
      unlock();
    }
    return passed;
  }

  /// Hashes and persists a new app-level PIN, marking the fallback ready.
  Future<void> configurePin(String pin) async {
    await ref.read(appPinStoreProvider).configure(pin);
    state = state.copyWith(pinConfigured: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.paused:
        _onBackgrounded();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onBackgrounded() {
    if (!state.enabled) {
      return;
    }
    _backgroundedAt = ref.read(clockProvider).now();
    if (state.timeoutSeconds <= 0 && !state.lockDue) {
      // "Immediately": lock the moment we leave the foreground so the app
      // switcher preview and the next frame are already behind the gate.
      state = state.copyWith(lockDue: true);
    }
  }

  void _onResumed() {
    final due = AppLockPolicy.shouldLockOnResume(
      enabled: state.enabled,
      timeoutSeconds: state.timeoutSeconds,
      backgroundedAt: _backgroundedAt,
      now: ref.read(clockProvider).now(),
    );
    if (due && !state.lockDue) {
      state = state.copyWith(lockDue: true);
    }
  }
}
