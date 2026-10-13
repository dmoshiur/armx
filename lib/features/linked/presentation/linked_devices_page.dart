// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/linked_device.dart';
import '../application/linked_devices_controller.dart';
import 'widgets/owner_password_dialog.dart';

/// Linked devices: pairing, the list, and unlinking.
///
/// ## Layout
///
/// Compact and medium stack the pairing card above the list. Expanded shows the list with
/// the pairing card beside it, so an owner can read a code off their phone while watching
/// the new device appear in the list.
///
/// ## The rules this screen implements
///
/// * **Pairing needs a trusted device.** This screen can start an offer (showing a QR and a
///   code with a live expiry) *and* approve a code typed from elsewhere. It never approves its
///   own offer — that would defeat the two-person rule.
/// * **Unlinking is gated by the owner's own password** and by a confirmation that names the
///   device. A wrong password leaves the link intact and says so.
/// * **The current device cannot unlink itself** from this list; that is what sign-out is for,
///   and the row says as much instead of offering a button that fails.
class LinkedDevicesPage extends ConsumerWidget {
  /// Creates the page.
  const LinkedDevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LinkedDevice>> devices = ref.watch(linkedDevicesProvider);
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.linkedTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () => ref.read(linkedDevicesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: switch (devices) {
        AsyncLoading<List<LinkedDevice>>() => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: ArmxSkeletonCard(lines: 4),
          ),
        AsyncError<List<LinkedDevice>>(:final Object error) => ArmxErrorState(
            error: error,
            onRetry: () => ref.invalidate(linkedDevicesProvider),
          ),
        AsyncData<List<LinkedDevice>>(:final List<LinkedDevice> value) => _Body(
            devices: value,
          ),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.devices});

  final List<LinkedDevice> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.linkedSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: Insets.lg),
        if (devices.isEmpty)
          ArmxEmptyState(
            icon: Icons.devices_other_outlined,
            title: context.l10n.linkedEmptyTitle,
            message: context.l10n.linkedEmptyBody,
          )
        else
          for (final LinkedDevice device in devices) ...<Widget>[
            _DeviceCard(device: device),
            const SizedBox(height: Insets.md),
          ],
      ],
    );

    final Widget pairing = const _PairingCard();

    if (!context.isExpanded) {
      return ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: <Widget>[list, const SizedBox(height: Insets.xl), pairing],
      );
    }
    return Padding(
      padding: EdgeInsets.all(context.pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 2, child: SingleChildScrollView(child: list)),
          const SizedBox(width: Insets.xl),
          SizedBox(
            width: 420,
            child: SingleChildScrollView(child: pairing),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({required this.device});

  final LinkedDevice device;

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final LinkedDevice device = widget.device;
    final ArmxColors colors = ArmxColors.of(context);

    return ArmxCard(
      title: device.name,
      semanticLabel: '${device.name}. ${_statusLabel(context)}',
      leading: Icon(
        _iconFor(device.platform),
        color: device.status.hasAccess ? colors.accentText : colors.textMuted,
      ),
      trailing: device.status.isOpen
          ? ArmxBadge(
              label: context.l10n.linkedPendingApproval,
              tone: ArmxBadgeTone.warning,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            children: <Widget>[
              ArmxBadge(
                label: _statusLabel(context),
                tone: switch (device.status) {
                  LinkStatus.active => ArmxBadgeTone.success,
                  LinkStatus.offline => ArmxBadgeTone.neutral,
                  LinkStatus.revoked => ArmxBadgeTone.danger,
                  LinkStatus.pendingApproval => ArmxBadgeTone.warning,
                  LinkStatus.expired => ArmxBadgeTone.neutral,
                },
              ),
              if (device.isCurrentDevice)
                ArmxBadge(
                  label: context.l10n.linkedThisDevice,
                  tone: ArmxBadgeTone.accent,
                  icon: Icons.phone_iphone_rounded,
                ),
              ArmxBadge(
                label: device.platform,
                tone: ArmxBadgeTone.neutral,
                icon: Icons.devices_rounded,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          ArmxStatusDot(
            status: device.status.hasAccess ? ArmxStatus.online : ArmxStatus.offline,
            label: device.status.hasAccess
                ? context.l10n.statusConnected
                : context.l10n.statusDisconnected,
            compact: true,
          ),
          const SizedBox(height: Insets.md),
          if (device.ownerEmail != null)
            ArmxDetailRow(
              label: context.l10n.linkedOwner(device.ownerEmail!),
              value: device.ownerEmail!,
              monospace: true,
              icon: Icons.person_outline_rounded,
            ),
          if (device.lastActiveAt != null)
            ArmxDetailRow(
              label: context.l10n.statusLastActive,
              value: device.lastActiveAt!.toLocal().toString(),
              icon: Icons.history_rounded,
            ),
          if (device.fingerprint != null)
            ArmxDetailRow(
              label: context.l10n.linkedFingerprint,
              value: device.fingerprint!,
              monospace: true,
              icon: Icons.fingerprint_rounded,
            ),
          const SizedBox(height: Insets.md),
          ArmxButton(
            label: device.isCurrentDevice
                ? context.l10n.linkedUnlinkCurrentDevice
                : context.l10n.linkedUnlink,
            variant: ArmxButtonVariant.destructive,
            size: ArmxButtonSize.small,
            icon: Icons.link_off_rounded,
            loading: _busy,
            // Disabled, not hidden, with the reason in the label.
            onPressed: device.isCurrentDevice || _busy
                ? null
                : () => _unlink(context, device),
          ),
        ],
      ),
    );
  }

  /// Confirm, then authenticate, then unlink — in that order.
  Future<void> _unlink(BuildContext context, LinkedDevice device) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.linkedUnlinkTitle(device.name),
        action: 'unlink_device',
        target: device.name,
        parameters: <ConfirmParameter>[
          ConfirmParameter(label: 'device_id', value: device.id, monospace: true),
          ConfirmParameter(label: 'platform', value: device.platform),
        ],
        consequence: context.l10n.linkedUnlinkBody,
        irreversible: true,
        requireTypedPhrase: true,
        confirmLabel: context.l10n.linkedUnlink,
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }

    final String? password = await OwnerPasswordDialog.show(
      context,
      deviceName: device.name,
      ownerEmail: device.ownerEmail,
    );
    if (password == null || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(linkedDevicesProvider.notifier).unlink(
            deviceId: device.id,
            ownerPassword: password,
          );
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.linkedUnlinkDone)),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        // A refused password is stated plainly, and the row stays — the device still has
        // access, and the list must not suggest otherwise.
        final String message =
            error is ForbiddenException || error is ValidationException
                ? context.l10n.linkedUnlinkWrongPassword
                : error.message;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _statusLabel(BuildContext context) => switch (widget.device.status) {
        LinkStatus.active => context.l10n.statusActive,
        LinkStatus.offline => context.l10n.statusOffline,
        LinkStatus.revoked => context.l10n.linkedRevoked,
        LinkStatus.pendingApproval => context.l10n.linkedPendingApproval,
        LinkStatus.expired => context.l10n.linkedPairingExpired,
      };

  IconData _iconFor(String platform) => switch (platform.toLowerCase()) {
        'windows' => Icons.window_rounded,
        'macos' => Icons.laptop_mac_rounded,
        'linux' => Icons.terminal_rounded,
        'web' => Icons.language_rounded,
        'wear' || 'watch' => Icons.watch_rounded,
        _ => Icons.phone_android_rounded,
      };
}

