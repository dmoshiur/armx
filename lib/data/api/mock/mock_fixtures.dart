// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../../core/network/token_store.dart';
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

/// Deterministic sample data for the mock backend.
///
/// Everything here is fictional and safe to commit: no real addresses, no real keys, no
/// real hostnames. The fixed values ([validResetToken], [pairingCode], …) are the tokens
/// the mock's flows accept, which is what lets a widget test drive "valid token",
/// "expired token" and "wrong password" paths without a server.
abstract final class MockFixtures {
  // ---- accounts ------------------------------------------------------------

  /// The demo owner/admin account.
  static const String ownerEmail = 'mohi@thamjj13.top';

  /// The demo owner's password. Used by the unlink gate.
  static const String ownerPassword = 'ArmxDemo#2026';

  /// The demo regular member.
  static const String memberEmail = 'rafi@example.com';

  /// Password for the demo member.
  static const String memberPassword = 'Member#2026';

  /// A VIP account, so the role-gated web-builder route is reachable in the demo.
  static const String vipEmail = 'vip@example.com';

  /// Address returned by the mock Google flow.
  static const String googleEmail = 'google.user@example.com';

  /// An account that exists but has not verified its email.
  static const String unverifiedEmail = 'unverified@example.com';

  // ---- tokens --------------------------------------------------------------

  /// The verification token the mock accepts.
  static const String validVerificationToken = 'verify-armx-2026';

  /// A reset token that is still valid.
  static const String validResetToken = 'reset-valid-armx-2026';

  /// A reset token that has expired.
  static const String expiredResetToken = 'reset-expired-armx-2026';

  /// How long a reset token lives.
  static const Duration resetTokenLifetime = Duration(minutes: 30);

  /// The pairing code the mock issues.
  static const String pairingCode = 'AR7X29KD';

  /// A short public-key fingerprint, shown during pairing.
  static const String fingerprint = '5F2A 91C4 7E30 B8DA';

  /// Host used to build the mock's live-URL strings.
  static const String deployHost = 'armx-preview.local';

  /// The only repository the mock will deploy to, mirroring the backend's allow-list.
  static const String deployTargetRepo = 'thamjj13/armx-site';

  // ---- rooms & devices -----------------------------------------------------

  /// Rooms belonging to the demo home.
  static List<ArmxRoom> rooms() => const <ArmxRoom>[
        ArmxRoom(id: 'living', name: 'Living room', floor: 'Ground'),
        ArmxRoom(id: 'bedroom', name: 'Bedroom', floor: 'First'),
        ArmxRoom(id: 'lab', name: 'Workshop', floor: 'Ground'),
        ArmxRoom(id: 'outdoor', name: 'Outside', floor: 'Ground'),
      ];

  /// Devices across those rooms, including one offline device, one read-only sensor and
  /// one device the current role may not command — the three states a naive UI collapses
  /// into "off".
  static List<ArmxDevice> devices() => <ArmxDevice>[
        const ArmxDevice(
          id: 'd-living-light',
          name: 'Living room light',
          kind: DeviceKind.light,
          roomId: 'living',
          online: true,
          level: true,
          brightness: 70,
          firmwareVersion: '1.4.2',
        ),
        const ArmxDevice(
          id: 'd-living-fan',
          name: 'Ceiling fan',
          kind: DeviceKind.fan,
          roomId: 'living',
          online: true,
          level: false,
          brightness: 0,
          firmwareVersion: '1.4.2',
        ),
        const ArmxDevice(
          id: 'd-bedroom-light',
          name: 'Bedside lamp',
          kind: DeviceKind.light,
          roomId: 'bedroom',
          online: true,
          level: false,
          brightness: 0,
          firmwareVersion: '1.3.9',
        ),
        const ArmxDevice(
          id: 'd-lab-light',
          name: 'Workshop light',
          kind: DeviceKind.light,
          roomId: 'lab',
          online: false,
          level: false,
          brightness: 0,
          firmwareVersion: '1.2.0',
        ),
        const ArmxDevice(
          id: 'd-lab-sensor',
          name: 'Workshop climate',
          kind: DeviceKind.sensor,
          roomId: 'lab',
          online: true,
          reading: SensorReading(metric: 'temperature', value: 27.4, unit: '°C'),
          firmwareVersion: '1.4.2',
        ),
        const ArmxDevice(
          id: 'd-outdoor-sensor',
          name: 'Outdoor climate',
          kind: DeviceKind.sensor,
          roomId: 'outdoor',
          online: true,
          reading: SensorReading(metric: 'humidity', value: 68, unit: '%'),
          firmwareVersion: '1.4.1',
        ),
        const ArmxDevice(
          id: 'd-gate-lock',
          name: 'Gate lock',
          kind: DeviceKind.lock,
          roomId: 'outdoor',
          online: true,
          level: false,
          firmwareVersion: '2.0.1',
          // A regular user may see it but not command it: the control renders disabled
          // with the reason shown, rather than vanishing.
          controllableByCurrentUser: false,
        ),
      ];

