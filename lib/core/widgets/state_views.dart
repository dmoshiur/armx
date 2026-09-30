// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../errors/app_exception.dart';
import '../l10n/l10n.dart';
import '../theme/armx_colors.dart';
import 'glass_panel.dart';

// The layout blocks and list tiles that every screen composes with live in
// `layout_blocks.dart` and `armx_tile.dart`; they are re-exported here so screens only
// ever import this one file.
export 'armx_tile.dart';
export 'layout_blocks.dart';

/// Centred progress indicator with a localized accessibility label.
class LoadingView extends StatelessWidget {
  /// Creates a loading view.
  const LoadingView({this.message, this.compact = false, super.key});

  /// Optional message under the spinner.
  final String? message;

  /// Renders a smaller, inline variant.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.a11yLoading,
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: compact ? 20 : 32,
                height: compact ? 20 : 32,
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state card with an optional call to action.
class EmptyView extends StatelessWidget {
  /// Creates an empty state.
  const EmptyView({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  /// Short headline.
  final String title;

  /// Optional explanation.
  final String? message;

  /// Icon shown above the headline.
  final IconData icon;

  /// Optional call-to-action button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassPanel(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 40, color: colors.muted),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted),
                ),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error card with a localized title/body and a retry button.
class ErrorView extends StatelessWidget {
  /// Creates an error view for [error].
  const ErrorView({
    required this.error,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  /// The error to render (localized through `core/errors/error_messages.dart`).
  final AppException error;

  /// Retry callback; hidden when null or when the error is not retryable.
  final VoidCallback? onRetry;

  /// Renders a smaller inline variant.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final showRetry = onRetry != null && (error.isRetryable || error is! ConfigException);

    return Semantics(
      liveRegion: true,
      label: context.l10n.a11yError(context.errorTitle(error)),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: GlassPanel(
          accent: colors.red,
          padding: EdgeInsets.all(compact ? 14 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.error_outline_rounded, color: colors.red, size: compact ? 18 : 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.errorTitle(error),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.errorBody(error),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (showRetry) ...<Widget>[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.l10n.commonRetry),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "This platform cannot do that" card, used by every feature that degrades gracefully.
class UnsupportedView extends StatelessWidget {
  /// Creates an unsupported-platform view.
  const UnsupportedView({required this.feature, required this.reason, super.key});

  /// Feature identifier, for example `face_detection`.
  final String feature;

  /// Diagnostic reason (English, from `PlatformCapabilities.unsupportedReason`).
  final String reason;

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassPanel(
          accent: colors.amber,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.devices_other_rounded, color: colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.errorUnsupportedTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                'feature: $feature',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.muted, fontFamily: 'JetBrainsMono'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
