// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../data/models/assistant.dart';
import '../../data/models/device.dart';
import '../l10n/l10n.dart';
import '../security/risk_tier.dart';
import '../widgets/armx_confirm_dialog.dart';

/// The one place that decides whether an action needs a confirmation, and shows it.
///
/// ## Why this is centralised
///
/// "Nothing reaches the backend until the user confirms a MEDIUM/HIGH action" is only true
/// if there is exactly one gate. If each screen built its own dialog, a single missed call
/// site would silently perform a HIGH-risk action with no prompt — and no test would prove
/// otherwise. Every screen that can trigger a risky action calls
/// [ConfirmPolicy.confirm], and the policy returns `true` **only** when the user
/// explicitly confirmed.
///
/// LOW-risk actions are returned as `true` without showing anything, which is what makes
/// "a LOW-risk request sees a confirm-free success" testable at the same seam as its
/// opposite.
abstract final class ConfirmPolicy {
  /// Whether [tier] requires a dialog at all.
  static bool requiresDialog(RiskTier tier) => tier.requiresConfirmation;

  /// Whether [action] must be confirmed by typing a phrase, not merely by tapping.
  ///
  /// Reserved for the actions that end access or change the world outside the app: publishing
  /// a site, stopping the assistant everywhere, signing every other device out, and unlocking
  /// a door. A tap is too cheap for those; a phrase is not.
  static bool requiresTypedPhrase(String action) =>
      _typedPhraseTools.contains(action);

  /// Whether [action] cannot be undone.
  static bool isIrreversible(String action) =>
      _irreversibleTools.contains(action);

  /// Shows the confirmation for [request] and reports the user's decision.
  ///
  /// Returns `true` for a LOW-risk request without rendering anything. For a dismissed or
  /// negative answer it returns `false`, and the caller must not proceed.
  static Future<bool> confirm(BuildContext context, ConfirmRequest request) async {
    if (request.riskTier == ArmxRiskTier.low) {
      return true;
    }
    return ArmxConfirmDialog.show(context, request);
  }

  /// Builds the confirmation for a device command issued from the smart-home screen.
  ///
  /// The parameters shown are the ones that will be sent, including the device id, so the
  /// dialog answers "which thing, and with what values" rather than "are you sure".
  static ConfirmRequest forDeviceCommand(
    BuildContext context, {
    required ArmxDevice device,
    required String command,
    required RiskTier tier,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) =>
      ConfirmRequest(
        title: '${device.name} · $command',
        action: command,
        target: device.name,
        riskTier: _widgetTier(tier),
        parameters: <ConfirmParameter>[
          ConfirmParameter(label: 'device_id', value: device.id, monospace: true),
          ConfirmParameter(label: 'room_id', value: device.roomId, monospace: true),
          for (final MapEntry<String, Object?> entry in parameters.entries)
            ConfirmParameter(
              label: entry.key,
              value: '${entry.value}',
              monospace: true,
            ),
        ],
        consequence: tier.explain(context.l10n),
        // Unlocking is the one device action the app cannot reverse — somebody has to close
        // the door again — so it demands the typed phrase.
        irreversible: tier == RiskTier.high && command == 'unlock',
        requireTypedPhrase: tier == RiskTier.high && command == 'unlock',
        typedPhrase: 'CONFIRM',
        confirmLabel:
            tier == RiskTier.high ? context.l10n.smartHomeUnlock : null,
        icon: device.kind == DeviceKind.lock
            ? Icons.lock_open_rounded
            : Icons.toggle_on_rounded,
      );

  /// Builds the confirmation for an assistant tool proposal.
  ///
  /// The request carries the **exact** tool name, target and parameters that will be sent,
  /// so the user confirms the real call rather than a paraphrase of it. A HIGH-risk call
  /// additionally requires the typed phrase, and a destructive one states that it cannot
  /// be undone.
  static ConfirmRequest forToolCall(BuildContext context, ToolCall call) {
    final bool high = call.riskTier == RiskTier.high;
    return ConfirmRequest(
      title: call.summary.isEmpty ? call.tool : call.summary,
      // The wire name of the tool, verbatim: the user is confirming the call that will
      // actually be made, not a friendlier description of it.
      action: call.tool,
      target: call.targetLabel ?? call.parameters['device_id'] as String? ?? '—',
      riskTier: _widgetTier(call.riskTier),
      parameters: call.parameters.entries
          .map(
            (MapEntry<String, Object?> entry) => ConfirmParameter(
              label: entry.key,
              value: '${entry.value}',
              monospace: true,
            ),
          )
          .toList(growable: false),
      // States the obligation the tier carries, in the user's language, rather than
      // restating the summary that is already the title.
      consequence: call.riskTier.explain(context.l10n),
      confirmLabel: context.l10n.toolApprove,
      // The typed phrase is demanded only for the two genuinely dangerous tools, so the
      // friction lands where it is earned rather than on every confirmation.
      requireTypedPhrase: high && _typedPhraseTools.contains(call.tool),
      typedPhrase: high ? 'CONFIRM' : null,
      irreversible: high && _irreversibleTools.contains(call.tool),
    );
  }

  /// Maps the domain tier onto the presentation enum.
  ///
  /// `core/widgets` deliberately does not import `data/models`, so the two enums are
  /// separate; this is the only place they meet, which keeps the boundary honest.
  static ArmxRiskTier _widgetTier(RiskTier tier) => switch (tier) {
        RiskTier.low => ArmxRiskTier.low,
        RiskTier.medium => ArmxRiskTier.medium,
        RiskTier.high => ArmxRiskTier.high,
      };

  /// Tools dangerous enough to demand a typed confirmation. Kept short on purpose.
  static const Set<String> _typedPhraseTools = <String>{
    'web_deploy',
    'kill_switch',
    'revoke_sessions',
  };

  /// Tools whose effect cannot be undone from the app.
  static const Set<String> _irreversibleTools = <String>{
    'web_deploy',
    'unlink_device',
    'delete_guest',
  };

  /// Builds a confirmation for a plain UI action (unlink, deploy, revoke, delete).
  static ConfirmRequest forAction(
    BuildContext context, {
    required String title,
    required String action,
    required String target,
    ArmxRiskTier tier = ArmxRiskTier.high,
    List<ConfirmParameter> parameters = const <ConfirmParameter>[],
    String? consequence,
    bool irreversible = false,
    bool requireTypedPhrase = false,
    String? confirmLabel,
  }) =>
      ConfirmRequest(
        title: title,
        action: action,
        target: target,
        riskTier: tier,
        parameters: parameters,
        consequence: consequence,
        irreversible: irreversible,
        requireTypedPhrase: requireTypedPhrase,
        typedPhrase: requireTypedPhrase ? 'CONFIRM' : null,
        confirmLabel: confirmLabel,
      );
}
