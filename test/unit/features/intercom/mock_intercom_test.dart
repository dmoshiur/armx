// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:armx_ai/core/config/app_config.dart';
import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/logging/armx_logger.dart';
import 'package:armx_ai/core/utils/clock.dart';
import 'package:armx_ai/data/api/armx_api.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/api/ws_events.dart';
import 'package:armx_ai/data/models/announcement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';
import '../../../support/test_harness.dart';

/// The intercom safety rules, exercised against the deterministic mock backend.
void main() {
  late MockArmxApi api;

  setUp(() {
    api = Fixtures.mockApi(control: MockBackendControl(latency: Duration.zero));
  });

  MockArmxApi buildApi() => MockArmxApi(
        config: AppConfig(
          environment: AppEnvironment.development,
          apiBaseUrl: Uri.parse('https://api.armx.test'),
          wsUrl: Uri.parse('wss://api.armx.test/ws'),
          useMockBackend: true,
          logLevel: AppLogLevel.off,
          mockLatencyMs: 0,
        ),
        logger: Fixtures.silentLogger(),
        clock: const FixedClock(testAnchor),
        random: MockArmxApi.deterministicRandom(),
      );

  group('rule 1 — consent', () {
    test('starts OFF for every device', () async {
      expect((await api.intercomConsent()).enabled, isFalse);
      expect((await api.intercomConsent()).allowWhileLocked, isFalse);
    });

    test('opt-in is local and immediate', () async {
      final consent = await api.setIntercomConsent(enabled: true, allowWhileLocked: true);
      expect(consent.enabled, isTrue);
      expect(consent.allowWhileLocked, isTrue);
      expect((await api.intercomConsent()).enabled, isTrue);
    });

    test('revoke is immediate and needs no approval', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: true);
      final revoked = await api.setIntercomConsent(enabled: false, allowWhileLocked: false);
      expect(revoked.enabled, isFalse);
    });

    test('the consent change is visible on the socket, not silent', () async {
      final events = <WsEvent>[];
      final subscription = api.events().listen(events.add);
      await pumpEventQueue();
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      await pumpEventQueue();
      await subscription.cancel();

      expect(
        events.whereType<IntercomConsentEvent>().single.consented,
        isTrue,
      );
    });
  });

  group('rule 1 — who can be targeted', () {
    test('a non-consented device cannot be targeted at all', () async {
      final recipients = await api.intercomRecipients();
      final kitchen = recipients.firstWhere((r) => r.userId == 'user-2');
      expect(kitchen.consented, isFalse);
      expect(kitchen.isTargetable, isFalse);
    });

    test('sending to a non-consented device is refused by the backend', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      await expectLater(
        api.sendAnnouncement(
          audioBytes: <int>[1, 2, 3],
          durationMs: 400,
          targetUserId: 'user-2',
        ),
        throwsA(isA<PolicyException>()),
      );
    });

    test('a device that never opted in cannot push audio either', () async {
      await expectLater(
        api.sendAnnouncement(
          audioBytes: <int>[1, 2, 3],
          durationMs: 400,
          targetUserId: 'user-1',
        ),
        throwsA(isA<PolicyException>()),
      );
    });
  });

  group('rule 2 — delivery', () {
    test('a send to an opted-in device chimes and streams the announcement', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      final events = <WsEvent>[];
      final subscription = api.events().listen(events.add);
      await pumpEventQueue();

      final announcement = await api.sendAnnouncement(
        audioBytes: <int>[1, 2, 3],
        durationMs: 400,
        targetUserId: 'user-1',
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(announcement.status, AnnouncementStatus.delivered);
      final frame = events.whereType<IntercomAnnouncementEvent>().single;
      expect(frame.announcementId, announcement.id);
      expect(frame.durationMs, 400);
      expect(frame.broadcast, isFalse);
    });

    test('an offline device is reported MISSED, never silently queued', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      final offlineApi = buildApi()..intercomTargetOnline = false;
      await offlineApi.setIntercomConsent(enabled: true, allowWhileLocked: false);

      final events = <WsEvent>[];
      final subscription = offlineApi.events().listen(events.add);
      await pumpEventQueue();

      final announcement = await offlineApi.sendAnnouncement(
        audioBytes: <int>[1, 2, 3],
        durationMs: 400,
        targetUserId: 'user-3',
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(announcement.status, AnnouncementStatus.missed);
      expect(announcement.deliveredAt, isNull, reason: 'it was never delivered');
      expect(
        events.whereType<IntercomAnnouncementEvent>(),
        isEmpty,
        reason: 'no frame is pushed to an offline device',
      );
      expect(
        events.whereType<IntercomOutcomeEvent>().single.status,
        'MISSED',
      );
    });

    test('the recorded audio can be fetched back for playback', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      final announcement = await api.sendAnnouncement(
        audioBytes: <int>[9, 8, 7],
        durationMs: 400,
        targetUserId: 'user-1',
      );
      final audio = await api.announcementAudio(announcement.id);
      expect(audio, <int>[9, 8, 7]);
    });

    test('an unknown announcement id fails instead of returning silence', () async {
      await expectLater(
        api.announcementAudio('nope'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('rule 3 — the shared log', () {
    test('both views read the same rows', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      final announcement = await api.sendAnnouncement(
        audioBytes: <int>[1],
        durationMs: 400,
        targetUserId: 'user-1',
      );

      final everything = await api.announcements();
      final perUser = await api.announcements(targetUserId: 'user-1');
      expect(everything.length, 1);
      expect(perUser.length, 1);
      expect(perUser.single.id, announcement.id);
      expect(perUser.single, everything.single);
    });

    test('a broadcast appears once per recipient view, not duplicated', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      final announcement = await api.sendAnnouncement(
        audioBytes: <int>[1],
        durationMs: 400,
      );
      expect(announcement.isBroadcast, isTrue);

      final log = await api.announcements();
      expect(log.length, 1, reason: 'one broadcast is one audit entry');
      expect(log.single.targetLabel, 'all opted-in devices');
    });

    test('the playback outcome updates the same row both views read', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      final announcement = await api.sendAnnouncement(
        audioBytes: <int>[1],
        durationMs: 400,
        targetUserId: 'user-1',
      );

      await api.reportAnnouncementOutcome(
        announcementId: announcement.id,
        status: AnnouncementStatus.played,
      );

      final row = (await api.announcements()).single;
      expect(row.status, AnnouncementStatus.played);
      expect(row.playedAt, isNotNull);
    });

    test('a revoked outcome is recorded, not hidden', () async {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: false);
      final announcement = await api.sendAnnouncement(
        audioBytes: <int>[1],
        durationMs: 400,
        targetUserId: 'user-1',
      );
      await api.reportAnnouncementOutcome(
        announcementId: announcement.id,
        status: AnnouncementStatus.revoked,
      );
      expect((await api.announcements()).single.status, AnnouncementStatus.revoked);
    });
  });

  group('kill-switch parity', () {
    test('an engaged kill-switch stops the intercom like everything else', () async {
      await api.setKillSwitch(engaged: true);
      await expectLater(api.intercomRecipients(), throwsA(isA<KillSwitchActiveException>()));
    });
  });

  group('ArmxApi contract', () {
    test('the mock still satisfies the full interface used by the UI', () {
      expect(api, isA<ArmxApi>());
    });
  });
}