  // ---- alarms --------------------------------------------------------------

  /// Two alarms: one armed across three targets, one disabled and single-target.
  static List<ArmxAlarm> alarms(DateTime Function() clock) => <ArmxAlarm>[
        ArmxAlarm(
          id: 'alarm-morning',
          label: 'Morning',
          hour: 6,
          minute: 30,
          enabled: true,
          repeat: AlarmRepeat.weekdays,
          snoozeMinutes: 5,
          lastRangAt: clock().toUtc().subtract(const Duration(hours: 9)),
          targets: const <AlarmTarget>[
            AlarmTarget(
              deviceId: 'self',
              kind: AlarmTargetKind.phone,
              label: 'This phone',
              reachable: true,
            ),
            AlarmTarget(
              deviceId: 'ld-study-pc',
              kind: AlarmTargetKind.computer,
              label: 'Study PC',
              reachable: true,
            ),
            AlarmTarget(
              deviceId: 'ld-band',
              kind: AlarmTargetKind.watch,
              label: 'Band',
              // Unreachable on purpose so the cross-device status list has something real
              // to report.
              reachable: false,
            ),
          ],
        ),
        ArmxAlarm(
          id: 'alarm-medicine',
          label: 'Medicine',
          hour: 21,
          minute: 0,
          enabled: false,
          repeat: AlarmRepeat.daily,
          targets: const <AlarmTarget>[
            AlarmTarget(
              deviceId: 'self',
              kind: AlarmTargetKind.phone,
              label: 'This phone',
            ),
          ],
        ),
      ];

  // ---- linked devices ------------------------------------------------------

  /// Three linked devices, including the one in hand and a revoked one kept for the audit.
  static List<LinkedDevice> linkedDevices(DateTime Function() clock) => <LinkedDevice>[
        LinkedDevice(
          id: 'ld-this-phone',
          name: 'This phone',
          platform: 'android',
          status: LinkStatus.active,
          ownerEmail: ownerEmail,
          lastActiveAt: clock().toUtc(),
          isCurrentDevice: true,
          fingerprint: fingerprint,
        ),
        LinkedDevice(
          id: 'ld-study-pc',
          name: 'Study PC',
          platform: 'windows',
          status: LinkStatus.active,
          ownerEmail: ownerEmail,
          lastActiveAt: clock().toUtc().subtract(const Duration(hours: 2)),
          linkMethod: LinkMethod.code,
          fingerprint: '11AC 44F0 9B27 6E13',
        ),
        LinkedDevice(
          id: 'ld-old-laptop',
          name: 'Old laptop',
          platform: 'linux',
          status: LinkStatus.offline,
          ownerEmail: memberEmail,
          lastActiveAt: clock().toUtc().subtract(const Duration(days: 21)),
          linkMethod: LinkMethod.qr,
          fingerprint: '87D2 3310 AEE4 0C59',
        ),
        LinkedDevice(
          id: 'ld-tablet',
          name: 'Kitchen tablet',
          platform: 'android',
          status: LinkStatus.revoked,
          ownerEmail: ownerEmail,
          lastActiveAt: clock().toUtc().subtract(const Duration(days: 40)),
          fingerprint: '4B19 8E77 20F1 5A6C',
        ),
      ];

