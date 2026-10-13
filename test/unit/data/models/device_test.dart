// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/models/device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceKind', () {
    test('parses the kinds the backend sends', () {
      expect(DeviceKind.fromWire('light'), DeviceKind.light);
      expect(DeviceKind.fromWire('CAMERA'), DeviceKind.camera);
      expect(DeviceKind.fromWire('lock'), DeviceKind.lock);
    });

    test('an unknown kind is `other` rather than a guess at something controllable', () {
      expect(DeviceKind.fromWire('kettle'), DeviceKind.other);
      expect(DeviceKind.fromWire(null), DeviceKind.other);
      expect(DeviceKind.other.isControllable, isFalse);
    });

    test('a sensor is read-only; everything else with a level can be switched', () {
      expect(DeviceKind.sensor.isReadOnly, isTrue);
      expect(DeviceKind.light.isReadOnly, isFalse);
      expect(DeviceKind.camera.isControllable, isFalse);
      expect(DeviceKind.light.isControllable, isTrue);
    });
  });

  group('ArmxDevice', () {
    test('parses the state the UI draws', () {
      final ArmxDevice device = ArmxDevice.fromJson(const <String, Object?>{
        'id': 'lamp-1',
        'name': 'Living room lamp',
        'kind': 'light',
        'room_id': 'living',
        'online': true,
        'level': true,
        'brightness': 70,
        'controllable_by_current_user': true,
      });
      expect(device.id, 'lamp-1');
      expect(device.kind, DeviceKind.light);
      expect(device.online, isTrue);
      expect(device.isActive, isTrue);
      expect(device.brightness, 70);
      expect(device.controllableByCurrentUser, isTrue);
    });

    test('a device the user may not control says so, and the UI disables rather than hides',
        () {
      final ArmxDevice device = ArmxDevice.fromJson(const <String, Object?>{
        'id': 'lock-1',
        'name': 'Front door',
        'kind': 'lock',
        'online': true,
        'controllable_by_current_user': false,
      });
      expect(device.controllableByCurrentUser, isFalse);
    });

    test('an unknown device is offline, not optimistically online', () {
      final ArmxDevice device = ArmxDevice.fromJson(const <String, Object?>{
        'id': 'x',
        'name': 'X',
        'kind': 'plug',
      });
      expect(device.online, isFalse);
      expect(device.isActive, isFalse);
    });
  });

  group('SensorReading', () {
    test('renders value and unit together', () {
      const SensorReading reading = SensorReading(
        metric: 'temperature',
        value: 27.5,
        unit: '°C',
      );
      expect(reading.display, '27.5 °C');
    });

    test('a unitless reading does not gain a trailing space', () {
      const SensorReading reading = SensorReading(
        metric: 'motion',
        value: 1,
        unit: '',
      );
      expect(reading.display.trim(), reading.display);
      expect(reading.display, '1');
    });
  });

  group('DeviceCommandResult', () {
    test('a pending result is not an accepted one', () {
      // The distinction the whole "never fake success" rule rests on.
      const DeviceCommandResult result = DeviceCommandResult(
        deviceId: 'lock-1',
        command: 'lock',
        accepted: true,
        pending: true,
        message: 'Waiting for the device to confirm',
      );
      expect(result.pending, isTrue);
      expect(result.state, isNull);
    });
  });
}
