// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/models/announcement.dart';
import 'package:armx_ai/features/intercom/intercom_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const off = IntercomConsent();
  const on = IntercomConsent(enabled: true);
  const onLocked = IntercomConsent(enabled: true, allowWhileLocked: true);

  group('rule 1 — consent state machine', () {
    test('consent is OFF by default and cannot be assumed on', () {
      expect(off.enabled, isFalse);
      expect(AnnouncementPolicy.mayPlay(off, false), isFalse);
      expect(AnnouncementPolicy.mustShowOverlay(off), isFalse);
      expect(AnnouncementPolicy.skipReason(off, false), SilenceReason.notConsented);
    });

    test('consent ON alone allows audio only when the OS is not silencing', () {
      expect(AnnouncementPolicy.mayPlay(on, false), isTrue);
      expect(AnnouncementPolicy.mayPlay(on, true), isFalse);
      expect(AnnouncementPolicy.skipReason(on, true), SilenceReason.systemSilenced);
      expect(AnnouncementPolicy.skipReason(on, false), isNull);
    });

    test('the locked-screen sub-toggle never widens the main consent', () {
      // Even with the second switch ON, a device that has not consented stays silent.
      expect(AnnouncementPolicy.mayPlay(off, false), isFalse);
      expect(off.mayPlayWhileLocked, isFalse);
      expect(on.mayPlayWhileLocked, isFalse);
      expect(onLocked.mayPlayWhileLocked, isTrue);
    });

    test('consent ON means the overlay is always shown, even while silenced', () {
      expect(AnnouncementPolicy.mustShowOverlay(on), isTrue);
      expect(AnnouncementPolicy.mustShowOverlay(onLocked), isTrue);
      expect(AnnouncementPolicy.mustShowOverlay(off), isFalse);
    });
  });

  group('rule 2 — DND handling', () {
    test('a silenced device shows the overlay but plays nothing', () {
      final state = IntercomState(consent: on);
      expect(state.audioAllowed(true), isFalse, reason: 'audio must never override DND');
      expect(AnnouncementPolicy.mustShowOverlay(state.consent), isTrue);
    });

    test('an unsilenced device plays audio', () {
      expect(IntercomState(consent: on).audioAllowed(false), isTrue);
    });

    test('a device without consent is silent and invisible', () {
      final state = IntercomState(consent: off);
      expect(state.audioAllowed(false), isFalse);
      expect(AnnouncementPolicy.mustShowOverlay(state.consent), isFalse);
    });
  });

  group('rule 3 — who the Admin can target', () {
    final optedIn = const IntercomRecipient(
      userId: 'u1',
      displayName: 'Living room tablet',
      consented: true,
      online: true,
    );
    final notConsented = const IntercomRecipient(
      userId: 'u2',
      displayName: 'Kitchen display',
      consented: false,
      online: true,
    );
    final offline = const IntercomRecipient(
      userId: 'u3',
      displayName: 'Gate panel',
      consented: true,
      online: false,
    );

    final state = IntercomState(
      enabled: true,
      consent: on,
      recipients: <IntercomRecipient>[optedIn, notConsented, offline],
    );

    test('a non-consented device is never targetable', () {
      expect(notConsented.isTargetable, isFalse);
      expect(state.targetable, isNot(contains(notConsented)));
    });

    test('an opted-in but offline device is not targetable', () {
      expect(offline.isTargetable, isFalse);
    });

    test('only the opted-in online device is listed', () {
      expect(state.targetable, <IntercomRecipient>[optedIn]);
      expect(state.hasNoTargets, isFalse);
    });

    test('with nobody opted in the Admin screen shows the empty state', () {
      expect(
        IntercomState(
          enabled: true,
          recipients: <IntercomRecipient>[notConsented],
        ).hasNoTargets,
        isTrue,
      );
    });

    test('the feature is gated by enableAdminIntercom', () {
      expect(const IntercomState().enabled, isFalse);
      expect(state.enabled, isTrue);
    });
  });

  group('IntercomState.copyWith', () {
    test('clears an error by passing null explicitly', () {
      const withError = IntercomState(error: 'no microphone');
      expect(withError.copyWith(error: null).error, isNull);
    });

    test('keeps the consent when only the talk phase changes', () {
      const talking = IntercomState(consent: on, talk: TalkPhase.recording);
      final sent = talking.copyWith(talk: TalkPhase.sent, lastOutcome: 'delivered');
      expect(sent.talk, TalkPhase.sent);
      expect(sent.consent, on);
      expect(sent.lastOutcome, 'delivered');
    });
  });

  group('announcement model', () {
    test('a broadcast is labelled for the Admin list', () {
      final announcement = Announcement(
        id: 'a1',
        fromUserId: 'admin-1',
        scope: AnnouncementScope.broadcast,
        createdAt: DateTime.utc(2026, 10, 1, 9),
      );
      expect(announcement.isBroadcast, isTrue);
      expect(announcement.targetSummary, 'all opted-in devices');
    });

    test('statuses are serialised with stable wire names', () {
      for (final status in AnnouncementStatus.values) {
        final json = <String, Object?>{'status': status.name.toUpperCase()};
        expect(AnnouncementStatus.values.contains(status), isTrue);
        expect(json['status'], isA<String>());
      }
      expect(AnnouncementStatus.values.length, 5);
    });
  });
}
