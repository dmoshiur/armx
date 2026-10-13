// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// The one text input in the app.
///
/// Wraps [TextFormField] with the design system's label/helper/error presentation and adds
/// the behaviours the spec requires:
///
/// * **Password reveal toggle** for [obscureText] fields, with a localized accessible name
///   that reflects the current state (`Show password` / `Hide password`).
/// * **Inline validation** — the error is rendered under the field *and* announced to
///   screen readers via [Semantics.liveRegion], so a validation failure is not
///   communicated by a red outline alone.
/// * **48 dp minimum height** so the field is a legal touch target on compact layouts.
/// * **Autofill hints and keyboard types** set from one place, so password managers and
///   the correct on-screen keyboard work on every platform.
class ArmxTextField extends StatefulWidget {
  /// Creates a text field.
  const ArmxTextField({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.focusNode,
    this.semanticLabel,
    this.required = false,
    super.key,
  })  : assert(
          controller == null || initialValue == null,
          'Pass either a controller or an initialValue, not both.',
        ),
        assert(
          !obscureText || maxLines == 1,
          'An obscured field must be single-line.',
        );

  /// Field label, always visible (never a placeholder-only field).
  final String label;

  /// External controller.
  final TextEditingController? controller;

  /// Initial text when no controller is supplied.
  final String? initialValue;

  /// Placeholder text shown when empty.
  final String? hint;

  /// Supporting line under the field, replaced by [errorText] when invalid.
  final String? helper;

  /// Error message. Usually produced by [validator] rather than passed directly.
  final String? errorText;

  /// Validation rule; its message is shown inline.
  final String? Function(String?)? validator;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Obscures the value and shows the reveal toggle.
  final bool obscureText;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Keyboard action button.
  final TextInputAction? textInputAction;

  /// Autofill hints, so the platform password manager recognises the field.
  final Iterable<String>? autofillHints;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Leading glyph.
  final Widget? prefixIcon;

  /// Trailing widget; ignored for obscured fields, which own their trailing toggle.
  final Widget? suffix;

  /// Whether the field accepts input.
  final bool enabled;

  /// Renders the value as read-only (still selectable and focusable).
  final bool readOnly;

  /// Requests focus on first build.
  final bool autofocus;

  /// Maximum visible lines. `null` grows without bound.
  final int? maxLines;

  /// Minimum visible lines.
  final int? minLines;

  /// Character ceiling, with a live counter once 75 % is reached.
  final int? maxLength;

  /// External focus node.
  final FocusNode? focusNode;

  /// Overrides the accessible name when the label alone is ambiguous.
  final String? semanticLabel;

  /// Marks the field as required, appending a visible cue and a semantic flag.
  final bool required;

  @override
  State<ArmxTextField> createState() => _ArmxTextFieldState();
}

class _ArmxTextFieldState extends State<ArmxTextField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialValue);
  bool _obscured = true;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _obscured = widget.obscureText;
  }

  @override
  void dispose() {
    // Only dispose what we created — an externally owned controller outlives this widget.
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final String label = widget.required ? '${widget.label} *' : widget.label;

    final Widget field = TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: widget.hint,
        helperText: widget.helper,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        // The counter is noise until it matters; only show it near the ceiling.
        counterText: widget.maxLength == null
            ? null
            : _controller.text.length > widget.maxLength! * 0.75
                ? null
                : '',
        suffixIcon: widget.obscureText
            ? ArmxIconToggle(
                icon: _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                semanticLabel: _obscured
                    ? context.l10n.a11yPasswordVisible
                    : context.l10n.a11yPasswordHidden,
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : widget.suffix,
      ),
    );

    // Validation errors are announced, not merely coloured. Without this a screen-reader
    // user gets no signal that the form refused their input.
    return Semantics(
      liveRegion: true,
      textField: false,
      label: widget.semanticLabel,
      child: field,
    );
  }
}

/// A small square toggle used inside input suffixes.
///
/// Keeps the 48 dp target so the reveal button is as easy to hit as the field itself.
class ArmxIconToggle extends StatelessWidget {
  /// Creates a toggle.
  const ArmxIconToggle({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  /// Glyph to draw.
  final IconData icon;

  /// Accessible name describing the *current* state.
  final String semanticLabel;

  /// Invoked on tap.
  final VoidCallback? onPressed;

  /// Renders the selected treatment.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return SizedBox(
      width: Insets.minTouchTarget,
      height: Insets.minTouchTarget,
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: true,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: colors.textMuted,
          tooltip: semanticLabel,
          splashRadius: 22,
        ),
      ),
    );
  }
}

/// A labelled switch row whose label is part of the hit target.
///
/// Used by Settings, the admin tool toggles and the messaging
/// auto-send/draft-only control. The whole row toggles — a 48 dp-high switch alone is a
/// needlessly small target on a phone.
class ArmxSwitchRow extends StatelessWidget {
  /// Creates a switch row.
  const ArmxSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  });

  /// Row title.
  final String title;

  /// Current value.
  final bool value;

  /// Invoked with the new value.
  final ValueChanged<bool>? onChanged;

  /// Optional supporting line.
  final String? subtitle;

  /// Optional leading glyph.
  final IconData? icon;

  /// Whether the row accepts input.
  final bool enabled;

  /// Overrides the accessible name.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final bool interactive = enabled && onChanged != null;

    return Semantics(
      toggled: value,
      enabled: interactive,
      label: semanticLabel ?? title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Insets.controlRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: interactive ? () => onChanged!(!value) : null,
          hoverColor: colors.accent.withValues(alpha: 0.07),
          focusColor: colors.accent.withValues(alpha: 0.14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Insets.minTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.sm,
              ),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(
                      icon,
                      size: 20,
                      color: interactive ? colors.textMuted : colors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: Insets.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: text.bodyLarge?.copyWith(
                            color: interactive ? colors.text : colors.textMuted,
                          ),
                        ),
                        if (subtitle != null)
                          Text(subtitle!, style: text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  // The state is also written as text so the control never depends on the
                  // switch colour alone (§7).
                  Text(
                    value ? context.l10n.commonOn : context.l10n.commonOff,
                    style: text.labelMedium,
                  ),
                  const SizedBox(width: Insets.sm),
                  IgnorePointer(
                    child: Switch(
                      value: value,
                      onChanged: interactive ? (_) {} : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
