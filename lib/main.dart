// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/app_info.dart';
import 'core/errors/app_exception.dart';
import 'core/logging/armx_logger.dart';
import 'core/providers.dart';
import 'core/theme/armx_colors.dart';
import 'core/theme/armx_theme.dart';
import 'core/widgets/armx_wordmark.dart';

/// Entry point.
///
/// Order matters: configuration is validated *before* the first frame (a release build with
/// a cleartext URL must refuse to start), the logger is created before any plugin runs, and
/// every error handler funnels into that logger so nothing is ever silently swallowed.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on AppException catch (error) {
    runApp(FatalConfigApp(exception: error));
    return;
  }

  final logger = ArmxLogging.create(config.logLevel, buffer: LogRingBuffer());
  _installErrorHandlers(logger);
  logger.i('A.R.M.X ${AppInfo.versionLabel} starting — ${config.describe()}');

  runApp(
    ProviderScope(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
        appLoggerProvider.overrideWithValue(logger),
      ],
      child: const ArmxApp(),
    ),
  );
}

void _installErrorHandlers(Logger logger) {
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousHandler?.call(details);
    logger.e(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.e('Unhandled platform error', error: error, stackTrace: stack);
    return true;
  };
}

/// Last-resort screen shown when the build configuration itself is unusable.
///
/// Intentionally dependency-free: it renders before Riverpod, the database or localization
/// exist, so a misconfigured release build shows an explanation instead of a blank window.
class FatalConfigApp extends StatelessWidget {
  /// Creates the fatal error app.
  const FatalConfigApp({required this.exception, super.key});

  /// The configuration error that stopped the launch.
  final AppException exception;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.productName,
      debugShowCheckedModeBanner: false,
      theme: ArmxTheme.dark(),
      home: Builder(
        builder: (context) {
          final colors = ArmxColors.of(context);
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const ArmxWordmark(fontSize: 30),
                    const SizedBox(height: 24),
                    Icon(Icons.report_gmailerrorred_rounded, size: 44, color: colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'This build cannot start',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      exception.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'code: ${exception.code}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colors.muted, fontFamily: 'JetBrainsMono'),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      AppInfo.credit,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
