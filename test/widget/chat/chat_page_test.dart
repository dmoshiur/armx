// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/widgets/armx_controls.dart';
import 'package:armx_ai/core/widgets/armx_orb.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/features/chat/chat_page.dart';
import 'package:armx_ai/features/chat/widgets/chat_composer.dart';
import 'package:armx_ai/features/chat/widgets/tool_approval_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fixtures.dart';

/// The chat tab end to end: empty state, streaming, tool approval cards
/// (MEDIUM + HIGH), denial and the kill-switch banner.
void main() {
  const surface = Size(1080, 1920);

  MockArmxApi apiWithZeroLatency() => Fixtures.mockApi(
        control: MockBackendControl(
          latency: Duration.zero,
          tokenInterval: Duration.zero,
          toolCallDelay: Duration.zero,
        ),
      );

  Future<void> pumpChat(
    WidgetTester tester, {
    required MockArmxApi api,
    Locale locale = const Locale('en'),
  }) =>
      pumpAuthApp(
        tester,
        home: () => const ChatPage(),
        overrides: <Override>[armxApiProvider.overrideWithValue(api)],
        locale: locale,
        surfaceSize: surface,
      );

  testWidgets('the empty transcript shows the orb, the pitch and the prompts',
      (tester) async {
    final api = apiWithZeroLatency();
    addTearDown(api.dispose);
    await pumpChat(tester, api: api);
    final l10n = l10nOf(tester, find.byType(ChatPage));

    expect(find.byType(ArmxOrb), findsOneWidget);
    expect(find.text(l10n.chatEmptyTitle), findsOneWidget);
    expect(find.text(l10n.chatSuggestionLight), findsOneWidget);
    expect(find.text(l10n.chatSuggestionUnlock), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
    expect(find.text(l10n.chatStatusLive), findsOneWidget);
  });

  testWidgets('a suggestion streams a reply and raises the MEDIUM approval card',
      (tester) async {
    final api = apiWithZeroLatency();
    addTearDown(api.dispose);
    await pumpChat(tester, api: api);
    final l10n = l10nOf(tester, find.byType(ChatPage));

    await tester.tap(find.text(l10n.chatSuggestionLight));
    await tester.pump();
    expect(find.text('turn on the living room light'), findsOneWidget);

    // Tokens stream, the reply finalises and the tool request follows.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('Switching the living room lights'), findsOneWidget);

    final card = find.byType(ToolApprovalCard);
    expect(card, findsOneWidget);
    expect(find.widgetWithText(ArmxButton, l10n.commonApprove), findsOneWidget);
    expect(find.widgetWithText(ArmxButton, l10n.commonDeny), findsOneWidget);
    expect(find.textContaining('armx/home/dev-living-light/cmd'), findsOneWidget);
    expect(find.text(l10n.chatVerificationNeeded), findsOneWidget);

    // Approving runs the (simulated) verification and then the tool.
    await tester.tap(find.widgetWithText(ArmxButton, l10n.commonApprove));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('mqtt.publish executed'), findsOneWidget);
    expect(find.widgetWithText(ArmxButton, l10n.commonApprove), findsNothing);
  });

  testWidgets('denying a MEDIUM call closes the card as denied', (tester) async {
    final api = apiWithZeroLatency();
    addTearDown(api.dispose);
    await pumpChat(tester, api: api);
    final l10n = l10nOf(tester, find.byType(ChatPage));

    await tester.tap(find.text(l10n.chatSuggestionLight));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.widgetWithText(ArmxButton, l10n.commonDeny));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(l10n.chatToolDenied), findsOneWidget);
    expect(find.widgetWithText(ArmxButton, l10n.commonApprove), findsNothing);
  });

  testWidgets('a HIGH call approves with the owner_verified assertion',
      (tester) async {
    final api = apiWithZeroLatency();
    addTearDown(api.dispose);
    await pumpChat(tester, api: api);
    final l10n = l10nOf(tester, find.byType(ChatPage));

    await tester.tap(find.text(l10n.chatSuggestionUnlock));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(ToolApprovalCard), findsOneWidget);
    expect(find.text('system.unlock'), findsOneWidget);

    await tester.tap(find.widgetWithText(ArmxButton, l10n.commonApprove));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('system.unlock executed'), findsOneWidget);
  });

  testWidgets('a LOW call runs without a card and lands as a tool line',
      (tester) async {
    final api = apiWithZeroLatency();
    addTearDown(api.dispose);
    await pumpChat(tester, api: api);
    final l10n = l10nOf(tester, find.byType(ChatPage));

    await tester.enterText(find.byType(ArmxTextField), 'give me a status snapshot');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(ToolApprovalCard), findsNothing);
    expect(find.textContaining('devices.list executed'), findsOneWidget);
  });

  testWidgets('the kill-switch banner blocks the composer', (tester) async {
    final api = apiWithZeroLatency();
    addTearDown(api.dispose);
    final container = await pumpChat(tester, api: api);
    final l10n = l10nOf(tester, find.byType(ChatPage));

    await (container.read(armxApiProvider) as MockArmxApi).setKillSwitch(engaged: true);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(l10n.errorKillSwitchTitle), findsOneWidget);
    expect(find.text(l10n.statusKilled), findsOneWidget);
    expect(tester.widget<ArmxTextField>(find.byType(ArmxTextField)).enabled, isFalse);
  });

  testWidgets('the transcript renders localized in Bengali', (tester) async {
    final api = apiWithZeroLatency();
    addTearDown(api.dispose);
    await pumpChat(tester, api: api, locale: const Locale('bn'));
    final l10n = l10nOf(tester, find.byType(ChatPage));

    expect(find.text(l10n.chatEmptyTitle), findsOneWidget);
    expect(find.text(l10n.chatSuggestionLight), findsOneWidget);
    expect(find.text(l10n.chatComposerHint), findsOneWidget);
    expect(l10n.chatTitle, isNot('Assistant'));
  });
}