  // ---- guest greeter -------------------------------------------------------

  /// Guests already enrolled, with consent version recorded per person.
  static List<GuestProfile> guests(DateTime Function() clock) => <GuestProfile>[
        GuestProfile(
          id: 'g-judge',
          displayName: 'Fair judge',
          enrolledAt: clock().toUtc().subtract(const Duration(days: 2)),
          note: 'Science fair',
          consentTextVersion: 'v1',
          encryptedTemplateRef: 'tpl-local-1',
        ),
        GuestProfile(
          id: 'g-meter',
          displayName: 'Meter reader',
          enrolledAt: clock().toUtc().subtract(const Duration(days: 9)),
          note: 'Utility visit',
          consentTextVersion: 'v1',
          encryptedTemplateRef: 'tpl-local-2',
        ),
      ];

  /// Recent greeter events, one of them low-confidence so the UI shows the number.
  static List<GreeterEvent> greeterEvents(DateTime Function() clock) =>
      <GreeterEvent>[
        GreeterEvent(
          id: 'ge-1',
          occurredAt: clock().toUtc().subtract(const Duration(minutes: 14)),
          guestName: 'Fair judge',
          confidence: 0.94,
          greetingSpoken: true,
        ),
        GreeterEvent(
          id: 'ge-2',
          occurredAt: clock().toUtc().subtract(const Duration(hours: 3)),
          guestName: 'Meter reader',
          // Deliberately below a comfortable threshold: the UI shows the score rather
          // than presenting an uncertain match as fact.
          confidence: 0.61,
        ),
        GreeterEvent(
          id: 'ge-3',
          occurredAt: clock().toUtc().subtract(const Duration(days: 1)),
          guestName: 'Fair judge',
          confidence: 0.88,
          greetingSpoken: true,
        ),
      ];

  // ---- messaging -----------------------------------------------------------

  /// The three tone profiles the spec names.
  static List<ToneProfile> toneProfiles() => const <ToneProfile>[
        ToneProfile(
          id: 'tone-student',
          name: 'Student',
          tag: 'student',
          formality: 35,
          warmth: 70,
          verbosity: 45,
          emojiAllowed: true,
          languageCode: 'auto',
        ),
        ToneProfile(
          id: 'tone-teacher',
          name: 'Teacher',
          tag: 'teacher',
          formality: 85,
          warmth: 55,
          verbosity: 60,
          emojiAllowed: false,
          languageCode: 'en',
          forbiddenTopics: <String>['money', 'health'],
        ),
        ToneProfile(
          id: 'tone-friend',
          name: 'Friend',
          tag: 'friend',
          formality: 15,
          warmth: 90,
          verbosity: 40,
          emojiAllowed: true,
          languageCode: 'bn',
        ),
      ];

  /// Contacts mapped to those profiles.
  static List<Contact> contacts() => const <Contact>[
        Contact(
          id: 'c-1',
          displayName: 'Nusrat (tuition)',
          toneProfileId: 'tone-student',
          deliveryMode: DeliveryMode.draftOnly,
          tag: 'student',
        ),
        Contact(
          id: 'c-2',
          displayName: 'Sir Kamal',
          toneProfileId: 'tone-teacher',
          deliveryMode: DeliveryMode.draftOnly,
          tag: 'teacher',
        ),
        Contact(
          id: 'c-3',
          displayName: 'Tanvir',
          toneProfileId: 'tone-friend',
          deliveryMode: DeliveryMode.autoSend,
          tag: 'friend',
        ),
      ];

