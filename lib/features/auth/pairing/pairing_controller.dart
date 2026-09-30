// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../core/security/device_identity.dart';
import '../../../core/security/secure_store.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/auth.dart';
import '../../../data/models/preferences.dart';

part 'pairing_controller.g.dart';

/// Steps of the pairing flow, in the order the screen walks them.
enum PairingPhase {
  /// Waiting for a server URL and a successful health check.
  idle,

  /// `GET /health` is in flight.
  testing,

  /// Healthy server + local keypair: QR code and fingerprint are visible.
  identity,

  /// `POST /devices/pair` is in flight.
  submitting,

  /// The server accepted the request; an owner must approve it.
  pending,

  /// Approved and persisted locally; the user taps through to sign in.
  approved,

  /// The owner refused this device; retry posts the request again.
  rejected,
}

/// Immutable view of the pairing screen, watched by the page and redirected by the router.
@immutable
class PairingFlowState {
  /// Creates a pairing state.
  const PairingFlowState({
    this.phase = PairingPhase.idle,
    this.serverUrl = '',
    this.deviceName = '',
    this.probe,
    this.identity,
    this.status,
    this.error,
    this.urlIssue,
    this.paired = false,
  });

  /// Current step of the state machine.
  final PairingPhase phase;

  /// Server URL being tested/used (raw user input until normalised).
  final String serverUrl;

  /// Display name the owner gave to this device.
  final String deviceName;

  /// Last successful `GET /health` answer.
  final ServerProbe? probe;

  /// Local Ed25519 identity shown as QR/fingerprint.
  final DeviceIdentity? identity;

  /// Last pairing status reported by the server.
  final PairingStatus? status;

  /// Last failure (health check or pairing submit), rendered by `ErrorView`.
  final AppException? error;

  /// Blocking validation issue for [serverUrl] (shown under the field).
  final ValidationIssue? urlIssue;

  /// Gate consumed by the router redirect: true once pairing is completed
  /// (or restored from a previous approval).
  final bool paired;

  static const Object _clear = Object();

  /// Copies selected fields; nullable fields are cleared by passing `null` explicitly.
  PairingFlowState copyWith({
    PairingPhase? phase,
    String? serverUrl,
    String? deviceName,
    bool? paired,
    Object? probe = _clear,
    Object? identity = _clear,
    Object? status = _clear,
    Object? error = _clear,
    Object? urlIssue = _clear,
  }) =>
      PairingFlowState(
        phase: phase ?? this.phase,
        serverUrl: serverUrl ?? this.serverUrl,
        deviceName: deviceName ?? this.deviceName,
        paired: paired ?? this.paired,
        probe: probe == _clear ? this.probe : probe as ServerProbe?,
        identity: identity == _clear ? this.identity : identity as DeviceIdentity?,
        status: status == _clear ? this.status : status as PairingStatus?,
        error: error == _clear ? this.error : error as AppException?,
        urlIssue: urlIssue == _clear ? this.urlIssue : urlIssue as ValidationIssue?,
      );
}

/// Owns the pairing state machine: health check → keypair → QR → `POST /devices/pair`
/// (pending/approved/rejected) → persisted "paired" gate.
///
/// Secrets (Ed25519 seed, issued device key) go to `SecureStore`; non-secret metadata
/// (status marker, device name, timestamps) goes to the Drift preferences table.
@Riverpod(keepAlive: true)
class PairingController extends _$PairingController {
  bool _restored = false;

  @override
  PairingFlowState build() => const PairingFlowState();

