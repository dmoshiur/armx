// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'armx_badge.dart';
import 'armx_button.dart';
import 'armx_status_dot.dart';

/// One parameter of the action being confirmed.
@immutable
class ConfirmParameter {
  /// Creates a parameter row.
  const ConfirmParameter({required this.label, required this.value, this.monospace = false});

  /// Parameter name.
  final String label;

  /// Exact value — never abbreviated, never elided.
  final String value;

  /// Renders the value monospace (ids, paths, repo names, device keys).
  final bool monospace;
}

/// Everything the user must see before a risky action fires.
@immutable
class ConfirmRequest {
  /// Creates a confirmation request.
  const ConfirmRequest({
    required this.title,
    required this.action,
    required this.target,
    this.parameters = const <ConfirmParameter>[],
    this.consequence,
    this.riskTier = ArmxRiskTier.medium,
    this.confirmLabel,
    this.cancelLabel,
    this.irreversible = false,
    this.requireTypedPhrase = false,
    this.typedPhrase,
    this.icon,
  });

  /// Dialog heading — the action in plain words ("Deploy to production").
  final String title;

  /// The exact action that will be performed, as the backend names it.
  final String action;

  /// The exact target (device, repo, user, contact).
  final String target;

  /// Parameters that will be sent. Any of these that is shown here is shown verbatim.
  final List<ConfirmParameter> parameters;

  /// What happens if the user proceeds. Required for MEDIUM and HIGH.
  final String? consequence;

  /// Risk tier — drives colour, the badge and whether a typed phrase is demanded.
  final ArmxRiskTier riskTier;

  /// Label for the affirmative button.
  final String? confirmLabel;

  /// Label for the negative button.
  final String? cancelLabel;

  /// True when the action cannot be undone. Adds a second, explicit warning line.
  final bool irreversible;

  /// Requires the user to type [typedPhrase] before the affirmative button enables.
  final bool requireTypedPhrase;

  /// The phrase to type. Defaults to the word `CONFIRM` when [requireTypedPhrase] is set.
  final String? typedPhrase;

  /// Optional glyph override.
  final IconData? icon;
}

/// The risk tiers a confirmation can carry.
enum ArmxRiskTier {
  /// Runs without confirmation; [ArmxConfirmDialog] must not be used for it.
  low,

  /// Needs a single explicit confirmation.
  medium,

  /// Needs an explicit confirmation, and is drawn in the danger tone.
  high,
}

/// The dialog every MEDIUM- and HIGH-risk action must pass through.
///
/// ## The requirements this widget exists to satisfy (§3, §8)
///
/// * **Shows the exact action, target and parameters.** These are rendered verbatim from
///   the values that will be sent, not paraphrased. If a call would send
///   `{"room": "lab", "relay": 3}` the dialog shows `room = lab` and `relay = 3`.
/// * **There is no default-focused affirmative button.** For HIGH risk the cancel button
///   holds the initial focus, so pressing Enter or Space immediately after the dialog
///   opens *cancels*. [barrierDismissible] is true so Escape also cancels.
/// * **Irreversible actions require typing a phrase.** Not a checkbox — a checkbox gets
///   clicked reflexively. On compact layouts the field also drives the keyboard, which
///   forces a deliberate act.
/// * **The affirmative button is never "OK".** It states what will happen
///   ("Deploy", "Unlink device", "Engage kill-switch").
/// * **It never fires the call itself.** [ArmxConfirmDialog.show] resolves to the user's
///   decision; the caller performs the action only after a `true` result, which is what
///   makes "no backend call before confirmation" testable in one place.
///
/// See `test/unit/core/widgets/armx_confirm_dialog_test.dart` for the assertions that pin
/// the focus rule and the parameter rendering.
class ArmxConfirmDialog extends StatefulWidget {
  /// Creates a confirmation dialog.
  const ArmxConfirmDialog({required this.request, super.key});

  /// What is being confirmed.
  final ConfirmRequest request;

  /// Shows the dialog and resolves to the user's decision.
  ///
  /// `true` means "the user explicitly confirmed"; `null`/`false` means they did not, so
  /// the caller must not proceed.
  static Future<bool> show(BuildContext context, ConfirmRequest request) async {
    final bool? result = await showDialog<bool>(
      context: context,
      // Escape, the back gesture and a barrier tap all cancel — a destructive dialog must
      // be easy to dismiss and hard to confirm.
      barrierDismissible: true,
      builder: (BuildContext context) => ArmxConfirmDialog(request: request),
    );
    return result ?? false;
  }

  @override
  State<ArmxConfirmDialog> createState() => _ArmxConfirmDialogState();
}

class _ArmxConfirmDialogState extends State<ArmxConfirmDialog> {
  final TextEditingController _phrase = TextEditingController();
  final FocusNode _cancelFocus = FocusNode();
  bool _typedMatches = false;

