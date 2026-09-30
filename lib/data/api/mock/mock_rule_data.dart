// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../../core/security/risk_tier.dart';
import '../../models/rules.dart';

/// Seeded automation rules and geofences for the mock backend.
abstract final class MockRuleData {
  /// Two starter automation rules.
  static List<AutomationRule> rules(DateTime anchor) => <AutomationRule>[
        AutomationRule(
          id: 'rule-drive-focus',
          name: 'Driving → focus mode',
          triggerType: RuleTriggerType.activityIs,
          actionType: RuleActionType.notify,
          enabled: true,
          dryRun: false,
          riskTier: RiskTier.low,
          triggerParams: const <String, Object?>{'activity': 'IN_VEHICLE'},
          actionParams: const <String, Object?>{'title': 'Driving detected'},
          lastRunAt: anchor.subtract(const Duration(hours: 4)),
          runCount: 12,
        ),
        AutomationRule(
          id: 'rule-work-arrive',
          name: 'Arrive at work → desk lights',
          triggerType: RuleTriggerType.geofenceEnter,
          actionType: RuleActionType.deviceCommand,
          enabled: true,
          dryRun: true,
          riskTier: RiskTier.medium,
          geofenceId: 'geo-work',
          deviceId: 'dev-living-light',
          triggerParams: const <String, Object?>{'geofence': 'Work'},
          actionParams: const <String, Object?>{
            'device': 'Living Room Lights',
            'command': 'relay-main:ON',
          },
          lastRunAt: anchor.subtract(const Duration(days: 1, hours: 3)),
          runCount: 5,
        ),
        AutomationRule(
          id: 'rule-home-leave',
          name: 'Leaving home → lock door',
          triggerType: RuleTriggerType.geofenceExit,
          actionType: RuleActionType.deviceCommand,
          enabled: false,
          dryRun: true,
          riskTier: RiskTier.high,
          geofenceId: 'geo-home',
          deviceId: 'dev-front-door',
          triggerParams: const <String, Object?>{'geofence': 'Home'},
          actionParams: const <String, Object?>{
            'device': 'Front Door Lock',
            'command': 'relay-bolt:ON',
          },
        ),
      ];

  /// Home/work geofences used by the activity screen.
  static List<Geofence> geofences() => const <Geofence>[
        Geofence(
          id: 'geo-home',
          label: 'Home',
          latitude: 23.8103,
          longitude: 90.4125,
          radiusMeters: 120,
          kind: GeofenceKind.home,
        ),
        Geofence(
          id: 'geo-work',
          label: 'Work',
          latitude: 23.7806,
          longitude: 90.4074,
          radiusMeters: 200,
          kind: GeofenceKind.work,
        ),
      ];
}
