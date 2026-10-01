// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/services/intercom_audio.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/features/intercom/intercom_consent_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fixtures.dart';

/// Rule 1 on screen: OFF by default, turned on by the person holding the device, and
/// revocable instantly from the same screen.
void main() {
  const surface = Size(1080, 1920);

  Future<ProviderContainer> pumpConsent(
    WidgetTester tester, {
    MockArmxApi? api,
  }) =>
      pumpAuthApp(
        tester,
        home: () => const IntercomConsentPage(),
        overrides: <Override>[
          armxApiProvider.overrideWithValue(api ?? Fixtures.mockApi()),
          intercomAudioProvider.overrideWithValue(const SilentIntercomAudio()),
        ],
        surfaceSize: surface,
      );

  testWidgets('the switch is OFF by default and explains what enabling it does',
      (tester) async {
    await pumpConsent(tester);

    expect(find.text('Allow voice announcements from Admin/Owner'), findsOneWidget);
    expect(
      find.textContaining('Nobody — including the Admin — can turn this on for you'),
      findsOneWidget,
    );

    // The main switch is off, so the locked-screen sub-toggle is disabled.
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.first.value, isFalse, reason: 'main consent starts OFF');
    expect(switches.last.onChanged, isNull, reason: 'locked playback stays OFF too');
    expect(find.text('Turn on announcements'), findsOneWidget);
  });

  testWidgets('turning it on is local, instant and enables the sub-toggle', (tester) async {
    final api = Fixtures.mockApi();
    final container = await pumpConsent(tester, api: api);

    await tester.tap(find.text('Turn on announcements'));
    await tester.pumpAndSettle();

    expect(container.read(intercomControllerProvider).consent.enabled, isTrue);
    expect(find.text('Turn off announcements'), findsOneWidget);

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches.first.value, isTrue);
    expect(switches.last.onChanged, isNotNull);
  });

  testWidgets('the sub-toggle stays OFF until it is explicitly allowed', (tester) async {
    final container = await pumpConsent(tester);

    await tester.tap(find.text('Turn on announcements'));
    await tester.pumpAndSettle();
    expect(container.read(intercomControllerProvider).consent.allowWhileLocked, isFalse);

    // The sub-toggle is a disabled-looking Switch; enable it directly.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(container.read(intercomControllerProvider).consent.allowWhileLocked, isTrue);

    // Turning the main switch off drops the sub-permission with it.
    await tester.tap(find.text('Turn off announcements'));
    await tester.pumpAndSettle();
    expect(container.read(intercomControllerProvider).consent.enabled, isFalse);
    expect(container.read(intercomControllerProvider).consent.allowWhileLocked, isFalse);
  });

  testWidgets('the three rules are stated on the consent screen', (tester) async {
    await pumpConsent(tester);

    expect(
      find.textContaining('Off until you turn it on'),
      findsOneWidget,
    );
    expect(find.textContaining('Always audible and visible'), findsOneWidget);
    expect(find.textContaining('you see too in My Activity'), findsOneWidget);
    expect(find.textContaining('needs no approval'), findsOneWidget);
  });
}
