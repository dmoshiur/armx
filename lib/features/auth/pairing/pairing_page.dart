// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/security/secure_screen.dart';
import '../../../core/theme/armx_colors.dart';
import '../../../core/utils/hex.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/armx_controls.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../data/models/auth.dart';
import 'pairing_controller.dart';

/// Step 2 screen: pair this phone with an A.R.M.X server.
///
/// Walks the state machine in [PairingPhase]: validate + test the server URL, generate
/// (or restore) the on-device Ed25519 keypair, show it as QR + grouped fingerprint, then
/// `POST /devices/pair` and surface the pending/approved/rejected answers.
class PairingPage extends ConsumerStatefulWidget {
  /// Creates the pairing screen.
  const PairingPage({super.key});

  @override
  ConsumerState<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends ConsumerState<PairingPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _nameController;
  var _defaultNameSeeded = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: ref.read(pairingControllerProvider).serverUrl,
    );
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultNameSeeded || _nameController.text.isNotEmpty) {
      return;
    }
    _defaultNameSeeded = true;
    final state = ref.read(pairingControllerProvider);
    _nameController.text = state.deviceName.isNotEmpty
        ? state.deviceName
        : context.l10n.pairingDefaultDeviceName(platform: _platformLabel);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _platformLabel => defaultTargetPlatform.name.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);
    final state = ref.watch(pairingControllerProvider);
    final notifier = ref.read(pairingControllerProvider.notifier);
    final busy =
        state.phase == PairingPhase.testing || state.phase == PairingPhase.submitting;
    final isPlainHttp = state.serverUrl.trim().toLowerCase().startsWith('http:');

    final children = <Widget>[
      SectionHeader(title: l10n.pairingServerSection),
      GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ArmxTextField(
              controller: _urlController,
              label: l10n.pairingServerUrlLabel,
              hint: l10n.pairingServerUrlHint,
              errorText: state.urlIssue == null
                  ? null
                  : context.validationMessage(state.urlIssue!),
              enabled: !busy,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onChanged: notifier.setServerUrl,
            ),
            if (isPlainHttp && !kReleaseMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.lock_open_rounded, size: 16, color: colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.pairingInsecureUrlWarning,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ArmxButton(
              label: l10n.pairingTestConnection,
              icon: Icons.bolt_rounded,
              loading: state.phase == PairingPhase.testing,
              expanded: true,
              onPressed: busy ? null : () => notifier.testConnection(),
            ),
          ],
        ),
      ),
      if (state.error != null && state.phase == PairingPhase.idle)
        ErrorView(
            error: state.error!,
            compact: true,
            onRetry: () => notifier.testConnection(),
          ),
    ];

    final identity = state.identity;
    if (identity != null &&
        state.phase != PairingPhase.idle &&
        state.phase != PairingPhase.testing) {
      children.add(SectionHeader(title: l10n.pairingIdentitySection));
      children.add(_buildIdentityPanel(context, state, notifier, busy));
    }

    return SecureScreen(
      security: ref.watch(screenSecurityProvider),
      child: Scaffold(
        appBar: ArmxAppBar(title: l10n.pairingTitle, subtitle: l10n.pairingSubtitle),
        body: ArmxBackground(
          child: ArmxPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  /// Panel to render while `submitting`: keep the caller's panel (pending or
  /// rejected) instead of flashing the QR form on every status poll.
  PairingPhase _displayPhase(PairingFlowState state) {
    if (state.phase != PairingPhase.submitting) {
      return state.phase;
    }
    return switch (state.status?.state) {
      PairingState.pending => PairingPhase.pending,
      PairingState.rejected => PairingPhase.rejected,
      _ => PairingPhase.identity,
    };
  }

  Widget _buildIdentityPanel(
    BuildContext context,
    PairingFlowState state,
    PairingController notifier,
    bool busy,
  ) {
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);

    switch (_displayPhase(state)) {
      case PairingPhase.approved:
        return GlassPanel(
          accent: colors.green,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, color: colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.pairingApprovedTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pairingApprovedBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 16),
              ArmxButton(
                label: l10n.pairingApprovedAction,
                icon: Icons.arrow_forward_rounded,
                expanded: true,
                onPressed: notifier.confirmPaired,
              ),
            ],
          ),
        );
      case PairingPhase.pending:
        return GlassPanel(
          accent: colors.amber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              StatusPill(
                label: l10n.pairingPendingTitle,
                tone: SeverityTone.warning,
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pairingPendingBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.muted),
              ),
              if (state.status != null && state.status!.deviceId.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  '${l10n.pairingDeviceIdLabel}: ${state.status!.deviceId}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontFamily: 'JetBrainsMono'),
                ),
              ],
              if (state.error != null) ...<Widget>[
                ErrorView(
                  error: state.error!,
                  compact: true,
                  onRetry: () => notifier.submitPairing(deviceName: _nameController.text),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 16),
                ArmxButton(
                  label: l10n.pairingCheckStatus,
                  icon: Icons.sync_rounded,
                  variant: ArmxButtonVariant.outlined,
                  loading: state.phase == PairingPhase.submitting,
                  expanded: true,
                  onPressed: () =>
                      notifier.submitPairing(deviceName: _nameController.text),
                ),
              ],
            ],
          ),
        );
      case PairingPhase.rejected:
        return GlassPanel(
          accent: colors.red,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              StatusPill(
                label: l10n.pairingRejectedTitle,
                tone: SeverityTone.danger,
                icon: Icons.block_rounded,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pairingRejectedBody,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 16),
              ArmxButton(
                label: context.l10n.commonRetry,
                icon: Icons.refresh_rounded,
                variant: ArmxButtonVariant.outlined,
                loading: state.phase == PairingPhase.submitting,
                expanded: true,
                onPressed: () =>
                    notifier.submitPairing(deviceName: _nameController.text),
              ),
            ],
          ),
        );
      case PairingPhase.idle:
      case PairingPhase.testing:
      case PairingPhase.submitting:
      case PairingPhase.identity:
        break;
    }

    // identity / submitting: server status, name field, QR + fingerprint, submit.
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (state.probe != null)
            StatusPill(
              label: l10n.pairingServerConnected(version: state.probe!.serverVersion),
              tone: SeverityTone.success,
              icon: Icons.cloud_done_rounded,
            ),
          if (state.phase == PairingPhase.identity) ...<Widget>[
            const SizedBox(height: 14),
            ArmxTextField(
              controller: _nameController,
              label: l10n.pairingDeviceNameLabel,
              enabled: !busy,
              onChanged: notifier.setDeviceName,
            ),
          ] else if (state.deviceName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '${state.deviceName} · ${state.identity?.platform ?? _platformLabel}',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: colors.muted),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Semantics(
              image: true,
              label: l10n.pairingQrSemantics,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: state.identity?.publicKey ?? '',
                  version: QrVersions.auto,
                  size: 208,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              l10n.pairingFingerprintLabel,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: colors.muted),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: SelectableText(
              Hex.group(state.identity?.fingerprintHex ?? ''),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontFamily: 'JetBrainsMono', letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                l10n.pairingQrHint,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.muted),
              ),
            ),
          ),
          if (state.error != null) ...<Widget>[
            ErrorView(
              error: state.error!,
              compact: true,
              onRetry: () => notifier.submitPairing(deviceName: _nameController.text),
            ),
          ] else if (state.phase == PairingPhase.identity) ...<Widget>[
            const SizedBox(height: 16),
            ArmxButton(
              label: l10n.pairingSubmit,
              icon: Icons.cell_tower_rounded,
              loading: state.phase == PairingPhase.submitting,
              expanded: true,
              onPressed: () =>
                  notifier.submitPairing(deviceName: _nameController.text),
            ),
          ],
        ],
      ),
    );
  }
}
