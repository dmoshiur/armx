// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/armx_tile.dart';
import '../../core/widgets/layout_blocks.dart';
import '../../core/widgets/glass_panel.dart';
import 'intercom_controller.dart';

/// The one-time opt-in screen for voice announcements (Alexa Drop-In model).
///
/// Default OFF. The switch can only be turned on from this screen, on this device, by the
/// person holding it — there is no remote enable, and the second switch (locked-screen
/// playback) is a separate, narrower permission. Turning the main switch off takes effect
/// instantly and stops any playback in flight.
class IntercomConsentPage extends ConsumerWidget {
  /// Creates the consent screen.
  const IntercomConsentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final state = ref.watch(intercomControllerProvider);
    final controller = ref.read(intercomControllerProvider.notifier);

    return Scaffold(
      appBar: ArmxAppBar(title: l10n.intercomConsentTitle),
      body: ArmxBackground(
        child: ArmxPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GlassPanel(
                accent: state.consent.enabled ? colors.green : colors.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          state.consent.enabled
                              ? Icons.record_voice_over_rounded
                              : Icons.voice_over_off_rounded,
                          color: state.consent.enabled ? colors.green : colors.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.intercomConsentMainTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(
                          value: state.consent.enabled,
                          onChanged: (bool value) => unawaited(controller.setConsent(
                                enabled: value,
                                allowWhileLocked: state.consent.allowWhileLocked,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.intercomConsentExplain,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ArmxTile(
                title: l10n.intercomConsentLockedTitle,
                subtitle: l10n.intercomConsentLockedBody,
                leading: const Icon(Icons.lock_outline_rounded),
                trailing: Switch(
                  value: state.consent.allowWhileLocked,
                  onChanged: state.consent.enabled
                      ? (bool value) => unawaited(controller.setConsent(
                            enabled: true,
                            allowWhileLocked: value,
                          ))
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: l10n.intercomConsentRulesTitle),
              for (final rule in <String>[
                l10n.intercomRuleConsent,
                l10n.intercomRuleAudible,
                l10n.intercomRuleMutual,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.check_circle_outline, size: 16, color: colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(rule, style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (state.consent.enabled)
                ArmxButton(
                  label: l10n.intercomTurnOff,
                  icon: Icons.notifications_off_rounded,
                  variant: ArmxButtonVariant.danger,
                  expanded: true,
                  onPressed: () => unawaited(controller.setConsent(
                        enabled: false,
                        allowWhileLocked: false,
                      )),
                )
              else
                ArmxButton(
                  label: l10n.intercomConsentEnable,
                  icon: Icons.check_rounded,
                  expanded: true,
                  onPressed: () => unawaited(controller.setConsent(
                        enabled: true,
                        allowWhileLocked: state.consent.allowWhileLocked,
                      )),
                ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l10n.intercomConsentRevokeNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
