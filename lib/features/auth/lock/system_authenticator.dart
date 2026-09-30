// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:local_auth/local_auth.dart';

/// Access to the platform authenticator (biometrics, device PIN/pattern/passcode).
///
/// Abstracted so widget/unit tests can substitute a fake and so lock-screen code
/// never imports `local_auth` directly.
abstract interface class SystemAuthenticator {
  /// Whether the device can present *any* system challenge (biometrics or
  /// device credentials). `false` means the caller must fall back to the
  /// app-level PIN.
  Future<bool> isAvailable();

  /// Prompts for authentication with [localizedReason] as the user-facing
  /// explanation (already localized by the caller).
  ///
  /// Returns `true` only when the user passed the challenge; `false` when the
  /// challenge was failed or dismissed. Platform/communication errors surface
  /// as exceptions.
  Future<bool> authenticate(String localizedReason);
}

/// `local_auth` implementation used on device builds.
class LocalSystemAuthenticator implements SystemAuthenticator {
  /// Creates the authenticator around an optional pre-built [LocalAuthentication]
  /// (injectable for tests).
  LocalSystemAuthenticator([LocalAuthentication? authentication])
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _authentication.isDeviceSupported();
    } on Object {
      // Plugin missing (desktop/web, unpatched platform folder): degrade to the
      // app-PIN path instead of crashing the lock screen.
      return false;
    }
  }

  @override
  Future<bool> authenticate(String localizedReason) {
    return _authentication.authenticate(
      localizedReason: localizedReason,
      // Device PIN/pattern/passcode is an acceptable challenge for opening the
      // app; biometrics-only would lock out devices without enrolled prints.
      biometricOnly: false,
      // Survive the app being backgrounded mid-prompt (Android stops the
      // activity otherwise) by retrying the same challenge on foregrounding.
      persistAcrossBackgrounding: true,
      // The lock screen *is* the confirmation step — no second face-unlock
      // confirmation dialog on top of it.
      sensitiveTransaction: false,
    );
  }
}
