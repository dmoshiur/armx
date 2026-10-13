// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../core/router/routes.dart';
import '../../core/security/risk_tier.dart';
import '../models/admin.dart';
import '../models/alarm.dart';
import '../models/assistant.dart';
import '../models/device.dart';
import '../models/guest.dart';
import '../models/linked_device.dart';
import '../models/messaging.dart';
import '../models/web_builder.dart';
import 'auth_session.dart';

/// The complete backend contract.
///
/// Two implementations satisfy it:
///
/// * [MockArmxApi] — deterministic, in-memory, always available. This is what makes every
///   screen, flow and test exercisable with no server, no hardware and no network.
/// * [RestArmxApi] — dio + `web_socket_channel` against the FastAPI backend described in
///   `docs/api.md`.
///
/// Every method either returns a model or throws an `AppException` from
/// `core/errors/app_exception.dart`. Nothing here returns `null` to mean "failed": an
/// absent value and a failed call are different outcomes and the UI renders them
/// differently.
abstract interface class ArmxApi {
  // ---- Authentication ------------------------------------------------------

  /// `POST /auth/login`.
  Future<AuthSession> login({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
  });

  /// `POST /auth/signup`. Creates the account and sends the verification email; the
  /// response carries **no** session, because an unverified account cannot be signed in.
  Future<SignupReceipt> signup({
    required String email,
    required String password,
    required String displayName,
  });

  /// `POST /auth/google`. Exchanges an OpenID Connect id token for a session.
  Future<AuthSession> signInWithGoogle({required String idToken});

  /// `POST /auth/verify-email`.
  Future<AuthSession> verifyEmail({required String token});

  /// `POST /auth/verify-email/resend`.
  Future<void> resendVerification({required String email});

  /// `POST /auth/forgot-password`.
  ///
  /// Always succeeds from the client's point of view — the response must not reveal
  /// whether the address has an account, so the screen always shows "check your inbox".
  Future<void> requestPasswordReset({required String email});

  /// `POST /auth/reset-password`.
  Future<void> resetPassword({required String token, required String newPassword});

  /// `GET /auth/reset-password/check?token=…` — validates a reset token **before** the
  /// form is shown, so an expired link gets its own screen instead of a form that fails
  /// on submit.
  Future<TokenValidity> checkResetToken({required String token});

  /// `POST /auth/refresh`.
  Future<AuthSession> refresh({required String refreshToken});

  /// `POST /auth/logout`. Best effort: the client clears local state regardless.
  Future<void> logout();

  /// `GET /auth/me`.
  Future<AuthUser> me();

  // ---- Sessions ------------------------------------------------------------

  /// `GET /auth/sessions`.
  Future<List<SessionInfo>> sessions();

  /// `DELETE /auth/sessions/{id}`.
  Future<void> revokeSession(String sessionId);

  // ---- Assistant -----------------------------------------------------------

  /// Server-push stream: assistant tokens, tool proposals, device state, kill-switch.
  Stream<AssistantEvent> events();

