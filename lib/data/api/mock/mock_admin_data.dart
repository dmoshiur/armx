// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../../core/security/risk_tier.dart';
import '../../models/admin.dart';

/// Seeded tool switches for the admin panel of the mock backend.
abstract final class MockAdminData {
  /// Tool switches shown in the admin panel.
  static List<ToolToggle> tools() => const <ToolToggle>[
        ToolToggle(
          id: ToolId.github,
          label: 'GitHub',
          description: 'Repositories, issues and pull requests.',
          enabled: true,
          connected: true,
          maxRiskTier: RiskTier.medium,
        ),
        ToolToggle(
          id: ToolId.mail,
          label: 'Mail',
          description: 'Draft and send email from the owner account.',
          enabled: false,
          connected: true,
          maxRiskTier: RiskTier.high,
        ),
        ToolToggle(
          id: ToolId.mqtt,
          label: 'MQTT',
          description: 'Publish to armx/{site}/{device}/cmd.',
          enabled: true,
          connected: true,
          maxRiskTier: RiskTier.high,
        ),
        ToolToggle(
          id: ToolId.database,
          label: 'Database',
          description: 'Read-only queries against the resource inventory.',
          enabled: true,
          connected: false,
          maxRiskTier: RiskTier.medium,
        ),
        ToolToggle(
          id: ToolId.system,
          label: 'System',
          description: 'Privileged shell tasks on paired machines.',
          enabled: false,
          connected: false,
          maxRiskTier: RiskTier.high,
        ),
        ToolToggle(
          id: ToolId.vision,
          label: 'Vision',
          description: 'Face/voice verification results (never raw templates).',
          enabled: true,
          connected: true,
          maxRiskTier: RiskTier.high,
        ),
      ];
}
