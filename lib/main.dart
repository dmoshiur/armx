// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/overlay/presentation/overlay_bubble_entry.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';

/// Entry point.
///
/// Only two things happen here: the configuration is validated and installed, and the app is
/// started. **No orientation is locked and no device class is special-cased** — the layout is
/// decided by available width alone, so a tablet in landscape, a phone in portrait and a
/// resized browser window all take the same code path.
///
/// Reading the stored preferences belongs to the splash screen, which waits for them before
/// the first themed frame: doing it here without awaiting would flash the wrong theme, and
/// awaiting it here would hold the very first frame behind a disk read with no UI to show.
///
/// ## Configuration
///
/// The backend URL is build-time configuration, injected with `--dart-define`:
///
/// ```bash
/// flutter run \
///   --dart-define=ARMX_API_BASE_URL=https://armx.example:8443 \
///   --dart-define=ARMX_USE_MOCK_BACKEND=false
/// ```
///
/// No key, token or secret is ever passed this way. `AppConfig` cannot represent one, and
/// [AppConfig.httpsBaseUrl] refuses a cleartext base URL outside a debug mock build.
///
/// ## Failure policy
///
/// If the preferences store cannot be read, the app still starts: the splash's `FutureBuilder`
/// reports the failure with a retry, because an unreadable preferences file must not mean an
/// unusable assistant. If the *configuration* is invalid (a cleartext URL in a release
/// build), `runApp` is never reached — the process fails loudly instead of talking to a
/// server in the clear.
/// The floating bubble's entry point.
///
/// `flutter_overlay_window` starts a second engine and calls this symbol by name, so it must
/// be a top-level function in the entry-point library and it must survive tree shaking. It is
/// declared here, in one line, so there is exactly one obvious answer to "where does the
/// overlay start?" — the UI it runs lives in the overlay feature.
@pragma('vm:entry-point')
void overlayMain() => overlayBubbleMain();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config = AppConfig.fromEnvironment();
  // Throws on a cleartext base URL outside a debug mock build, before any widget exists.
  config.httpsBaseUrl;

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[appConfigProvider.overrideWithValue(config)],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ArmxApp(),
    ),
  );
}