  /// Restores a previous pairing session (called once from the bootstrap gate).
  ///
  /// Approved pairings flip [PairingFlowState.paired] immediately so the router can
  /// skip this screen; `pending`/`rejected` states resume where they left off.
  Future<void> restore() async {
    if (_restored) {
      return;
    }
    _restored = true;

    String deviceKey = '';
    String deviceId = '';
    String publicKey = '';
    String privateKey = '';
    AppPreferences prefs = const AppPreferences();
    try {
      final store = ref.read(secureStoreProvider);
      deviceKey = await store.read(SecureKeys.deviceKey) ?? '';
      deviceId = await store.read(SecureKeys.deviceId) ?? '';
      publicKey = await store.read(SecureKeys.devicePublicKey) ?? '';
      privateKey = await store.read(SecureKeys.devicePrivateKey) ?? '';
      prefs = await ref.read(preferencesRepositoryProvider).load();
    } on Object catch (error) {
      ref
          .read(appLoggerProvider)
          .w('pairing: restore skipped (${error.runtimeType})');
      return;
    }

    DeviceIdentity? identity;
    if (publicKey.isNotEmpty && privateKey.isNotEmpty) {
      identity = DeviceIdentity(
        deviceName: prefs.pairingDeviceName,
        platform: _platform,
        publicKey: publicKey,
        fingerprintHex: await DeviceKeys.fingerprintFromSpkiBase64(publicKey),
        deviceId: deviceId,
        pairedAt: DateTime.tryParse(prefs.pairingPairedAt)?.toUtc(),
      );
    }

    final restored = PairingFlowState(
      serverUrl: prefs.lastServerUrl,
      deviceName: prefs.pairingDeviceName,
      identity: identity,
    );

    if (deviceKey.isNotEmpty && deviceId.isNotEmpty) {
      // Secure storage is authoritative: an issued device key means "paired".
      state = restored.copyWith(phase: PairingPhase.approved, paired: true);
      return;
    }
    if (identity == null) {
      state = restored;
      return;
    }
    if (prefs.pairingStatus == 'pending') {
      state = restored.copyWith(
        phase: PairingPhase.pending,
        status: PairingStatus(state: PairingState.pending, deviceId: deviceId),
      );
      return;
    }
    if (prefs.pairingStatus == 'rejected') {
      state = restored.copyWith(
        phase: PairingPhase.rejected,
        status: const PairingStatus(state: PairingState.rejected),
      );
      return;
    }
    state = restored.copyWith(phase: PairingPhase.identity);
  }

  /// Updates the typed server URL and clears any previous validation issue.
  void setServerUrl(String url) {
    state = state.copyWith(serverUrl: url, urlIssue: null);
  }

  /// Updates the device display name.
  void setDeviceName(String name) {
    state = state.copyWith(deviceName: name);
  }

  /// Validates the URL, runs `GET /health` and prepares the local Ed25519 identity.
  Future<void> testConnection() async {
    final issue = Validators.serverUrl(state.serverUrl, requireTls: kReleaseMode);
    if (issue != null) {
      state = state.copyWith(urlIssue: issue, error: null);
      return;
    }
    state = state.copyWith(
      phase: PairingPhase.testing,
      urlIssue: null,
      error: null,
      probe: null,
    );
    final serverUrl = Validators.normaliseServerUrl(state.serverUrl);
    try {
      final probe = await ref.read(armxApiProvider).health(serverUrl);
      final identity = await _ensureIdentity();
      await ref.read(preferencesRepositoryProvider).setLastServerUrl(serverUrl.toString());
      state = state.copyWith(
        phase: PairingPhase.identity,
        serverUrl: serverUrl.toString(),
        probe: probe,
        identity: identity,
        error: null,
      );
    } on AppException catch (error) {
      state = state.copyWith(phase: PairingPhase.idle, error: error, probe: null);
    }
  }

