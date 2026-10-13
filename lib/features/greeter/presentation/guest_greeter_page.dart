// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../data/api/armx_api.dart';
import '../../../data/models/guest.dart';
import '../application/greeter_controller.dart';
import 'widgets/greeter_camera_preview.dart';

/// The guest greeter.
///
/// ## Layout
///
/// Compact and medium stack: preview, kill-switch, then the roster and recent greetings.
/// Expanded puts the preview beside the roster, so an owner at a desk can watch the door and
/// manage people at the same time. The preview keeps its 4:3 box at every width — a stretched
/// camera image is evidence of nothing.
///
/// ## What this screen refuses to do
///
/// * show a preview when the backend says the camera is off or killed;
/// * enrol anybody without an explicit consent tick, or hide the kill-switch behind a menu;
/// * claim the camera stopped when the backend refused to stop it.
class GuestGreeterPage extends ConsumerWidget {
  /// Creates the page.
  const GuestGreeterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GreeterState> greeter = ref.watch(greeterProvider);
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.greeterTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.person_add_alt_rounded,
            semanticLabel: context.l10n.greeterEnrollOpen,
            onPressed: () => context.go(Routes.guestEnrollment),
          ),
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () {
              ref.read(greeterProvider.notifier).refresh();
              ref.invalidate(guestsProvider);
              ref.invalidate(greeterEventsProvider);
            },
          ),
        ],
      ),
      body: switch (greeter) {
        AsyncLoading<GreeterState>() => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: ArmxSkeletonCard(lines: 4),
          ),
        AsyncError<GreeterState>(:final Object error) => ArmxErrorState(
            error: error,
            onRetry: () => ref.invalidate(greeterProvider),
          ),
        AsyncData<GreeterState>(:final GreeterState value) => _Body(state: value),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final GreeterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool killed = state.camera == GreeterCameraState.killed;

    final Widget left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (killed) ...<Widget>[
          ArmxNotice(
            tone: ArmxBadgeToneLike.danger,
            title: context.l10n.greeterCameraKilled,
            message: context.l10n.greeterKillSwitchBody,
          ),
          const SizedBox(height: Insets.lg),
        ],
        GreeterCameraPreview(
          cameraState: state.camera,
          onRequestAccess: () => _requestCameraPermission(context, ref),
          onCameraFailed: (String message) => ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(SnackBar(content: Text(message))),
        ),
        const SizedBox(height: Insets.lg),
        GreeterKillSwitch(
          engaged: killed,
          busy: false,
          // Engaging is never confirmed: it is the brake, and it must work on the first tap.
          onEngage: () => ref.read(greeterProvider.notifier).kill(),
          onRelease: () => _release(context, ref),
        ),
        const SizedBox(height: Insets.lg),
        ArmxCard(
          title: context.l10n.greeterStoredTitle,
          leading: const Icon(Icons.people_outline_rounded),
          trailing: ArmxBadge(
            label: '${state.enrolledGuestCount}',
            tone: ArmxBadgeTone.neutral,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.greeterEnrollConsentBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.md),
              ArmxButton(
                label: context.l10n.greeterEnrollOpen,
                variant: ArmxButtonVariant.secondary,
                icon: Icons.person_add_alt_rounded,
                onPressed: () => context.go(Routes.guestEnrollment),
              ),
            ],
          ),
        ),
      ],
    );

    const Widget right = _Roster();

    if (!context.isExpanded) {
      return ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: <Widget>[
          Text(
            context.l10n.greeterSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.lg),
          left,
          const SizedBox(height: Insets.xl),
          right,
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.all(context.pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: SingleChildScrollView(child: left),
          ),
          const SizedBox(width: Insets.xl),
          const Expanded(child: SingleChildScrollView(child: right)),
        ],
      ),
    );
  }

  /// Releasing the kill-switch resumes capture, so it is confirmed — the opposite of
  /// engaging it.
  Future<void> _release(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.greeterReleaseKill,
        action: 'greeter_camera',
        target: 'greeter:camera',
        parameters: const <ConfirmParameter>[
          ConfirmParameter(label: 'state', value: 'live'),
        ],
        consequence: context.l10n.greeterKillSwitchBody,
        confirmLabel: context.l10n.greeterReleaseKill,
      ),
    );
    if (confirmed) {
      await ref.read(greeterProvider.notifier).release();
    }
  }

  Future<void> _requestCameraPermission(BuildContext context, WidgetRef ref) async {
    // The permission prompt belongs to the platform; the app routes to it and then re-reads
    // the state, so the preview appears only if it genuinely became available.
    await Permission.camera.request();
    await ref.read(greeterProvider.notifier).refresh();
  }
}

