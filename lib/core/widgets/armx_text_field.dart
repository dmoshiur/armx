// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';

/// Branded text field. Styles `InputDecoration` inline so no theme extension is required
/// and the app stays compatible across Flutter versions.
class ArmxTextField extends StatelessWidget {
  /// Creates a text field.
  const ArmxTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.obscure = false,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    super.key,
  });

  /// Text controller.
  final TextEditingController controller;

  /// Field label.
  final String label;

  /// Placeholder text.
  final String? hint;

  /// Helper text under the field.
  final String? helper;

  /// Error text (localized); non-null renders the error state.
  final String? errorText;

  /// Obscures input (passwords, tokens).
  final bool obscure;

  /// Whether the field accepts input.
  final bool enabled;

  /// Maximum lines (`1` renders single-line).
  final int maxLines;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Keyboard action button.
  final TextInputAction? textInputAction;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Leading icon.
  final IconData? prefixIcon;

  /// Trailing widget.
  final Widget? suffix;

  /// Change handler.
  final ValueChanged<String>? onChanged;

  /// Submit handler.
  final ValueChanged<String>? onSubmitted;

  /// Optional focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final hasError = errorText != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: Theme.of(context).textTheme.bodyLarge,
        cursorColor: colors.cyan,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          errorText: errorText,
          filled: true,
          fillColor: colors.panel.withValues(alpha: colors.isDark ? 0.85 : 1),
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.cyan, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.red, width: 1.6),
          ),
          errorStyle: TextStyle(color: colors.red, fontSize: 12.5),
          helperStyle: TextStyle(color: colors.muted, fontSize: 12.5),
          labelStyle: TextStyle(color: hasError ? colors.red : colors.muted),
          floatingLabelStyle: TextStyle(color: hasError ? colors.red : colors.cyan),
        ),
      ),
    );
  }
}
