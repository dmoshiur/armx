// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:math';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/security/risk_tier.dart';
import '../../models/admin.dart';
import '../../models/alarm.dart';
import '../../models/assistant.dart';
import '../../models/device.dart';
import '../../models/guest.dart';
import '../../models/linked_device.dart';
import '../../models/messaging.dart';
import '../../models/web_builder.dart';
import '../armx_api.dart';
import '../auth_session.dart';
import '../mock/mock_fixtures.dart';

/// A deterministic, in-memory implementation of [ArmxApi].
///
/// ## Why this exists and what it guarantees
///
/// The backend is not in this repository. Rather than faking success in the UI — which
/// would make every screen's error handling untestable — the mock implements the *same
/// contract* the server will, including the parts that are supposed to fail:
///
/// * signing in with the wrong password throws [UnauthorizedException];
/// * signing in with an unverified address throws with `email_not_verified`, so the
///   verification route is reachable;
/// * unlinking requires the **owner's** password and refuses a wrong one;
/// * the guest greeter refuses enrolment while the kill switch is engaged;
/// * `web_deploy` returns a `pending` deployment and only becomes `live` after a delay
///   that the UI must actually wait for.
///
/// Every list is generated from a seeded [Random] so runs are reproducible, and nothing
/// here is time-dependent in a way that makes a test flaky.
class MockArmxApi implements ArmxApi {
  /// Creates the mock.
  ///
  /// [latency] is applied to every call so loading, skeleton and pending states are
  /// exercised rather than skipped. Pass [Duration.zero] in unit tests.
  MockArmxApi({
    this.latency = const Duration(milliseconds: 320),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _seed();
  }

  /// Artificial delay applied to each call.
  final Duration latency;

  final DateTime Function() _clock;
  final Random _random = Random(20261013);
  final StreamController<AssistantEvent> _events =
      StreamController<AssistantEvent>.broadcast();

  // ---- mock state ----------------------------------------------------------
  final Map<String, String> _passwords = <String, String>{};
  final Set<String> _verifiedEmails = <String>{};
  final Map<String, AuthUser> _users = <String, AuthUser>{};
  final Map<String, String> _resetTokens = <String, String>{};
  final Set<String> _usedResetTokens = <String>{};
  final Map<String, DateTime> _resetTokenExpiry = <String, DateTime>{};

  final List<ArmxRoom> _rooms = <ArmxRoom>[];
  final List<ArmxDevice> _devices = <ArmxDevice>[];
  final List<ArmxAlarm> _alarms = <ArmxAlarm>[];
  final List<LinkedDevice> _linked = <LinkedDevice>[];
  final List<GuestProfile> _guests = <GuestProfile>[];
  final List<GreeterEvent> _greeterEvents = <GreeterEvent>[];
  final List<Contact> _contacts = <Contact>[];
  final List<ToneProfile> _tones = <ToneProfile>[];
  final List<AdminUserRow> _adminUsers = <AdminUserRow>[];
  final List<AuditEntry> _audit = <AuditEntry>[];
  final List<ToolToggle> _tools = <ToolToggle>[];
  final List<SessionInfo> _sessions = <SessionInfo>[];
  final List<ChatMessage> _transcript = <ChatMessage>[];
  final Map<String, ToolCall> _toolCalls = <String, ToolCall>{};

  PairingOffer? _pairing;
  KillSwitchState _killSwitch = const KillSwitchState(engaged: false);
  GreeterState _greeter = const GreeterState(
    camera: GreeterCameraState.off,
    killEngaged: false,
  );
  Deployment? _deployment;
  String _currentUserEmail = MockFixtures.ownerEmail;
  // The password the *owner* set, used by the unlink gate. The mock holds it so the
  // "wrong password is refused" path is real rather than decorative.
  String _ownerPassword = MockFixtures.ownerPassword;

  void _seed() {
    _rooms.addAll(MockFixtures.rooms());
    _devices.addAll(MockFixtures.devices());
    _alarms.addAll(MockFixtures.alarms(_clock));
    _linked.addAll(MockFixtures.linkedDevices(_clock));
    _guests.addAll(MockFixtures.guests(_clock));
    _greeterEvents.addAll(MockFixtures.greeterEvents(_clock));
    _tones.addAll(MockFixtures.toneProfiles());
    _contacts.addAll(MockFixtures.contacts());
    _adminUsers.addAll(MockFixtures.adminUsers(_clock));
    _audit.addAll(MockFixtures.auditEntries(_clock));
    _tools.addAll(MockFixtures.toolToggles());
    _sessions.addAll(MockFixtures.sessions(_clock));

    for (final AdminUserRow row in _adminUsers) {
      _users[row.email] = AuthUser(
        id: row.id,
        email: row.email,
        displayName: row.displayName,
        role: row.role,
        emailVerified: row.status == AccountStatus.active,
      );
      _passwords[row.email] = row.email == MockFixtures.ownerEmail
          ? MockFixtures.ownerPassword
          : MockFixtures.memberPassword;
      if (row.status == AccountStatus.active) {
        _verifiedEmails.add(row.email);
      }
    }
    _transcript.addAll(MockFixtures.seedTranscript(_clock));
  }

  Future<void> _wait() =>
      latency == Duration.zero ? Future<void>.value() : Future<void>.delayed(latency);

  /// Emits an event, for tests that want to drive the stream directly.
  void emit(AssistantEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  /// Advances a deployment to `live`. Tests call this instead of waiting on a timer.
  void completeDeployment() {
    final Deployment? current = _deployment;
    if (current == null) {
      return;
    }
    _deployment = current.copyWith(
      status: DeploymentStatus.live,
      liveUrl: 'https://${MockFixtures.deployHost}/${current.draftId}',
      commitSha: 'a1b2c3d',
      deployedAt: _clock().toUtc(),
    );
  }

  /// The current password for the owner account, so a test can prove the unlink gate.
  String get ownerPassword => _ownerPassword;

  // ---- auth ---------------------------------------------------------------

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
  }) async {
    await _wait();
    final String normalized = email.trim().toLowerCase();
    final String? expected = _passwords[normalized];
    if (expected == null || expected != password) {
      throw const UnauthorizedException(
        message: 'Email or password is incorrect.',
        code: 'invalid_credentials',
      );
    }
    if (!_verifiedEmails.contains(normalized)) {
      throw const UnauthorizedException(
        message: 'This address has not been verified yet.',
        code: 'email_not_verified',
      );
    }
    final AuthUser user = _users[normalized]!;
    _currentUserEmail = normalized;
    _record(action: 'auth.login', outcome: AuditOutcome.success, actor: normalized);
    return _sessionFor(user);
  }

