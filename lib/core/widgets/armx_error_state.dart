// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../errors/app_exception.dart';
import '../l10n/l10n.dart';
import '../theme/colors.dart';
import 'armx_button.dart';
import 'armx_card.dart';

/// The localized copy for one failure.
@immutable
class ArmxErrorCopy {
  /// Creates error copy.
  const ArmxErrorCopy({
    required this.title,
    required this.body,
    this.icon = Icons.error_outline_rounded,
  });

  /// Headline.
  final String title;

  /// Explanation.
  final String body;

  /// Glyph.
  final IconData icon;
}

/// Shown whenever a request failed.
///
/// ## Why this maps the sealed exception hierarchy instead of printing the exception
///
/// A user must never read `DioException [connection error]`. Each [AppException] case has
/// its own localized title and body, so the message is accurate *and* translatable. The
/// developer-facing detail and the server's request id are rendered only in a collapsed
/// "reference" line, which is what support needs and nothing more.
///
/// Nothing here ever says "success", and nothing retries silently: the user is given an
/// explicit [onRetry].
class ArmxErrorState extends StatelessWidget {
  /// Creates an error state.
  const ArmxErrorState({
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.compact = false,
    super.key,
  });

  /// The failure to render.
  final Object? error;

  /// Retry action. Omitted for failures that cannot succeed on retry (e.g. forbidden).
  final VoidCallback? onRetry;

  /// Optional escape hatch, usually "Go back".
  final VoidCallback? onDismiss;

  /// Renders inside a card at a smaller size, for a failed panel rather than a page.
  final bool compact;

  /// Maps an exception onto localized copy.
  static ArmxErrorCopy copyFor(Object? error, BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return switch (error) {
      NetworkException() => ArmxErrorCopy(
          title: l10n.errorNetworkTitle,
          body: l10n.errorNetworkBody,
          icon: Icons.cloud_off_rounded,
        ),
      TimeoutException() => ArmxErrorCopy(
          title: l10n.errorTimeoutTitle,
          body: l10n.errorTimeoutBody,
          icon: Icons.hourglass_empty_rounded,
        ),
      UnauthorizedException() => ArmxErrorCopy(
          title: l10n.errorUnauthorizedTitle,
          body: l10n.errorUnauthorizedBody,
          icon: Icons.lock_clock_outlined,
        ),
      ForbiddenException() => ArmxErrorCopy(
          title: l10n.errorForbiddenTitle,
          body: l10n.errorForbiddenBody,
          icon: Icons.block_rounded,
        ),
      NotFoundException() => ArmxErrorCopy(
          title: l10n.errorNotFoundTitle,
          body: l10n.errorNotFoundBody,
          icon: Icons.search_off_rounded,
        ),
      ValidationException() => ArmxErrorCopy(
          title: l10n.errorValidationTitle,
          body: l10n.errorValidationBody,
          icon: Icons.rule_rounded,
        ),
      RateLimitedException() => ArmxErrorCopy(
          title: l10n.errorGenericTitle,
          body: l10n.errorGenericBody,
          icon: Icons.timer_outlined,
        ),
      ServerException() => ArmxErrorCopy(
          title: l10n.errorServerTitle,
          body: l10n.errorServerBody,
          icon: Icons.dns_outlined,
        ),
      MalformedResponseException() => ArmxErrorCopy(
          title: l10n.errorServerTitle,
          body: l10n.errorUnexpectedBody,
          icon: Icons.broken_image_outlined,
        ),
      CapabilityException(message: final String message) => ArmxErrorCopy(
          title: l10n.commonNotAvailable,
          body: message,
          icon: Icons.devices_other_rounded,
        ),
      PolicyException(message: final String message) => ArmxErrorCopy(
          title: l10n.errorForbiddenTitle,
          body: message,
          icon: Icons.shield_outlined,
        ),
      StorageException() => ArmxErrorCopy(
          title: l10n.errorGenericTitle,
          body: l10n.errorUnexpectedBody,
          icon: Icons.storage_rounded,
        ),
      CancelledException() => ArmxErrorCopy(
          title: l10n.commonCancel,
          body: l10n.commonNone,
          icon: Icons.close_rounded,
        ),
      _ => ArmxErrorCopy(
          title: l10n.errorGenericTitle,
          body: l10n.errorGenericBody,
        ),
    };
  }

  /// True when retrying could plausibly succeed.
  static bool isRetryable(Object? error) => switch (error) {
        NetworkException() || TimeoutException() || ServerException() => true,
        RateLimitedException() => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final ArmxErrorCopy copy = copyFor(error, context);
    final AppException? exception = error is AppException ? error as AppException : null;
    final bool canRetry = onRetry != null && isRetryable(error);

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 44 : 64,
          height: compact ? 44 : 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.danger.withValues(alpha: 0.14),
          ),
          child: Icon(copy.icon, size: compact ? 22 : 30, color: colors.dangerText),
        ),
        SizedBox(height: compact ? Insets.md : Insets.lg),
        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: compact
              ? Theme.of(context).textTheme.titleSmall
              : Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          copy.body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (exception != null && (exception.requestId != null || exception.code != null))
          Padding(
            padding: const EdgeInsets.only(top: Insets.md),
            // The reference line is monospace and selectable so it can be pasted into a
            // support message; it is never the primary message.
            child: SelectableText(
              <String>[
                if (exception.code != null) exception.code!,
                if (exception.requestId != null) exception.requestId!,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        if (canRetry || onDismiss != null) ...<Widget>[
          SizedBox(height: compact ? Insets.lg : Insets.xl),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              if (canRetry)
                ArmxButton(
                  label: context.l10n.commonRetry,
                  onPressed: onRetry,
                  icon: Icons.refresh_rounded,
                  variant: ArmxButtonVariant.primary,
                  size: compact ? ArmxButtonSize.small : ArmxButtonSize.medium,
                ),
              if (onDismiss != null)
                ArmxButton(
                  label: context.l10n.commonClose,
                  onPressed: onDismiss,
                  variant: ArmxButtonVariant.ghost,
                  size: compact ? ArmxButtonSize.small : ArmxButtonSize.medium,
                ),
            ],
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${copy.title}. ${copy.body}',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Insets.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: compact
                ? ArmxCard(
                    tone: ArmxCardTone.tinted,
                    tint: colors.danger,
                    padding: const EdgeInsets.all(Insets.lg),
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    );
  }
}
