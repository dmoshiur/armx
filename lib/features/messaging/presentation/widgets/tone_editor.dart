// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_button.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../core/widgets/armx_text_field.dart';
import '../../../../data/models/messaging.dart';
import '../../application/messaging_controller.dart';

/// A read-first view of one tone profile, with the editor behind an explicit action.
///
/// Profiles are read far more often than they are changed, so the card describes the profile
/// in labelled numbers first and offers editing second. "How will it write to her?" should be
/// answerable at a glance, which a row of nameless sliders is not.
class ToneProfileCard extends ConsumerWidget {
  /// Creates the card.
  const ToneProfileCard({required this.profile, super.key});

  /// The profile.
  final ToneProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ArmxCard(
      title: profile.name,
      leading: const Icon(Icons.record_voice_over_outlined),
      trailing: ArmxBadge(
        label: profile.tag,
        tone: ArmxBadgeTone.secondary,
        icon: Icons.sell_outlined,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Meter(label: context.l10n.messagingFormality, value: profile.formality),
          _Meter(label: context.l10n.messagingWarmth, value: profile.warmth),
          _Meter(label: context.l10n.messagingVerbosity, value: profile.verbosity),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            children: <Widget>[
              ArmxBadge(
                label: profile.emojiAllowed
                    ? context.l10n.messagingEmoji
                    : context.l10n.commonDisabled,
                tone: profile.emojiAllowed
                    ? ArmxBadgeTone.success
                    : ArmxBadgeTone.neutral,
                icon: Icons.emoji_emotions_outlined,
              ),
              ArmxBadge(
                label: profile.languageCode.toUpperCase(),
                tone: ArmxBadgeTone.neutral,
                icon: Icons.translate_rounded,
              ),
            ],
          ),
          if (profile.forbiddenTopics.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              context.l10n.messagingForbiddenTopics,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final String topic in profile.forbiddenTopics)
                  ArmxBadge(
                    label: topic,
                    tone: ArmxBadgeTone.danger,
                    icon: Icons.block_rounded,
                  ),
              ],
            ),
          ],
          const SizedBox(height: Insets.md),
          ArmxButton(
            label: context.l10n.commonEdit,
            variant: ArmxButtonVariant.secondary,
            size: ArmxButtonSize.small,
            icon: Icons.tune_rounded,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext context) => ToneEditorSheet(profile: profile),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled 1–5 meter: the bar is decoration beside the number, never instead of it.
