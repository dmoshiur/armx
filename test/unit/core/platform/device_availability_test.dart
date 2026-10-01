// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/platform/device_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final checkedAt = DateTime.utc(2026, 10, 1, 9);

  DeviceStatus status({
    DeviceAvailability microphone = DeviceAvailability.available,
    DeviceAvailability camera = DeviceAvailability.available,
    List<String> inputs = const <String>['Built-in Microphone'],
    List<String> videos = const <String>['FaceTime HD Camera'],
  }) =>
      DeviceStatus(
        microphone: microphone,
        camera: camera,
        inputDevices: inputs,
        videoDevices: videos,
        checkedAt: checkedAt,
      );

  group('DeviceStatus fallback logic', () {
    test('both devices present: nothing degrades', () {
      final result = status();
      expect(result.microphoneUsable, isTrue);
      expect(result.cameraUsable, isTrue);
      expect(result.isDegraded, isFalse);
    });

    test('no microphone: voice is unavailable and the popup must open typed', () {
      final result = status(
        microphone: DeviceAvailability.missing,
        inputs: const <String>[],
      );
      expect(result.microphoneUsable, isFalse);
      expect(result.voiceUnavailable, isTrue);
      expect(result.isDegraded, isFalse, reason: 'the camera still works');
    });

    test('microphone permission refused is not the same as "unplugged"', () {
      final result = status(microphone: DeviceAvailability.permissionDenied);
      expect(result.microphoneUsable, isFalse);
      expect(deviceAvailabilityLabel(result.microphone), 'permission denied');
    });

    test('no camera: face verification degrades, never silently', () {
      final result = status(
        camera: DeviceAvailability.missing,
        videos: const <String>[],
      );
      expect(result.cameraUsable, isFalse);
      expect(result.faceUnavailable, isTrue);
      expect(result.microphoneUsable, isTrue);
    });

    test('camera unsupported on this platform is reported as unsupported', () {
      final result = status(camera: DeviceAvailability.unsupported);
      expect(result.cameraUsable, isFalse);
      expect(deviceAvailabilityLabel(result.camera), 'unsupported');
    });

    test('both missing: the desktop tooltip must say "voice unavailable"', () {
      final result = status(
        microphone: DeviceAvailability.missing,
        camera: DeviceAvailability.missing,
        inputs: const <String>[],
        videos: const <String>[],
      );
      expect(result.isDegraded, isTrue);
    });

    test('unknown is not usable: nothing runs before the first probe', () {
      final result = DeviceStatus.empty(checkedAt);
      expect(result.microphoneUsable, isFalse);
      expect(result.cameraUsable, isFalse);
      expect(deviceAvailabilityLabel(result.microphone), 'unknown');
    });

    test('copyWith keeps the rest of the snapshot', () {
      final result = status().copyWith(microphone: DeviceAvailability.missing);
      expect(result.microphone, DeviceAvailability.missing);
      expect(result.camera, DeviceAvailability.available);
      expect(result.inputDevices, <String>['Built-in Microphone']);
      expect(result.checkedAt, checkedAt);
    });
  });

  group('NoopDeviceAvailabilityService', () {
    test('probes as unknown and never emits changes', () async {
      const service = NoopDeviceAvailabilityService();
      final result = await service.probe();
      expect(result.microphone, DeviceAvailability.unknown);
      expect(result.camera, DeviceAvailability.unknown);
      expect(result.microphoneUsable, isFalse);
      expect(service.changes, isA<Stream<DeviceStatus>>());
      await service.dispose();
    });
  });
}
