// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/messaging.dart';
import '../application/messaging_controller.dart';
import 'widgets/tone_editor.dart';

/// Per-contact tone and delivery rules.
///
/// The screen is organised around one question — **may the assistant write to this person
/// without me?** Each row answers it, the answer is per contact, and switching it on is the
/// only change here that asks for a confirmation, because it is the only one that can put
/// words in the owner's mouth.
class MessagingPage extends ConsumerStatefulWidget {
  /// Creates the page.
  const MessagingPage({super.key});

  @override
  ConsumerState<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends ConsumerState<MessagingPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Contact>> contacts = ref.watch(contactsProvider);
    final AsyncValue<List<ToneProfile>> tones = ref.watch(toneProfilesProvider);
    final ArmxColors colors = ArmxColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.messagingTitle),
        actions: <Widget>[
          ArmxIconButton(
            icon: Icons.refresh_rounded,
            semanticLabel: context.l10n.commonRefresh,
            onPressed: () {
              ref.read(contactsProvider.notifier).refresh();
              ref.read(toneProfilesProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.messagingSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.lg),
          // Stated before anything can be switched on, not after.
          ArmxNotice(
            tone: ArmxBadgeToneLike.warning,
            message: context.l10n.messagingAutoSendWarning,
          ),
          const SizedBox(height: Insets.lg),
          ArmxTextField(
            label: context.l10n.commonSearch,
            hint: context.l10n.commonSearchHint,
            controller: _search,
            onChanged: (String value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: Insets.xl),
          ArmxCard(
            title: context.l10n.messagingContacts,
            leading: const Icon(Icons.forum_outlined),
            child: switch (contacts) {
              AsyncLoading<List<Contact>>() => const ArmxSkeletonCard(lines: 3),
              AsyncError<List<Contact>>(:final Object error) => ArmxErrorState(
                  error: error,
                  compact: true,
                  onRetry: () => ref.invalidate(contactsProvider),
                ),
              AsyncData<List<Contact>>(:final List<Contact> value) =>
                _contacts(context, value, tones.value ?? const <ToneProfile>[]),
            },
          ),
          const SizedBox(height: Insets.xl),
          ArmxCard(
            title: context.l10n.messagingTones,
            leading: const Icon(Icons.record_voice_over_outlined),
            child: switch (tones) {
              AsyncLoading<List<ToneProfile>>() => const ArmxSkeletonCard(lines: 3),
              AsyncError<List<ToneProfile>>(:final Object error) => ArmxErrorState(
                  error: error,
                  compact: true,
                  onRetry: () => ref.invalidate(toneProfilesProvider),
                ),
              AsyncData<List<ToneProfile>>(:final List<ToneProfile> value) => Column(
                  children: <Widget>[
                    for (final ToneProfile profile in value) ...<Widget>[
                      ToneProfileCard(profile: profile),
                      const SizedBox(height: Insets.md),
                    ],
                  ],
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _contacts(
    BuildContext context,
    List<Contact> all,
    List<ToneProfile> tones,
  ) {
    if (all.isEmpty) {
      return ArmxEmptyState(
        icon: Icons.forum_outlined,
        title: context.l10n.messagingContactsEmpty,
        message: context.l10n.messagingContactsEmptyBody,
        compact: true,
      );
    }

    final List<Contact> shown = _query.isEmpty
        ? all
        : all
            .where((Contact c) =>
                c.displayName.toLowerCase().contains(_query.toLowerCase()))
            .toList(growable: false);

    if (shown.isEmpty) {
      return ArmxEmptyState(
        icon: Icons.search_off_rounded,
        title: context.l10n.commonNoResults,
        actionLabel: context.l10n.commonReset,
        onAction: () {
          _search.clear();
          setState(() => _query = '');
        },
        compact: true,
      );
    }

    return Column(
      children: <Widget>[
        for (final Contact contact in shown) ...<Widget>[
          _ContactCard(
            contact: contact,
            tone: tones
                .where((ToneProfile p) => p.id == contact.toneProfileId)
                .firstOrNull,
            onDeliveryModeChanged: (DeliveryMode mode) =>
                _changeDeliveryMode(context, contact, mode),
            onBlockedChanged: (bool blocked) =>
                _persist(context, contact.copyWith(blocked: blocked)),
          ),
          const SizedBox(height: Insets.md),
        ],
      ],
    );
  }

  /// Switching a contact *to* automatic sending is confirmed; switching back is not.
  ///
  /// The asymmetry is deliberate: relaxing a privacy rule deserves a prompt, tightening one
  /// should never be in the way.
  Future<void> _changeDeliveryMode(
    BuildContext context,
    Contact contact,
    DeliveryMode mode,
  ) async {
    if (mode == DeliveryMode.autoSend) {
      final bool confirmed = await ConfirmPolicy.confirm(
        context,
        ConfirmPolicy.forAction(
          context,
          title: context.l10n.messagingAutoSend,
          action: 'set_delivery_mode',
          target: contact.displayName,
          parameters: <ConfirmParameter>[
            ConfirmParameter(label: 'contact_id', value: contact.id, monospace: true),
            ConfirmParameter(label: 'channel', value: contact.channel),
            ConfirmParameter(label: 'delivery_mode', value: mode.wire, monospace: true),
          ],
          consequence: context.l10n.messagingAutoSendWarning,
          confirmLabel: context.l10n.messagingAutoSend,
        ),
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }
    await _persist(context, contact.copyWith(deliveryMode: mode));
  }

  Future<void> _persist(BuildContext context, Contact contact) async {
    try {
      await ref.read(contactsProvider.notifier).update(contact);
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.tone,
    required this.onDeliveryModeChanged,
    required this.onBlockedChanged,
  });

  final Contact contact;
  final ToneProfile? tone;
  final ValueChanged<DeliveryMode> onDeliveryModeChanged;
  final ValueChanged<bool> onBlockedChanged;

  @override
  Widget build(BuildContext context) {
    final bool auto = contact.deliveryMode == DeliveryMode.autoSend;
    final ArmxColors colors = ArmxColors.of(context);

    return ArmxCard(
      tone: auto ? ArmxCardTone.tinted : ArmxCardTone.surface,
      tint: auto ? colors.warning : null,
      title: contact.displayName,
      semanticLabel: '${contact.displayName}. '
          '${auto ? context.l10n.messagingAutoSend : context.l10n.messagingDraftOnly}',
      leading: Icon(
        contact.blocked ? Icons.block_rounded : Icons.person_outline_rounded,
        color: contact.blocked ? colors.dangerText : colors.textMuted,
      ),
      trailing: ArmxBadge(
        label:
            auto ? context.l10n.messagingAutoSend : context.l10n.messagingDraftOnly,
        tone: auto ? ArmxBadgeTone.warning : ArmxBadgeTone.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (contact.tag != null) ...<Widget>[
            ArmxBadge(label: contact.tag!, tone: ArmxBadgeTone.neutral),
            const SizedBox(height: Insets.sm),
          ],
          if (tone != null)
            Text(
              '${context.l10n.messagingContactTone}: ${tone!.name} · '
              '${context.l10n.messagingFormality} ${tone!.formality}/5 · '
              '${context.l10n.messagingWarmth} ${tone!.warmth}/5',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: Insets.md),
          ArmxSwitchRow(
            title: context.l10n.messagingAutoSend,
            subtitle: context.l10n.messagingAutoSendWarning,
            value: auto,
            onChanged: (bool value) => onDeliveryModeChanged(
              value ? DeliveryMode.autoSend : DeliveryMode.draftOnly,
            ),
          ),
          ArmxSwitchRow(
            title: context.l10n.messagingBlockContact,
            value: contact.blocked,
            icon: Icons.block_rounded,
            onChanged: onBlockedChanged,
          ),
        ],
      ),
    );
  }
}
