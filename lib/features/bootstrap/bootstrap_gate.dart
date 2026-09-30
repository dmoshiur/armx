// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_exception.dart';
import '../../core/router/routes.dart';
import '../../core/widgets/state_views.dart';
import '../splash/splash_page.dart';
import 'bootstrap.dart';

/// Shows the splash while the launch sequence runs, then enters the shell.
///
/// Any fatal error (usually a corrupt local database) is rendered with the localized error
/// card and a retry action instead of a white screen.
class BootstrapGate extends ConsumerStatefulWidget {
  /// Creates the gate.
  const BootstrapGate({super.key});

  @override
  ConsumerState<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends ConsumerState<BootstrapGate> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(bootstrapProvider);

    return bootstrap.when(
      loading: () => const SplashPage(),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: ErrorView(
            error: error is AppException
                ? error
                : StorageException('Startup failed: ${error.runtimeType}'),
            onRetry: () => ref.invalidate(bootstrapProvider),
          ),
        ),
      ),
      data: (report) {
        if (!_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go(AppRoutes.dashboard);
            }
          });
        }
        return const SplashPage();
      },
    );
  }
}