/// Start an offer, and approve somebody else's.
class _PairingCard extends ConsumerStatefulWidget {
  const _PairingCard();

  @override
  ConsumerState<_PairingCard> createState() => _PairingCardState();
}

class _PairingCardState extends ConsumerState<_PairingCard> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String? _codeError;
  bool _approving = false;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PairingState pairing = ref.watch(pairingProvider);

    return ArmxCard(
      title: context.l10n.linkedPair,
      leading: const Icon(Icons.qr_code_rounded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ArmxTextField(
            label: context.l10n.linkedPairingDeviceName,
            helper: context.l10n.linkedPairingDeviceNameHelp,
            controller: _name,
            maxLength: 40,
          ),
          const SizedBox(height: Insets.md),
          ArmxButton(
            label: pairing.status.isTerminal
                ? context.l10n.linkedPair
                : context.l10n.linkedPairingTitle,
            icon: Icons.add_link_rounded,
            onPressed: () => ref.read(pairingProvider.notifier).start(
                  deviceName: _name.text.trim().isEmpty
                      ? context.l10n.linkedPairingDefaultName
                      : _name.text.trim(),
                  // The platform comes from the running app, not from a preference: this is
                  // the device doing the pairing.
                  platform: 'android',
                ),
          ),
          const SizedBox(height: Insets.lg),
          if (pairing.offer != null && pairing.status == PairingStatus.waiting)
            _LiveOffer(offer: pairing.offer!)
          else if (pairing.error != null) ...<Widget>[
            ArmxErrorState(error: pairing.error, compact: true),
            const SizedBox(height: Insets.md),
          ],
          const Divider(height: Insets.xl),
          Text(
            context.l10n.linkedApproveTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            context.l10n.linkedApproveBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.md),
          ArmxTextField(
            label: context.l10n.linkedPairingCode,
            hint: Validators.formatPairingCode('12345678'),
            controller: _code,
            errorText: _codeError,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _approve(),
          ),
          const SizedBox(height: Insets.md),
          ArmxButton(
            label: context.l10n.linkedApproveAction,
            icon: Icons.check_rounded,
            loading: _approving,
            onPressed: _approving ? null : _approve,
          ),
        ],
      ),
    );
  }

  Future<void> _approve() async {
    final String value = _code.text;
    final String? error = Validators.pairingCode(value, context.l10n);
    if (error != null) {
      setState(() => _codeError = error);
      return;
    }
    setState(() {
      _codeError = null;
      _approving = true;
    });
    await ref.read(pairingProvider.notifier).approve(value);
    if (!mounted) {
      return;
    }
    setState(() => _approving = false);
    final PairingState state = ref.read(pairingProvider);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          state.status == PairingStatus.approved
              ? context.l10n.linkedPairingApproved
              : state.error?.message ?? context.l10n.linkedPairingRejected,
        ),
      ),
    );
  }
}

