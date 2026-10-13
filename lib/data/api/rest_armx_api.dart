// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_client.dart';
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
import 'armx_api.dart';
import 'auth_session.dart';

/// The REST + WebSocket transport for the real backend.
///
/// Every call goes through [ApiClient], which owns the base URL, the bearer token, the
/// refresh dance and the mapping of transport failures onto `AppException`. This class
/// therefore contains no HTTP details at all — only endpoint paths and JSON shaping, which
/// is what keeps `docs/api.md` and this file in step.
///
/// The API base path is `/v1` for everything except the auth endpoints, matching the
/// backend's router layout.
class RestArmxApi implements ArmxApi {
  /// Creates the transport.
  RestArmxApi({
    required ApiClient client,
    required AppConfig config,
    WebSocketClient? socket,
  })  : _client = client,
        _config = config,
        _socket = socket;

  final ApiClient _client;
  final AppConfig _config;
  final WebSocketClient? _socket;

  static const String _v1 = '/v1';

  // ---- helpers -------------------------------------------------------------

  Future<Map<String, Object?>> _get(String path, {bool auth = true}) async =>
      (await _client.getJson(path, authenticated: auth)).data;

  Future<List<Object?>> _getList(String path, {bool auth = true}) async =>
      (await _client.getJsonList(path, authenticated: auth)).data;

  Future<Map<String, Object?>> _post(
    String path, {
    Object? body,
    bool auth = true,
  }) async =>
      (await _client.postJson(path, body: body, authenticated: auth)).data;

  Future<Map<String, Object?>> _patch(String path, {Object? body}) async =>
      (await _client.patchJson(path, body: body)).data;

  List<T> _mapList<T>(
    List<Object?> raw,
    T Function(Map<String, Object?> json) parse,
  ) =>
      raw
          .whereType<Map<String, Object?>>()
          .map(parse)
          .toList(growable: false);