class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final int clamped = value.clamp(0, 5);
    final ArmxColors colors = ArmxColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Row(
            children: <Widget>[
              for (int step = 1; step <= 5; step++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 3),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step <= clamped ? colors.accent : colors.hairline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 32,
            child: Text(
              '$clamped/5',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Edits one tone profile.
///
/// Saving is a straight write of what the user assembled: nothing here is destructive, so
/// there is no confirmation dialog — but the sheet stays open and shows the failure if the
/// backend refuses, rather than closing as though it had saved.
class ToneEditorSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ToneEditorSheet({required this.profile, super.key});

  /// The profile being edited.
  final ToneProfile profile;

  @override
  ConsumerState<ToneEditorSheet> createState() => _ToneEditorSheetState();
}

class _ToneEditorSheetState extends ConsumerState<ToneEditorSheet> {
  late ToneProfile _draft = widget.profile;
  final TextEditingController _topic = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          Insets.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                context.l10n.messagingTones,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Insets.lg),
              ArmxTextField(
                label: context.l10n.messagingToneName,
                initialValue: _draft.name,
                enabled: !_busy,
                onChanged: (String value) =>
                    _draft = _draft.copyWith(name: value),
              ),
              const SizedBox(height: Insets.lg),
              _TraitSlider(
                label: context.l10n.messagingFormality,
                value: _draft.formality,
                onChanged: _busy
                    ? null
                    : (int value) =>
                        setState(() => _draft = _draft.copyWith(formality: value)),
              ),
              _TraitSlider(
                label: context.l10n.messagingWarmth,
                value: _draft.warmth,
                onChanged: _busy
                    ? null
                    : (int value) =>
                        setState(() => _draft = _draft.copyWith(warmth: value)),
              ),
              _TraitSlider(
                label: context.l10n.messagingVerbosity,
                value: _draft.verbosity,
                onChanged: _busy
                    ? null
                    : (int value) =>
                        setState(() => _draft = _draft.copyWith(verbosity: value)),
              ),
              const SizedBox(height: Insets.md),
              ArmxSwitchRow(
                title: context.l10n.messagingEmoji,
                value: _draft.emojiAllowed,
                enabled: !_busy,
                onChanged: (bool value) =>
                    setState(() => _draft = _draft.copyWith(emojiAllowed: value)),
              ),
              const SizedBox(height: Insets.md),
              Text(
                context.l10n.messagingLanguage,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: <Widget>[
                  ArmxChip(
                    label: context.l10n.messagingLanguageAuto,
                    selected: _draft.languageCode == 'auto',
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                              () => _draft = _draft.copyWith(languageCode: 'auto'),
                            ),
                  ),
                  ArmxChip(
                    label: context.l10n.settingsLanguageEnglish,
                    selected: _draft.languageCode == 'en',
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                              () => _draft = _draft.copyWith(languageCode: 'en'),
                            ),
                  ),
                  ArmxChip(
                    label: context.l10n.settingsLanguageBengali,
                    selected: _draft.languageCode == 'bn',
                    onSelected: _busy
                        ? null
                        : (_) => setState(
                              () => _draft = _draft.copyWith(languageCode: 'bn'),
                            ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              Text(
                context.l10n.messagingForbiddenTopics,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: Insets.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ArmxTextField(
                      label: context.l10n.messagingForbiddenTopics,
                      hint: context.l10n.messagingForbiddenHint,
                      controller: _topic,
                      enabled: !_busy,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  ArmxButton(
                    label: context.l10n.messagingAddTopic,
                    variant: ArmxButtonVariant.secondary,
                    onPressed: _busy ? null : _addTopic,
                  ),
                ],
              ),
              if (_draft.forbiddenTopics.isNotEmpty) ...<Widget>[
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    for (final String topic in _draft.forbiddenTopics)
                      ArmxChip(
                        label: '${topic} ✕',
                        selected: true,
                        semanticLabel: '${context.l10n.commonRemove} $topic',
                        onSelected: _busy
                            ? null
                            : (_) => setState(
                                  () => _draft = _draft.copyWith(
                                    forbiddenTopics: _draft.forbiddenTopics
                                        .where((String t) => t != topic)
                                        .toList(growable: false),
                                  ),
                                ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Insets.xl),
              Wrap(
                spacing: Insets.md,
                runSpacing: Insets.md,
                children: <Widget>[
                  ArmxButton(
                    label: context.l10n.commonSave,
                    icon: Icons.check_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : _save,
                  ),
                  ArmxButton(
                    label: context.l10n.commonCancel,
                    variant: ArmxButtonVariant.ghost,
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addTopic() {
    final String topic = _topic.text.trim();
    if (topic.isEmpty || _draft.forbiddenTopics.contains(topic)) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        forbiddenTopics: <String>[..._draft.forbiddenTopics, topic],
      );
      _topic.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(toneProfilesProvider.notifier).save(_draft);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _TraitSlider extends StatelessWidget {
  const _TraitSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final int clamped = value.clamp(1, 5);
    return Semantics(
      label: label,
      value: '$clamped',
      slider: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text('$clamped/5', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          Slider(
            value: clamped.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$clamped',
            onChanged: onChanged == null
                ? null
                : (double raw) => onChanged!(raw.round()),
          ),
        ],
      ),
    );
  }
}
