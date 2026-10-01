// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/data/models/chat.dart';
import 'package:armx_ai/features/chat/chat_controller.dart';
import 'package:armx_ai/features/voice/voice_controller.dart';
import 'package:armx_ai/features/voice/voice_engines.dart';
import 'package:armx_ai/features/voice/voice_state.dart';
import 'package:armx_ai/features/voice/wake_word.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';
import '../../../support/test_harness.dart';

/// Speech engine whose transcript and level the test controls frame by frame.
class _ManualStt implements SpeechToTextEngine {
  void Function(String words, bool isFinal)? _result;
  void Function(double level)? _level;

  @override
  String get engineId => 'manual';

  @override
  bool get isAvailable => true;

  @override
  bool get isSimulated => false;

  @override
  Future<bool> initialize({
    required String localeCode,
    void Function(String code)? onError,
  }) async =>
      true;

  @override
  Future<void> startListening({
    required String localeCode,
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
  }) async {
    _result = onResult;
    _level = onLevel;
  }

  void emit(String words, {bool isFinal = false}) {
    _result?.call(words, isFinal);
    _level?.call(0.42);
  }

  @override
  Future<String> stopListening() async => 'turn the lights on';

  @override
  Future<void> cancelListening() async {
    _result = null;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  late _ManualStt stt;
  late SimulatedSpeechSynthesisEngine tts;
  late StubWakeWordAdapter wakeWord;

  setUp(() {
    stt = _ManualStt();
    tts = SimulatedSpeechSynthesisEngine(wordsPerMinute: 6000);
    wakeWord = StubWakeWordAdapter();
  });

  ProviderContainer containerWith({
    StubWakeWordAdapter? adapter,
    List<Override> extra = const <Override>[],
  }) {
    final container = ProviderContainer(
      overrides: <Override>[
        ...testOverrides(),
        armxApiProvider.overrideWithValue(
          Fixtures.mockApi(control: MockBackendControl(latency: Duration.zero)),
        ),
        speechToTextEngineProvider.overrideWithValue(stt),
        speechSynthesisEngineProvider.overrideWithValue(tts),
        wakeWordAdapterProvider.overrideWithValue(adapter ?? wakeWord),
        ...extra,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('refuses push-to-talk while the microphone switch is off', () async {
    final container = containerWith();
    final controller = container.read(voiceControllerProvider.notifier);

    final started = await controller.startPushToTalk();

    expect(started, isFalse);
    expect(container.read(voiceControllerProvider).errorCode, 'microphone_switch_off');
    expect(container.read(voiceControllerProvider).phase, VoicePhase.error);
  });

  test('push-to-talk streams the partial transcript and keeps the final one', () async {
    final container = containerWith();
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.setMicrophoneEnabled(true);

    expect(await controller.startPushToTalk(), isTrue);
    expect(container.read(voiceControllerProvider).phase, VoicePhase.listening);

    stt.emit('turn the');
    expect(container.read(voiceControllerProvider).displayTranscript, 'turn the');
    expect(container.read(voiceControllerProvider).level, closeTo(0.42, 0.001));

    final text = await controller.stopPushToTalk();

    expect(text, 'turn the lights on');
    final state = container.read(voiceControllerProvider);
    expect(state.phase, VoicePhase.idle);
    expect(state.transcript, 'turn the lights on');
    expect(state.partialTranscript, isEmpty);
    expect(state.isCapturing, isFalse);
  });

  test('push-to-talk with sendToAssistant lands in the transcript as a user message',
      () async {
    final container = containerWith();
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.setMicrophoneEnabled(true);
    await controller.startPushToTalk();

    await controller.stopPushToTalk(sendToAssistant: true);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final messages = container.read(chatControllerProvider).messages;
    expect(messages.where((message) => message.role == ChatRole.user), isNotEmpty);
    expect(
      messages.firstWhere((message) => message.role == ChatRole.user).text,
      'turn the lights on',
    );
  });

  test('wake-word mode refuses platforms without a background listener', () async {
    final container = containerWith();
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.setMicrophoneEnabled(true);

    final armed = await controller.setWakeWordEnabled(true);

    expect(armed, isFalse);
    final state = container.read(voiceControllerProvider);
    expect(state.wakeWordEnabled, isFalse);
    expect(state.errorCode, 'background_listening_unsupported');
  });

  test('wake-word mode requires the microphone switch first', () async {
    final container = containerWith(adapter: StubWakeWordAdapter(supported: true));
    final controller = container.read(voiceControllerProvider.notifier);

    expect(await controller.setWakeWordEnabled(true), isFalse);
    expect(container.read(voiceControllerProvider).errorCode, 'microphone_switch_off');
  });

  test('an armed stub detector can be simulated into a capture', () async {
    final container = containerWith(adapter: StubWakeWordAdapter(supported: true));
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.setMicrophoneEnabled(true);
    expect(await controller.setWakeWordEnabled(true), isTrue);

    controller.simulateWakeWord();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(voiceControllerProvider);
    expect(state.isCapturing, isTrue);
    expect(state.mode, VoiceInputMode.wakeWord);

    await controller.stopPushToTalk(sendToAssistant: true);
    expect(container.read(voiceControllerProvider).mode, VoiceInputMode.wakeWord);
  });

  test('text-to-speech announces a reply and returns to idle', () async {
    final container = containerWith();
    final controller = container.read(voiceControllerProvider.notifier);

    await controller.speak('Good evening, Mohi.');

    expect(tts.spoken, contains('Good evening, Mohi.'));
    expect(container.read(voiceControllerProvider).phase, VoicePhase.idle);
    expect(container.read(voiceControllerProvider).lastSpoken, 'Good evening, Mohi.');
  });

  test('disabling the microphone cancels a running capture', () async {
    final container = containerWith();
    final controller = container.read(voiceControllerProvider.notifier);
    await controller.setMicrophoneEnabled(true);
    await controller.startPushToTalk();

    await controller.setMicrophoneEnabled(false);

    final state = container.read(voiceControllerProvider);
    expect(state.microphoneEnabled, isFalse);
    expect(state.isCapturing, isFalse);
    expect(state.wakeWordEnabled, isFalse);
  });
}