  // ---- admin ---------------------------------------------------------------

  /// The user table, covering all three roles and three account statuses.
  static List<AdminUserRow> adminUsers(DateTime Function() clock) => <AdminUserRow>[
        AdminUserRow(
          id: 'u-1',
          displayName: 'Md. Moshiur Rahman Mohi',
          email: ownerEmail,
          role: UserRole.admin,
          status: AccountStatus.active,
          lastActiveAt: clock().toUtc(),
          linkedDeviceCount: 2,
          isSelf: true,
        ),
        AdminUserRow(
          id: 'u-2',
          displayName: 'VIP guest',
          email: vipEmail,
          role: UserRole.vip,
          status: AccountStatus.active,
          lastActiveAt: clock().toUtc().subtract(const Duration(hours: 5)),
          linkedDeviceCount: 1,
        ),
        AdminUserRow(
          id: 'u-3',
          displayName: 'Rafi',
          email: memberEmail,
          role: UserRole.user,
          status: AccountStatus.active,
          lastActiveAt: clock().toUtc().subtract(const Duration(minutes: 40)),
          linkedDeviceCount: 1,
        ),
        AdminUserRow(
          id: 'u-4',
          displayName: 'Unverified account',
          email: unverifiedEmail,
          role: UserRole.user,
          status: AccountStatus.invited,
        ),
        AdminUserRow(
          id: 'u-5',
          displayName: 'Suspended account',
          email: 'suspended@example.com',
          role: UserRole.user,
          status: AccountStatus.suspended,
          lastActiveAt: clock().toUtc().subtract(const Duration(days: 30)),
        ),
      ];

  /// An audit trail with one row per outcome, so the log's four states are all visible.
  static List<AuditEntry> auditEntries(DateTime Function() clock) => <AuditEntry>[
        AuditEntry(
          id: 'a-1',
          occurredAt: clock().toUtc().subtract(const Duration(minutes: 3)),
          actorEmail: ownerEmail,
          action: 'set_light',
          outcome: AuditOutcome.success,
          targetLabel: 'Living room light',
          riskTierName: 'low',
          detail: '{"device_id":"d-living-light","command":"toggle"}',
          requestId: 'req-88213',
        ),
        AuditEntry(
          id: 'a-2',
          occurredAt: clock().toUtc().subtract(const Duration(minutes: 11)),
          actorEmail: ownerEmail,
          action: 'web_deploy',
          outcome: AuditOutcome.pending,
          targetLabel: deployTargetRepo,
          riskTierName: 'high',
          detail: '{"branch":"main"}',
          requestId: 'req-88212',
        ),
        AuditEntry(
          id: 'a-3',
          occurredAt: clock().toUtc().subtract(const Duration(hours: 2)),
          actorEmail: memberEmail,
          action: 'unlock_gate',
          outcome: AuditOutcome.denied,
          targetLabel: 'Gate lock',
          riskTierName: 'high',
          detail: 'Denied: owner password not supplied.',
          requestId: 'req-88211',
        ),
        AuditEntry(
          id: 'a-4',
          occurredAt: clock().toUtc().subtract(const Duration(hours: 6)),
          actorEmail: 'system',
          action: 'device.offline',
          outcome: AuditOutcome.failed,
          targetLabel: 'Workshop light',
          riskTierName: 'low',
          detail: 'No heartbeat for 42 minutes.',
          requestId: 'req-88203',
        ),
      ];

