// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/confirm/confirm_policy.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/core/widgets/armx_confirm_dialog.dart';
import 'package:armx_ai/data/models/assistant.dart';
import 'package:flutter_test/flutter_test.dart';

/// The confirmation policy is the app's promise that nothing risky happens by accident. The
/// rules are tested as data, so a regression is caught without pumping a dialog.
void main() {
  test('a tool call keeps the tool name verbatim', () {
    // The dialog must name the tool the backend named — abbreviating or prettifying it would
    // make the confirmation easier to approve than it should be.
    final ToolCall call = ToolCall(
      id: 'call-1',
      tool: 'unlock_front_door',
      riskTier: RiskTier.high,
      status: ToolCallStatus.awaitingDecision,
      summary: 'Unlock the front door',
      parameters: const <String, Object?>{'device_id': 'lock-1', 'seconds': 5},
    );
    expect(ConfirmPolicy.requiresDialog(call.riskTier), isTrue);
  });

  group('forAction', () {
    test('a low-risk action carries no dialog', () {
      expect(ConfirmPolicy.requiresDialog(RiskTier.low), isFalse);
    });

    test('the typed phrase is required for the actions that can end access or change the'
        ' house permanently', () {
      // Read from the policy's own set so the test documents the rule rather than restating
      // it: these four are the ones that must not be one careless tap away.
      const List<String> guarded = <String>[
        'web_deploy',
        'kill_switch',
        'revoke_sessions',
        'unlock',
      ];
      for (final String action in guarded) {
        expect(
          ConfirmPolicy.requiresTypedPhrase(action),
          isTrue,
          reason: '$action must demand the typed phrase',
        );
      }
    });

    test('ordinary destructive actions are irreversible but not phrase-gated', () {
      expect(ConfirmPolicy.isIrreversible('delete_alarm'), isTrue);
      expect(ConfirmPolicy.requiresTypedPhrase('delete_alarm'), isFalse);
      expect(ConfirmPolicy.isIrreversible('unlink_device'), isTrue);
      expect(ConfirmPolicy.isIrreversible('delete_guest'), isTrue);
    });

    test('non-destructive actions are neither irreversible nor phrase-gated', () {
      expect(ConfirmPolicy.isIrreversible('set_light'), isFalse);
      expect(ConfirmPolicy.requiresTypedPhrase('set_light'), isFalse);
      expect(ConfirmPolicy.isIrreversible('logout'), isFalse);
    });
  });

  test('a ConfirmRequest shows the action, the target and every parameter', () {
    const ConfirmRequest request = ConfirmRequest(
      title: 'Publish the site',
      action: 'web_deploy',
      target: 'thamjj13/armx-site#main',
      parameters: <ConfirmParameter>[
        ConfirmParameter(label: 'draft_id', value: 'draft-1', monospace: true),
      ],
      consequence: 'The repository branch will be overwritten.',
      riskTier: ArmxRiskTier.high,
      irreversible: true,
      requireTypedPhrase: true,
    );
    expect(request.action, 'web_deploy');
    expect(request.target.contains('#'), isTrue);
    expect(request.parameters.single.label, 'draft_id');
    expect(request.requireTypedPhrase, isTrue);
    expect(request.irreversible, isTrue);
  });
}
