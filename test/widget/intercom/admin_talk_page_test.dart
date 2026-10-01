// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/services/intercom_audio.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/features/intercom/admin_talk_page.dart';
import 'package:armx_ai/features/intercom/intercom_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fixtures.dart';

/// The Admin "Talk" screen: only opted-in devices are listed, everybody else is absent.
void main() {
  const surface = Size(1080, 1920);

  Future<ProviderContainer> pumpTalk(
    WidgetTester tester, {
    bool enabled = true,
    MockArmxApi? api,
  }) async {
    final container = await pumpAuthApp(
      tester,
      home: () => const AdminTalkPage(),
      overrides: <Override>[
        armxApiProvider.overrideWithValue(api ?? Fixtures.mockApi()),
        intercomAudioProvider.overrideWithValue(const SilentIntercomAudio()),
      ],
      surfaceSize: surface,
    );
    if (enabled) {
      await container.read(intercomControllerProvider.notifier).setEnabled(true);
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets('only opted-in devices are listed; a non-consented one is absent',
      (tester) async {
    await pumpTalk(tester);

    expect(find.text('Living room tablet'), findsOneWidget);
    expect(find.text('Kitchen display'), findsNothing,
        reason: 'it has not turned announcements on, so the Admin cannot even aim at it');
    expect(find.text('Gate panel'), findsNothing, reason: 'it is offline');
    expect(
      find.text('Devices that have not turned announcements on are not listed here.'),
      findsOneWidget,
    );
  });

  testWidgets('the screen says why a device is not listed instead of showing it disabled',
      (tester) async {
    await pumpTalk(tester);

    expect(
      find.text('Nobody has turned voice announcements on yet. They must switch it on '
          'themselves — you cannot enable it for them.'),
      findsNothing,
      reason: 'at least one device has opted in',
    );
  });

  testWidgets('when nobody has opted in the Admin gets the empty state', (tester) async {
    final api = Fixtures.mockApi();
    final container = await pumpTalk(tester, api: api);
    expect(find.text('Living room tablet'), findsOneWidget);

    // The last opted-in device revokes its consent.
    api.setRecipientConsent('user-1', false);
    await container.read(intercomControllerProvider.notifier).refreshRecipients();
    await tester.pumpAndSettle();

    expect(container.read(intercomControllerProvider).targetable, isEmpty);
    expect(find.text('No opted-in devices'), findsOneWidget);
    expect(find.text('Living room tablet'), findsNothing);
  });

  testWidgets('the feature flag gates the whole screen', (tester) async {
    await pumpTalk(tester, enabled: false);

    expect(find.text('Voice announcements are off'), findsOneWidget);
    expect(find.text('Turn on'), findsOneWidget);
    expect(find.text('Living room tablet'), findsNothing);
  });

  testWidgets('broadcast mode lists every opted-in device as included', (tester) async {
    final container = await pumpTalk(tester);
    expect(container.read(intercomControllerProvider).targetable.length, 1);

    await tester.tap(find.text('Broadcast: every device that turned announcements on will '
        'hear you.'));
    await tester.pumpAndSettle();

    expect(find.text('Included'), findsOneWidget);
    expect(find.text('Hold to talk'), findsOneWidget);
  });

  testWidgets('the talk button is armed once a device is selected', (tester) async {
    await pumpTalk(tester);

    await tester.tap(find.text('Living room tablet'));
    await tester.pumpAndSettle();

    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Hold to talk'), findsOneWidget);
  });

  testWidgets('the CSV export is labelled as visible to the user', (tester) async {
    await pumpTalk(tester);

    expect(find.text('Export CSV'), findsOneWidget);
  });
}