  // ---- auth ---------------------------------------------------------------

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
  }) async {
    final Map<String, Object?> json = await _post(
      '/auth/login',
      auth: false,
      body: <String, Object?>{
        'email': email,
        'password': password,
        'device_name': deviceName,
        'platform': platform,
      },
    );
    return AuthSession.fromJson(json);
  }

  @override
  Future<SignupReceipt> signup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final Map<String, Object?> json = await _post(
      '/auth/signup',
      auth: false,
      body: <String, Object?>{
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    return SignupReceipt.fromJson(json);
  }

  @override
  Future<AuthSession> signInWithGoogle({required String idToken}) async {
    final Map<String, Object?> json = await _post(
      '/auth/google',
      auth: false,
      body: <String, Object?>{'id_token': idToken},
    );
    return AuthSession.fromJson(json);
  }

  @override
  Future<AuthSession> verifyEmail({required String token}) async {
    final Map<String, Object?> json = await _post(
      '/auth/verify-email',
      auth: false,
      body: <String, Object?>{'token': token},
    );
    return AuthSession.fromJson(json);
  }

  @override
  Future<void> resendVerification({required String email}) async {
    await _post(
      '/auth/verify-email/resend',
      auth: false,
      body: <String, Object?>{'email': email},
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _post(
      '/auth/forgot-password',
      auth: false,
      body: <String, Object?>{'email': email},
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _post(
      '/auth/reset-password',
      auth: false,
      body: <String, Object?>{'token': token, 'new_password': newPassword},
    );
  }

  @override
  Future<TokenValidity> checkResetToken({required String token}) async {
    if (token.trim().isEmpty) {
      return TokenValidity.invalid;
    }
    final Map<String, Object?> json = await _get(
      '/auth/reset-password/check?token=$token',
      auth: false,
    );
    return switch (json['validity']) {
      'valid' => TokenValidity.valid,
      'expired' => TokenValidity.expired,
      _ => TokenValidity.invalid,
    };
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    final Map<String, Object?> json = await _post(
      '/auth/refresh',
      auth: false,
      body: <String, Object?>{'refresh_token': refreshToken},
    );
    return AuthSession.fromJson(json);
  }

  @override
  Future<void> logout() async {
    await _post('/auth/logout');
  }

  @override
  Future<AuthUser> me() async => _authUserFrom(await _get('/auth/me'));

  AuthUser _authUserFrom(Map<String, Object?> json) {
    final Object? user = json['user'];
    return AuthUser.fromJson(
      user is Map<String, Object?> ? user : json,
    );
  }

  // ---- sessions -----------------------------------------------------------

  @override
  Future<List<SessionInfo>> sessions() async =>
      _mapList<SessionInfo>(await _getList('/auth/sessions'), SessionInfo.fromJson);

  @override
  Future<void> revokeSession(String sessionId) async {
    await _client.delete('/auth/sessions/$sessionId');
  }

  // ---- assistant ----------------------------------------------------------

  @override
  Stream<AssistantEvent> events() {
    final WebSocketClient? socket = _socket;
    if (socket == null) {
      return Stream<AssistantEvent>.error(missingSocketError());
    }
    unawaited(socket.connect());
    return socket.messages.map(_eventFrom).where((AssistantEvent? e) => e != null).cast();
  }

  /// Maps a wire frame onto a typed event. Unrecognised frames return `null` and are
  /// dropped rather than turned into a fake event.
  AssistantEvent? _eventFrom(SocketMessage message) {
    final Map<String, Object?> payload = message.payload;
    return switch (message.type) {
      'assistant.token' => AssistantTokenEvent(
          messageId: (payload['message_id'] ?? '') as String,
          text: (payload['text'] ?? '') as String,
          done: payload['done'] == true,
        ),
      'assistant.tool_call' => AssistantToolCallEvent(
          call: ToolCall.fromJson(payload),
        ),
      'assistant.tool_status' => AssistantToolStatusEvent(
          toolCallId: (payload['id'] ?? '') as String,
          status: ToolCallStatus.fromWire(payload['status'] as String?),
          message: payload['message'] as String?,
        ),
      'device.state' => AssistantDeviceEvent(
          device: ArmxDevice.fromJson(payload),
        ),
      'admin.kill_switch' => AssistantKillSwitchEvent(
          state: KillSwitchState.fromJson(payload),
        ),
      'assistant.voice' => AssistantVoiceEvent(
          listening: payload['listening'] == true,
          languageCode: payload['language'] as String?,
        ),
      'connection' => AssistantConnectionEvent(
          connected: payload['connected'] == true,
          reason: payload['reason'] as String?,
        ),
      _ => null,
    };
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? languageCode,
  }) async {
    // Preferred path: the socket, so the reply streams back on the same channel.
    final bool sent = _socket?.send('assistant.message', <String, Object?>{
          'conversation_id': conversationId,
          'text': text,
          'language': languageCode,
        }) ??
        false;
    if (sent) {
      return;
    }
    // Fallback: the REST endpoint still delivers the reply over the socket, so a missing
    // socket is a degraded path rather than a silent success.
    await _post(
      '$_v1/assistant/messages',
      body: <String, Object?>{
        'conversation_id': conversationId,
        'text': text,
        'language': languageCode,
      },
    );
  }

  @override
  Future<void> decideToolCall({
    required String toolCallId,
    required ToolDecision decision,
    String? denyReason,
  }) async {
    await _post(
      '$_v1/assistant/tool-calls/$toolCallId/decision',
      body: <String, Object?>{
        'decision': decision.name,
        'reason': denyReason,
      },
    );
  }

  @override
  Future<List<ChatMessage>> transcript({required String conversationId}) async =>
      _mapList<ChatMessage>(
        await _getList('$_v1/assistant/transcript?conversation_id=$conversationId'),
        ChatMessage.fromJson,
      );

  // ---- smart home ---------------------------------------------------------

  @override
  Future<List<ArmxRoom>> rooms() async =>
      _mapList<ArmxRoom>(await _getList('$_v1/rooms'), ArmxRoom.fromJson);

  @override
  Future<List<ArmxDevice>> devices() async =>
      _mapList<ArmxDevice>(await _getList('$_v1/devices'), ArmxDevice.fromJson);

  @override
  Future<DeviceCommandResult> sendDeviceCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> parameters = const <String, Object?>{},
    RiskTier? declaredRisk,
  }) async {
    final Map<String, Object?> json = await _post(
      '$_v1/devices/$deviceId/command',
      body: <String, Object?>{
        'command': command,
        'parameters': parameters,
        if (declaredRisk != null) 'declared_risk': declaredRisk.wire,
      },
    );
    return DeviceCommandResult.fromJson(json);
  }

  // ---- alarms -------------------------------------------------------------

  @override
  Future<List<ArmxAlarm>> alarms() async =>
      _mapList<ArmxAlarm>(await _getList('$_v1/alarms'), ArmxAlarm.fromJson);

  @override
  Future<ArmxAlarm> saveAlarm(ArmxAlarm alarm) async {
    final bool creating = alarm.id == 'new' || alarm.id.isEmpty;
    final Map<String, Object?> json = creating
        ? await _post('$_v1/alarms', body: alarm.toJson())
        : await _patch('$_v1/alarms/${alarm.id}', body: alarm.toJson());
    return ArmxAlarm.fromJson(json);
  }

  @override
  Future<void> deleteAlarm(String alarmId) async {
    await _client.delete('$_v1/alarms/$alarmId');
  }

  @override
  Future<ArmxAlarm> testAlarmRing(String alarmId) async =>
      ArmxAlarm.fromJson(await _post('$_v1/alarms/$alarmId/ring-test'));

  @override
  Future<ArmxAlarm> acknowledgeAlarm(String alarmId) async =>
      ArmxAlarm.fromJson(await _post('$_v1/alarms/$alarmId/acknowledge'));

  // ---- linked devices -----------------------------------------------------

  @override
  Future<List<LinkedDevice>> linkedDevices() async => _mapList<LinkedDevice>(
        await _getList('$_v1/linked-devices'),
        LinkedDevice.fromJson,
      );

  @override
  Future<PairingOffer> startPairing({
    required String deviceName,
    required String platform,
  }) async =>
      PairingOffer.fromJson(
        await _post(
          '$_v1/linked-devices/pairing',
          body: <String, Object?>{'device_name': deviceName, 'platform': platform},
        ),
      );

  @override
  Future<LinkedDevice> approvePairing(String code) async => LinkedDevice.fromJson(
        await _post('$_v1/linked-devices/pairing/$code/approve'),
      );

  @override
  Future<void> cancelPairing() async {
    await _post('$_v1/linked-devices/pairing/cancel');
  }

  @override
  Future<void> unlinkDevice({
    required String deviceId,
    required String ownerPassword,
  }) async {
    // The password travels in the body over TLS and is never logged or retained. The
    // backend validates it against the *target device's owner*, not the caller.
    await _post(
      '$_v1/linked-devices/$deviceId/unlink',
      body: <String, Object?>{'owner_password': ownerPassword},
    );
  }

  // ---- guest greeter ------------------------------------------------------

  @override
  Future<GreeterState> greeterState() async =>
      GreeterState.fromJson(await _get('$_v1/greeter/state'));

  @override
  Future<GreeterState> setGreeterCamera({required String state}) async =>
      GreeterState.fromJson(
        await _post('$_v1/greeter/camera', body: <String, Object?>{'state': state}),
      );

  @override
  Future<List<GuestProfile>> guests() async =>
      _mapList<GuestProfile>(await _getList('$_v1/greeter/guests'), GuestProfile.fromJson);

  @override
  Future<GuestProfile> enrollGuest({
    required String displayName,
    required bool consentGiven,
    String? note,
  }) async =>
      GuestProfile.fromJson(
        await _post(
          '$_v1/greeter/guests',
          body: <String, Object?>{
            'display_name': displayName,
            'consent_given': consentGiven,
            'note': note,
          },
        ),
      );

  @override
  Future<void> deleteGuest(String guestId) async {
    await _client.delete('$_v1/greeter/guests/$guestId');
  }

  @override
  Future<List<GreeterEvent>> greeterEvents() async =>
      _mapList<GreeterEvent>(await _getList('$_v1/greeter/events'), GreeterEvent.fromJson);

  // ---- web builder --------------------------------------------------------

  @override
  Future<SiteDraft> generateSite({
    required String prompt,
    String? templateHint,
  }) async =>
      SiteDraft.fromJson(
        await _post(
          '$_v1/web-builder/drafts',
          body: <String, Object?>{'prompt': prompt, 'template_hint': templateHint},
        ),
      );

  @override
  Future<Deployment> deploySite({
    required String draftId,
    required String repository,
    required String branch,
  }) async =>
      Deployment.fromJson(
        await _post(
          '$_v1/web-builder/deploy',
          body: <String, Object?>{
            'draft_id': draftId,
            'repository': repository,
            'branch': branch,
          },
        ),
      );

  @override
  Future<List<Deployment>> deployments() async => _mapList<Deployment>(
        await _getList('$_v1/web-builder/deployments'),
        Deployment.fromJson,
      );

  // ---- messaging ----------------------------------------------------------

  @override
  Future<List<Contact>> contacts() async =>
      _mapList<Contact>(await _getList('$_v1/messaging/contacts'), Contact.fromJson);

  @override
  Future<List<ToneProfile>> toneProfiles() async => _mapList<ToneProfile>(
        await _getList('$_v1/messaging/tones'),
        ToneProfile.fromJson,
      );

  @override
  Future<ToneProfile> saveToneProfile(ToneProfile profile) async =>
      ToneProfile.fromJson(
        await _post('$_v1/messaging/tones', body: profile.toJson()),
      );

  @override
  Future<Contact> updateContact(Contact contact) async => Contact.fromJson(
        await _patch(
          '$_v1/messaging/contacts/${contact.id}',
          body: <String, Object?>{
            'tone_profile_id': contact.toneProfileId,
            'delivery_mode': contact.deliveryMode.wire,
            'blocked': contact.blocked,
          },
        ),
      );

  // ---- admin --------------------------------------------------------------

  @override
  Future<List<AdminUserRow>> adminUsers() async => _mapList<AdminUserRow>(
        await _getList('$_v1/admin/users'),
        AdminUserRow.fromJson,
      );

  @override
  Future<AdminUserRow> updateAdminUser({
    required String userId,
    UserRole? role,
    AccountStatus? status,
  }) async =>
      AdminUserRow.fromJson(
        await _patch(
          '$_v1/admin/users/$userId',
          body: <String, Object?>{
            if (role != null) 'role': role.wire,
            if (status != null) 'status': status.name,
          },
        ),
      );

  @override
  Future<List<AuditEntry>> auditLog({
    String? actorEmail,
    String? action,
    int limit = 100,
  }) async {
    final Uri query = Uri(
      path: '/audit',
      queryParameters: <String, String>{
        if (actorEmail != null && actorEmail.isNotEmpty) 'actor': actorEmail,
        if (action != null && action.isNotEmpty) 'action': action,
        'limit': '$limit',
      },
    );
    return _mapList<AuditEntry>(
      await _getList('$_v1${query.toString()}'),
      AuditEntry.fromJson,
    );
  }

  @override
  Future<List<ToolToggle>> toolToggles() async => _mapList<ToolToggle>(
        await _getList('$_v1/admin/tools'),
        ToolToggle.fromJson,
      );

  @override
  Future<ToolToggle> setToolEnabled({
    required String toolId,
    required bool enabled,
  }) async =>
      ToolToggle.fromJson(
        await _post(
          '$_v1/admin/tools/$toolId',
          body: <String, Object?>{'enabled': enabled},
        ),
      );

  @override
  Future<KillSwitchState> setKillSwitch({
    required bool engaged,
    String reason = '',
  }) async =>
      KillSwitchState.fromJson(
        await _post(
          '$_v1/admin/kill-switch',
          body: <String, Object?>{'engaged': engaged, 'reason': reason},
        ),
      );

  @override
  Future<KillSwitchState> killSwitchState() async =>
      KillSwitchState.fromJson(await _get('$_v1/admin/kill-switch'));

  @override
  Future<void> dispose() async {
    await _socket?.dispose();
  }

  /// The configuration this transport was built with.
  AppConfig get config => _config;
}