  /// Tool toggles, including a HIGH-risk one so the admin sees the tier before enabling.
  static List<ToolToggle> toolToggles() => const <ToolToggle>[
        ToolToggle(
          id: 'set_light',
          name: 'set_light',
          description: 'Switch or dim a light.',
          enabled: true,
          riskTierName: 'low',
        ),
        ToolToggle(
          id: 'set_fan',
          name: 'set_fan',
          description: 'Switch a fan on or off.',
          enabled: true,
          riskTierName: 'low',
        ),
        ToolToggle(
          id: 'read_sensors',
          name: 'read_sensors',
          description: 'Read temperature, humidity and motion.',
          enabled: true,
          riskTierName: 'low',
        ),
        ToolToggle(
          id: 'web_deploy',
          name: 'web_deploy',
          description: 'Generate and publish a website to the project repository.',
          enabled: true,
          riskTierName: 'high',
        ),
        ToolToggle(
          id: 'unlock_gate',
          name: 'unlock_gate',
          description: 'Release the gate lock.',
          enabled: false,
          riskTierName: 'high',
          blockedReason: 'Requires the owner password in the confirmation dialog.',
        ),
      ];

  /// Signed-in sessions for the Settings → Account list.
  static List<SessionInfo> sessions(DateTime Function() clock) => <SessionInfo>[
        SessionInfo(
          id: 's-current',
          deviceName: 'This phone',
          platform: 'android',
          createdAt: clock().toUtc().subtract(const Duration(hours: 4)),
          lastUsedAt: clock().toUtc(),
          current: true,
          ipHint: 'Shibganj, BD',
        ),
        SessionInfo(
          id: 's-pc',
          deviceName: 'Study PC',
          platform: 'windows',
          createdAt: clock().toUtc().subtract(const Duration(days: 3)),
          lastUsedAt: clock().toUtc().subtract(const Duration(hours: 20)),
          ipHint: 'Shibganj, BD',
        ),
        SessionInfo(
          id: 's-old',
          deviceName: 'Old laptop',
          platform: 'linux',
          createdAt: clock().toUtc().subtract(const Duration(days: 46)),
          lastUsedAt: clock().toUtc().subtract(const Duration(days: 30)),
          ipHint: 'Rajshahi, BD',
        ),
      ];

  // ---- assistant -----------------------------------------------------------

  /// The opening transcript.
  static List<ChatMessage> seedTranscript(DateTime Function() clock) => <ChatMessage>[
        ChatMessage(
          id: 'seed-1',
          author: ChatAuthor.assistant,
          text: 'Ready. Ask me about the house, the devices or the workshop.',
          createdAt: clock().toUtc().subtract(const Duration(minutes: 2)),
        ),
      ];

  /// A canned reply. The mock echoes the language of the question so the Bengali path is
  /// exercisable without a backend translator.
  static String replyFor(String prompt) {
    final String lower = prompt.toLowerCase();
    if (lower.contains('bengali') || RegExp('[\\u0980-\\u09FF]').hasMatch(prompt)) {
      return 'আচ্ছা, দেখছি। আপনার জন্য কাজটি সাজিয়ে দিচ্ছি।';
    }
    if (lower.contains('light')) {
      return 'The living room light is on at 70%. I can switch it off, or dim it.';
    }
    if (lower.contains('temperature') || lower.contains('sensor')) {
      return 'The workshop is at 27.4 °C and outside humidity is 68%.';
    }
    if (lower.contains('site') || lower.contains('website') || lower.contains('deploy')) {
      return 'I can draft that site. I will show you every file before anything is published.';
    }
    return 'Noted. I have kept that in the transcript for this device.';
  }

  /// Splits a reply into stream chunks so the UI must handle partial text.
  static List<String> chunk(String reply, {int size = 18}) {
    final List<String> parts = <String>[];
    for (int i = 0; i < reply.length; i += size) {
      parts.add(reply.substring(i, i + size > reply.length ? reply.length : i + size));
    }
    return parts;
  }

