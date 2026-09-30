// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockAuthDomain — one slice of [MockArmxApi].
///
/// Declared as a mixin in a part file so the mock backend stays split across small
/// files while every slice keeps access to the shared in-memory state.
mixin MockAuthDomain on MockArmxApi {
  // ---- Authentication & pairing -------------------------------------------

  /// `GET /health` — reachability, version and TLS fingerprint probe.
  @override
  Future<ServerProbe> health(Uri serverUrl) async {
    await _delay();
    return ServerProbe(
      reachable: !control.offline,
      at: _clock.now().toUtc(),
      serverVersion: 'mock-1.0.0',
      message: control.offline ? 'Simulated: host unreachable' : 'Mock server ready',
      requiresPairing: true,
      tlsFingerprintMatched: serverUrl.scheme == 'https',
    );
  }

  @override
  Future<AuthSession> login({
    required Uri serverUrl,
    required String username,
    required String password,
    required String deviceKey,
  }) async {
    await _delay();
    // Deterministic lock simulation: the reserved username `locked` always answers
    // `403 auth_account_locked`, whatever the password is.
    if (username.trim().toLowerCase() == 'locked') {
      throw const AuthException(AuthFailureReason.accountLocked);
    }
    if (username.trim().toLowerCase() == 'wrong' || password == 'wrong') {
      throw const AuthException(AuthFailureReason.invalidCredentials);
    }
    if (deviceKey.length < 16) {
      throw const AuthException(AuthFailureReason.pairingRejected);
    }
    final now = _clock.now().toUtc();
    final session = AuthSession(
      accessToken: 'mock.access.${_random.nextInt(1 << 32).toRadixString(16)}',
      refreshToken: 'mock.refresh.${_random.nextInt(1 << 32).toRadixString(16)}',
      expiresAt: now.add(const Duration(minutes: 30)),
      deviceId: 'device-${_uuid.v4().substring(0, 8)}',
      user: const UserProfile(
        id: 'user-mohiur',
        displayName: 'Md. Moshiur Rahman Mohi',
        email: 'owner@thamjj13.top',
        roles: <String>['owner', 'admin'],
      ),
    );
    _pairedDeviceIds.add(session.deviceId);
    return session;
  }

  @override
  Future<AuthTokens> refresh({
    required Uri serverUrl,
    required String refreshToken,
  }) async {
    await _delay();
    // Only tokens this mock minted refresh; anything else is rejected exactly like a
    // real server treats an unknown/rotated-away refresh token.
    if (!refreshToken.startsWith('mock.refresh.')) {
      throw const AuthException(AuthFailureReason.refreshRejected);
    }
    final now = _clock.now().toUtc();
    return AuthTokens(
      accessToken: 'mock.access.${_random.nextInt(1 << 32).toRadixString(16)}',
      refreshToken: 'mock.refresh.${_random.nextInt(1 << 32).toRadixString(16)}',
      expiresAt: now.add(const Duration(minutes: 30)),
    );
  }

  @override
  Future<PairingStatus> pair({
    required Uri serverUrl,
    required String publicKey,
    required String deviceName,
    required String platform,
  }) async {
    await _delay();
    if (publicKey.length < 32) {
      throw const AuthException(AuthFailureReason.pairingRejected);
    }
    final outcome = control.pairingOutcome;
    if (outcome == MockPairingOutcome.rejected) {
      _pendingPairing.remove(publicKey);
      throw const AuthException(AuthFailureReason.pairingRejected);
    }
    if (outcome == MockPairingOutcome.pending) {
      // Stable device id per public key: re-polling returns the same pending slot
      // until the control knob flips to `approved`.
      final deviceId =
          _pendingPairing.putIfAbsent(publicKey, () => 'device-${_uuid.v4().substring(0, 8)}');
      _logger.i('mock: device $deviceId awaits approval');
      return PairingStatus(
        state: PairingState.pending,
        deviceId: deviceId,
        message: 'Awaiting owner approval',
      );
    }
    // `approved`: when the request was previously queued as pending, approve the very
    // same device id so the screen's status poll stays consistent.
    final deviceId = _pendingPairing.remove(publicKey) ?? 'device-${_uuid.v4().substring(0, 8)}';
    final result = PairingResult(
      deviceId: deviceId,
      deviceKey: 'mockkey_${_uuid.v4().replaceAll('-', '')}',
      site: 'home',
      pairedAt: _clock.now().toUtc(),
    );
    _pairedDeviceIds.add(result.deviceId);
    _logger.i('mock: device $deviceId paired');
    return PairingStatus(
      state: PairingState.approved,
      deviceId: deviceId,
      message: 'Pairing approved',
      result: result,
    );
  }

  @override
  Future<void> logout() async {
    await _delay();
  }

  @override
  Future<void> unpair({
    required Uri serverUrl,
    required String deviceId,
  }) async {
    await _delay();
    _pairedDeviceIds.remove(deviceId);
    _pendingPairing.removeWhere((_, pendingDeviceId) => pendingDeviceId == deviceId);
    _logger.i('mock: device $deviceId unpairs');
  }

  // ---- Pairing bookkeeping -------------------------------------------------

  /// Public keys that currently sit in the `pending` queue (public key → device id).
  final Map<String, String> _pendingPairing = <String, String>{};

  /// Device ids the mock currently treats as registered.
  final Set<String> _pairedDeviceIds = <String>{};
}
