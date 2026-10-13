// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Roles are the authorisation axis of the whole app, and the router turns them into
/// redirects. Both halves are pinned here.
void main() {
  group('UserRole.fromWire', () {
    test('reads the three known roles', () {
      expect(UserRole.fromWire('admin'), UserRole.admin);
      expect(UserRole.fromWire('VIP'), UserRole.vip);
      expect(UserRole.fromWire('user'), UserRole.user);
    });

    test('an unknown or absent role is the least-privileged one, never the most', () {
      expect(UserRole.fromWire('superuser'), UserRole.user);
      expect(UserRole.fromWire(''), UserRole.user);
      expect(UserRole.fromWire(null), UserRole.user);
    });

    test('the legacy owner alias still means admin', () {
      expect(UserRole.fromWire('owner'), UserRole.admin);
    });
  });

  group('UserRole.satisfies', () {
    test('every role satisfies the user requirement', () {
      for (final UserRole role in UserRole.values) {
        expect(role.satisfies(UserRole.user), isTrue, reason: '$role');
      }
    });

    test('only vip and admin satisfy the vip requirement', () {
      expect(UserRole.user.satisfies(UserRole.vip), isFalse);
      expect(UserRole.vip.satisfies(UserRole.vip), isTrue);
      expect(UserRole.admin.satisfies(UserRole.vip), isTrue);
    });

    test('only admin satisfies the admin requirement', () {
      expect(UserRole.user.satisfies(UserRole.admin), isFalse);
      expect(UserRole.vip.satisfies(UserRole.admin), isFalse);
      expect(UserRole.admin.satisfies(UserRole.admin), isTrue);
    });

    test('the convenience getters agree with satisfies', () {
      expect(UserRole.admin.canAdminister, isTrue);
      expect(UserRole.vip.canAdminister, isFalse);
      expect(UserRole.vip.isVipOrAbove, isTrue);
      expect(UserRole.user.isVipOrAbove, isFalse);
    });
  });

  group('path helpers', () {
    test('a device deep link is built from the id', () {
      expect(Routes.deviceFor('lamp-1'), '/smart-home/lamp-1');
    });

    test('the alarm editor accepts new and an existing id', () {
      expect(Routes.alarmFor('new'), '/alarms/new');
      expect(Routes.alarmFor('alarm-7'), '/alarms/alarm-7');
    });

    test('a reset token is URL-encoded, so a token with punctuation cannot break the link',
        () {
      final String path = Routes.resetPasswordWith('a+b/c=d?e');
      expect(path.startsWith('${Routes.resetPassword}?token='), isTrue);
      expect(path.contains(' '), isFalse);
      expect(Uri.parse(path).queryParameters['token'], 'a+b/c=d?e');
    });
  });

  group('nameOf', () {
    test('produces a stable camelCase name for a path', () {
      expect(Routes.nameOf('/smart-home'), 'smartHome');
      expect(Routes.nameOf('/settings/design-system'), 'settingsDesignSystem');
      expect(Routes.nameOf('/admin/audit'), 'adminAudit');
    });

    test('a parameterised path still yields a name, so navigation never loses a highlight',
        () {
      expect(Routes.nameOf('/smart-home/:id'), 'smartHomeId');
    });

    test('an empty path has a name rather than an empty string', () {
      expect(Routes.nameOf(''), 'root');
      expect(Routes.nameOf('///'), 'root');
    });
  });

  test('every route constant is an absolute path', () {
    // A relative route constant would silently nest under whatever route happened to be
    // active; the guard is cheap and the failure it prevents is confusing.
    final List<String> paths = <String>[
      Routes.splash,
      Routes.login,
      Routes.signup,
      Routes.forgotPassword,
      Routes.resetPassword,
      Routes.verifyEmail,
      Routes.overlayPermission,
      Routes.home,
      Routes.assistant,
      Routes.smartHome,
      Routes.deviceDetail,
      Routes.alarms,
      Routes.alarmEditor,
      Routes.linkedDevices,
      Routes.guestGreeter,
      Routes.guestEnrollment,
      Routes.webBuilder,
      Routes.messaging,
      Routes.admin,
      Routes.adminAudit,
      Routes.adminTools,
      Routes.settings,
      Routes.settingsPreferences,
      Routes.settingsPermissions,
      Routes.settingsAccount,
      Routes.settingsDesignSystem,
      Routes.settingsDiagnostics,
      Routes.settingsAbout,
    ];
    for (final String path in paths) {
      expect(path.startsWith('/'), isTrue, reason: '$path must be absolute');
    }
  });

  test('route names are unique, so `goNamed` can never be ambiguous', () {
    final List<String> paths = <String>[
      Routes.splash,
      Routes.login,
      Routes.signup,
      Routes.forgotPassword,
      Routes.resetPassword,
      Routes.verifyEmail,
      Routes.overlayPermission,
      Routes.home,
      Routes.assistant,
      Routes.smartHome,
      Routes.deviceDetail,
      Routes.alarms,
      Routes.alarmEditor,
      Routes.linkedDevices,
      Routes.guestGreeter,
      Routes.guestEnrollment,
      Routes.webBuilder,
      Routes.messaging,
      Routes.admin,
      Routes.adminAudit,
      Routes.adminTools,
      Routes.settings,
      Routes.settingsPreferences,
      Routes.settingsPermissions,
      Routes.settingsAccount,
      Routes.settingsDesignSystem,
      Routes.settingsDiagnostics,
      Routes.settingsAbout,
    ];
    final List<String> names = paths.map(Routes.nameOf).toList(growable: false);
    expect(names.toSet().length, names.length);
  });
}
