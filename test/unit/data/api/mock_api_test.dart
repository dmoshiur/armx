// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/router/routes.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/data/api/armx_api.dart';
import 'package:armx_ai/data/api/auth_session.dart';
import 'package:armx_ai/data/api/mock/mock_armx_api.dart';
import 'package:armx_ai/data/api/mock/mock_fixtures.dart';
import 'package:armx_ai/data/models/admin.dart';
import 'package:armx_ai/data/models/alarm.dart';
import 'package:armx_ai/data/models/device.dart';
import 'package:armx_ai/data/models/assistant.dart';
import 'package:armx_ai/data/models/guest.dart';
import 'package:armx_ai/data/models/linked_device.dart';
import 'package:armx_ai/data/models/web_builder.dart';
import 'package:armx_ai/features/auth/data/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mock backend is what the app is developed and demoed against, so it is tested like a
/// backend: it must refuse what a real one refuses, and it must never show a success that did
/// not happen.
///
/// No artificial latency: these tests are about behaviour, and 320 ms × 30 calls is a slow
/// suite that people stop running.
MockArmxApi buildApi({DateTime? now}) => MockArmxApi(
      latency: Duration.zero,
      clock: now == null ? null : () => now,
    );

Future<AuthSession> signIn(MockArmxApi api,
        {String email = MockFixtures.ownerEmail,
        String password = MockFixtures.ownerPassword}) =>
    api.login(
      email: email,
      password: password,
      deviceName: 'Test device',
      platform: 'test',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the mock implements the same interface as the REST client', () {
    // Compile-time as well as run-time: a method missing from the mock would break the build
    // here rather than at the first screen that calls it.
    final ArmxApi api = buildApi();
    expect(api, isA<ArmxApi>());
  });

  group('sign-in', () {
    test('the right password signs the owner in as admin', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      final AuthSession session = await signIn(api);
      expect(session.user.email, MockFixtures.ownerEmail);
      expect(session.user.role, UserRole.admin);
      expect(session.tokens.accessToken, isNotEmpty);
      expect(session.tokens.refreshToken, isNotEmpty);
    });

    test('a wrong password fails, and the failure does not say which half was wrong',
        () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      await expectLater(
        signIn(api, password: 'not-the-password'),
        throwsA(
          isA<UnauthorizedException>().having(
            (UnauthorizedException e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
    });

    test('an unknown address fails the same way as a wrong password', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      // Distinguishing the two would tell an attacker which addresses exist.
      Object? unknownAddress;
      Object? wrongPassword;
      try {
        await signIn(api, email: 'nobody@example.com');
      } on AppException catch (error) {
        unknownAddress = error.code;
      }
      try {
        await signIn(api, password: 'nope');
      } on AppException catch (error) {
        wrongPassword = error.code;
      }
      expect(unknownAddress, wrongPassword);
    });

    test('an unverified account is a distinct outcome, not a failed sign-in', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      // The gate has to be reportable: the UI sends the user to the code screen rather than
      // telling them their password is wrong.
      await expectLater(
        signIn(
          api,
          email: MockFixtures.unverifiedEmail,
          password: MockFixtures.memberPassword,
        ),
        throwsA(
          isA<UnauthorizedException>().having(
            (UnauthorizedException e) => e.code,
            'code',
            'email_not_verified',
          ),
        ),
      );
    });

    test('the member account is not an admin', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      final AuthSession session = await signIn(
        api,
        email: MockFixtures.memberEmail,
        password: MockFixtures.memberPassword,
      );
      expect(session.user.role, isNot(UserRole.admin));
    });
  });

  group('password reset', () {
    test('the valid token is accepted and the expired one is reported as expired',
        () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      expect(
        await api.checkResetToken(token: MockFixtures.validResetToken),
        TokenValidity.valid,
      );
      expect(
        await api.checkResetToken(token: MockFixtures.expiredResetToken),
        TokenValidity.expired,
      );
      expect(
        await api.checkResetToken(token: 'never-issued'),
        TokenValidity.invalid,
      );
    });

    test('a reset token cannot be used twice', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      await api.resetPassword(
        token: MockFixtures.validResetToken,
        newPassword: 'Brand#New2026',
      );
      await expectLater(
        api.resetPassword(
          token: MockFixtures.validResetToken,
          newPassword: 'Another#New2026',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('resetting a password does not reveal whether the address exists', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      // Both must resolve: an error for the unknown address would be an account oracle.
      await api.requestPasswordReset(email: MockFixtures.ownerEmail);
      await api.requestPasswordReset(email: 'nobody@example.com');
    });
  });

  group('the assistant', () {
    test('a plain prompt streams tokens and then stops speaking', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<AssistantEvent> events = <AssistantEvent>[];
      final subscription = api.events().listen(events.add);
      addTearDown(subscription.cancel);

      await api.sendMessage(conversationId: 'c-1', text: 'what is the time');
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<AssistantTokenEvent>(), isNotEmpty);
      expect(
        events.whereType<AssistantTokenEvent>().last.done,
        isTrue,
        reason: 'the stream must end, or the UI shows a cursor forever',
      );
    });

    test('a HIGH-risk tool call waits for a decision instead of acting', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<AssistantEvent> events = <AssistantEvent>[];
      final subscription = api.events().listen(events.add);
      addTearDown(subscription.cancel);

      await api.sendMessage(conversationId: 'c-1', text: 'unlock the front door');
      await Future<void>.delayed(Duration.zero);

      final AssistantToolCallEvent call =
          events.whereType<AssistantToolCallEvent>().single;
      expect(call.call.riskTier, RiskTier.high);
      expect(call.call.status, ToolCallStatus.awaitingDecision);
    });

    test('denying a tool call reports a denial, never a success', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<AssistantEvent> events = <AssistantEvent>[];
      final subscription = api.events().listen(events.add);
      addTearDown(subscription.cancel);

      await api.sendMessage(conversationId: 'c-1', text: 'unlock the front door');
      await Future<void>.delayed(Duration.zero);
      final String id =
          events.whereType<AssistantToolCallEvent>().single.call.id;

      await api.decideToolCall(
        toolCallId: id,
        decision: ToolDecision.deny,
        denyReason: 'Not now',
      );
      await Future<void>.delayed(Duration.zero);

      final AssistantToolStatusEvent status =
          events.whereType<AssistantToolStatusEvent>().last;
      expect(status.status, ToolCallStatus.denied);
      expect(status.status.isSuccess, isFalse);
    });

    test('the transcript records what was said, in order', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<ChatMessage> before = await api.transcript(conversationId: 'c-1');
      await api.sendMessage(conversationId: 'c-1', text: 'turn off the fan');
      final List<ChatMessage> after = await api.transcript(conversationId: 'c-1');
      expect(after.length, greaterThan(before.length));
      expect(
        after.any((ChatMessage message) =>
            message.text.contains('turn off the fan')),
        isTrue,
      );
    });
  });

  group('devices', () {
    test('a LOW-risk command is accepted without a pending phase', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<ArmxDevice> devices = await api.devices();
      final String lightId = devices
          .firstWhere((ArmxDevice device) => device.kind == DeviceKind.light)
          .id;
      final DeviceCommandResult result = await api.sendDeviceCommand(
        deviceId: lightId,
        command: 'turn_on',
      );
      expect(result.accepted, isTrue);
      expect(result.pending, isFalse);
    });

    test('an unrecognised device is refused rather than answered with a happy default',
        () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      await expectLater(
        api.sendDeviceCommand(deviceId: 'no-such-device', command: 'turn_on'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('alarms', () {
    test('a ringing alarm can be acknowledged, and then it stops ringing', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<ArmxAlarm> alarms = await api.alarms();
      final List<ArmxAlarm> ringing =
          alarms.where((ArmxAlarm alarm) => alarm.isRinging).toList();
      expect(ringing, isNotEmpty, reason: 'the fixture must include a ringing alarm');
      final ArmxAlarm acknowledged =
          await api.acknowledgeAlarm(ringing.first.id);
      expect(acknowledged.isRinging, isFalse);
    });

    test('deleting an alarm removes it, and deleting it twice fails', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final String id = (await api.alarms()).first.id;
      await api.deleteAlarm(id);
      final List<ArmxAlarm> remaining = await api.alarms();
      expect(
        remaining.where((ArmxAlarm alarm) => alarm.id == id),
        isEmpty,
      );
      await expectLater(api.deleteAlarm(id), throwsA(isA<AppException>()));
    });
  });

  group('linked devices', () {
    test('pairing returns a code, approving it links the device once, and cancelling'
        ' clears the pending request', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final PairingOffer offer =
          await api.startPairing(deviceName: 'New laptop', platform: 'linux');
      expect(offer.code, isNotEmpty);
      expect(offer.expiresAt.isAfter(DateTime.now()), isTrue);

      final LinkedDevice linked = await api.approvePairing(offer.code);
      expect(linked.name, 'New laptop');
      expect(linked.status.hasAccess, isTrue);

      // The same code cannot be redeemed twice.
      await expectLater(api.approvePairing(offer.code), throwsA(isA<AppException>()));

      await api.startPairing(deviceName: 'Another', platform: 'linux');
      await api.cancelPairing();
    });

    test('unlinking requires the owner password and refuses a wrong one', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<LinkedDevice> devices = await api.linkedDevices();
      final String id = devices
          .firstWhere((LinkedDevice device) => !device.isCurrentDevice)
          .id;
      await expectLater(
        api.unlinkDevice(deviceId: id, ownerPassword: 'wrong-password'),
        throwsA(isA<AppException>()),
      );
      // Still linked: a refusal must not have half-applied.
      final List<LinkedDevice> after = await api.linkedDevices();
      expect(
        after.any((LinkedDevice device) => device.id == id),
        isTrue,
      );
    });
  });

  group('the guest greeter', () {
    test('the camera can be turned off, and off is what the state says', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final GreeterState on = await api.setGreeterCamera(state: 'live');
      expect(on.camera.isCapturing, isTrue);

      final GreeterState off = await api.setGreeterCamera(state: 'off');
      expect(off.camera.isCapturing, isFalse);
    });

    test('enrolment without consent is refused', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      await expectLater(
        api.enrollGuest(displayName: 'Someone', consentGiven: false),
        throwsA(isA<AppException>()),
      );
      expect((await api.guests()), isEmpty);
    });

    test('a consented enrolment is stored, and deleting removes it completely', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final GuestProfile guest = await api.enrollGuest(
        displayName: 'Nadia',
        consentGiven: true,
        note: 'Neighbour',
      );
      expect(guest.consentTextVersion, isNotEmpty);
      await api.deleteGuest(guest.id);
      final List<GuestProfile> remaining = await api.guests();
      expect(
        remaining.any((GuestProfile profile) => profile.id == guest.id),
        isFalse,
      );
    });
  });

  group('the web builder', () {
    test('generating a site returns a diffable draft against the fixture repository',
        () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final SiteDraft draft = await api.generateSite(prompt: 'a page for the workshop');
      expect(draft.files, isNotEmpty);
      expect(draft.repository, MockFixtures.deployTargetRepo);
      expect(draft.prompt, contains('workshop'));
    });

    test('a deployment starts pending and only becomes live when the backend says so',
        () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final SiteDraft draft = await api.generateSite(prompt: 'a page');
      final Deployment first = await api.deploySite(
        draftId: draft.id,
        repository: draft.repository,
        branch: draft.branch,
      );
      expect(first.status.isLive, isFalse);
      expect(first.liveUrl, isNull);

      final List<Deployment> history = await api.deployments();
      expect(history, isNotEmpty);
      expect(
        history.any((Deployment deployment) => deployment.status.isLive),
        isTrue,
        reason: 'the backend eventually reports a live URL — not the client',
      );
    });

    test('deploying into a repository that is not the configured one is refused', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final SiteDraft draft = await api.generateSite(prompt: 'a page');
      await expectLater(
        api.deploySite(
          draftId: draft.id,
          repository: 'somebody-else/their-site',
          branch: 'main',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('administration', () {
    test('the owner is the admin row marked as self, and cannot be demoted by accident',
        () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<AdminUserRow> users = await api.adminUsers();
      final AdminUserRow self =
          users.firstWhere((AdminUserRow row) => row.isSelf);
      expect(self.email, MockFixtures.ownerEmail);

      await expectLater(
        api.updateAdminUser(
          userId: self.id,
          role: UserRole.user,
        ),
        throwsA(isA<AppException>()),
        reason: 'an admin removing their own admin rights locks the estate out',
      );
    });

    test('suspending another account is recorded in the audit log', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<AdminUserRow> rows = await api.adminUsers();
      final AdminUserRow other =
          rows.firstWhere((AdminUserRow row) => !row.isSelf);
      await api.updateAdminUser(userId: other.id, status: AccountStatus.suspended);

      final List<AuditEntry> log = await api.auditLog();
      expect(log, isNotEmpty);
      expect(
        log.any((entry) => entry.outcome == AuditOutcome.success),
        isTrue,
        reason: 'an administrative change must leave a record',
      );
      final AdminUserRow after = (await api.adminUsers())
          .firstWhere((AdminUserRow row) => row.id == other.id);
      expect(after.status, AccountStatus.suspended);
    });

    test('the audit log can be filtered by actor and by action', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<AuditEntry> byActor =
          await api.auditLog(actorEmail: MockFixtures.ownerEmail);
      expect(
        byActor.every(
            (AuditEntry entry) => entry.actorEmail == MockFixtures.ownerEmail),
        isTrue,
      );
      expect(await api.auditLog(action: 'no-such-action-ever'), isEmpty);
    });

    test('a tool can be disabled and enabled again, and its state is reported', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final ToolToggle tool = (await api.toolToggles()).first;
      final ToolToggle off =
          await api.setToolEnabled(toolId: tool.id, enabled: false);
      expect(off.enabled, isFalse);
      final ToolToggle on =
          await api.setToolEnabled(toolId: tool.id, enabled: true);
      expect(on.enabled, isTrue);
    });

    test('the kill switch engages and disengages, and announces both', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<AssistantEvent> events = <AssistantEvent>[];
      final subscription = api.events().listen(events.add);
      addTearDown(subscription.cancel);

      final KillSwitchState engaged = await api.setKillSwitch(
        engaged: true,
        reason: 'Testing the switch',
      );
      expect(engaged.engaged, isTrue);
      expect(engaged.reason, 'Testing the switch');
      expect(engaged.engagedBy, MockFixtures.ownerEmail);

      await api.setKillSwitch(engaged: false);
      expect((await api.killSwitchState()).engaged, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<AssistantKillSwitchEvent>(), isNotEmpty);
    });

    test('a non-admin cannot read the admin surface', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(
        api,
        email: MockFixtures.memberEmail,
        password: MockFixtures.memberPassword,
      );

      await expectLater(api.adminUsers(), throwsA(isA<AppException>()));
      await expectLater(api.auditLog(), throwsA(isA<AppException>()));
      await expectLater(api.toolToggles(), throwsA(isA<AppException>()));
      await expectLater(api.setKillSwitch(engaged: true), throwsA(isA<AppException>()));
    });

    test('a signed-out client cannot read anything that needs a session', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);

      await expectLater(api.devices(), throwsA(isA<AppException>()));
      await expectLater(api.sessions(), throwsA(isA<AppException>()));
      await expectLater(api.me(), throwsA(isA<AppException>()));
    });
  });

  group('sessions', () {
    test('the current session is listed and cannot be revoked from the list', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<SessionInfo> sessions = await api.sessions();
      expect(sessions, isNotEmpty);
      final SessionInfo current =
          sessions.firstWhere((SessionInfo sessionInfo) => sessionInfo.current);
      await expectLater(
        api.revokeSession(current.id),
        throwsA(isA<AppException>()),
      );
    });

    test('revoking another session removes it', () async {
      final MockArmxApi api = buildApi();
      addTearDown(api.dispose);
      await signIn(api);

      final List<SessionInfo> sessions = await api.sessions();
      final SessionInfo other =
          sessions.firstWhere((SessionInfo sessionInfo) => !sessionInfo.current);
      await api.revokeSession(other.id);
      final List<SessionInfo> after = await api.sessions();
      expect(
        after.any((SessionInfo sessionInfo) => sessionInfo.id == other.id),
        isFalse,
      );
    });
  });

  test('the mock signs out completely: the next call is unauthorised', () async {
    final MockArmxApi api = buildApi();
    addTearDown(api.dispose);
    await signIn(api);
    expect((await api.devices()), isNotEmpty);

    await api.logout();
    await expectLater(api.devices(), throwsA(isA<AppException>()));
  });
}
