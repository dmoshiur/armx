// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../core/widgets/armx_empty_state.dart';
import '../../../../core/widgets/armx_status_dot.dart';
import '../../../../data/models/guest.dart';

/// The live camera area of the guest greeter.
///
/// It exists to enforce three things:
///
/// * **Nothing is captured while the kill-switch is engaged.** In that state the camera is
///   never opened, so there is no window in which a "stopped" camera is still warm.
/// * **The indicator is never colour alone.** "Camera is on" is written out, so a person
///   standing in front of the device can tell what it is doing without interpreting a dot.
/// * **No preview is faked.** With no camera, or with permission refused, the box says
///   exactly that. A grey rectangle labelled "preview" would be a lie about surveillance —
///   the worst possible lie for this screen.
class GreeterCameraPreview extends StatefulWidget {
  /// Creates the preview.
  const GreeterCameraPreview({
    required this.cameraState,
    required this.onRequestAccess,
    this.onCameraFailed,
    super.key,
  });

  /// The backend-reported camera state.
  final GreeterCameraState cameraState;

  /// Called when the user asks to grant camera permission.
  final VoidCallback onRequestAccess;

  /// Reports a camera failure to the page so it can surface it.
  final ValueChanged<String>? onCameraFailed;

  @override
  State<GreeterCameraPreview> createState() => _GreeterCameraPreviewState();
}