  /// A tool proposal for prompts that imply an action, or `null` for a pure question.
  ///
  /// The tier is set here exactly as the backend will set it, which is what lets a test
  /// assert that a MEDIUM action is stopped by the confirmation dialog.
  static ToolCall? toolCallFor(String prompt, DateTime Function() clock) {
    final String lower = prompt.toLowerCase();
    DateTime now() => clock().toUtc();
    if (lower.contains('turn off') || lower.contains('switch off') ||
        lower.contains('turn on') || lower.contains('switch on')) {
      final bool turningOn = lower.contains('turn on') || lower.contains('switch on');
      return ToolCall(
        id: 'tc-${now().microsecondsSinceEpoch % 100000}',
        tool: 'set_light',
        summary: '${turningOn ? 'Switch on' : 'Switch off'} the living room light',
        riskTier: RiskTier.low,
        status: ToolCallStatus.awaitingDecision,
        targetLabel: 'Living room light',
        requestedAt: now(),
        parameters: <String, Object?>{
          'device_id': 'd-living-light',
          'command': turningOn ? 'on' : 'off',
        },
      );
    }
    if (lower.contains('deploy') || lower.contains('publish') || lower.contains('site')) {
      return ToolCall(
        id: 'tc-${now().microsecondsSinceEpoch % 100000}',
        tool: 'web_deploy',
        summary: 'Publish the generated site to $deployTargetRepo',
        // HIGH: the client must not fire this without the confirmation dialog.
        riskTier: RiskTier.high,
        status: ToolCallStatus.awaitingDecision,
        targetLabel: deployTargetRepo,
        requestedAt: now(),
        parameters: <String, Object?>{
          'repository': deployTargetRepo,
          'branch': 'main',
        },
      );
    }
    if (lower.contains('unlock') || lower.contains('gate')) {
      return ToolCall(
        id: 'tc-${now().microsecondsSinceEpoch % 100000}',
        tool: 'unlock_gate',
        summary: 'Release the gate lock',
        riskTier: RiskTier.high,
        status: ToolCallStatus.awaitingDecision,
        targetLabel: 'Gate lock',
        requestedAt: now(),
        parameters: <String, Object?>{'device_id': 'd-gate-lock'},
      );
    }
    return null;
  }

  /// A generated draft with a real-looking diff.
  static SiteDraft draftFor(String prompt, DateTime Function() clock) {
    final String slug = prompt
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9 ]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .take(3)
        .join('-');
    return SiteDraft(
      id: 'draft-${slug.isEmpty ? 'site' : slug}',
      prompt: prompt,
      repository: deployTargetRepo,
      branch: 'main',
      createdAt: clock().toUtc(),
      notes: 'Fonts are linked from the project CDN; no external analytics.',
      files: <GeneratedFile>[
        GeneratedFile(
          path: 'index.html',
          language: 'html',
          contents: '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${_titleFor(prompt)}</title>
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body>
    <main>
      <h1>${_titleFor(prompt)}</h1>
      <p>${prompt.trim()}</p>
    </main>
  </body>
</html>
''',
          // An existing file, so the preview renders a genuine modification rather than
          // only new files.
          previousContents: '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Placeholder</title>
  </head>
  <body>
    <main><h1>Coming soon</h1></main>
  </body>
</html>
''',
        ),
        const GeneratedFile(
          path: 'styles.css',
          language: 'css',
          contents: '''
:root { --ink: #0B1220; --navy: #101935; --accent: #5B8CFF; }
body { margin: 0; background: var(--ink); color: #F4F6FB;
  font-family: Inter, system-ui, sans-serif; }
main { max-width: 60ch; margin: 12vh auto; padding: 0 24px; }
h1 { font-size: 2rem; }
''',
        ),
      ],
    );
  }

  static String _titleFor(String prompt) {
    final List<String> words = prompt
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .take(4)
        .toList(growable: false);
    if (words.isEmpty) {
      return 'Site';
    }
    return words
        .map((String w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

/// Issues deterministic token pairs for the mock.
abstract final class AuthTokensFixture {
  /// Creates a token pair for [userId].
  static AuthTokens issue(String userId, DateTime Function() clock) => AuthTokens(
        accessToken: 'mock-access-$userId',
        refreshToken: 'mock-refresh-$userId',
        accessExpiresAt: clock().toUtc().add(const Duration(minutes: 15)),
      );
}
