// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'core/config/app_config.dart';
import 'core/router/routes.dart';
import 'core/network/websocket_client.dart';
import 'core/preferences/preferences_store.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/auth_models.dart';
import 'features/overlay/application/overlay_bubble_controller.dart';
import 'features/overlay/application/overlay_host.dart';
import 'core/theme/app_theme.dart';

/// The application widget.
///
/// ## What lives here and what does not
///
/// `ArmxApp` owns exactly three things: the theme, the locale, and the router. Everything
/// else — session state, socket state, layout — belongs to the screen that shows it, so a
/// rebuild caused by a preference change cannot cascade into the whole tree.
///
/// Two decisions are worth stating:
///
/// * **The theme is always one of [AppTheme.dark] / [AppTheme.light].** No screen builds a
///   `ThemeData`, and no screen hardcodes a colour, so switching the theme here is the only
///   way the palette changes anywhere in the app.
/// * **The font stack is bundled, not downloaded.** The app must look identical with no
///   network, so `Inter` ships in `assets/fonts/` and the theme references it; a font that
///   had to be fetched would also make the first frame of a cold start depend on Google's
///   CDN.
class ArmxApp extends ConsumerStatefulWidget {
  /// Creates the app.
  const ArmxApp({super.key});

  @override
  ConsumerState<ArmxApp> createState() => _ArmxAppState();
}

class _ArmxAppState extends ConsumerState<ArmxApp> {
  StreamSubscription<Object?>? _bubbleEvents;

  /// The saved locale, or the device's if the user has never chosen one.
  Locale _localeFor(AppPreferences preferences) =>
      Locale(preferences.localeCode);

  @override
  void initState() {
    super.initState();
    // The floating bubble runs in its own isolate with no session and no router, so it sends
    // intents here as data. They are handled in exactly one place, which is what keeps a
    // second engine from becoming a second source of navigation.
    _bubbleEvents =
        ref.read(overlayBubbleHostProvider).events.listen(_onBubbleEvent);
  }

  @override
  void dispose() {
    _bubbleEvents?.cancel();
    super.dispose();
  }

  /// Routes what the bubble asked for. Unknown payloads are ignored rather than guessed at.
  void _onBubbleEvent(Object? event) {
    if (event is! Map) {
      return;
    }
    final Object? name = event['event'];
    final GoRouter router = ref.read(appRouterProvider);
    if (name == 'open-assistant') {
      // Opening the assistant from the bubble means the app is about to be in the
      // foreground, and the bubble closes itself when tapped — so the truthful state here is
      // "no window on screen", recorded rather than assumed.
      ref.read(overlayBubbleProvider.notifier).reportAttached(attached: false);
      router.go(Routes.assistant);
    } else if (name == 'bring-app') {
      router.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPreferences preferences = ref.watch(preferencesProvider);
    final GoRouter router = ref.watch(appRouterProvider);

    // The socket follows the session: signing in opens it, signing out closes it. Without
    // this the assistant would keep a socket open for a signed-out account.
    ref.listen<AuthState>(authControllerProvider, (AuthState? was, AuthState now) {
      if (now.isSignedIn == was?.isSignedIn) {
        return;
      }
      final WebSocketClient socket = ref.read(webSocketProvider);
      if (now.isSignedIn) {
        socket.connect();
      } else {
        socket.close(reason: 'Signed out.');
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Dark is the product default; `system` is an explicit choice the user makes.
      themeMode: preferences.themeMode,
      locale: _localeFor(preferences),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Bengali is longer than English in most UI strings; letting the framework shrink a
      // label slightly is better than clipping it, and it is capped so text never becomes
      // unreadable. Screens are still expected to reflow rather than rely on this.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.6,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
