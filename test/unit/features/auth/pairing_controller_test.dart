// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/security/secure_store.dart';
import 'package:armx_ai/data/api/mock/mock_api.dart';
import 'package:armx_ai/data/models/auth.dart';
import 'package:armx_ai/features/auth/pairing/pairing_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fixtures.dart';
import '../../../support/test_harness.dart';

/// The pairing state machine: health check → identity → approved / pending /
/// rejected, with the `paired` gate the router reads.
void main() {
  Future<(ProviderContainer, MockBackendControl)> buildContainer({
    MockPairingOutcome outcome = MockPairingOutcome.approved,
  }) async {
    final control = MockBackendControl(
      latency: Duration.zero,
      tokenInterval: Duration.zero,
      pairingOutcome: outcome,
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...testOverrides(),
        armxApiProvider.overrideWithValue(Fixtures.mockApi(control: control)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(pairingControllerProvider.notifier).restore();
    return (container, control);
  }

  Future<void> connect(ProviderContainer container) async {
    container.read(pairingControllerProvider.notifier).setServerUrl('https://home.example.com');
    await container.read(pairingControllerProvider.notifier).testConnection();
  }

  test('a valid URL passes the health check and prepares the identity', () async {
    final (container, _) = await buildContainer();
    await connect(container);

    final state = container.read(pairingControllerProvider);
    expect(state.phase, PairingPhase.identity);
    expect(state.probe?.reachable, isTrue);
    expect(state.identity, isNotNull);
    expect(state.identity!.fingerprintHex, hasLength(64));
    expect(state.error, isNull);

    final prefs = await container.read(preferencesRepositoryProvider).load();
    expect(prefs.lastServerUrl, 'https://home.example.com');
  });

  test('an invalid URL is rejected without touching the network', () async {
    final (container, _) = await buildContainer();
    container.read(pairingControllerProvider.notifier).setServerUrl('not-a-url');
    await container.read(pairingControllerProvider.notifier).testConnection();

    final state = container.read(pairingControllerProvider);
    expect(state.phase, PairingPhase.idle);
    expect(state.urlIssue, isNotNull);
    expect(state.identity, isNull);
  });

  test('an approved answer persists the pairing but waits for "Continue"', () async {
    final (container, _) = await buildContainer();
    await connect(container);
    await container.read(pairingControllerProvider.notifier).submitPairing();

    var state = container.read(pairingControllerProvider);
    expect(state.phase, PairingPhase.approved);
    expect(state.status?.state, PairingState.approved);
    expect(state.paired, isFalse, reason: 'the success screen shows first');

    final prefs = await container.read(preferencesRepositoryProvider).load();
    expect(prefs.pairingStatus, 'approved');
    final store = container.read(secureStoreProvider);
    expect(await store.read(SecureKeys.deviceKey), isNotEmpty);
    expect(await store.read(SecureKeys.deviceId), isNotEmpty);

    container.read(pairingControllerProvider.notifier).confirmPaired();
    state = container.read(pairingControllerProvider);
    expect(state.paired, isTrue, reason: 'this flips the router gate');
  });

  test('a pending answer keeps the gate closed until approval', () async {
    final (container, control) = await buildContainer(outcome: MockPairingOutcome.pending);
    await connect(container);
    await container.read(pairingControllerProvider.notifier).submitPairing();

    var state = container.read(pairingControllerProvider);
    expect(state.phase, PairingPhase.pending);
    expect(state.paired, isFalse);
    expect(
      (await container.read(preferencesRepositoryProvider).load()).pairingStatus,
      'pending',
    );

    // The owner taps Approve in the admin panel, then "Check approval status".
    control.pairingOutcome = MockPairingOutcome.approved;
    await container.read(pairingControllerProvider.notifier).submitPairing();

    state = container.read(pairingControllerProvider);
    expect(state.phase, PairingPhase.approved);
    expect(state.paired, isFalse);
  });

  test('a rejected answer records the refusal and keeps the gate closed', () async {
    final (container, _) = await buildContainer(outcome: MockPairingOutcome.rejected);
    await connect(container);
    await container.read(pairingControllerProvider.notifier).submitPairing();

    final state = container.read(pairingControllerProvider);
    expect(state.phase, PairingPhase.rejected);
    expect(state.paired, isFalse);
    expect(state.error, isA<Exception>());
    expect(
      (await container.read(preferencesRepositoryProvider).load()).pairingStatus,
      'rejected',
    );
  });

  test('restore flips straight to the gate when the device is already paired', () async {
    final store = InMemorySecureStore(<String, String>{
      SecureKeys.deviceKey: 'issued-device-key',
      SecureKeys.deviceId: 'device-1',
      SecureKeys.devicePublicKey:
          'MCowBQYDK2VwAyEAGb5ECmVtcmFuY2Vycm9yZGVidWc2Ng==',
      SecureKeys.devicePrivateKey: 'priv-seed-material-for-restore',
    });
    final control = MockBackendControl(
      latency: Duration.zero,
      tokenInterval: Duration.zero,
    );
    final container = ProviderContainer(
      overrides: <Override>[
        ...testOverrides(secureStore: store),
        armxApiProvider.overrideWithValue(Fixtures.mockApi(control: control)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(pairingControllerProvider.notifier).restore();

    final state = container.read(pairingControllerProvider);
    expect(state.paired, isTrue);
    expect(state.phase, PairingPhase.approved);
  });

  test('resetAfterUnpair returns the flow to a fresh pairing screen', () async {
    final (container, _) = await buildContainer();
    await connect(container);
    await container.read(pairingControllerProvider.notifier).submitPairing();
    container.read(pairingControllerProvider.notifier).confirmPaired();

    container.read(pairingControllerProvider.notifier).resetAfterUnpair();

    final state = container.read(pairingControllerProvider);
    expect(state.paired, isFalse);
    expect(state.phase, PairingPhase.idle);
    expect(state.serverUrl, isEmpty);
  });
}