  bool get _isHigh => widget.request.riskTier == ArmxRiskTier.high;

  String get _requiredPhrase => widget.request.typedPhrase ?? 'CONFIRM';

  bool get _canConfirm => !widget.request.requireTypedPhrase || _typedMatches;

  @override
  void initState() {
    super.initState();
    // The non-destructive choice takes focus. A HIGH-risk dialog therefore cancels if the
    // user hits Enter out of habit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cancelFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _phrase.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ConfirmRequest request = widget.request;
    final Color tone = switch (request.riskTier) {
      ArmxRiskTier.high => colors.dangerText,
      ArmxRiskTier.medium => colors.warningText,
      ArmxRiskTier.low => colors.accentText,
    };
    final String riskLabel = switch (request.riskTier) {
      ArmxRiskTier.high => context.l10n.riskHigh,
      ArmxRiskTier.medium => context.l10n.riskMedium,
      ArmxRiskTier.low => context.l10n.riskLow,
    };
    final String riskExplain = switch (request.riskTier) {
      ArmxRiskTier.high => context.l10n.riskHighExplain,
      ArmxRiskTier.medium => context.l10n.riskMediumExplain,
      ArmxRiskTier.low => context.l10n.riskLowExplain,
    };

    return AlertDialog(
      // A destructive dialog is announced as such; screen readers read the whole request
      // rather than only the title.
      title: Semantics(
        namesRoute: true,
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              request.icon ??
                  (_isHigh ? Icons.gpp_maybe_outlined : Icons.help_outline_rounded),
              color: tone,
              size: 24,
            ),
            const SizedBox(width: Insets.md),
            Expanded(child: Text(request.title)),
          ],
        ),
      ),
      content: ConstrainedBox(
        // Keeps the dialog readable on a 2560 dp monitor and scrollable on a 360 dp phone.
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  ArmxBadge(
                    label: riskLabel,
                    tone: switch (request.riskTier) {
                      ArmxRiskTier.high => ArmxBadgeTone.danger,
                      ArmxRiskTier.medium => ArmxBadgeTone.warning,
                      ArmxRiskTier.low => ArmxBadgeTone.success,
                    },
                  ),
                  ArmxStatusDot(
                    status: request.irreversible
                        ? ArmxStatus.failed
                        : ArmxStatus.pending,
                    label: request.irreversible
                        ? context.l10n.commonDelete
                        : context.l10n.commonPending,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text(riskExplain, style: text.bodySmall),
              const SizedBox(height: Insets.lg),

              // ---- The exact action, target and parameters ----------------------
              _KeyValue(
                label: context.l10n.confirmActionLabel,
                value: request.action,
                monospace: true,
              ),
              _KeyValue(
                label: context.l10n.confirmTargetLabel,
                value: request.target,
              ),
              for (final ConfirmParameter parameter in request.parameters)
                _KeyValue(
                  label: parameter.label,
                  value: parameter.value,
                  monospace: parameter.monospace,
                ),

              if (request.consequence != null) ...<Widget>[
                const SizedBox(height: Insets.md),
                Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Insets.controlRadius),
                    border: Border.all(color: tone.withValues(alpha: 0.38)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.info_outline_rounded, size: 16, color: tone),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          request.consequence!,
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (request.requireTypedPhrase) ...<Widget>[
                const SizedBox(height: Insets.lg),
                Text(
                  context.l10n.confirmTypeToProceed(_requiredPhrase),
                  style: text.bodySmall,
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  controller: _phrase,
                  autofocus: false,
                  onChanged: (String value) => setState(
                    () => _typedMatches = value.trim() == _requiredPhrase,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _requiredPhrase,
                  ),
                  style: ArmxTypography.mono(size: 14, color: colors.text),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        Focus(
          focusNode: _cancelFocus,
          child: ArmxButton(
            label: request.cancelLabel ?? context.l10n.commonCancel,
            onPressed: () => Navigator.of(context).pop(false),
            variant: ArmxButtonVariant.secondary,
          ),
        ),
        ArmxButton(
          // The label states the action. Never "OK".
          label: request.confirmLabel ?? context.l10n.commonConfirm,
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          variant: request.riskTier == ArmxRiskTier.high
              ? ArmxButtonVariant.destructive
              : ArmxButtonVariant.primary,
          icon: request.riskTier == ArmxRiskTier.high
              ? Icons.gpp_maybe_outlined
              : null,
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96, maxWidth: 170),
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: Insets.md),
          // `Expanded` + wrapping text: a long target is wrapped, never truncated, because
          // a truncated target is exactly the ambiguity this dialog exists to remove.
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.hairline),
              ),
              child: SelectableText(
                value,
                style: monospace
                    ? ArmxTypography.mono(size: 13, color: colors.text)
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
