// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/services/intercom_audio.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/models/announcement.dart';
import 'package:armx_ai/features/intercom/intercom_activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fixtures.dart';

/// Rule 3 on screen: the user's own Activity screen shows exactly what the Admin panel
/// shows about them, and nothing they cannot see themselves.
void main() {
  const surface = Size(1080, 1920);

  Future<ProviderContainer> pumpActivity(
    WidgetTester tester, {
    bool adminView = false,
  }) =>
      pumpAuthApp(
        tester,
        home: () => IntercomActivityPage(adminView: adminView),
        overrides: <Override>[
          armxApiProvider.overrideWithValue(Fixtures.mockApi()),
          intercomAudioProvider.overrideWithValue(const SilentIntercomAudio()),
        ],
        surfaceSize: surface,
      );

  testWidgets('an empty log explains itself', (tester) async {
    await pumpActivity(tester);

    expect(find.text('No announcements yet'), findsOneWidget);
    expect(find.text('Announcements you receive or send will appear here.'), findsOneWidget);
  });

  testWidgets('the user view and the admin view read the same rows', (tester) async {
    final container = await pumpActivity(tester);

    final api = container.read(armxApiProvider);
    await api.setIntercomConsent(enabled: true, allowWhileLocked: true);
    final sent = await api.sendAnnouncement(
      audioBytes: <int>[1, 2, 3],
      durationMs: 400,
      targetUserId: 'user-1',
    );

    // The device receives its own announcement: it must land in its own log.
    await container.read(intercomControllerProvider.notifier).refreshLog();
    await tester.pumpAndSettle();

    expect(find.text('Admin → Living room tablet'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(sent.id, isNotEmpty);
  });

  testWidgets('the admin view carries the "visible to this user" export label',
      (tester) async {
    await pumpActivity(tester, adminView: true);

    expect(find.textContaining('Visible to this user in their own Activity screen'),
        findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('the user view has no export button — it is the same data, read-only',
      (tester) async {
    await pumpActivity(tester);

    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('a missed announcement is shown, never silently dropped', (tester) async {
    final container = await pumpActivity(tester);

    final repository = container.read(announcementRepositoryProvider);
    await repository.save(Announcement(
      id: 'missed-1',
      fromUserId: 'admin-1',
      fromName: 'Admin',
      targetUserId: 'self',
      targetLabel: 'this device',
      durationMs: 400,
      status: AnnouncementStatus.missed,
      createdAt: DateTime.utc(2026, 10, 1, 9),
    ));
    await container.read(intercomControllerProvider.notifier).refreshLog();
    await tester.pumpAndSettle();

    expect(find.text('Missed (offline)'), findsOneWidget);
  });
}
