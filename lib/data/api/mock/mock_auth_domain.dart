// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockAuthDomain — one slice of [MockArmxApi].
///
/// Declared as a mixin in a part file so the mock backend stays split across small
/// files while every slice keeps access to the shared in-memory state.
mixin MockAuthDomain on MockArmxApi {
  // ---- Authentication & pairing -------------------------------------------

  @override
  Future<ServerProbe> probe(Uri serverUrl) async {
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
    if (username.trim().toLowerCase() == 'wrong' || password == 'wrong') {
      throw const AuthException(AuthFailureReason.invalidCredentials);
    }
    if (deviceKey.length < 16) {
      throw const AuthException(AuthFailureReason.pairingRejected);
    }
    final now = _clock.now().toUtc();
    return AuthSession(
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
  }

  @override
  Future<PairingResult> pair({
    required Uri serverUrl,
    required String publicKey,
    required String deviceName,
    required String platform,
  }) async {
    await _delay();
    if (publicKey.length < 32) {
      throw const AuthException(AuthFailureReason.pairingRejected);
    }
    return PairingResult(
      deviceId: 'device-${_uuid.v4().substring(0, 8)}',
      deviceKey: 'mockkey_${_uuid.v4().replaceAll('-', '')}',
      site: 'home',
      pairedAt: _clock.now().toUtc(),
    );
  }

  @override
  Future<void> logout() async {
    await _delay();
  }
}