class _GreeterCameraPreviewState extends State<GreeterCameraPreview> {
  CameraController? _controller;
  _PreviewStatus _status = _PreviewStatus.off;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(GreeterCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraState != widget.cameraState) {
      _sync();
    }
  }

  @override
  void dispose() {
    // Disposing releases the hardware; a controller left alive keeps the sensor powered.
    _controller?.dispose();
    super.dispose();
  }

  /// Opens or closes the camera to match [widget.cameraState].
  ///
  /// The backend's state decides first: anything other than [GreeterCameraState.live] is
  /// handled without ever calling the camera plugin.
  Future<void> _sync() async {
    if (widget.cameraState != GreeterCameraState.live) {
      final CameraController? existing = _controller;
      _controller = null;
      await existing?.dispose();
      if (mounted) {
        setState(() {
          _status = switch (widget.cameraState) {
            GreeterCameraState.killed => _PreviewStatus.killed,
            GreeterCameraState.permissionRequired => _PreviewStatus.permission,
            GreeterCameraState.unavailable => _PreviewStatus.unavailable,
            GreeterCameraState.live || GreeterCameraState.off => _PreviewStatus.off,
          };
        });
      }
      return;
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (!mounted) {
        return;
      }
      if (cameras.isEmpty) {
        _fail(context.l10n.greeterPreviewUnavailable);
        return;
      }
      // The rear camera greets guests; the front one is for the owner.
      final CameraDescription chosen = cameras.firstWhere(
        (CameraDescription camera) =>
            camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _status = _PreviewStatus.live;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      // `CameraAccessDenied` is the one failure the user can fix, so it gets its own state
      // with a button rather than a dead panel.
      final bool denied = error.code == 'CameraAccessDenied';
      _fail(
        denied
            ? context.l10n.greeterPreviewPermission
            : error.description ?? error.code,
        permission: denied,
      );
    } catch (_) {
      // No plugin on this platform (web, desktop): said plainly, not left spinning.
      if (mounted) {
        _fail(context.l10n.greeterPreviewUnavailable);
      }
    }
  }

  void _fail(String message, {bool permission = false}) {
    if (mounted) {
      setState(() {
        _controller = null;
        _status =
            permission ? _PreviewStatus.permission : _PreviewStatus.unavailable;
      });
    }
    widget.onCameraFailed?.call(message);
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final CameraController? controller = _controller;
    final bool live = _status == _PreviewStatus.live && controller != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Above the preview, not on top of it: the indicator must stay readable whatever the
        // picture behind it happens to be.
        ArmxStatusPill(
          status: live
              ? ArmxStatus.online
              : _status == _PreviewStatus.killed
                  ? ArmxStatus.stopped
                  : ArmxStatus.unknown,
          label: live
              ? context.l10n.greeterCameraLive
              : _status == _PreviewStatus.killed
                  ? context.l10n.greeterCameraKilled
                  : context.l10n.greeterCameraOff,
          pulse: live,
        ),
        const SizedBox(height: Insets.md),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(Insets.cardRadius),
              border: Border.all(color: colors.hairline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Insets.cardRadius),
              child: _surface(context, controller, live),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          context.l10n.greeterScienceFairNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _surface(BuildContext context, CameraController? controller, bool live) {
    if (live) {
      return CameraPreview(controller!);
    }
    return switch (_status) {
      _PreviewStatus.killed => ArmxEmptyState(
          icon: Icons.videocam_off_rounded,
          title: context.l10n.greeterCameraKilled,
          message: context.l10n.greeterKillSwitchBody,
          compact: true,
        ),
      _PreviewStatus.permission => ArmxEmptyState(
          icon: Icons.no_photography_rounded,
          title: context.l10n.greeterPreviewPermission,
          message: context.l10n.settingsPermissionWhy,
          actionLabel: context.l10n.greeterGrantCamera,
          onAction: widget.onRequestAccess,
          compact: true,
        ),
      _PreviewStatus.unavailable => ArmxEmptyState(
          icon: Icons.videocam_off_outlined,
          title: context.l10n.greeterPreviewUnavailable,
          message: context.l10n.greeterScienceFairNote,
          compact: true,
        ),
      _PreviewStatus.live || _PreviewStatus.off => ArmxEmptyState(
          icon: Icons.videocam_off_outlined,
          title: context.l10n.greeterCameraOff,
          message: context.l10n.greeterPreviewPlaceholder,
          compact: true,
        ),
    };
  }
}

/// Why no picture is on screen. Every value is a fact, not a spinner.
enum _PreviewStatus {
  /// The backend says the camera is off.
  off,

  /// The kill-switch is engaged.
  killed,

  /// A preview is running.
  live,

  /// Permission was refused and the user can change that.
  permission,

  /// No camera exists on this platform.
  unavailable,
}

/// The kill-switch control.
///
/// **One tap to stop, a confirmation to restart.** Engaging never queues behind a prompt —
/// an emergency brake that asks "are you sure?" is not an emergency brake. Releasing resumes
/// capture, so the caller confirms that and names the camera.
class GreeterKillSwitch extends StatelessWidget {
  /// Creates the control.
  const GreeterKillSwitch({
    required this.engaged,
    required this.busy,
    required this.onEngage,
    required this.onRelease,
    super.key,
  });

  /// Whether capture is currently killed.
  final bool engaged;

  /// Whether a request is in flight.
  final bool busy;

  /// Engages the switch.
  final VoidCallback onEngage;

  /// Releases it.
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);

    return ArmxCard(
      tone: engaged ? ArmxCardTone.tinted : ArmxCardTone.surface,
      tint: engaged ? colors.danger : null,
      title: context.l10n.greeterKillSwitch,
      leading: Icon(
        engaged ? Icons.do_not_disturb_on_rounded : Icons.videocam_rounded,
        color: engaged ? colors.dangerText : colors.textMuted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context.l10n.greeterKillSwitchBody,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.md),
          if (engaged)
            ArmxButton(
              label: context.l10n.greeterReleaseKill,
              variant: ArmxButtonVariant.secondary,
              icon: Icons.videocam_rounded,
              loading: busy,
              onPressed: busy ? null : onRelease,
            )
          else
            ArmxButton(
              label: context.l10n.greeterKillSwitch,
              variant: ArmxButtonVariant.destructive,
              icon: Icons.videocam_off_rounded,
              loading: busy,
              onPressed: busy ? null : onEngage,
            ),
        ],
      ),
    );
  }
}
