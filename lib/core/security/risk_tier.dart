// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import '../l10n/l10n.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// How dangerous an action is, and therefore what the UI must do before running it.
///
/// The tier is **server-supplied** for any action the assistant proposes, because only the
/// backend knows what a tool actually does. The client may not downgrade it: if the server
/// says HIGH, the confirmation dialog appears even if the tool looks harmless. The client
/// *may* raise it (a UI path that unlocks a door can insist on HIGH even if the tool is
/// reported MEDIUM).
///
/// | Tier | Client obligation |
/// | --- | --- |
/// | [low] | Run and report. No confirmation. |
/// | [medium] | `ArmxConfirmDialog` before the call fires. |
/// | [high] | `ArmxConfirmDialog`, destructive styling, and on-device re-authentication. |
enum RiskTier {
  /// Read-only, or reversible by the person standing next to it: status reads, sensor
  /// values, a light, a fan, a plug. Putting a dialog in front of a lamp switch is how
  /// people learn to dismiss dialogs without reading them.
  low,

  /// Side effects that reach beyond the screen you are on but are still reversible:
  /// arming an alarm that rings on someone else's device, activating a multi-device scene,
  /// editing a role.
  medium,

  /// Destructive, security-sensitive, or hard to undo: publishing a site, unlinking a
  /// device, deleting guest data, the kill-switch, revoking a session, unlocking a door.
  high;

  /// Parses a wire value.
  ///
  /// Anything unrecognised becomes [high], not [low]. Failing closed means a server that
  /// introduces a new tier cannot cause the client to run it without confirmation.
  static RiskTier fromWire(String? value) => switch (value?.toLowerCase().trim()) {
        'low' || 'l0' => RiskTier.low,
        'medium' || 'med' || 'l1' => RiskTier.medium,
        'high' || 'critical' || 'l2' => RiskTier.high,
        _ => RiskTier.high,
      };

  /// The wire value.
  String get wire => name;

  /// True when a confirmation dialog is mandatory before the action runs.
  bool get requiresConfirmation => this != RiskTier.low;

  /// True when the destructive treatment applies.
  bool get isDestructive => this == RiskTier.high;

  /// Escalates to the higher of the two tiers.
  RiskTier max(RiskTier other) => index >= other.index ? this : other;

  /// The localized badge label (`LOW` / `MEDIUM` / `HIGH`).
  String label(AppLocalizations l10n) => switch (this) {
        RiskTier.low => l10n.riskLow,
        RiskTier.medium => l10n.riskMedium,
        RiskTier.high => l10n.riskHigh,
      };

  /// The localized one-line explanation shown inside the confirmation dialog.
  String explain(AppLocalizations l10n) => switch (this) {
        RiskTier.low => l10n.riskLowExplain,
        RiskTier.medium => l10n.riskMediumExplain,
        RiskTier.high => l10n.riskHighExplain,
      };

  /// Convenience for widget code.
  String explainFor(BuildContext context) => explain(context.l10n);
}
