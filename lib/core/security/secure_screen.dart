// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Contract for blocking screenshots/screen recording on sensitive screens.
abstract interface class ScreenSecurity {
  /// Enables the platform "no capture" flag (no-op where unsupported).
  Future<void> enable();

  /// Disables the flag again.
  Future<void> disable();

  /// Whether the current platform can actually block capture.
  bool get isSupported;
}

/// Android implementation using `FLAG_SECURE`.
///
/// The Kotlin side is a ten-line `MethodChannel` handler documented in
/// `docs/platform_setup.md`; when the handler is missing (desktop, or a platform folder
/// that has not been patched yet) every call degrades to a no-op instead of crashing.
class PlatformScreenSecurity implements ScreenSecurity {
  /// Creates the service. [channel] is injectable for tests.
  PlatformScreenSecurity({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('top.thamjj13.armx/secure_screen');

  final MethodChannel _channel;

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> enable() => _invoke('enableSecure');

  @override
  Future<void> disable() => _invoke('disableSecure');

  Future<void> _invoke(String method) async {
    if (!isSupported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Platform folder not patched yet: degrade silently, never block the UI.
    } on PlatformException {
      // Some OEM builds refuse the flag; not fatal.
    }
  }
}

/// [ScreenSecurity] that does nothing (tests, unsupported platforms).
class NoopScreenSecurity implements ScreenSecurity {
  /// Creates a no-op service.
  const NoopScreenSecurity();

  @override
  bool get isSupported => false;

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

/// Wraps a subtree and keeps the screenshot flag enabled while it is mounted.
///
/// Used by every screen that renders sensitive material: pairing keys, unlock flow,
/// admin audit log, vision enrolment.
class SecureScreen extends StatefulWidget {
  /// Creates the barrier around [child].
  const SecureScreen({
    required this.child,
    required this.security,
    this.enabled = true,
    super.key,
  });

  /// Subtree protected while visible.
  final Widget child;

  /// Platform service that toggles the flag.
  final ScreenSecurity security;

  /// Set to false to temporarily allow capture (for example during a support screenshot).
  final bool enabled;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      widget.security.enable();
    }
  }

  @override
  void didUpdateWidget(covariant SecureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) {
      return;
    }
    if (widget.enabled) {
      widget.security.enable();
    } else {
      widget.security.disable();
    }
  }

  @override
  void dispose() {
    if (widget.enabled) {
      widget.security.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
