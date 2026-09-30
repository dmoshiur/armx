// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockUnlockDomain — one slice of [MockArmxApi].
///
/// Declared as a mixin in a part file so the mock backend stays split across small
/// files while every slice keeps access to the shared in-memory state.
mixin MockUnlockDomain on MockArmxApi {
  // ---- Unlock --------------------------------------------------------------

  @override
  Future<List<UnlockTarget>> unlockTargets() async {
    await _delay();
    return List<UnlockTarget>.unmodifiable(_targets);
  }

  @override
  Future<UnlockRequestOutcome> requestUnlock(
    SignedUnlockToken token, {
    OwnerVerifiedToken? assertion,
  }) async {
    await _delay();
    _guardKillSwitch();
    final now = _clock.now().toUtc();
    if (token.signature.isEmpty || token.publicKey.isEmpty) {
      throw ApiException('Unsigned unlock token rejected', statusCode: 400, serverCode: 'bad_signature');
    }
    if (!token.payload.expiresAt.isAfter(now)) {
      return UnlockRequestOutcome(
        requestId: 'unlock-${_uuid.v4().substring(0, 8)}',
        status: UnlockStatus.expired,
        at: now,
        message: 'Token expired before it reached the target.',
        targetId: token.payload.deviceId,
      );
    }
    if (token.payload.expiresAt.difference(now) > const Duration(seconds: 30)) {
      throw ApiException(
        'Unlock token TTL must not exceed 30 seconds',
        statusCode: 400,
        serverCode: 'token_ttl_too_long',
      );
    }
    final target = _targets.firstWhere(
      (entry) => entry.id == token.payload.deviceId,
      orElse: () => _targets.first,
    );
    if (!target.online) {
      return UnlockRequestOutcome(
        requestId: 'unlock-${_uuid.v4().substring(0, 8)}',
        status: UnlockStatus.failed,
        at: now,
        message: '${target.name} is offline — nothing was unlocked.',
        targetId: target.id,
      );
    }
    return UnlockRequestOutcome(
      requestId: 'unlock-${_uuid.v4().substring(0, 8)}',
      status: UnlockStatus.unlocked,
      at: now,
      message: '${target.name} unlocked'
          '${assertion == null ? ' (owner assertion was not required)' : ' with owner assertion'}',
      targetId: target.id,
    );
  }

  @override
  Future<List<UnlockTarget>> revokeUnlockTarget(String targetId) async {
    await _delay();
    _targets = _targets
        .map((target) => target.id == targetId ? target.copyWith(paired: false) : target)
        .toList(growable: false);
    return List<UnlockTarget>.unmodifiable(_targets);
  }
}
