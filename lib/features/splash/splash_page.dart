// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../core/config/app_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/armx_orb.dart';
import '../../core/widgets/armx_wordmark.dart';

/// Launch screen: wordmark, assistant orb and initialization status.
///
/// Shown while the database, secure storage and (from step 2) the session are restored.
/// It never blocks on the network: the shell is reachable offline by design.
class SplashPage extends StatefulWidget {
  /// Creates the splash screen.
  const SplashPage({this.statusMessage, this.failed = false, super.key});

  /// Localized status line; defaults to the "initialising" string.
  final String? statusMessage;

  /// When true the splash renders the failure copy instead of the spinner.
  final bool failed;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ArmxMotion.gentle,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final reduceMotion = ArmxMotion.reduceMotion(context);
    final animation = reduceMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : CurvedAnimation(parent: _controller, curve: ArmxMotion.enter);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[colors.background, colors.panel],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: animation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const ArmxWordmark(fontSize: 40),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.muted, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 36),
                  ArmxOrb(
                    state: widget.failed ? ArmxOrbState.locked : ArmxOrbState.thinking,
                    size: 132,
                    showLabel: false,
                  ),
                  const SizedBox(height: 28),
                  if (!widget.failed)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    widget.statusMessage ?? context.l10n.splashInitialising,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'v${AppInfo.versionLabel}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colors.muted, fontFamily: 'JetBrainsMono'),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      AppInfo.credit,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.muted),
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
