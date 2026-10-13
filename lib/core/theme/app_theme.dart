// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Shared spacing and radius steps.
///
/// Screens compose with these instead of inventing values, which is what keeps card
/// padding, gaps and corner radii identical across fourteen screens.
abstract final class Insets {
  /// 4 dp — hairline gaps between a label and its value.
  static const double xs = 4;

  /// 8 dp — inside compact chips and between list-tile lines.
  static const double sm = 8;

  /// 12 dp — the tightest card padding in the system.
  static const double md = 12;

  /// 16 dp — the default card padding and page gutter on phones.
  static const double lg = 16;

  /// 24 dp — the generous card padding and page gutter on desktop.
  static const double xl = 24;

  /// 32 dp — section separation.
  static const double xxl = 32;

  /// 48 dp — the minimum interactive target on compact layouts.
  static const double minTouchTarget = 48;

  /// Card corner radius.
  static const double cardRadius = 14;

  /// Control (button, field) corner radius.
  static const double controlRadius = 10;

  /// Chip / badge corner radius.
  static const double chipRadius = 8;

  /// Dialog corner radius.
  static const double dialogRadius = 18;
}

/// Motion timings. `MediaQuery.disableAnimations` (reduce-motion) collapses these to zero
/// via [Motion.durationOf], so no widget has to special-case it.
abstract final class Motion {
  /// Quick state change: hover, press, focus.
  static const Duration fast = Duration(milliseconds: 120);

  /// Standard transition: sheets, expansions, page-level fades.
  static const Duration standard = Duration(milliseconds: 220);

  /// Slower, deliberate motion: the assistant orb, skeleton shimmer.
  static const Duration slow = Duration(milliseconds: 420);

  /// [duration], or [Duration.zero] when the platform asks for reduced motion.
  static Duration durationOf(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Builds the two [ThemeData] instances the app runs on.
///
/// Dark is the product default. Light swaps `ink`/`navy` for `fog`/white and keeps
/// `accent #5B8CFF` and `accent2 #8B5CF6` identical, exactly as specified.
abstract final class AppTheme {
  /// The dark theme (default).
  static ThemeData dark() => _build(ArmxColors.dark, Brightness.dark);

  /// The light theme.
  static ThemeData light() => _build(ArmxColors.light, Brightness.light);

  static ThemeData _build(ArmxColors c, Brightness brightness) {
    final TextTheme text = ArmxTypography.textTheme(
      text: c.text,
      muted: c.textMuted,
    );

    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accent.withValues(alpha: c.isDark ? 0.18 : 0.12),
      onPrimaryContainer: c.isDark ? c.text : c.accentText,
      secondary: c.accent2,
      onSecondary: c.isDark ? c.text : Colors.white,
      secondaryContainer: c.accent2.withValues(alpha: c.isDark ? 0.18 : 0.12),
      onSecondaryContainer: c.isDark ? c.text : c.accent2Text,
      tertiary: c.warning,
      onTertiary: c.isDark ? ArmxPalette.ink : Colors.white,
      error: c.danger,
      onError: Colors.white,
      errorContainer: c.danger.withValues(alpha: 0.16),
      onErrorContainer: c.dangerText,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceAlt,
      surfaceContainerHighest: c.surfaceAlt,
      onSurfaceVariant: c.textMuted,
      outline: c.hairline,
      outlineVariant: c.border.withValues(alpha: c.isDark ? 0.14 : 1),
      shadow: Colors.black,
      scrim: c.scrim,
      inverseSurface: c.text,
      onInverseSurface: c.background,
      inversePrimary: c.accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      textTheme: text,
      fontFamily: ArmxTypography.family,
      fontFamilyFallback: ArmxTypography.fallback,
      extensions: <ThemeExtension<dynamic>>[c],
      visualDensity: VisualDensity.standard,

      // Focus rings must be visible on desktop/web where interaction is keyboard-driven.
      focusColor: c.accent.withValues(alpha: 0.22),
      hoverColor: c.accent.withValues(alpha: 0.08),
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarTextStyle: text.bodyMedium,
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.cardRadius),
          side: BorderSide(color: c.hairline),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.dialogRadius),
          side: BorderSide(color: c.hairline),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        barrierColor: c.scrim,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Insets.dialogRadius)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: c.hairline,
        thickness: 1,
        space: 1,
      ),

      // ---- Controls ---------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(Insets.minTouchTarget, Insets.minTouchTarget),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.controlRadius)),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            ArmxTypography.inter(size: 14, weight: 600, height: 1.2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(Insets.minTouchTarget, Insets.minTouchTarget),
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(c.text),
          side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: c.hairline)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.controlRadius)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(Insets.minTouchTarget, Insets.minTouchTarget),
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(c.accentText),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(Insets.controlRadius)),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.isDark ? c.surfaceAlt : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: c.textMuted),
        labelStyle: text.labelMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: c.accentText),
        errorStyle: text.bodySmall?.copyWith(color: c.dangerText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          borderSide: BorderSide(color: c.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          borderSide: BorderSide(color: c.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          borderSide: BorderSide(color: c.danger, width: 2),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accent.withValues(alpha: c.isDark ? 0.20 : 0.16),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? c.accentText : c.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (Set<WidgetState> states) => ArmxTypography.inter(
            size: 12,
            weight: states.contains(WidgetState.selected) ? 700 : 500,
            height: 1.34,
            color: states.contains(WidgetState.selected) ? c.accentText : c.textMuted,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.accent.withValues(alpha: c.isDark ? 0.20 : 0.16),
        selectedIconTheme: IconThemeData(color: c.accentText, size: 24),
        unselectedIconTheme: IconThemeData(color: c.textMuted, size: 24),
        selectedLabelTextStyle: ArmxTypography.inter(
          size: 12,
          weight: 700,
          height: 1.34,
          color: c.accentText,
        ),
        unselectedLabelTextStyle: ArmxTypography.inter(
          size: 12,
          weight: 500,
          height: 1.34,
          color: c.textMuted,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceAlt,
        selectedColor: c.accent.withValues(alpha: c.isDark ? 0.22 : 0.16),
        side: BorderSide(color: c.hairline),
        labelStyle: text.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.chipRadius),
        ),
      ),

      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.surfaceAlt,
        ),
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? c.onAccent : c.textMuted,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.text,
        minVerticalPadding: Insets.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.controlRadius),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Insets.chipRadius),
          border: Border.all(color: c.hairline),
        ),
        textStyle: text.bodySmall?.copyWith(color: c.text),
        waitDuration: const Duration(milliseconds: 450),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceAlt,
        circularTrackColor: c.surfaceAlt,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceAlt,
        contentTextStyle: text.bodyMedium,
        actionTextColor: c.accentText,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Insets.controlRadius),
          side: BorderSide(color: c.hairline),
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(c.textMuted.withValues(alpha: 0.5)),
        trackColor: WidgetStatePropertyAll<Color>(c.border.withValues(alpha: 0.1)),
        thickness: const WidgetStatePropertyAll<double>(8),
        radius: const Radius.circular(4),
      ),

      // Text selection must be legible in both themes.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.30),
        selectionHandleColor: c.accent,
      ),

      splashColor: c.accent.withValues(alpha: 0.10),
      highlightColor: c.accent.withValues(alpha: 0.06),
      disabledColor: c.textMuted.withValues(alpha: 0.55),
      hintColor: c.textMuted,
      dividerColor: c.hairline,
    );
  }
}