  @override
  Future<SignupReceipt> signup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _wait();
    final String normalized = email.trim().toLowerCase();
    if (_passwords.containsKey(normalized)) {
      throw const ConflictException(
        message: 'That email already has an account.',
        code: 'email_already_registered',
      );
    }
    _passwords[normalized] = password;
    _users[normalized] = AuthUser(
      id: 'u-${_random.nextInt(99999)}',
      email: normalized,
      displayName: displayName.trim().isEmpty ? normalized : displayName.trim(),
      // A self-service signup is a regular user. Privileges are granted by an admin,
      // never by the signup form.
      role: UserRole.user,
      emailVerified: false,
    );
    _record(
      action: 'auth.signup',
      outcome: AuditOutcome.success,
      actor: normalized,
    );
    return SignupReceipt(
      email: normalized,
      verificationSent: true,
      resendAfter: const Duration(seconds: 60),
    );
  }

  @override
  Future<AuthSession> signInWithGoogle({required String idToken}) async {
    await _wait();
    if (idToken.trim().isEmpty) {
      throw const UnauthorizedException(
        message: 'Google sign-in returned no token.',
        code: 'google_failed',
      );
    }
    // The mock treats a Google token as proof of a verified address, which is what the
    // backend will do after it validates the token signature.
    const String email = MockFixtures.googleEmail;
    _verifiedEmails.add(email);
    _users[email] ??= AuthUser(
      id: 'u-google',
      email: email,
      displayName: 'Google account',
      role: UserRole.user,
      emailVerified: true,
    );
    _passwords.putIfAbsent(email, () => 'google-federated');
    _currentUserEmail = email;
    return _sessionFor(_users[email]!);
  }

  @override
  Future<AuthSession> verifyEmail({required String token}) async {
    await _wait();
    if (token != MockFixtures.validVerificationToken) {
      throw const ValidationException(
        message: 'That verification link is not valid.',
        code: 'invalid_token',
      );
    }
    const String email = MockFixtures.unverifiedEmail;
    _verifiedEmails.add(email);
    final AuthUser? user = _users[email];
    if (user == null) {
      throw const NotFoundException(
        message: 'That account no longer exists.',
        code: 'account_missing',
      );
    }
    final AuthUser verified = user.copyWith(emailVerified: true);
    _users[email] = verified;
    return _sessionFor(verified);
  }

  @override
  Future<void> resendVerification({required String email}) async {
    await _wait();
    // Deliberately silent about whether the address exists: the screen says "sent"
    // either way, so the endpoint cannot be used to enumerate accounts.
    _record(
      action: 'auth.verify_resend',
      outcome: AuditOutcome.success,
      actor: email.trim().toLowerCase(),
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    await _wait();
    final String normalized = email.trim().toLowerCase();
    // Always succeeds: revealing whether an address is registered would turn this into an
    // account-enumeration oracle.
    if (_passwords.containsKey(normalized)) {
      _resetTokens[MockFixtures.validResetToken] = normalized;
      _resetTokenExpiry[MockFixtures.validResetToken] =
          _clock().toUtc().add(MockFixtures.resetTokenLifetime);
      _resetTokens[MockFixtures.expiredResetToken] = normalized;
      _resetTokenExpiry[MockFixtures.expiredResetToken] =
          _clock().toUtc().subtract(const Duration(minutes: 1));
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _wait();
    final TokenValidity validity = await checkResetToken(token: token);
    if (validity == TokenValidity.expired) {
      throw const ValidationException(
        message: 'That reset link has expired.',
        code: 'expired_token',
      );
    }
    if (validity == TokenValidity.invalid) {
      throw const ValidationException(
        message: 'That reset link is not valid.',
        code: 'invalid_token',
      );
    }
    final String email = _resetTokens[token]!;
    _passwords[email] = newPassword;
    _usedResetTokens.add(token);
    _record(
      action: 'auth.password_reset',
      outcome: AuditOutcome.success,
      actor: email,
    );
  }

  @override
  Future<TokenValidity> checkResetToken({required String token}) async {
    await _wait();
    if (token.isEmpty || !_resetTokens.containsKey(token)) {
      return TokenValidity.invalid;
    }
    if (_usedResetTokens.contains(token)) {
      return TokenValidity.invalid;
    }
    final DateTime? expiry = _resetTokenExpiry[token];
    if (expiry != null && expiry.isBefore(_clock().toUtc())) {
      return TokenValidity.expired;
    }
    return TokenValidity.valid;
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    await _wait();
    if (refreshToken.isEmpty || refreshToken.startsWith('revoked')) {
      throw const UnauthorizedException(
        message: 'The refresh token was rejected.',
        code: 'refresh_rejected',
      );
    }
    final AuthUser user = _users[_currentUserEmail] ??
        _users[MockFixtures.ownerEmail]!;
    return _sessionFor(user);
  }

  @override
  Future<void> logout() async {
    await _wait();
    _record(action: 'auth.logout', outcome: AuditOutcome.success);
  }

  @override
  Future<AuthUser> me() async {
    await _wait();
    return _users[_currentUserEmail] ?? _users[MockFixtures.ownerEmail]!;
  }

  AuthSession _sessionFor(AuthUser user) => AuthSession(
        tokens: AuthTokensFixture.issue(user.id, _clock),
        user: user,
      );

  // ---- sessions -----------------------------------------------------------

  @override
  Future<List<SessionInfo>> sessions() async {
    await _wait();
    return List<SessionInfo>.unmodifiable(_sessions);
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _wait();
    final SessionInfo? target =
        _sessions.where((SessionInfo s) => s.id == sessionId).firstOrNull;
    if (target == null) {
      throw const NotFoundException(message: 'That session no longer exists.');
    }
    if (target.current) {
      throw const PolicyException(
        message: 'You cannot revoke the session you are using.',
        reason: 'cannot_revoke_current_session',
      );
    }
    _sessions.removeWhere((SessionInfo s) => s.id == sessionId);
    _record(
      action: 'auth.session_revoked',
      outcome: AuditOutcome.success,
      target: target.deviceName,
      risk: RiskTier.high,
    );
  }

  // ---- assistant ----------------------------------------------------------

  @override
  Stream<AssistantEvent> events() => _events.stream;

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    String? languageCode,
  }) async {
    await _wait();
    if (text.trim().isEmpty) {
      throw const ValidationException(message: 'The message was empty.');
    }
    _transcript.add(
      ChatMessage(
        id: 'm-${_transcript.length}-user',
        author: ChatAuthor.user,
        text: text.trim(),
        createdAt: _clock().toUtc(),
        languageCode: languageCode,
      ),
    );

    // A canned reply, streamed in chunks so the UI has to handle partial text.
    final String reply = MockFixtures.replyFor(text);
    final String messageId = 'm-${_transcript.length}-assistant';
    for (final String chunk in MockFixtures.chunk(reply)) {
      emit(AssistantTokenEvent(messageId: messageId, text: chunk));
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
    _transcript.add(
      ChatMessage(
        id: messageId,
        author: ChatAuthor.assistant,
        text: reply,
        createdAt: _clock().toUtc(),
      ),
    );

    final ToolCall? proposal = MockFixtures.toolCallFor(text, _clock());
    if (proposal != null) {
      _toolCalls[proposal.id] = proposal;
      emit(AssistantToolCallEvent(call: proposal));
    }
  }

  @override
  Future<void> decideToolCall({
    required String toolCallId,
    required ToolDecision decision,
    String? denyReason,
  }) async {
    await _wait();
    final ToolCall? call = _toolCalls[toolCallId];
    if (call == null) {
      throw const NotFoundException(message: 'That proposal is no longer available.');
    }
    if (!call.status.isOpen) {
      throw const ConflictException(
        message: 'That proposal has already been decided.',
        code: 'already_decided',
      );
    }

    if (decision == ToolDecision.deny) {
      // A denial performs **no** action and no side effect.
      final ToolCall denied = call.copyWith(
        status: ToolCallStatus.denied,
        resultMessage: denyReason,
      );
      _toolCalls[toolCallId] = denied;
      emit(AssistantToolStatusEvent(
        toolCallId: toolCallId,
        status: ToolCallStatus.denied,
        message: denyReason,
      ));
      _record(
        action: call.tool,
        outcome: AuditOutcome.denied,
        target: call.targetLabel,
        risk: call.riskTier,
      );
      return;
    }

    _toolCalls[toolCallId] = call.copyWith(status: ToolCallStatus.running);
    emit(AssistantToolStatusEvent(
      toolCallId: toolCallId,
      status: ToolCallStatus.running,
    ));

    // Perform the action the proposal described, for the tools the mock models.
    String? resultMessage;
    ToolCallStatus finalStatus = ToolCallStatus.succeeded;
    try {
      switch (call.tool) {
        case 'set_light':
        case 'set_fan':
          resultMessage = await _applyDeviceToggle(call, finalStatus);
        case 'web_deploy':
          resultMessage = await _applyDeploy(call);
        case _:
          resultMessage = 'Done.';
      }
    } on AppException catch (error) {
      finalStatus = ToolCallStatus.failed;
      resultMessage = error.message;
    }

    final ToolCall finished = call.copyWith(
      status: finalStatus,
      resultMessage: resultMessage,
    );
    _toolCalls[toolCallId] = finished;
    emit(AssistantToolStatusEvent(
      toolCallId: toolCallId,
      status: finalStatus,
      message: resultMessage,
    ));
    _record(
      action: call.tool,
      outcome: finalStatus == ToolCallStatus.succeeded
          ? AuditOutcome.success
          : AuditOutcome.failed,
      target: call.targetLabel,
      risk: call.riskTier,
    );
  }

  Future<String> _applyDeviceToggle(ToolCall call, ToolCallStatus ignored) async {
    if (_killSwitch.engaged) {
      throw const PolicyException(
        message: 'The kill-switch is engaged.',
        reason: 'kill_switch_engaged',
      );
    }
    final String? deviceId = call.parameters['device_id'] as String?;
    if (deviceId == null) {
      throw const ValidationException(message: 'The proposal named no device.');
    }
    final ArmxDevice? device =
        _devices.where((ArmxDevice d) => d.id == deviceId).firstOrNull;
    if (device == null) {
      throw const NotFoundException(message: 'That device is no longer registered.');
    }
    if (!device.online) {
      // The device is unreachable: the command is queued, not reported as done.
      return 'Queued — ${device.name} is offline and will apply it when it returns.';
    }
    final ArmxDevice updated = device.copyWith(level: !device.isActive);
    _replaceDevice(updated);
    emit(AssistantDeviceEvent(device: updated));
    return '${updated.name} is now ${updated.isActive ? 'on' : 'off'}.';
  }

  Future<String> _applyDeploy(ToolCall call) async {
    final String repository = (call.parameters['repository'] ?? '') as String;
    if (repository.isEmpty) {
      throw const ValidationException(message: 'The proposal named no repository.');
    }
    if (repository != MockFixtures.deployTargetRepo) {
      throw const ForbiddenException(
        message: 'Deployments are limited to the configured project repository.',
        code: 'repo_not_allowed',
      );
    }
    completeDeployment();
    return 'Deployed to $repository.';
  }

  @override
  Future<List<ChatMessage>> transcript({required String conversationId}) async {
    await _wait();
    return List<ChatMessage>.unmodifiable(_transcript);
  }

  /// Records a tool proposal that a test wants to exercise directly.
  void registerToolCall(ToolCall call) {
    _toolCalls[call.id] = call;
    emit(AssistantToolCallEvent(call: call));
  }

  // ---- smart home ---------------------------------------------------------

  @override
  Future<List<ArmxRoom>> rooms() async {
    await _wait();
    return List<ArmxRoom>.unmodifiable(_rooms);
  }

  @override
  Future<List<ArmxDevice>> devices() async {
    await _wait();
    return List<ArmxDevice>.unmodifiable(_devices);
  }

  @override
  Future<DeviceCommandResult> sendDeviceCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> parameters = const <String, Object?>{},
    RiskTier? declaredRisk,
  }) async {
    await _wait();
    if (_killSwitch.engaged) {
      throw const PolicyException(
        message: 'The kill-switch is engaged, so no command can be sent.',
        reason: 'kill_switch_engaged',
      );
    }
    final ArmxDevice? device =
        _devices.where((ArmxDevice d) => d.id == deviceId).firstOrNull;
    if (device == null) {
      throw const NotFoundException(message: 'That device is not registered.');
    }
    if (device.kind.isReadOnly) {
      throw const PolicyException(
        message: 'That device only reports readings.',
        reason: 'read_only_device',
      );
    }
    if (!device.online) {
      // Offline is a *pending* outcome, never a success.
      return DeviceCommandResult(
        deviceId: deviceId,
        command: command,
        accepted: false,
        pending: true,
        message: 'The device is offline. The command will be sent when it returns.',
        state: device,
      );
    }

    final ArmxDevice updated = switch (command) {
      'toggle' => device.copyWith(level: !device.isActive),
      'on' => device.copyWith(level: true),
      'off' => device.copyWith(level: false),
      'set_level' => device.copyWith(
          level: ((parameters['level'] as num?)?.toInt() ?? 0) > 0,
        ),
      'set_brightness' => device.copyWith(
          brightness: ((parameters['brightness'] as num?)?.toInt() ?? 0).clamp(0, 100),
          level: ((parameters['brightness'] as num?)?.toInt() ?? 0) > 0,
        ),
      _ => device,
    };
    _replaceDevice(updated);
    emit(AssistantDeviceEvent(device: updated));
    _record(
      action: 'device.$command',
      outcome: AuditOutcome.success,
      target: device.name,
      risk: declaredRisk ?? RiskTier.low,
    );
    return DeviceCommandResult(
      deviceId: deviceId,
      command: command,
      accepted: true,
      state: updated,
    );
  }

  void _replaceDevice(ArmxDevice device) {
    final int index = _devices.indexWhere((ArmxDevice d) => d.id == device.id);
    if (index >= 0) {
      _devices[index] = device;
    }
  }

  // ---- alarms -------------------------------------------------------------

  @override
  Future<List<ArmxAlarm>> alarms() async {
    await _wait();
    return List<ArmxAlarm>.unmodifiable(_alarms);
  }

  @override
  Future<ArmxAlarm> saveAlarm(ArmxAlarm alarm) async {
    await _wait();
    if (alarm.targets.isEmpty) {
      throw const ValidationException(
        message: 'Choose at least one device for the alarm to ring on.',
        fieldErrors: <String, String>{'targets': 'At least one device is required.'},
      );
    }
    final ArmxAlarm saved = alarm.id == 'new' || alarm.id.isEmpty
        ? alarm.copyWith(id: 'alarm-${_random.nextInt(99999)}')
        : alarm;
    final int index = _alarms.indexWhere((ArmxAlarm a) => a.id == saved.id);
    if (index >= 0) {
      _alarms[index] = saved;
    } else {
      _alarms.add(saved);
    }
    _record(
      action: 'alarm.save',
      outcome: AuditOutcome.success,
      target: saved.label,
      risk: RiskTier.medium,
    );
    return saved;
  }

  @override
  Future<void> deleteAlarm(String alarmId) async {
    await _wait();
    _alarms.removeWhere((ArmxAlarm a) => a.id == alarmId);
    _record(action: 'alarm.delete', outcome: AuditOutcome.success, risk: RiskTier.medium);
  }

  @override
  Future<ArmxAlarm> testAlarmRing(String alarmId) async {
    await _wait();
    final int index = _alarms.indexWhere((ArmxAlarm a) => a.id == alarmId);
    if (index < 0) {
      throw const NotFoundException(message: 'That alarm no longer exists.');
    }
    // The ring test marks every reachable target as ringing and leaves unreachable ones
    // honestly unreachable, which is exactly what the cross-device status list renders.
    final ArmxAlarm alarm = _alarms[index].copyWith(
      targets: _alarms[index]
          .targets
          .map((AlarmTarget t) => t.copyWith(ringing: t.reachable))
          .toList(growable: false),
      lastRangAt: _clock().toUtc(),
    );
    _alarms[index] = alarm;
    return alarm;
  }

  @override
  Future<ArmxAlarm> acknowledgeAlarm(String alarmId) async {
    await _wait();
    final int index = _alarms.indexWhere((ArmxAlarm a) => a.id == alarmId);
    if (index < 0) {
      throw const NotFoundException(message: 'That alarm no longer exists.');
    }
    final ArmxAlarm alarm = _alarms[index].copyWith(
      targets: _alarms[index]
          .targets
          .map((AlarmTarget t) => t.copyWith(ringing: false, acknowledged: true))
          .toList(growable: false),
    );
    _alarms[index] = alarm;
    return alarm;
  }

  // ---- linked devices -----------------------------------------------------

  @override
  Future<List<LinkedDevice>> linkedDevices() async {
    await _wait();
    return List<LinkedDevice>.unmodifiable(_linked);
  }

  @override
  Future<PairingOffer> startPairing({
    required String deviceName,
    required String platform,
  }) async {
    await _wait();
    if (_killSwitch.engaged) {
      throw const PolicyException(
        message: 'Pairing is unavailable while the kill-switch is engaged.',
        reason: 'kill_switch_engaged',
      );
    }
    final String code = MockFixtures.pairingCode;
    _pairing = PairingOffer(
      code: code,
      expiresAt: _clock().toUtc().add(const Duration(minutes: 10)),
      deviceName: deviceName,
      qrPayload: 'armx://pair?code=$code&host=${MockFixtures.deployHost}',
    );
    return _pairing!;
  }

  @override
  Future<LinkedDevice> approvePairing(String code) async {
    await _wait();
    final PairingOffer? offer = _pairing;
    if (offer == null || offer.code != code) {
      throw const ValidationException(
        message: 'That pairing code does not match an open request.',
        code: 'pairing_code_mismatch',
      );
    }
    if (offer.isExpired(now: _clock().toUtc())) {
      throw const ValidationException(
        message: 'That pairing request expired.',
        code: 'pairing_expired',
      );
    }
    final LinkedDevice device = LinkedDevice(
      id: 'ld-${_random.nextInt(9999)}',
      name: offer.deviceName,
      platform: 'pending',
      status: LinkStatus.active,
      ownerEmail: _currentUserEmail,
      lastActiveAt: _clock().toUtc(),
      linkMethod: LinkMethod.qr,
      fingerprint: MockFixtures.fingerprint,
    );
    _linked.add(device);
    _pairing = null;
    _record(
      action: 'device.link',
      outcome: AuditOutcome.success,
      target: device.name,
      risk: RiskTier.high,
    );
    return device;
  }

  @override
  Future<void> cancelPairing() async {
    await _wait();
    _pairing = null;
  }

  @override
  Future<void> unlinkDevice({
    required String deviceId,
    required String ownerPassword,
  }) async {
    await _wait();
    final LinkedDevice? target =
        _linked.where((LinkedDevice d) => d.id == deviceId).firstOrNull;
    if (target == null) {
      throw const NotFoundException(message: 'That device is not linked.');
    }
    if (target.isCurrentDevice) {
      throw const PolicyException(
        message: 'You cannot unlink the device you are using.',
        reason: 'current_device',
      );
    }
    if (ownerPassword != _ownerPassword) {
      _record(
        action: 'device.unlink',
        outcome: AuditOutcome.denied,
        target: target.name,
        risk: RiskTier.high,
      );
      throw const ForbiddenException(
        message: 'That password is not correct for the device owner.',
        code: 'owner_password_invalid',
      );
    }
    _linked.removeWhere((LinkedDevice d) => d.id == deviceId);
    _record(
      action: 'device.unlink',
      outcome: AuditOutcome.success,
      target: target.name,
      risk: RiskTier.high,
    );
  }

  // ---- guest greeter ------------------------------------------------------

  @override
  Future<GreeterState> greeterState() async {
    await _wait();
    return _greeter;
  }

  @override
  Future<GreeterState> setGreeterCamera({required String state}) async {
    await _wait();
    final GreeterCameraState next = switch (state) {
      'live' => GreeterCameraState.live,
      'killed' => GreeterCameraState.killed,
      _ => GreeterCameraState.off,
    };
    _greeter = GreeterState(
      camera: next,
      killEngaged: next == GreeterCameraState.killed,
      startedAt: next == GreeterCameraState.live ? _clock().toUtc() : null,
      enrolledGuestCount: _guests.length,
      lastEventAt: _greeter.lastEventAt,
    );
    _record(
      action: next == GreeterCameraState.killed ? 'greeter.kill' : 'greeter.camera',
      outcome: AuditOutcome.success,
      target: next.name,
      risk: next == GreeterCameraState.killed ? RiskTier.high : RiskTier.medium,
    );
    return _greeter;
  }

  @override
  Future<List<GuestProfile>> guests() async {
    await _wait();
    return List<GuestProfile>.unmodifiable(_guests);
  }

  @override
  Future<GuestProfile> enrollGuest({
    required String displayName,
    required bool consentGiven,
    String? note,
  }) async {
    await _wait();
    if (_greeter.killEngaged) {
      throw const PolicyException(
        message: 'Release the camera kill-switch before enrolling anyone.',
        reason: 'kill_switch_engaged',
      );
    }
    if (!consentGiven) {
      throw const PolicyException(
        message: 'Enrolment needs the guest\'s explicit consent.',
        reason: 'consent_required',
      );
    }
    if (displayName.trim().isEmpty) {
      throw const ValidationException(
        message: 'Enter the guest\'s name.',
        fieldErrors: <String, String>{'displayName': 'Required.'},
      );
    }
    final GuestProfile profile = GuestProfile(
      id: 'g-${_random.nextInt(9999)}',
      displayName: displayName.trim(),
      enrolledAt: _clock().toUtc(),
      note: note,
    );
    _guests.add(profile);
    _greeter = GreeterState(
      camera: _greeter.camera,
      killEngaged: _greeter.killEngaged,
      startedAt: _greeter.startedAt,
      enrolledGuestCount: _guests.length,
      lastEventAt: _greeter.lastEventAt,
    );
    _record(
      action: 'greeter.enroll',
      outcome: AuditOutcome.success,
      target: profile.displayName,
      risk: RiskTier.high,
    );
    return profile;
  }

  @override
  Future<void> deleteGuest(String guestId) async {
    await _wait();
    final int before = _guests.length;
    _guests.removeWhere((GuestProfile g) => g.id == guestId);
    if (_guests.length == before) {
      throw const NotFoundException(message: 'That enrolment no longer exists.');
    }
    _record(
      action: 'greeter.delete',
      outcome: AuditOutcome.success,
      risk: RiskTier.high,
    );
  }

  @override
  Future<List<GreeterEvent>> greeterEvents() async {
    await _wait();
    return List<GreeterEvent>.unmodifiable(_greeterEvents);
  }

  // ---- web builder --------------------------------------------------------

  @override
  Future<SiteDraft> generateSite({
    required String prompt,
    String? templateHint,
  }) async {
    await _wait();
    if (prompt.trim().length < 8) {
      throw const ValidationException(
        message: 'Describe the site in a little more detail.',
        fieldErrors: <String, String>{'prompt': 'At least 8 characters.'},
      );
    }
    return MockFixtures.draftFor(prompt, _clock());
  }

  @override
  Future<Deployment> deploySite({
    required String draftId,
    required String repository,
    required String branch,
  }) async {
    await _wait();
    if (_killSwitch.engaged) {
      throw const PolicyException(
        message: 'The kill-switch is engaged, so nothing can be deployed.',
        reason: 'kill_switch_engaged',
      );
    }
    if (repository != MockFixtures.deployTargetRepo) {
      throw const ForbiddenException(
        message: 'Deployments are limited to ${MockFixtures.deployTargetRepo}.',
        code: 'repo_not_allowed',
      );
    }
    // The deployment starts *pending*. The UI must wait for a status change; it may not
    // show a live URL it has not been given.
    _deployment = Deployment(
      id: 'dep-${_random.nextInt(9999)}',
      draftId: draftId,
      status: DeploymentStatus.pending,
    );
    _record(
      action: 'web_deploy',
      outcome: AuditOutcome.pending,
      target: repository,
      risk: RiskTier.high,
    );
    return _deployment!;
  }

  @override
  Future<List<Deployment>> deployments() async {
    await _wait();
    return <Deployment>[if (_deployment != null) _deployment!];
  }

  // ---- messaging ----------------------------------------------------------

  @override
  Future<List<Contact>> contacts() async {
    await _wait();
    return List<Contact>.unmodifiable(_contacts);
  }

  @override
  Future<List<ToneProfile>> toneProfiles() async {
    await _wait();
    return List<ToneProfile>.unmodifiable(_tones);
  }

  @override
  Future<ToneProfile> saveToneProfile(ToneProfile profile) async {
    await _wait();
    final int index = _tones.indexWhere((ToneProfile t) => t.id == profile.id);
    if (index >= 0) {
      _tones[index] = profile;
    } else {
      _tones.add(profile);
    }
    return profile;
  }

  @override
  Future<Contact> updateContact(Contact contact) async {
    await _wait();
    final int index =
        _contacts.indexWhere((Contact c) => c.id == contact.id);
    if (index < 0) {
      throw const NotFoundException(message: 'That contact is no longer in the list.');
    }
    _contacts[index] = contact;
    // Flipping a contact to auto-send is a meaningful permission change, so it is audited
    // at MEDIUM.
    _record(
      action: 'messaging.contact_update',
      outcome: AuditOutcome.success,
      target: contact.displayName,
      risk: RiskTier.medium,
    );
    return contact;
  }

  // ---- admin --------------------------------------------------------------

  @override
  Future<List<AdminUserRow>> adminUsers() async {
    await _wait();
    return List<AdminUserRow>.unmodifiable(_adminUsers);
  }

  @override
  Future<AdminUserRow> updateAdminUser({
    required String userId,
    UserRole? role,
    AccountStatus? status,
  }) async {
    await _wait();
    final int index =
        _adminUsers.indexWhere((AdminUserRow u) => u.id == userId);
    if (index < 0) {
      throw const NotFoundException(message: 'That account no longer exists.');
    }
    final AdminUserRow row = _adminUsers[index];
    if (row.isSelf && (status == AccountStatus.suspended || role == UserRole.user)) {
      throw const PolicyException(
        message: 'You cannot remove your own admin access.',
        reason: 'self_demotion_blocked',
      );
    }
    final AdminUserRow updated = AdminUserRow(
      id: row.id,
      displayName: row.displayName,
      email: row.email,
      role: role ?? row.role,
      status: status ?? row.status,
      lastActiveAt: row.lastActiveAt,
      linkedDeviceCount: row.linkedDeviceCount,
      isSelf: row.isSelf,
    );
    _adminUsers[index] = updated;
    _record(
      action: 'admin.user_update',
      outcome: AuditOutcome.success,
      target: row.email,
      risk: RiskTier.high,
    );
    return updated;
  }

  @override
  Future<List<AuditEntry>> auditLog({
    String? actorEmail,
    String? action,
    int limit = 100,
  }) async {
    await _wait();
    Iterable<AuditEntry> rows = _audit;
    if (actorEmail != null && actorEmail.isNotEmpty) {
      rows = rows.where((AuditEntry e) => e.actorEmail == actorEmail);
    }
    if (action != null && action.isNotEmpty) {
      rows = rows.where((AuditEntry e) => e.action == action);
    }
    return rows.take(limit).toList(growable: false);
  }

  @override
  Future<List<ToolToggle>> toolToggles() async {
    await _wait();
    return List<ToolToggle>.unmodifiable(_tools);
  }

  @override
  Future<ToolToggle> setToolEnabled({
    required String toolId,
    required bool enabled,
  }) async {
    await _wait();
    final int index = _tools.indexWhere((ToolToggle t) => t.id == toolId);
    if (index < 0) {
      throw const NotFoundException(message: 'That tool does not exist.');
    }
    if (_killSwitch.engaged && enabled) {
      throw const PolicyException(
        message: 'Release the kill-switch before enabling tools.',
        reason: 'kill_switch_engaged',
      );
    }
    final ToolToggle updated = _tools[index].copyWith(enabled: enabled);
    _tools[index] = updated;
    _record(
      action: 'admin.tool_toggle',
      outcome: AuditOutcome.success,
      target: updated.name,
      risk: RiskTier.high,
    );
    return updated;
  }

  @override
  Future<KillSwitchState> setKillSwitch({
    required bool engaged,
    String reason = '',
  }) async {
    await _wait();
    _killSwitch = KillSwitchState(
      engaged: engaged,
      engagedAt: engaged ? _clock().toUtc() : null,
      engagedBy: engaged ? _currentUserEmail : null,
      reason: reason.isEmpty ? null : reason,
    );
    emit(AssistantKillSwitchEvent(state: _killSwitch));
    _record(
      action: 'admin.kill_switch',
      outcome: AuditOutcome.success,
      target: engaged ? 'engaged' : 'released',
      risk: RiskTier.high,
    );
    return _killSwitch;
  }

  @override
  Future<KillSwitchState> killSwitchState() async {
    await _wait();
    return _killSwitch;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }

  void _record({
    required String action,
    required AuditOutcome outcome,
    String? actor,
    String? target,
    RiskTier risk = RiskTier.low,
  }) {
    _audit.insert(
      0,
      AuditEntry(
        id: 'a-${_audit.length}-${_random.nextInt(9999)}',
        occurredAt: _clock().toUtc(),
        actorEmail: actor ?? _currentUserEmail,
        action: action,
        outcome: outcome,
        targetLabel: target,
        riskTierName: risk.name,
        requestId: 'req-${_random.nextInt(999999)}',
      ),
    );
  }
}

/// Small extension so the mock can use `firstOrNull` without importing collection.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
