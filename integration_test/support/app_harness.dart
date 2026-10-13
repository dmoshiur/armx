// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/app.dart';
import 'package:armx_ai/core/config/app_config.dart';
import 'package:armx_ai/core/network/token_store.dart';
import 'package:armx_ai/core/providers.dart';
import 'package:armx_ai/core/security/risk_tier.dart';
import 'package:armx_ai/core/widgets/armx_button.dart';
import 'package:armx_ai/data/api/armx_api.dart';
import 'package:armx_ai/data/api/mock/mock_armx_api.dart';
import 'package:armx_ai/data/api/mock/mock_fixtures.dart';
import 'package:armx_ai/data/models/device.dart';
import 'package:armx_ai/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A mock backend that records the calls the UI makes.
///
/// Confirming "nothing was sent to the backend before the user confirmed" is a claim about
/// the network, so it is checked at the network rather than by looking at the screen.
class RecordingMockApi extends MockArmxApi {
  /// Creates the recorder.
  RecordingMockApi({super.clock}) : super(latency: Duration.zero);

  /// Every privileged call the UI made, in order.
  final List<String> calls = <String>[];

  @override
  Future<void> decideToolCall({
    required String toolCallId,
    required ToolDecision decision,
    String? denyReason,
  }) {
    calls.add('decideToolCall:${decision.name}');
    return super.decideToolCall(
      toolCallId: toolCallId,
      decision: decision,
      denyReason: denyReason,
    );
  }

  @override
  Future<DeviceCommandResult> sendDeviceCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> parameters = const <String, Object?>{},
    RiskTier? declaredRisk,
  }) {
    calls.add('sendDeviceCommand:$command');
    return super.sendDeviceCommand(
      deviceId: deviceId,
      command: command,
      parameters: parameters,
      declaredRisk: declaredRisk,
    );
  }
}

/// The app under test: the real widget tree, the real router, the real theme.
class AppHarness {
  AppHarness._(this.container, this.api);

  /// The provider container the app is running on.
  final ProviderContainer container;

  /// The recording backend.
  final RecordingMockApi api;

  /// Boots the app exactly as `main()` does — same override, same scope — and waits for the
  /// splash to hand over.
  ///
  /// [size] is the logical window size, so the same harness drives the responsive checks.
  static Future<AppHarness> boot(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    double textScale = 1,
  }) async {
    // The window size and the text scale come from the platform, which is exactly where the
    // running app reads them from — no test-only MediaQuery is injected above the app.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });

    final RecordingMockApi api = RecordingMockApi();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appConfigProvider.overrideWithValue(
          AppConfig(
            apiBaseUrl: Uri.parse('https://armx.test:8443'),
            webSocketUrl: Uri.parse('wss://armx.test:8443/ws'),
            useMockBackend: true,
            environment: 'integration',
          ),
        ),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        armxApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ArmxApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return AppHarness._(container, api);
  }

  /// The active localizations, read from the running app rather than constructed separately.
  AppLocalizations strings(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(ArmxApp)))!;

  /// Signs in with the owner account through the real sign-in form.
  Future<void> signIn(
    WidgetTester tester, {
    String email = MockFixtures.ownerEmail,
    String password = MockFixtures.ownerPassword,
  }) async {
    final AppLocalizations l10n = strings(tester);
    expect(
      find.text(l10n.authLoginTitle),
      findsOneWidget,
      reason: 'the harness expects to start signed out, on the sign-in screen',
    );

    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ArmxButton, l10n.authSignInAction));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(l10n.authLoginTitle), findsNothing);
  }

  /// Navigates the way the app does, through the router, so guards still run.
  Future<void> go(WidgetTester tester, String location) async {
    container.read(appRouterProvider).go(location);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }
}
