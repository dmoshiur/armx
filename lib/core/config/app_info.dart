// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Static product identity, ownership and credit strings.
///
/// Kept in one place so the splash screen, the About page and the license page can
/// never drift apart.
abstract final class AppInfo {
  /// Product wordmark used on splash and About ("AI" is rendered in cyan by `ArmxWordmark`).
  static const String productName = 'A.R.M.X AI';

  /// Expanded product name.
  static const String productLongName = 'Automated Resource Management eXtension';

  /// Application version. Bumped alongside `pubspec.yaml` (kept in sync manually because
  /// the app intentionally does not depend on `package_info_plus`).
  static const String version = '0.1.0';

  /// Build number mirrored from `pubspec.yaml`.
  static const String buildNumber = '1';

  /// Current owner of the product, per the brand guidelines.
  static const String owner = 'Md. Moshiur Rahman Mohi';

  /// Brand domain.
  static const String brand = 'THAMJJ13.TOP';

  /// Mandatory footer credit, rendered verbatim in About and in the license page.
  static const String credit =
      'A.R.M.X AI by THAMJJ13.TOP - Md. Moshiur Rahman Mohi. All Rights Reserved.';

  /// Copyright header that every source file must carry.
  static const String copyrightHeader =
      'Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. '
      'Proprietary. All Rights Reserved.';

  /// Dart package name (also the Android application id suffix).
  static const String packageName = 'armx_ai';

  /// Reverse-DNS identifier used for the Android application id and desktop metadata.
  static const String applicationId = 'top.thamjj13.armx';

  /// Default wake word spoken by the user.
  static const String wakeWord = 'Armex';

  /// Full version label, for example `0.1.0+1`.
  static String get versionLabel => '$version+$buildNumber';

  /// Whether this build is a release build (used for security decisions in the UI).
  static bool get isRelease => kReleaseMode;

  /// Whether the desktop background mode (tray, hotkey, autostart) applies to this build.
  ///
  /// Web and mobile builds keep the Android foreground-service path; only Windows, macOS
  /// and Linux get the tray/hotkey shell.
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
}
