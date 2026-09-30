// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockAdminDomain — one slice of [MockArmxApi].
///
/// Declared as a mixin in a part file so the mock backend stays split across small
/// files while every slice keeps access to the shared in-memory state.
mixin MockAdminDomain on MockArmxApi {
  // ---- Audit ---------------------------------------------------------------

  @override
  Future<List<AuditEntry>> audit(AuditQuery query) async {
    await _delay();
    final search = query.search.toLowerCase();
    final filtered = _audit.where((entry) {
      if (query.riskTier != null && entry.riskTier != query.riskTier) {
        return false;
      }
      if (query.outcome != null && entry.outcome != query.outcome) {
        return false;
      }
      if (query.actor.isNotEmpty && !entry.actor.toLowerCase().contains(query.actor.toLowerCase())) {
        return false;
      }
      if (query.from != null && entry.at.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && entry.at.isAfter(query.to!)) {
        return false;
      }
      if (search.isNotEmpty) {
        final haystack = '${entry.action} ${entry.target} ${entry.detail} ${entry.actor}'
            .toLowerCase();
        if (!haystack.contains(search)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false)
      ..sort((a, b) => b.at.compareTo(a.at));

    final start = query.offset.clamp(0, filtered.length);
    final end = (start + query.limit).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  // ---- Admin & kill-switch -------------------------------------------------

  @override
  Future<AdminState> adminState() async {
    await _delay();
    return _adminState();
  }

  @override
  Future<KillSwitchState> setKillSwitch({required bool engaged, String reason = ''}) async {
    await _delay();
    _killSwitchEngaged = engaged;
    final now = _clock.now().toUtc();
    if (engaged) {
      _toolCalls.clear();
      _emit(SystemKilledEvent(
        receivedAt: now,
        engaged: true,
        reason: reason.isEmpty ? 'Owner engaged the kill-switch' : reason,
        actor: 'owner',
      ));
      // The real server closes the WebSocket; the mock mirrors that behaviour.
      _closeChannel();
    } else {
      _ensureChannel();
      _emit(SystemKilledEvent(
        receivedAt: now,
        engaged: false,
        reason: 'Re-enabled by the owner',
        actor: 'owner',
      ));
    }
    _audit = <AuditEntry>[
      AuditEntry(
        id: 'aud-${_uuid.v4().substring(0, 8)}',
        at: now,
        actor: 'owner',
        action: 'admin.kill',
        target: 'global',
        riskTier: RiskTier.high,
        outcome: AuditOutcome.success,
        detail: engaged ? 'KILL-SWITCH engaged.' : 'KILL-SWITCH released.',
      ),
      ..._audit,
    ];
    return KillSwitchState(
      engaged: engaged,
      at: now,
      reason: reason,
      actor: 'owner',
      socketsClosed: engaged ? 1 : 0,
    );
  }

  @override
  Future<List<ToolToggle>> setToolEnabled({
    required ToolId tool,
    required bool enabled,
  }) async {
    await _delay();
    _tools = _tools
        .map((entry) => entry.id == tool ? entry.copyWith(enabled: enabled) : entry)
        .toList(growable: false);
    return List<ToolToggle>.unmodifiable(_tools);
  }

  @override
  Future<AdminState> revokeDevice(String deviceId) async {
    await _delay();
    _devices = _devices.where((device) => device.id != deviceId).toList(growable: false);
    _emit(DeviceStateEvent(
      receivedAt: _clock.now().toUtc(),
      deviceId: deviceId,
      online: false,
      relayStates: const <String, String>{},
      payload: const <String, Object?>{'revoked': true},
    ));
    return _adminState();
  }
}
