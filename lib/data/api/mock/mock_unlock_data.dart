// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../../../core/security/risk_tier.dart';
import '../../models/unlock.dart';

/// Seeded unlock targets for the mock backend.
abstract final class MockUnlockData {
  /// Machines paired for unlock.
  static List<UnlockTarget> unlockTargets(DateTime anchor) => <UnlockTarget>[
        UnlockTarget(
          id: 'pc-studio',
          name: 'Studio PC (Windows)',
          kind: UnlockTargetKind.windowsPc,
          online: true,
          lastSeenAt: anchor.subtract(const Duration(seconds: 40)),
          riskTier: RiskTier.high,
          agentVersion: '0.4.1',
        ),
        UnlockTarget(
          id: 'pc-desk',
          name: 'Desk Workstation (Linux)',
          kind: UnlockTargetKind.linuxPc,
          online: true,
          lastSeenAt: anchor.subtract(const Duration(minutes: 3)),
          riskTier: RiskTier.high,
          agentVersion: '0.4.1',
        ),
        UnlockTarget(
          id: 'phone-linux',
          name: 'Pocket Linux (Termux)',
          kind: UnlockTargetKind.linuxPhone,
          online: false,
          lastSeenAt: anchor.subtract(const Duration(hours: 5)),
          riskTier: RiskTier.high,
          agentVersion: '0.3.9',
        ),
      ];
}