  /// `POST /assistant/messages`. The reply arrives on [events].
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? languageCode,
  });

  /// `POST /assistant/tool-calls/{id}/decision`.
  ///
  /// Must only be called after the user has explicitly approved or denied the proposal.
  Future<void> decideToolCall({
    required String toolCallId,
    required ToolDecision decision,
    String? denyReason,
  });

  /// `GET /assistant/transcript`.
  Future<List<ChatMessage>> transcript({required String conversationId});

  // ---- Smart home ----------------------------------------------------------

  /// `GET /rooms`.
  Future<List<ArmxRoom>> rooms();

  /// `GET /devices`.
  Future<List<ArmxDevice>> devices();

  /// `POST /devices/{id}/command`.
  Future<DeviceCommandResult> sendDeviceCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> parameters = const <String, Object?>{},
    RiskTier? declaredRisk,
  });

  // ---- Alarms --------------------------------------------------------------

  /// `GET /alarms`.
  Future<List<ArmxAlarm>> alarms();

  /// `POST /alarms` / `PATCH /alarms/{id}`. An id of `new` creates.
  Future<ArmxAlarm> saveAlarm(ArmxAlarm alarm);

  /// `DELETE /alarms/{id}`.
  Future<void> deleteAlarm(String alarmId);

  /// `POST /alarms/{id}/ring-test` — rings the targets once so the owner can check them.
  Future<ArmxAlarm> testAlarmRing(String alarmId);

  /// `POST /alarms/{id}/acknowledge`.
  Future<ArmxAlarm> acknowledgeAlarm(String alarmId);

  // ---- Linked devices ------------------------------------------------------

  /// `GET /linked-devices`.
  Future<List<LinkedDevice>> linkedDevices();

  /// `POST /linked-devices/pairing` — starts a pairing offer (code + QR payload).
  Future<PairingOffer> startPairing({required String deviceName, required String platform});

  /// `POST /linked-devices/pairing/{code}/approve` — approves an offer from an
  /// already-trusted device.
  Future<LinkedDevice> approvePairing(String code);

  /// `POST /linked-devices/pairing/cancel`.
  Future<void> cancelPairing();

  /// `POST /linked-devices/{id}/unlink`, gated by the **owner's own password**.
  ///
  /// The password belongs to the account that linked the target, not to the caller and
  /// never to a shared admin credential. A wrong password throws
  /// `ValidationException`/`ForbiddenException` and nothing is unlinked.
  Future<void> unlinkDevice({required String deviceId, required String ownerPassword});

  // ---- Guest greeter -------------------------------------------------------

  /// `GET /greeter/state`.
  Future<GreeterState> greeterState();

  /// `POST /greeter/camera` — `live` | `off` | `killed`.
  Future<GreeterState> setGreeterCamera({required String state});

  /// `GET /greeter/guests`.
  Future<List<GuestProfile>> guests();

  /// `POST /greeter/guests` — enrols one guest after explicit consent.
  Future<GuestProfile> enrollGuest({
    required String displayName,
    required bool consentGiven,
    String? note,
  });

  /// `DELETE /greeter/guests/{id}` — immediate and irreversible.
  Future<void> deleteGuest(String guestId);

  /// `GET /greeter/events`.
  Future<List<GreeterEvent>> greeterEvents();

  // ---- Web builder ---------------------------------------------------------

  /// `POST /web-builder/drafts` — generates a draft **without deploying anything**.
  Future<SiteDraft> generateSite({required String prompt, String? templateHint});

  /// `POST /web-builder/deploy` — the destructive step. Only called after the
  /// confirmation dialog resolves true.
  Future<Deployment> deploySite({
    required String draftId,
    required String repository,
    required String branch,
  });

  /// `GET /web-builder/deployments`.
  Future<List<Deployment>> deployments();

  // ---- Messaging personality ----------------------------------------------

  /// `GET /messaging/contacts`.
  Future<List<Contact>> contacts();

  /// `GET /messaging/tones`.
  Future<List<ToneProfile>> toneProfiles();

  /// `POST /messaging/tones`.
  Future<ToneProfile> saveToneProfile(ToneProfile profile);

  /// `PATCH /messaging/contacts/{id}` — mostly to flip auto-send vs draft-only.
  Future<Contact> updateContact(Contact contact);

  // ---- Admin ---------------------------------------------------------------

  /// `GET /admin/users`.
  Future<List<AdminUserRow>> adminUsers();

  /// `PATCH /admin/users/{id}` — role and status changes.
  Future<AdminUserRow> updateAdminUser({
    required String userId,
    UserRole? role,
    AccountStatus? status,
  });

  /// `GET /audit`.
  Future<List<AuditEntry>> auditLog({
    String? actorEmail,
    String? action,
    int limit = 100,
  });

  /// `GET /admin/tools`.
  Future<List<ToolToggle>> toolToggles();

  /// `POST /admin/tools/{id}`.
  Future<ToolToggle> setToolEnabled({required String toolId, required bool enabled});

  /// `POST /admin/kill-switch`. Engages or releases the global stop. Works without any
  /// biometric — it is the emergency brake.
  Future<KillSwitchState> setKillSwitch({required bool engaged, String reason = ''});

  /// `GET /admin/kill-switch`.
  Future<KillSwitchState> killSwitchState();

  /// Releases sockets and timers.
  Future<void> dispose();
}

