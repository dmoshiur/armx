// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../../core/security/risk_tier.dart';
import '../../models/device.dart';

/// Seed data for the in-app mock backend: the four fake ESP32 nodes.
///
/// Everything here is deterministic — the same [anchor] instant always yields byte
/// identical data — so widget and golden tests are stable. `anchor` is normally the
/// injected clock's `now()`. The remaining seed data lives in the sibling
/// `mock_*_data.dart` files so that no source file grows past the 300-line budget.
abstract final class MockData {
  /// The four fake ESP32 devices.
  static List<ArmxDevice> devices(DateTime anchor) => <ArmxDevice>[
        ArmxDevice(
          id: 'dev-living-light',
          name: 'Living Room Lights',
          site: 'home',
          kind: DeviceKind.light,
          online: true,
          riskTier: RiskTier.medium,
          firmware: '1.4.2',
          lastSeenAt: anchor.subtract(const Duration(seconds: 12)),
          relays: <Relay>[
            Relay(
              id: 'relay-main',
              label: 'Main',
              state: RelayState.on,
              lastChangedAt: anchor.subtract(const Duration(minutes: 42)),
              riskTier: RiskTier.medium,
            ),
            Relay(
              id: 'relay-accent',
              label: 'Accent',
              state: RelayState.off,
              lastChangedAt: anchor.subtract(const Duration(hours: 3)),
              riskTier: RiskTier.medium,
            ),
          ],
          sensors: <SensorReading>[
            SensorReading(
              id: 'sen-power',
              label: 'Power draw',
              kind: SensorKind.power,
              value: 42.5,
              unit: 'W',
              updatedAt: anchor.subtract(const Duration(seconds: 30)),
            ),
          ],
          tags: const <String, String>{'mqtt': 'armx/home/dev-living-light'},
        ),
        ArmxDevice(
          id: 'dev-gate',
          name: 'Main Gate',
          site: 'home',
          kind: DeviceKind.gate,
          online: true,
          riskTier: RiskTier.high,
          firmware: '1.4.2',
          lastSeenAt: anchor.subtract(const Duration(seconds: 25)),
          relays: <Relay>[
            Relay(
              id: 'relay-gate',
              label: 'Gate motor',
              state: RelayState.off,
              lastChangedAt: anchor.subtract(const Duration(hours: 7)),
              riskTier: RiskTier.high,
              isMomentary: true,
            ),
          ],
          sensors: <SensorReading>[
            SensorReading(
              id: 'sen-contact',
              label: 'Gate contact',
              kind: SensorKind.contact,
              value: 0,
              unit: '',
              updatedAt: anchor.subtract(const Duration(seconds: 25)),
            ),
          ],
        ),
        ArmxDevice(
          id: 'dev-greenhouse',
          name: 'Greenhouse Node',
          site: 'garden',
          kind: DeviceKind.sensor,
          online: false,
          riskTier: RiskTier.low,
          firmware: '1.3.9',
          lastSeenAt: anchor.subtract(const Duration(hours: 2, minutes: 14)),
          sensors: <SensorReading>[
            SensorReading(
              id: 'sen-temp',
              label: 'Temperature',
              kind: SensorKind.temperature,
              value: 31.4,
              unit: '°C',
              updatedAt: anchor.subtract(const Duration(hours: 2, minutes: 14)),
              isStale: true,
            ),
            SensorReading(
              id: 'sen-humidity',
              label: 'Humidity',
              kind: SensorKind.humidity,
              value: 62,
              unit: '%',
              updatedAt: anchor.subtract(const Duration(hours: 2, minutes: 14)),
              isStale: true,
            ),
            SensorReading(
              id: 'sen-battery',
              label: 'Battery',
              kind: SensorKind.battery,
              value: 87,
              unit: '%',
              updatedAt: anchor.subtract(const Duration(hours: 2, minutes: 14)),
              isStale: true,
            ),
          ],
        ),
        ArmxDevice(
          id: 'dev-front-door',
          name: 'Front Door Lock',
          site: 'home',
          kind: DeviceKind.lock,
          online: true,
          riskTier: RiskTier.high,
          firmware: '1.4.0',
          lastSeenAt: anchor.subtract(const Duration(minutes: 4)),
          relays: <Relay>[
            Relay(
              id: 'relay-bolt',
              label: 'Deadbolt',
              state: RelayState.on,
              lastChangedAt: anchor.subtract(const Duration(minutes: 4)),
              riskTier: RiskTier.high,
            ),
          ],
          sensors: <SensorReading>[
            SensorReading(
              id: 'sen-tamper',
              label: 'Tamper',
              kind: SensorKind.motion,
              value: 0,
              unit: '',
              updatedAt: anchor.subtract(const Duration(minutes: 4)),
            ),
          ],
        ),
      ];
}
