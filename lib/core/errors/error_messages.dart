// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import 'app_exception.dart';

/// Turns the sealed [AppException] hierarchy into localized titles and bodies.
///
/// The exhaustive `switch` is the reason [AppException] is sealed: adding a new error case
/// breaks the build here until it has user-facing copy in both languages.
abstract final class AppErrorMessages {
  /// Short localized headline for [error].
  static String title(BuildContext context, AppException error) {
    final l10n = context.l10n;
    return switch (error) {
      ConfigException() => l10n.errorConfigTitle,
      NetworkException() => l10n.errorNetworkTitle,
      RequestTimeoutException() => l10n.errorTimeoutTitle,
      AuthException() => l10n.errorAuthTitle,
      PolicyException() => l10n.errorPolicyTitle,
      VerificationException() => l10n.errorVerificationTitle,
      StorageException() => l10n.errorStorageTitle,
      PermissionDeniedException() => l10n.errorPermissionTitle,
      PlatformUnsupportedException() => l10n.errorUnsupportedTitle,
      TransportClosedException() => l10n.errorTransportTitle,
      KillSwitchActiveException() => l10n.errorKillSwitchTitle,
      ApiException() => l10n.errorUnexpectedTitle,
    };
  }

  /// Longer localized explanation for [error], including a machine-readable reference.
  static String body(BuildContext context, AppException error) {
    final l10n = context.l10n;
    return switch (error) {
      ConfigException() => l10n.errorConfigBody,
      NetworkException() => l10n.errorNetworkBody,
      RequestTimeoutException() => l10n.errorTimeoutBody,
      AuthException(reason: final reason) => switch (reason) {
          AuthFailureReason.invalidCredentials => l10n.errorAuthBody,
          AuthFailureReason.sessionExpired => l10n.errorAuthBody,
          AuthFailureReason.refreshRejected => l10n.errorAuthBody,
          AuthFailureReason.pairingRejected => l10n.errorAuthBody,
          AuthFailureReason.deviceRevoked => l10n.errorAuthBody,
          AuthFailureReason.appLockFailed => l10n.errorAuthBody,
          AuthFailureReason.biometricUnavailable => l10n.errorAuthBody,
          AuthFailureReason.serverUrlRejected => l10n.validationNotAbsoluteUrl,
        },
      PolicyException(requiredTier: final required, satisfiedTier: final satisfied) =>
        '${l10n.errorPolicyBody} ($required > $satisfied)',
      VerificationException(reason: final reason) =>
        '${l10n.errorVerificationBody} · ${reason.name}',
      StorageException() => l10n.errorStorageBody,
      PermissionDeniedException(permission: final permission) =>
        '${l10n.errorPermissionBody} ($permission)',
      PlatformUnsupportedException() => l10n.errorUnsupportedBody(error.message),
      TransportClosedException() => l10n.errorTransportBody,
      KillSwitchActiveException() => l10n.errorKillSwitchBody,
      ApiException() => l10n.errorUnexpectedBody(error.code),
    };
  }
}
