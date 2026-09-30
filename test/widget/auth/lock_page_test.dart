// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/core/widgets/armx_controls.dart';
import 'package:armx_ai/features/auth/lock/app_lock_controller.dart';
import 'package:armx_ai/features/auth/lock/app_pin_store.dart';
import 'package:armx_ai/features/auth/lock/lock_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/auth_test_harness.dart';

/// The LOW-tier lock screen: system challenge, failure copy, and the app-PIN
/// fallback (verify and first-run setup).
void main() {
  const surface = Size(1080, 1600);
  final destinationKey = GlobalKey(debugLabel: 'destination');

  GoRouter lockRouter() => GoRouter(
        initialLocation: '/lock',
        routes: <RouteBase>[
          GoRoute(path: '/lock', builder: (context, state) => const LockPage()),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) =>
                Scaffold(body: Text('UNLOCKED', key: destinationKey)),
          ),
        ],
      );

  Future<void> primeLocked(ProviderContainer container) =>
      container.read(appLockControllerProvider.notifier).restore(sessionRestored: true);

  testWidgets('a successful system challenge releases the gate and navigates',
      (tester) async {
    final fake = FakeSystemAuthenticator(available: true, result: true);
    await pumpAuthApp(
      tester,
      router: lockRouter(),
      overrides: <Override>[systemAuthenticatorProvider.overrideWithValue(fake)],
      prime: primeLocked,
      surfaceSize: surface,
    );

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('UNLOCKED'), findsOneWidget);
    expect(fake.authenticateCalls, 1);
    expect(fake.promptedWith.single, isNotEmpty);
    expect(fake.promptedWith.single, isNot(contains('{')));
  });

  testWidgets('a failed challenge stays on the lock screen with its own copy',
      (tester) async {
    final fake = FakeSystemAuthenticator(available: true, result: false);
    final container = await pumpAuthApp(
      tester,
      router: lockRouter(),
      overrides: <Override>[systemAuthenticatorProvider.overrideWithValue(fake)],
      prime: primeLocked,
      surfaceSize: surface,
    );
    final l10n = l10nOf(tester, find.byType(LockPage));

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text(l10n.appLockFailed), findsOneWidget);
    expect(container.read(appLockControllerProvider).lockDue, isTrue);
    expect(find.text('UNLOCKED'), findsNothing);

    // Tapping Unlock again re-prompts.
    await tester.tap(find.widgetWithText(ArmxButton, l10n.appLockUnlockAction));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    expect(fake.authenticateCalls, 2);
  });

  testWidgets('no system authenticator and no PIN starts first-run setup',
      (tester) async {
    final fake = FakeSystemAuthenticator(available: false);
    await pumpAuthApp(
      tester,
      router: lockRouter(),
      overrides: <Override>[systemAuthenticatorProvider.overrideWithValue(fake)],
      prime: primeLocked,
      surfaceSize: surface,
    );
    final l10n = l10nOf(tester, find.byType(LockPage));

    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text(l10n.appLockPinSetupTitle), findsOneWidget);
    expect(find.text(l10n.appLockNoSystem), findsOneWidget);
    expect(find.widgetWithText(ArmxButton, l10n.appLockPinSave), findsOneWidget);
    expect(find.text('UNLOCKED'), findsNothing);
  });

  testWidgets('setup refuses mismatched PINs, then saves and unlocks',
      (tester) async {
    final fake = FakeSystemAuthenticator(available: false);
    final container = await pumpAuthApp(
      tester,
      router: lockRouter(),
      overrides: <Override>[systemAuthenticatorProvider.overrideWithValue(fake)],
      prime: primeLocked,
      surfaceSize: surface,
    );
    final l10n = l10nOf(tester, find.byType(LockPage));

    await tester.pump(const Duration(milliseconds: 20));

    await tester.enterText(find.byType(ArmxTextField).at(0), '1234');
    await tester.enterText(find.byType(ArmxTextField).at(1), '9999');
    await tester.tap(find.widgetWithText(ArmxButton, l10n.appLockPinSave));
    await tester.pump();

    expect(find.text(l10n.appLockPinMismatch), findsOneWidget);
    expect(container.read(appLockControllerProvider).lockDue, isTrue);

    await tester.enterText(find.byType(ArmxTextField).at(1), '1234');
    await tester.tap(find.widgetWithText(ArmxButton, l10n.appLockPinSave));
    // Argon2id derivation may need real time: let the event loop run.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('UNLOCKED'), findsOneWidget);
    expect(container.read(appLockControllerProvider).lockDue, isFalse);
    expect(await container.read(secureStoreProvider).read(SecureKeys.appPin), isNotNull);
  });

  group('with a stored PIN and no system authenticator', () {
    late InMemorySecureStore store;

    setUp(() async {
      store = InMemorySecureStore();
      // Real Argon2id happens outside the fake-async test zone.
      await Argon2AppPinStore(store: store).configure('4321');
    });

    testWidgets('the lock screen verifies the app PIN', (tester) async {
      final fake = FakeSystemAuthenticator(available: false);
      final container = await pumpAuthApp(
        tester,
        router: lockRouter(),
        overrides: <Override>[systemAuthenticatorProvider.overrideWithValue(fake)],
        secureStore: store,
        prime: primeLocked,
        surfaceSize: surface,
      );
      final l10n = l10nOf(tester, find.byType(LockPage));

      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text(l10n.appLockPinEntryLabel), findsOneWidget);
      expect(find.text(l10n.appLockPinSetupTitle), findsNothing);

      await tester.enterText(find.byType(ArmxTextField).at(0), '0000');
      await tester.tap(find.widgetWithText(ArmxButton, l10n.appLockUnlockAction));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text(l10n.appLockWrongPin), findsOneWidget);
      expect(container.read(appLockControllerProvider).lockDue, isTrue);

      await tester.enterText(find.byType(ArmxTextField).at(0), '4321');
      await tester.tap(find.widgetWithText(ArmxButton, l10n.appLockUnlockAction));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('UNLOCKED'), findsOneWidget);
      expect(container.read(appLockControllerProvider).lockDue, isFalse);
      expect(fake.authenticateCalls, 0, reason: 'the system path is never reached');
    });

    testWidgets('the system path can be offered alongside the PIN',
        (tester) async {
      final fake = FakeSystemAuthenticator(available: true, result: true);
      await pumpAuthApp(
        tester,
        router: lockRouter(),
        overrides: <Override>[systemAuthenticatorProvider.overrideWithValue(fake)],
        secureStore: store,
        prime: primeLocked,
        surfaceSize: surface,
      );

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      // Available system authenticator wins on entry.
      expect(fake.authenticateCalls, 1);
      expect(find.text('UNLOCKED'), findsOneWidget);
    });
  });
}
