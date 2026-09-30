// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import 'armx_colors.dart';
import 'armx_typography.dart';
import 'motion.dart';

/// Material 3 [ThemeData] for A.R.M.X AI, dark-first with a matching light variant.
///
/// Design-system rules honoured here and enforced by tests in `test/widget/design_system_test.dart`:
/// * minimum interactive dimension of 48 dp ([minimumTouchTarget]);
/// * WCAG AA text contrast in both themes;
/// * no component theme is set that would fight the signature widgets (the app uses its
///   own glass panels, pills, chips and app bar).
abstract final class ArmxTheme {
  /// Minimum tap target required by the product spec.
  static const double minimumTouchTarget = 48;

  /// Corner radius for panels.
  static const double panelRadius = 18;

  /// Corner radius for pills and chips.
  static const double pillRadius = 999;

  /// The default (dark) theme.
  static ThemeData dark() => _build(ArmxColors.dark, Brightness.dark);

  /// The light theme.
  static ThemeData light() => _build(ArmxColors.light, Brightness.light);

  /// Resolves a stored theme-mode preference name back into a [ThemeMode].
  static ThemeMode themeModeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Serialises a [ThemeMode] for the preferences table.
  static String themeModeToName(ThemeMode mode) => mode.name;

  static ThemeData _build(ArmxColors colors, Brightness brightness) {
    final colorScheme = _colorScheme(colors, brightness);
    final textTheme = ArmxTypography.textTheme(text: colors.text, muted: colors.muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.muted, size: 22),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.panel2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: colors.text),
        waitDuration: const Duration(milliseconds: 600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(minimumTouchTarget, minimumTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minimumTouchTarget, minimumTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minimumTouchTarget, minimumTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: colors.border),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.panel2,
        selectedColor: colors.cyan.withValues(alpha: 0.18),
        side: BorderSide(color: colors.border),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: colors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(pillRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected) ? colors.cyan : colors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (states) => states.contains(WidgetState.selected)
              ? colors.cyan.withValues(alpha: 0.35)
              : colors.panel2,
        ),
        trackOutlineColor: WidgetStateProperty.all<Color>(colors.border),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.cyan,
        inactiveTrackColor: colors.panel2,
        thumbColor: colors.cyan,
        overlayColor: colors.cyan.withValues(alpha: 0.12),
        valueIndicatorColor: colors.panel2,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(color: colors.text),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.cyan,
        linearTrackColor: colors.panel2,
        circularTrackColor: colors.panel2,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.muted,
        textColor: colors.text,
        selectedColor: colors.cyan,
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.panel,
        indicatorColor: colors.cyan.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all<TextStyle?>(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? colors.cyan : colors.muted,
          ),
        ),
        height: 68,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.panel2,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: colors.cyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.panel,
        modalBackgroundColor: colors.panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      pageTransitionsTheme: ArmxMotion.pageTransitions,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }

  static ColorScheme _colorScheme(ArmxColors colors, Brightness brightness) {
    final onAccent = brightness == Brightness.dark
        ? ArmxPalette.darkBackground
        : const Color(0xFFFFFFFF);
    return ColorScheme(
      brightness: brightness,
      primary: colors.cyan,
      onPrimary: onAccent,
      primaryContainer: colors.cyan.withValues(alpha: 0.16),
      onPrimaryContainer: colors.text,
      secondary: colors.violet,
      onSecondary: onAccent,
      secondaryContainer: colors.violet.withValues(alpha: 0.16),
      onSecondaryContainer: colors.text,
      tertiary: colors.violet,
      onTertiary: onAccent,
      error: colors.red,
      onError: brightness == Brightness.dark ? ArmxPalette.darkBackground : Colors.white,
      errorContainer: colors.red.withValues(alpha: 0.16),
      onErrorContainer: colors.text,
      surface: colors.background,
      onSurface: colors.text,
      surfaceContainerHighest: colors.panel2,
      onSurfaceVariant: colors.muted,
      outline: colors.border,
      outlineVariant: colors.border.withValues(alpha: 0.6),
      shadow: Colors.black,
      scrim: colors.scrim,
      inverseSurface: colors.panel2,
      onInverseSurface: colors.text,
    );
  }
}
