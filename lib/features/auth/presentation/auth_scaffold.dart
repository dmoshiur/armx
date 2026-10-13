// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../core/breakpoints.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/armx_brand.dart';

/// The shared frame around every authentication screen.
///
/// On compact and medium layouts the form occupies the screen with a scroll view, so a
/// 360 dp phone with a large text scale never clips the submit button. On expanded layouts
/// — desktop and wide web — a branded panel appears beside the form, which is what stops a
/// sign-in page from rendering as a single 400 dp column lost in the middle of a 2560 dp
/// monitor.
class AuthScaffold extends StatelessWidget {
  /// Creates the frame.
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBackButton = false,
    super.key,
  });

  /// Form heading (H1).
  final String title;

  /// Supporting line under the heading.
  final String subtitle;

  /// The form itself.
  final Widget child;

  /// Optional trailing content (links, "already have an account").
  final Widget? footer;

  /// Shows a back affordance for pushed auth screens.
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: BreakpointBuilder(
          builder: (BuildContext context, Breakpoint breakpoint) {
            final Widget form = _AuthForm(
              title: title,
              subtitle: subtitle,
              child: child,
              footer: footer,
              showBackButton: showBackButton,
            );

            if (breakpoint != Breakpoint.expanded) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.pagePadding,
                  vertical: Insets.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: form,
                  ),
                ),
              );
            }

            // Desktop: brand panel + form, side by side, with the form column capped.
            return Row(
              children: <Widget>[
                const Expanded(child: _AuthBrandPanel()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(Insets.xxl),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
    required this.showBackButton,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showBackButton)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: context.l10n.commonBack,
            ),
          ),
        // The wordmark is hidden here on desktop because the brand panel already carries
        // it; showing it twice reads as a mistake.
        if (MediaQuery.sizeOf(context).width < Breakpoint.mediumMax)
          const Padding(
            padding: EdgeInsets.only(bottom: Insets.xl),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ArmxWordmark(),
            ),
          ),
        Semantics(
          header: true,
          child: Text(title, style: text.headlineMedium),
        ),
        const SizedBox(height: Insets.sm),
        Text(subtitle, style: text.bodyMedium),
        const SizedBox(height: Insets.xl),
        child,
        if (footer != null) ...<Widget>[
          const SizedBox(height: Insets.xl),
          footer!,
        ],
      ],
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[
            colors.surface,
            Color.alphaBlend(colors.accent.withValues(alpha: 0.18), colors.surface),
            colors.background,
          ],
        ),
        border: BorderDirectional(end: BorderSide(color: colors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const ArmxWordmark(size: 44),
            const SizedBox(height: Insets.lg),
            Text(
              context.l10n.appTagline,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Insets.xl),
            _FeatureLine(
              icon: Icons.record_voice_over_outlined,
              text: context.l10n.authFeatureVoice,
            ),
            _FeatureLine(
              icon: Icons.home_work_outlined,
              text: context.l10n.authFeatureHome,
            ),
            _FeatureLine(
              icon: Icons.shield_outlined,
              text: context.l10n.authFeatureRisk,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: colors.accentText),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Maps an [AuthFailureReason] onto the localized sentence a form should show.
String? authFailureMessage(BuildContext context, AuthFailureReason? reason) =>
    switch (reason) {
      AuthFailureReason.invalidCredentials => context.l10n.authErrorInvalidCredentials,
      AuthFailureReason.emailNotVerified => context.l10n.authErrorEmailNotVerified,
      AuthFailureReason.emailAlreadyRegistered => context.l10n.authErrorEmailTaken,
      AuthFailureReason.rateLimited => context.l10n.authErrorRateLimited,
      AuthFailureReason.googleCancelled => context.l10n.authErrorGoogleCancelled,
      AuthFailureReason.googleFailed => context.l10n.authErrorGoogleFailed,
      AuthFailureReason.invalidToken => context.l10n.authErrorTokenInvalid,
      AuthFailureReason.expiredToken => context.l10n.authErrorTokenExpired,
      AuthFailureReason.weakPassword => context.l10n.validatorPasswordWeak,
      AuthFailureReason.network => context.l10n.errorNetworkBody,
      AuthFailureReason.unknown || null => null,
    };