/// Events pushed by the backend.
sealed class AssistantEvent {
  /// Const constructor for subclasses.
  const AssistantEvent();
}

/// A streamed chunk of the assistant's reply.
final class AssistantTokenEvent extends AssistantEvent {
  /// Creates a token event.
  const AssistantTokenEvent({required this.messageId, required this.text, this.done = false});

  /// Message the chunk belongs to.
  final String messageId;

  /// The chunk.
  final String text;

  /// True on the final chunk, so the UI can stop the "typing" indicator.
  final bool done;
}

/// The assistant proposes an action.
final class AssistantToolCallEvent extends AssistantEvent {
  /// Creates a tool-call event.
  const AssistantToolCallEvent({required this.call});

  /// The proposal, including its risk tier.
  final ToolCall call;
}

/// The status of a previously proposed call changed.
final class AssistantToolStatusEvent extends AssistantEvent {
  /// Creates a status event.
  const AssistantToolStatusEvent({
    required this.toolCallId,
    required this.status,
    this.message,
  });

  /// Which call.
  final String toolCallId;

  /// Its new status.
  final ToolCallStatus status;

  /// Optional detail from the backend.
  final String? message;
}

/// A device's state changed.
final class AssistantDeviceEvent extends AssistantEvent {
  /// Creates a device event.
  const AssistantDeviceEvent({required this.device});

  /// The device's new state.
  final ArmxDevice device;
}

/// The kill-switch was engaged or released (possibly by someone else).
final class AssistantKillSwitchEvent extends AssistantEvent {
  /// Creates a kill-switch event.
  const AssistantKillSwitchEvent({required this.state});

  /// The new state.
  final KillSwitchState state;
}

/// A voice input began or ended, so multiple devices can show "listening".
final class AssistantVoiceEvent extends AssistantEvent {
  /// Creates a voice event.
  const AssistantVoiceEvent({required this.listening, this.languageCode});

  /// True when capture started.
  final bool listening;

  /// Language being captured.
  final String? languageCode;
}

/// The transport dropped and reconnected. The transcript does not need rebuilding, but the
/// UI shows a notice so a gap in the stream is never silent.
final class AssistantConnectionEvent extends AssistantEvent {
  /// Creates a connection event.
  const AssistantConnectionEvent({required this.connected, this.reason});

  /// True when the socket is usable again.
  final bool connected;

  /// Why it dropped, when known.
  final String? reason;
}

/// Greeter state, so the camera indicator follows the backend rather than local belief.
@immutable
class GreeterState {
  /// Creates a state.
  const GreeterState({
    required this.camera,
    required this.killEngaged,
    this.startedAt,
    this.enrolledGuestCount = 0,
    this.lastEventAt,
  });

  /// Camera state.
  final GreeterCameraState camera;

  /// Whether the kill switch is engaged.
  final bool killEngaged;

  /// When the current session started.
  final DateTime? startedAt;

  /// How many guests are enrolled.
  final int enrolledGuestCount;

  /// When the last recognition happened.
  final DateTime? lastEventAt;

  /// Parses from the wire.
  factory GreeterState.fromJson(Map<String, Object?> json) => GreeterState(
        camera: switch ((json['camera'] as String?)?.toLowerCase()) {
          'live' || 'on' => GreeterCameraState.live,
          'killed' => GreeterCameraState.killed,
          'permission_required' => GreeterCameraState.permissionRequired,
          'unavailable' => GreeterCameraState.unavailable,
          _ => GreeterCameraState.off,
        },
        killEngaged: json['kill_engaged'] == true,
        startedAt: json['started_at'] is String
            ? DateTime.tryParse(json['started_at']! as String)
            : null,
        enrolledGuestCount: (json['guest_count'] as num?)?.toInt() ?? 0,
        lastEventAt: json['last_event_at'] is String
            ? DateTime.tryParse(json['last_event_at']! as String)
            : null,
      );
}