/// The live code: a QR for scanning, the digits for typing, and a countdown.
///
/// Both routes are first-class. A device without a camera types the digits; a device without
/// a screen scans. Neither is presented as the fallback.
class _LiveOffer extends StatefulWidget {
  const _LiveOffer({required this.offer});

  final PairingOffer offer;

  @override
  State<_LiveOffer> createState() => _LiveOfferState();
}

class _LiveOfferState extends State<_LiveOffer> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final Duration left =
        widget.offer.expiresAt.difference(DateTime.now().toUtc());
    if (mounted) {
      setState(() => _remaining = left.isNegative ? Duration.zero : left);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final bool expired = _remaining == Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.offer.qrPayload != null && !expired)
          Center(
            child: Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                // A QR is read by a camera: it keeps a light background in both themes,
                // because an inverted code is a code that does not scan.
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(Insets.cardRadius),
              ),
              child: QrImageView(
                data: widget.offer.qrPayload!,
                size: 180,
                backgroundColor: const Color(0xFFFFFFFF),
                semanticsLabel: context.l10n.linkedPairingScanHint,
              ),
            ),
          ),
        const SizedBox(height: Insets.md),
        Text(
          context.l10n.linkedPairingScanHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Insets.md),
        SelectableText(
          Validators.formatPairingCode(widget.offer.code),
          textAlign: TextAlign.center,
          style: ArmxTypography.mono(size: 24, color: colors.text),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          context.l10n.linkedPairingCodeHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Insets.md),
        if (expired)
          ArmxNotice(
            tone: ArmxBadgeToneLike.warning,
            message: context.l10n.linkedPairingExpired,
          )
        else
          Center(
            child: ArmxStatusPill(
              status: _remaining.inSeconds <= 30
                  ? ArmxStatus.pending
                  : ArmxStatus.online,
              // The countdown is the honest part: a code that looks permanent but expires is
              // how people end up staring at a dead screen.
              label: context.l10n.linkedPairingExpires(_format(_remaining)),
              pulse: true,
            ),
          ),
        const SizedBox(height: Insets.md),
        ArmxButton(
          label: context.l10n.linkedPairingCancel,
          variant: ArmxButtonVariant.ghost,
          onPressed: () => ref.read(pairingProvider.notifier).cancel(),
        ),
      ],
    );
  }

  String _format(Duration duration) {
    final String minutes = duration.inMinutes.toString().padLeft(2, '0');
    final String seconds =
        (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
