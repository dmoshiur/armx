// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/models/alarm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArmxAlarm', () {
    ArmxAlarm alarm({
      int hour = 6,
      int minute = 5,
      List<AlarmTarget> targets = const <AlarmTarget>[],
    }) =>
        ArmxAlarm(
          id: 'a-1',
          label: 'Wake up',
          hour: hour,
          minute: minute,
          enabled: true,
          repeat: AlarmRepeat.weekdays,
          targets: targets,
        );

    test('the time is labelled in 24-hour form, zero-padded', () {
      expect(alarm(hour: 6, minute: 5).timeLabel, '06:05');
      expect(alarm(hour: 23, minute: 59).timeLabel, '23:59');
      expect(alarm(hour: 0, minute: 0).timeLabel, '00:00');
    });

    test('an alarm rings if any of its targets is ringing — cross-device status', () {
      const AlarmTarget ringing = AlarmTarget(
        deviceId: 'phone-1',
        kind: AlarmTargetKind.phone,
        label: 'My phone',
        ringing: true,
        acknowledged: false,
        reachable: true,
      );
      const AlarmTarget quiet = AlarmTarget(
        deviceId: 'pc-1',
        kind: AlarmTargetKind.computer,
        label: 'Study computer',
      );
      expect(alarm(targets: <AlarmTarget>[quiet, ringing]).isRinging, isTrue);
      expect(alarm(targets: <AlarmTarget>[quiet]).isRinging, isFalse);
    });

    test('unreachable targets are reported so the user knows one device missed it', () {
      const AlarmTarget away = AlarmTarget(
        deviceId: 'watch-1',
        kind: AlarmTargetKind.watch,
        label: 'Watch',
        reachable: false,
      );
      expect(alarm(targets: <AlarmTarget>[away]).unreachableTargets, hasLength(1));
    });

    test('parses from the wire, including the target list', () {
      final ArmxAlarm parsed = ArmxAlarm.fromJson(const <String, Object?>{
        'id': 'a-2',
        'label': 'Office',
        'hour': 7,
        'minute': 30,
        'enabled': false,
        'repeat': 'daily',
        'targets': <Object?>[
          <String, Object?>{
            'device_id': 'phone-1',
            'kind': 'phone',
            'label': 'My phone',
            'ringing': true,
          },
        ],
      });
      expect(parsed.hour, 7);
      expect(parsed.minute, 30);
      expect(parsed.enabled, isFalse);
      expect(parsed.repeat, AlarmRepeat.daily);
      expect(parsed.targets.single.deviceId, 'phone-1');
      expect(parsed.targets.single.ringing, isTrue);
      expect(parsed.isRinging, isTrue);
    });

    test('an out-of-range hour from the wire cannot produce a nonsense clock', () {
      final ArmxAlarm parsed = ArmxAlarm.fromJson(const <String, Object?>{
        'id': 'a-3',
        'label': 'Bad',
        'hour': 99,
        'minute': 99,
      });
      expect(parsed.hour, inInclusiveRange(0, 23));
      expect(parsed.minute, inInclusiveRange(0, 59));
    });
  });

  group('AlarmRepeat', () {
    test('round-trips through its wire value', () {
      for (final AlarmRepeat repeat in AlarmRepeat.values) {
        expect(AlarmRepeat.fromWire(repeat.wire), repeat);
      }
    });

    test('an unknown repeat becomes the safest option: one-off, not every day', () {
      expect(AlarmRepeat.fromWire('fortnightly'), AlarmRepeat.once);
      expect(AlarmRepeat.fromWire(null), AlarmRepeat.once);
    });

    test('target kinds round-trip and an unknown kind defaults to a phone', () {
      for (final AlarmTargetKind kind in AlarmTargetKind.values) {
        expect(AlarmTargetKind.fromWire(kind.wire), kind);
      }
      expect(AlarmTargetKind.fromWire('toaster'), AlarmTargetKind.phone);
      expect(AlarmTargetKind.fromWire('mobile'), AlarmTargetKind.phone);
    });
  });
}
