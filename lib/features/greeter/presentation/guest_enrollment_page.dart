// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/guest.dart';
import '../application/greeter_controller.dart';

/// Enrolling a person — deliberately separated from the live greeter.
///
/// Consent lives in its own flow: the camera screen never enrols anybody, and this screen
/// never captures. The rules it enforces:
///
/// * **Consent is a gate, not decoration.** Enrolment stays disabled until the box is ticked,
///   and the wording version is recorded with the guest so a later change to the text is
///   visible in the data.
/// * **Deleting is real and individual.** Removing a guest deletes the name and the template
///   reference, is confirmed (it cannot be undone), and is offered per person — never as a
///   "clear all" button that is easy to hit by accident.
/// * **A killed camera blocks enrolment**, because enrolling somebody means capturing them.
class GuestEnrollmentPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const GuestEnrollmentPage({super.key});

  @override
  ConsumerState<GuestEnrollmentPage> createState() => _GuestEnrollmentPageState();
}

class _GuestEnrollmentPageState extends ConsumerState<GuestEnrollmentPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _nameError;
  AppException? _failure;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool killed =
        ref.watch(greeterProvider).value?.camera == GreeterCameraState.killed;
    final bool blocked = killed || !_consent;

    return Scaffold(
      backgroundColor: ArmxColors.of(context).background,
      appBar: AppBar(title: Text(context.l10n.greeterEnrollTitle)),
      body: ListView(
        padding: EdgeInsets.all(context.pagePadding),
        children: <Widget>[
          ArmxCard(
            tone: ArmxCardTone.tinted,
            title: context.l10n.greeterEnrollConsentTitle,
            leading: const Icon(Icons.verified_user_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.greeterEnrollConsentBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.md),
                ArmxSwitchRow(
                  title: context.l10n.greeterEnrollConsentCheck,
                  value: _consent,
                  onChanged: (bool value) => setState(() => _consent = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          if (killed)
            ArmxNotice(
              tone: ArmxBadgeToneLike.warning,
              message: context.l10n.greeterEnrollBlockedKill,
            )
          else if (!_consent)
            ArmxNotice(
              tone: ArmxBadgeToneLike.info,
              message: context.l10n.greeterEnrollNeedsConsent,
            ),
          const SizedBox(height: Insets.lg),
          if (_failure != null) ...<Widget>[
            ArmxErrorState(error: _failure, compact: true),
            const SizedBox(height: Insets.lg),
          ],
          ArmxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ArmxTextField(
                  label: context.l10n.greeterEnrollName,
                  controller: _name,
                  errorText: _nameError,
                  enabled: !blocked && !_busy,
                  required: true,
                  maxLength: 80,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
                const SizedBox(height: Insets.lg),
                ArmxTextField(
                  label: context.l10n.greeterEnrollNote,
                  hint: context.l10n.greeterEnrollNoteHint,
                  controller: _note,
                  enabled: !blocked && !_busy,
                  maxLength: 140,
                  maxLines: 2,
                ),
                const SizedBox(height: Insets.lg),
                ArmxButton(
                  label: context.l10n.greeterEnrollAction,
                  icon: Icons.person_add_alt_rounded,
                  loading: _busy,
                  // Disabled with the reason spelled out above, rather than hidden.
                  onPressed: blocked || _busy ? null : _enroll,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          const _EnrolledList(),
        ],
      ),
    );
  }

  Future<void> _enroll() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.l10n.validatorRequired);
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(guestsProvider.notifier).enroll(
            displayName: name,
            consentGiven: _consent,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) {
        return;
      }
      _name.clear();
      _note.clear();
      setState(() => _consent = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.greeterEnrolledDone)),
      );
    } on AppException catch (error) {
      setState(() => _failure = error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _EnrolledList extends ConsumerWidget {
  const _EnrolledList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GuestProfile>> guests = ref.watch(guestsProvider);

    return ArmxCard(
      title: context.l10n.greeterStoredTitle,
      leading: const Icon(Icons.people_outline_rounded),
      child: switch (guests) {
        AsyncLoading<List<GuestProfile>>() => const ArmxSkeletonCard(lines: 2),
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
                  compact: true,
                )
              : Column(
                  children: <Widget>[
                    for (final GuestProfile guest in value) ...<Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  guest.displayName,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(
                                  context.l10n.greeterConsentVersion(
                                    guest.consentTextVersion,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          ArmxButton(
                            label: context.l10n.greeterDeleteAction,
                            variant: ArmxButtonVariant.destructive,
                            size: ArmxButtonSize.small,
                            icon: Icons.delete_outline_rounded,
                            onPressed: () => _delete(context, ref, guest),
                          ),
                        ],
                      ),
                      const Divider(height: Insets.xl),
                    ],
                  ],
                ),
      },
    );
  }

  /// Deleting a person's enrolment touches their data and cannot be undone: HIGH risk, named,
  /// with the typed phrase required.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    GuestProfile guest,
  ) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.greeterDeleteTitle(guest.displayName),
        action: 'delete_guest',
        target: guest.displayName,
        parameters: <ConfirmParameter>[
          ConfirmParameter(label: 'guest_id', value: guest.id, monospace: true),
          ConfirmParameter(
            label: 'consent_version',
            value: guest.consentTextVersion,
          ),
          ConfirmParameter(
            label: 'template_ref',
            value: guest.encryptedTemplateRef ?? 'none',
            monospace: true,
          ),
        ],
        consequence: context.l10n.greeterDeleteBody,
        irreversible: true,
        requireTypedPhrase: true,
        confirmLabel: context.l10n.greeterDeleteAction,
      ),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(guestsProvider.notifier).delete(guest.id);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}
