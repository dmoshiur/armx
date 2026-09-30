// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../core/security/risk_tier.dart';
import '../models/admin.dart';
import '../models/audit_entry.dart';
import '../models/auth.dart';
import '../models/device.dart';
import '../models/rules.dart';
import '../models/unlock.dart';
import 'ws_events.dart';

/// The complete backend contract of A.R.M.X AI.
///
/// Two implementations exist:
/// * `MockArmxApi` — deterministic, in-memory, always available (default while the backend
///   does not exist);
/// * `RestArmxApi` — dio + `web_socket_channel` against a real server (step 2 onwards).
///
/// Every method either returns a model or throws an [AppException] from
/// `core/errors/app_exception.dart`; no raw `DioException` ever escapes this layer.
///
/// REST endpoints (see `docs/api.md` for full JSON schemas):
/// `POST /auth/login`, `POST /devices/pair`, `GET /devices`,
/// `POST /devices/{id}/command`, `GET /audit`, `POST /admin/kill`, `POST /admin/tools`,
/// `POST /unlock/request`, `GET|POST /rules`, plus `GET /ws` for events.
abstract interface class ArmxApi {
  // ---- Authentication & pairing -------------------------------------------

  /// Probes a server before pairing: reachability, version and TLS fingerprint.
  Future<ServerProbe> probe(Uri serverUrl);

  /// Signs in and returns a session. The device key is sent as `X-Armx-Device-Key`.
  Future<AuthSession> login({
    required Uri serverUrl,
    required String username,
    required String password,
    required String deviceKey,
  });

  /// Registers this device's Ed25519 public key with the server.
  Future<PairingResult> pair({
    required Uri serverUrl,
    required String publicKey,
    required String deviceName,
    required String platform,
  });

  /// Invalidates the current session server-side (best effort).
  Future<void> logout();

  // ---- Devices -------------------------------------------------------------

  /// Lists every ESP32 node visible to this account.
  Future<List<ArmxDevice>> devices();

  /// Sends a command to a device (relay toggle, scene member, momentary pulse).
  Future<DeviceCommandResult> sendCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> parameters = const <String, Object?>{},
    RiskTier? riskTier,
  });

  /// Activates a scene by id.
  Future<void> activateScene(String sceneId);

  // ---- Audit ---------------------------------------------------------------

  /// Queries the audit log with filters/paging.
  Future<List<AuditEntry>> audit(AuditQuery query);

  // ---- Admin & kill-switch -------------------------------------------------

  /// Current global assistant/tool state.
  Future<AdminState> adminState();

  /// Engages or releases the global kill-switch. Works without any biometrics.
  Future<KillSwitchState> setKillSwitch({
    required bool engaged,
    String reason = '',
  });

  /// Enables/disables one tool and returns the refreshed tool list.
  Future<List<ToolToggle>> setToolEnabled({required ToolId tool, required bool enabled});

  /// Revokes a device key; the device is disconnected on its next request.
  Future<AdminState> revokeDevice(String deviceId);

  // ---- Unlock (client side) ------------------------------------------------

  /// Machines paired for unlock.
  Future<List<UnlockTarget>> unlockTargets();

  /// Posts a signed, short-lived (≤30 s) unlock token.
  ///
  /// [assertion] is the optional single-use `owner_verified` token; raw biometric data is
  /// never part of this call.
  Future<UnlockRequestOutcome> requestUnlock(
    SignedUnlockToken token, {
    OwnerVerifiedToken? assertion,
  });

  /// Removes a paired unlock target (revoke).
  Future<List<UnlockTarget>> revokeUnlockTarget(String targetId);

  // ---- Rules ---------------------------------------------------------------

  /// Lists automation rules.
  Future<List<AutomationRule>> rules();

  /// Creates or replaces a rule.
  Future<AutomationRule> upsertRule(AutomationRule rule);

  /// Deletes a rule.
  Future<void> deleteRule(String ruleId);

  /// Simulates a rule without executing its action (the builder's dry-run switch).
  Future<RuleDryRunResult> dryRunRule(AutomationRule rule);

  // ---- Chat & realtime -----------------------------------------------------

  /// Server-push event stream (assistant tokens, tool requests, device state, kill switch).
  Stream<WsEvent> events();

  /// Sends a user message; the reply arrives through [events].
  Future<void> sendChatMessage(String text, {required String conversationId});

  /// Approves or denies a pending tool call.
  Future<void> decideToolCall({
    required String toolCallId,
    required bool approve,
    OwnerVerifiedToken? assertion,
  });

  /// Releases sockets/timers. Called when the session ends or the app shuts down.
  Future<void> dispose();
}
