// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/widgets/armx_orb.dart';
import 'package:armx_ai/features/voice/voice_controller.dart';
import 'package:armx_ai/features/voice/voice_engines.dart';
import 'package:armx_ai/features/voice/voice_page.dart';
import 'package:armx_ai/features/voice/wake_word.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/test_harness.dart';

/// The voice screen: privacy gates, honesty labels and the push-to-talk entry point.
void main() {
  const surface = Size(1080, 2600);

  Future<ProviderContainer> pumpVoice(WidgetTester tester) async {
    return pumpArmxWidget(
      tester,
      const VoicePage(),
      overrides: <Override>[
        speechToTextEngineProvider.overrideWithValue(SimulatedSpeechToTextEngine()),
        speechSynthesisEngineProvider
            .overrideWithValue(SimulatedSpeechSynthesisEngine(wordsPerMinute: 6000)),
        wakeWordAdapterProvider.overrideWithValue(StubWakeWordAdapter()),
      ],
      surfaceSize: surface,
    );
  }

  testWidgets('starts with the microphone off and says so', (tester) async {
    await pumpVoice(tester);
    final l10n = l10nOf(tester, find.byType(VoicePage));

    expect(find.text(l10n.voiceTitle), findsOneWidget);
    expect(find.text(l10n.voiceMicOffNotice), findsOneWidget);
    // Both l10n strings exist in the ARB, so this also guards the EN/BN parity rule.
    expect(l10n.voiceWakeWordStubNotice, isNotEmpty);
    expect(find.byType(ArmxOrb), findsOneWidget);
  });

  testWidgets('tapping the orb without the microphone shows the localized refusal',
      (tester) async {
    await pumpVoice(tester);
    final l10n = l10nOf(tester, find.byType(VoicePage));

    await tester.tap(find.byType(ArmxOrb));
    await tester.pump();

    expect(find.text(l10n.voiceErrorMicOff), findsOneWidget);
  });

  testWidgets('engine rows name the engines and their honest status', (tester) async {
    await pumpVoice(tester);
    final l10n = l10nOf(tester, find.byType(VoicePage));

    expect(find.text(l10n.voiceEngineStt), findsOneWidget);
    expect(find.text(l10n.voiceEngineTts), findsOneWidget);
    expect(find.text(l10n.voiceEngineWakeWord), findsOneWidget);
    // The simulated STT/TTS pair reports "simulated"; the wake-word stub reports unavailable.
    expect(find.text(l10n.voiceEngineSimulated), findsNWidgets(2));
    expect(find.text(l10n.voiceEngineUnavailable), findsOneWidget);
  });

  testWidgets('surfaces the voice-only-never-verifies notice', (tester) async {
    await pumpVoice(tester);
    final l10n = l10nOf(tester, find.byType(VoicePage));
    expect(find.text(l10n.voiceVerifyHint), findsOneWidget);
  });
}
