// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockRuleDomain — one slice of [MockArmxApi].
///
/// Declared as a mixin in a part file so the mock backend stays split across small
/// files while every slice keeps access to the shared in-memory state.
mixin MockRuleDomain on MockArmxApi {
  // ---- Rules ---------------------------------------------------------------

  @override
  Future<List<AutomationRule>> rules() async {
    await _delay();
    return List<AutomationRule>.unmodifiable(_rules);
  }

  @override
  Future<AutomationRule> upsertRule(AutomationRule rule) async {
    await _delay();
    final exists = _rules.any((entry) => entry.id == rule.id);
    _rules = exists
        ? _rules.map((entry) => entry.id == rule.id ? rule : entry).toList(growable: false)
        : <AutomationRule>[..._rules, rule];
    return rule;
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    await _delay();
    _rules = _rules.where((rule) => rule.id != ruleId).toList(growable: false);
  }

  @override
  Future<RuleDryRunResult> dryRunRule(AutomationRule rule) async {
    await _delay();
    final steps = <String>[
      'Evaluating WHEN ${rule.whenLabel}',
      'Risk tier: ${rule.riskTier.wireName}',
      rule.riskTier == RiskTier.low
          ? 'Would run without a new verification prompt'
          : 'Would require face verification (60 s window) before THEN ${rule.thenLabel}',
      'Would execute THEN ${rule.thenLabel}',
    ];
    return RuleDryRunResult(
      ruleId: rule.id,
      wouldFire: rule.enabled,
      at: _clock.now().toUtc(),
      steps: steps,
      blockedReason: rule.enabled ? '' : 'Rule is disabled',
    );
  }
}
