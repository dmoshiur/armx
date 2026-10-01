// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/services/intercom_audio.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/models/announcement.dart';
import 'package:armx_ai/features/intercom/announcement_overlay.dart';
import 'package:armx_ai/features/intercom/intercom_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/auth_test_harness.dart';
import '../../support/fixtures.dart';

/// Recorder/player stand-in so the overlay rules are tested without audio hardware.
///
/// [playFile] waits on a gate, which lets a test inspect the overlay *while* the
/// announcement is still playing instead of after it has auto-dismissed.
class _FakeIntercomAudio implements IntercomAudio {
  final StreamController<double> _amplitude = StreamController<double>.broadcast();
  final Completer<void> playbackGate = Completer<void>();

  int chimes = 0;
  int plays = 0;
  int stops = 0;
  String? playedPath;

  @override
  Future<bool> get hasMicrophone async => true;

  @override
  Future<void> startRecording() async {}

  @override
  Future<IntercomClip> stopRecording() async => IntercomClip.empty;

  @override
  Future<void> cancelRecording() async {}

  @override
  Stream<double> get amplitude => _amplitude.stream;

  @override
  Future<void> playChime() async => chimes++;

  @override
  Future<void> playFile(String path) async {
    plays++;
    playedPath = path;
    await playbackGate.future;
  }

  @override
  Future<void> stopPlayback() async {
    stops++;
    if (!playbackGate.isCompleted) {
      playbackGate.complete();
    }
  }

  @override
  Future<void> dispose() async => _amplitude.close();
}

void main() {
  const surface = Size(1080, 1920);

  /// Opts in, then makes the Admin speak, and leaves the announcement playing.
  Future<(ProviderContainer, _FakeIntercomAudio, MockArmxApi)> speak(
    WidgetTester tester, {
    bool consented = true,
  }) async {
    final api = Fixtures.mockApi();
    final audio = _FakeIntercomAudio();
    final container = await pumpAuthApp(
      tester,
      home: () => const AnnouncementOverlayHost(),
      overrides: <Override>[
        armxApiProvider.overrideWithValue(api),
        intercomAudioProvider.overrideWithValue(audio),
      ],
      surfaceSize: surface,
    );
    if (consented) {
      await api.setIntercomConsent(enabled: true, allowWhileLocked: true);
      await tester.pumpAndSettle();
    }
    await api.sendAnnouncement(
      audioBytes: <int>[1, 2, 3],
      durationMs: 400,
      targetUserId: 'user-1',
    );
    await tester.pumpAndSettle();
    return (container, audio, api);
  }

  testWidgets('an opted-in device chimes, shows who is speaking and plays the audio',
      (tester) async {
    final (_, audio, _) = await speak(tester);

    expect(audio.chimes, greaterThan(0), reason: 'rule 2: the chime always comes first');
    expect(audio.plays, greaterThan(0), reason: 'rule 2: the audio plays out loud');
    expect(audio.playedPath, isNotNull, reason: 'the downloaded clip is cached and played');
    expect(find.text('Admin is speaking'), findsOneWidget);
    expect(find.text('Speaking…'), findsOneWidget);
    expect(find.byType(AnnouncementOverlay), findsOneWidget);
    expect(find.text('Voice announcement from A.R.M.X Admin'), findsOneWidget);
  });

  testWidgets('a device that has not consented shows and plays nothing', (tester) async {
    final (_, audio, _) = await speak(tester, consented: false);

    expect(find.byType(AnnouncementOverlay), findsNothing);
    expect(audio.chimes, 0);
    expect(audio.plays, 0);
  });

  testWidgets('the overlay is hidden while the feature flag is off', (tester) async {
    final container = await pumpAuthApp(
      tester,
      home: () => const AnnouncementOverlayHost(),
      overrides: <Override>[
        armxApiProvider.overrideWithValue(Fixtures.mockApi()),
        intercomAudioProvider.overrideWithValue(_FakeIntercomAudio()),
      ],
      surfaceSize: surface,
    );

    expect(container.read(intercomControllerProvider).enabled, isFalse);
    expect(find.byType(AnnouncementOverlay), findsNothing);
  });

  testWidgets('Mute this once stops the audio but keeps the notice and the log entry',
      (tester) async {
    final (container, audio, _) = await speak(tester);

    await tester.tap(find.text('Mute this once'));
    await tester.pumpAndSettle();

    expect(audio.stops, greaterThan(0));
    expect(container.read(intercomControllerProvider).overlay, OverlayPhase.mutedOnce);
    expect(
      container.read(intercomControllerProvider).log,
      isNotEmpty,
      reason: 'muting an announcement is not deleting it from the shared log',
    );
    expect(find.text('Mute this once'), findsOneWidget);
  });

  testWidgets('Turn off announcements revokes consent immediately, from the overlay',
      (tester) async {
    final (container, audio, _) = await speak(tester);

    await tester.tap(find.text('Turn off announcements'));
    await tester.pumpAndSettle();

    expect(container.read(intercomControllerProvider).consent.enabled, isFalse);
    expect(container.read(intercomControllerProvider).overlay, OverlayPhase.hidden);
    expect(find.byType(AnnouncementOverlay), findsNothing);
  });

  testWidgets('after playback the overlay auto-dismisses and the log says PLAYED',
      (tester) async {
    final (container, audio, _) = await speak(tester);
    expect(find.byType(AnnouncementOverlay), findsOneWidget);

    // Release the playback gate the way the player would when the clip ends.
    await tester.runAsync(() async {
      audio.playbackGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();

    expect(container.read(intercomControllerProvider).overlay, OverlayPhase.done);
    expect(find.byType(AnnouncementOverlay), findsNothing);
    expect(
      container.read(intercomControllerProvider).log.single.status.name,
      'played',
    );
  });
}