  /// Posts `POST /devices/pair` and applies the pending/approved/rejected answer.
  ///
  /// Also used by "Check approval status" while pending and by "Retry" after a
  /// rejection — the endpoint is idempotent per public key.
  Future<void> submitPairing({String deviceName = ''}) async {
    final identity = state.identity;
    if (identity == null || state.phase == PairingPhase.submitting) {
      return;
    }
    final previous = state.phase;
    if (state.serverUrl.trim().isEmpty) {
      state = state.copyWith(urlIssue: ValidationIssue.empty);
      return;
    }
    final effectiveName =
        deviceName.trim().isNotEmpty ? deviceName.trim() : state.deviceName.trim();
    final serverUrl = Validators.normaliseServerUrl(state.serverUrl);
    state = state.copyWith(
      phase: PairingPhase.submitting,
      deviceName: effectiveName,
      error: null,
      urlIssue: null,
    );
    final repository = ref.read(preferencesRepositoryProvider);
    try {
      final status = await ref.read(armxApiProvider).pair(
            serverUrl: serverUrl,
            publicKey: identity.publicKey,
            deviceName: effectiveName,
            platform: identity.platform,
          );
      final result = status.result;
      if (status.state == PairingState.approved && result != null) {
        final store = ref.read(secureStoreProvider);
        await store.write(SecureKeys.deviceKey, result.deviceKey);
        await store.write(SecureKeys.deviceId, result.deviceId);
        await repository.setPairingStatus('approved');
        await repository.setPairingDeviceName(effectiveName);
        await repository.setPairingPairedAt(result.pairedAt.toIso8601String());
        await repository.setLastServerUrl(serverUrl.toString());
        // `paired` stays false until the user taps "Continue to sign in", so the
        // success screen remains visible before the router redirects to login.
        state = state.copyWith(
          phase: PairingPhase.approved,
          status: status,
          error: null,
        );
        return;
      }
      if (status.state == PairingState.pending) {
        await repository.setPairingStatus('pending');
        await repository.setPairingDeviceName(effectiveName);
        state = state.copyWith(
          phase: PairingPhase.pending,
          status: status,
          error: null,
        );
        return;
      }
      // Any other answer keeps the flow where it was; the screen renders its
      // own copy for states it knows and an error view for the rest.
      state = state.copyWith(phase: previous);
    } on AuthException catch (error) {
      if (error.reason == AuthFailureReason.pairingRejected) {
        await repository.setPairingStatus('rejected');
        await repository.setPairingDeviceName(effectiveName);
        state = state.copyWith(
          phase: PairingPhase.rejected,
          status: const PairingStatus(state: PairingState.rejected),
          error: error,
        );
        return;
      }
      state = state.copyWith(phase: previous, error: error);
    } on AppException catch (error) {
      state = state.copyWith(phase: previous, error: error);
    }
  }

  /// Flips the router gate after the approved screen's "Continue" button.
  void confirmPaired() {
    state = state.copyWith(paired: true);
  }

  /// Clears the in-memory flow after "Unpair device" erased the secrets, so the
  /// router sends the user back to a fresh pairing screen.
  void resetAfterUnpair() {
    _restored = true;
    state = const PairingFlowState();
  }

  String get _platform => defaultTargetPlatform.name.toLowerCase();

  /// Loads a stored keypair or generates (and persists) a fresh one.
  Future<DeviceIdentity> _ensureIdentity() async {
    final store = ref.read(secureStoreProvider);
    final existingPublic = await store.read(SecureKeys.devicePublicKey);
    final existingPrivate = await store.read(SecureKeys.devicePrivateKey);
    if (existingPublic != null &&
        existingPublic.isNotEmpty &&
        existingPrivate != null &&
        existingPrivate.isNotEmpty) {
      return DeviceIdentity(
        deviceName: state.deviceName,
        platform: _platform,
        publicKey: existingPublic,
        fingerprintHex: await DeviceKeys.fingerprintFromSpkiBase64(existingPublic),
      );
    }
    final material = await DeviceKeys.generate();
    await store.write(SecureKeys.devicePrivateKey, material.seedBase64);
    await store.write(SecureKeys.devicePublicKey, material.publicKeyBase64);
    return DeviceIdentity(
      deviceName: state.deviceName,
      platform: _platform,
      publicKey: material.publicKeyBase64,
      fingerprintHex: material.fingerprintHex,
    );
  }
}