/// Enrolled guests and the recent greetings.
class _Roster extends ConsumerWidget {
  const _Roster();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GuestProfile>> guests = ref.watch(guestsProvider);
    final AsyncValue<List<GreeterEvent>> events = ref.watch(greeterEventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.greeterStoredTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Insets.md),
        switch (guests) {
          AsyncLoading<List<GuestProfile>>() => const ArmxSkeletonCard(lines: 3),
          AsyncError<List<GuestProfile>>(:final Object error) => ArmxErrorState(
              error: error,
              compact: true,
              onRetry: () => ref.invalidate(guestsProvider),
            ),
          AsyncData<List<GuestProfile>>(:final List<GuestProfile> value) =>
            value.isEmpty
                ? ArmxEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: context.l10n.greeterStoredEmpty,
                    message: context.l10n.greeterEnrollConsentBody,
                    compact: true,
                  )
                : Column(
                    children: <Widget>[
                      for (final GuestProfile guest in value) ...<Widget>[
                        _GuestRow(guest: guest),
                        const SizedBox(height: Insets.sm),
                      ],
                    ],
                  ),
        },
        const SizedBox(height: Insets.xl),
        Text(
          context.l10n.greeterEventsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Insets.md),
        switch (events) {
          AsyncLoading<List<GreeterEvent>>() => const ArmxSkeletonCard(lines: 2),
          AsyncError<List<GreeterEvent>>(:final Object error) => ArmxErrorState(
              error: error,
              compact: true,
              onRetry: () => ref.invalidate(greeterEventsProvider),
            ),
          AsyncData<List<GreeterEvent>>(:final List<GreeterEvent> value) =>
            value.isEmpty
                ? ArmxEmptyState(
                    icon: Icons.door_front_door_outlined,
                    title: context.l10n.greeterEventsEmpty,
                    compact: true,
                  )
                : Column(
                    children: <Widget>[
                      for (final GreeterEvent event in value.take(8))
                        _EventRow(event: event),
                    ],
                  ),
        },
      ],
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({required this.guest});

  final GuestProfile guest;

  @override
  Widget build(BuildContext context) {
    return ArmxCard(
      dense: true,
      title: guest.displayName,
      leading: const Icon(Icons.person_outline_rounded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.greeterEnrolledOn(_relative(guest.enrolledAt)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            context.l10n.greeterConsentVersion(guest.consentTextVersion),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (guest.note != null)
            Text(guest.note!, style: Theme.of(context).textTheme.bodySmall),
          // What is held, and where: showing the reference makes "delete" mean a stored
          // template rather than an abstract row.
          if (guest.encryptedTemplateRef != null)
            ArmxDetailRow(
              label: 'ref',
              value: guest.encryptedTemplateRef!,
              monospace: true,
              icon: Icons.enhanced_encryption_outlined,
            ),
        ],
      ),
    );
  }

  String _relative(DateTime when) {
    final Duration age = DateTime.now().toUtc().difference(when.toUtc());
    if (age.inDays >= 1) {
      return context.l10n.commonDays(age.inDays);
    }
    if (age.inHours >= 1) {
      return context.l10n.commonHours(age.inHours);
    }
    if (age.inMinutes >= 1) {
      return context.l10n.commonMinutes(age.inMinutes);
    }
    return context.l10n.commonJustNow;
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final GreeterEvent event;

  @override
  Widget build(BuildContext context) {
    final double? confidence = event.confidence;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(event.guestName, style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  event.occurredAt.toLocal().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              if (confidence != null)
                // A weak match says so instead of presenting a guess as an identification.
                Text(
                  confidence < 0.75
                      ? context.l10n.greeterLowConfidence
                      : context.l10n.greeterConfidence((confidence * 100).round()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 2),
              ArmxStatusDot(
                status: event.greetingSpoken ? ArmxStatus.online : ArmxStatus.unknown,
                label: event.greetingSpoken
                    ? context.l10n.greeterSpoken
                    : context.l10n.greeterNotSpoken,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
