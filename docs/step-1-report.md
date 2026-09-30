<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Step 1 report — setup, theme, router, l10n, skeleton, mock backend

A.R.M.X AI client · owner **Md. Moshiur Rahman Mohi** · brand **THAMJJ13.TOP** ·
Flutter 3.47.5 / Dart 3.13.4 · target Android + Windows/Linux desktop.

> **Sandbox limitation.** This container has no Flutter/Dart SDK, so `flutter analyze`,
> `flutter test` and `dart run build_runner` could not be executed here. Every cross-file
> reference was reconciled by reading the source; the open items to confirm on the first
> analyzer run are listed at the end of this document.

## 1. File tree

```
assets/
  fonts/
    Inter.ttf
    JetBrainsMono.ttf
    OFL-Inter.txt
    OFL-JetBrainsMono.txt
  images/
    README.md
  models/
    README.md
docs/
  decisions/
    0002-dependency-pins.md
  api.md
  run.md
  step-1-report.md
integration_test/
lib/
  core/
    config/
      app_config.dart
      app_info.dart
    errors/
      app_exception.dart
      error_mapper.dart
      error_messages.dart
    l10n/
      l10n.dart
    logging/
      armx_logger.dart
      log_redactor.dart
    router/
      app_router.dart
      routes.dart
    security/
      risk_policy.dart
      risk_tier.dart
      secure_screen.dart
      secure_store.dart
      security_constants.dart
      verification_evidence.dart
    theme/
      armx_colors.dart
      armx_effects.dart
      armx_theme.dart
      armx_typography.dart
      motion.dart
    utils/
      clock.dart
      formatters.dart
      hex.dart
      json_utils.dart
      platform_capabilities.dart
      responsive.dart
      validators.dart
    widgets/
      ambient_background.dart
      armx_app_bar.dart
      armx_button.dart
      armx_controls.dart
      armx_glow_button.dart
      armx_orb.dart
      armx_text_field.dart
      armx_tile.dart
      armx_wordmark.dart
      glass_panel.dart
      layout_blocks.dart
      risk_tier_chip.dart
      sanitized_markdown.dart
      state_views.dart
      status_pill.dart
    providers.dart
  data/
    api/
      mock/
        mock_admin_data.dart
        mock_admin_domain.dart
        mock_api.dart
        mock_assistant.dart
        mock_audit_data.dart
        mock_auth_domain.dart
        mock_chat_domain.dart
        mock_data.dart
        mock_device_domain.dart
        mock_rule_data.dart
        mock_rule_domain.dart
        mock_unlock_data.dart
        mock_unlock_domain.dart
      armx_api.dart
      ws_events.dart
      ws_events_assistant.dart
      ws_events_system.dart
    db/
      armx_database.dart
      tables.dart
    models/
      admin.dart
      audit_entry.dart
      auth.dart
      chat.dart
      converters.dart
      device.dart
      preferences.dart
      rules.dart
      unlock.dart
      vision.dart
    repositories/
      preferences_repository.dart
  features/
    bootstrap/
      bootstrap.dart
      bootstrap_gate.dart
    common/
      placeholder_page.dart
    dev/
      design_system_page.dart
    settings/
      about_page.dart
      diagnostics_page.dart
      settings_page.dart
    shell/
      app_shell.dart
    splash/
      splash_page.dart
  l10n/
    app_bn.arb
    app_en.arb
  app.dart
  main.dart
test/
  support/
    fixtures.dart
    test_harness.dart
  unit/
    core/
      security/
        risk_policy_test.dart
      utils/
        validators_and_hex_test.dart
    data/
      mock_api_chat_test.dart
      mock_api_test.dart
      ws_events_test.dart
tool/
README.md
analysis_options.yaml
build.yaml
l10n.yaml
pubspec.yaml
```

## 2. `pubspec.yaml`

```yaml
# Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.
#
# A.R.M.X AI — Automated Resource Management eXtension (client).
# Every dependency is PINNED EXACTLY (no ^, no ranges) so builds are reproducible.
# Version resolution notes and deliberate substitutions are documented in docs/decisions/0002-dependency-pins.md
# and README.md ("Dependency decisions").

name: armx_ai
description: >-
  A.R.M.X AI (Automated Resource Management eXtension) client application.
  Owner: Md. Moshiur Rahman Mohi. Brand: THAMJJ13.TOP. Proprietary software.
publish_to: "none"
version: 0.1.0+1

environment:
  # Flutter 3.47.5 ships Dart 3.13.4 (stable, 2026-09-18). Floor is 3.12.0 because
  # flutter_riverpod 3.4.3 and camera 0.12.1 both require Dart ^3.12.0 / Flutter >=3.44.0.
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # ---- State management ----------------------------------------------------
  flutter_riverpod: 3.4.3 # latest stable on the 3.4 line
  riverpod_annotation: 4.0.7 # generator 4.0.9 <-> annotation 4.0.7 is the published pairing

  # ---- Routing -------------------------------------------------------------
  go_router: 18.0.2

  # ---- Models --------------------------------------------------------------
  freezed_annotation: 3.1.0
  json_annotation: 4.12.0

  # ---- Local database (offline cache, prefs, outbox) -----------------------
  drift: 2.35.0
  drift_flutter: 0.3.1 # bundles path_provider + sqlite3_flutter_libs wiring for all target platforms

  # ---- Logging -------------------------------------------------------------
  logger: 2.7.0

  # ---- Network -------------------------------------------------------------
  dio: 5.11.1
  web_socket_channel: 3.0.1

  # ---- Secure storage + crypto --------------------------------------------
  flutter_secure_storage: 10.3.4
  cryptography: 2.9.0 # Ed25519 + SHA-256 (package:crypto has no Ed25519)

  # ---- Voice ---------------------------------------------------------------
  speech_to_text: 7.5.0
  flutter_tts: 4.2.5

  # ---- Vision --------------------------------------------------------------
  camera: 0.12.1
  google_mlkit_face_detection: 0.13.2
  google_mlkit_pose_detection: 0.14.1 # palm gesture; Android/iOS only (desktop degrades gracefully)
  tflite_flutter: 0.12.1 # face embeddings, on-device only

  # ---- Device / system -----------------------------------------------------
  local_auth: 3.0.2
  permission_handler: 13.0.2
  geolocator: 14.1.1

  # ---- Activity ------------------------------------------------------------
  flutter_activity_recognition: 4.0.0

  # ---- Misc ----------------------------------------------------------------
  qr_flutter: 4.1.0 # pairing QR for the device public key / fingerprint
  intl: 0.20.3 # must stay compatible with flutter_localizations (^0.20.3 on Flutter 3.47)
  uuid: 4.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  flutter_lints: 6.0.0

  # ---- Code generation -----------------------------------------------------
  build_runner: 2.16.1
  freezed: 4.0.2
  json_serializable: 6.14.1
  drift_dev: 2.35.0
  riverpod_generator: 4.0.9

  # ---- Lints ---------------------------------------------------------------
  custom_lint: 0.8.1
  riverpod_lint: 3.1.9

  # ---- Test helpers --------------------------------------------------------
  mocktail: 1.0.5

flutter:
  uses-material-design: true
  generate: true # runs `flutter gen-l10n` from l10n.yaml during pub get / build

  assets:
    - assets/models/ # optional .tflite model dir (see assets/models/README.md)
    - assets/images/

  # Fonts are BUNDLED (no runtime font downloads, works offline, no network fonts).
  # Both files are variable fonts (fvar axes: Inter -> opsz,wght; JetBrains Mono -> wght);
  # typography sets FontVariation values so weights render exactly.
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter.ttf
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono.ttf
```

## 3. Per-file contents

Every Dart file starts with the proprietary header and public members carry doc
comments. `lib/` and `test/` are listed below with each file's public surface.

### `lib/app.dart` · 43 lines

- **ArmxApp** — Root widget: themes, localization delegates and the router.
  - `ArmxApp`
  - `build`

### `lib/core/config/app_config.dart` · 164 lines

- **AppLogLevel** — Log levels understood by the app (mapped onto `package:logger` in `core/logging`).
- **AppEnvironment** — Deployment environment. Only [AppEnvironment.production] enforces strict TLS.
- **AppConfig**
  - `AppConfig`
  - `environment`
  - `apiBaseUrl`
  - `wsUrl`
  - `useMockBackend`
  - `logLevel`
  - `certificatePins`
  - `mockLatencyMs`
  - `wakeWordEngineId`
  - `faceMatchThreshold`
  - `palmGestureEnabled`
  - `telemetryEnabled`
  - `requiresTls`
  - `hasCertificatePins`
  - `isOfflineFirst`
  - `describe`
  - `validate`

### `lib/core/config/app_info.dart` · 51 lines

- **AppInfo** — Static product identity, ownership and credit strings.
  - `productName`
  - `productLongName`
  - `version`
  - `buildNumber`
  - `owner`
  - `brand`
  - `credit`
  - `copyrightHeader`
  - `packageName`
  - `applicationId`
  - `wakeWord`
  - `versionLabel`
  - `isRelease`

### `lib/core/errors/app_exception.dart` · 285 lines

- **AppException** — Base type for every error A.R.M.X surfaces to the user.
  - `AppException`
  - `message`
  - `cause`
  - `stackTrace`
  - `isRetryable`
  - `code`
  - `toString`
- **ConfigException** — Misconfiguration detected at startup (bad `--dart-define`, unreachable pin set, …).
  - `ConfigException`
  - `code`
- **NetworkException** — Transport failure: DNS, TLS, socket, or a refused connection.
  - `NetworkException`
  - `code`
- **RequestTimeoutException** — The request was accepted but did not complete in the allotted time.
  - `RequestTimeoutException`
  - `code`
- **ApiException** — The server answered with a non-success status or an unparsable payload.
  - `ApiException`
  - `statusCode`
  - `serverCode`
  - `code`
- **AuthException** — Authentication, pairing and session failures.
  - `AuthException`
  - `reason`
  - `code`
  - `message`
- **AuthFailureReason** — Why an authentication attempt failed.
- **PolicyException** — The risk policy refused an action because verification was insufficient or stale.
  - `PolicyException`
  - `requiredTier`
  - `satisfiedTier`
  - `reason`
  - `code`
- **VerificationException** — A verification prompt (face / voice / biometric) failed or was cancelled.
  - `VerificationException`
  - `reason`
  - `code`
  - `message`
- **VerificationFailureReason** — Why a verification attempt failed.
- **StorageException** — Secure storage / local database failure.
  - `StorageException`
  - `code`
- **PermissionDeniedException** — A permission (camera, microphone, activity, location, notifications) was denied.
  - `PermissionDeniedException`
  - `permission`
  - `permanentlyDenied`
  - `code`
  - `message`
- **PlatformUnsupportedException** — The requested capability does not exist on this platform (for example ML Kit on Linux).
  - `PlatformUnsupportedException`
  - `feature`
  - `platformName`
  - `code`
  - `message`
- **TransportClosedException** — The WebSocket session dropped and is currently reconnecting.
  - `TransportClosedException`
  - `code`
- **KillSwitchActiveException** — The global kill-switch is engaged; privileged actions are blocked.
  - `KillSwitchActiveException`
  - `code`

### `lib/core/errors/error_mapper.dart` · 101 lines

- **ErrorMapper** — Converts arbitrary errors (Dio, WebSocket, platform channels) into [AppException]s.
  - `map`

### `lib/core/errors/error_messages.dart` · 62 lines

- **AppErrorMessages** — Turns the sealed [AppException] hierarchy into localized titles and bodies.
  - `title`
  - `body`

### `lib/core/l10n/l10n.dart` · 78 lines

- **ArmxL10n** — Localization access + error/validation translation helpers.
  - `l10n`
  - `errorTitle`
  - `errorBody`
  - `validationMessage`
- **AppLanguage** — Locale identifiers supported by the product.
  - `AppLanguage`
  - `locale`
  - `englishLabel`
  - `bengaliLabel`
  - `fromCode`
  - `code`
  - `label`

### `lib/core/logging/armx_logger.dart` · 152 lines

- **LogRecord**
  - `LogRecord`
  - `time`
  - `level`
  - `message`
- **LogRingBuffer** — Fixed-size ring buffer of recent log lines.
  - `capacity`
  - `records`
  - `add`
  - `clear`
- **ArmxLogPrinter** — `LogPrinter` that redacts before printing and mirrors output into a [LogRingBuffer].
  - `buffer`
  - `colors`
  - `includeTimestamp`
  - `log`
- **LevelLogFilter** — Keeps only events at or above a configured level.
  - `LevelLogFilter`
  - `level`
  - `shouldLog`
- **ArmxLogging** — Factory for the app-wide [Logger].
  - `create`

### `lib/core/logging/log_redactor.dart` · 129 lines

- **LogRedactor** — Removes secrets and biometric material from anything that reaches a log sink.
  - `mask`
  - `sensitiveKeys`
  - `redact`
  - `redactValue`
  - `encodeRedacted`
  - `fingerprint`

### `lib/core/providers.dart` · 86 lines

  - `config`
  - `MockArmxApi`

### `lib/core/router/app_router.dart` · 211 lines

  - `GoRouter`
- **AppRouteErrorPage** — Fallback screen for an unknown or malformed route.
  - `AppRouteErrorPage`
  - `message`
  - `build`

### `lib/core/router/routes.dart` · 52 lines

- **AppRoutes** — Every route path in the app, in one place.
  - `splash`
  - `login`
  - `pairing`
  - `dashboard`
  - `chat`
  - `devices`
  - `activity`
  - `admin`
  - `vision`
  - `unlock`
  - `settings`
  - `about`
  - `diagnostics`
  - `designSystem`
  - `placeholderName`

### `lib/core/security/risk_policy.dart` · 297 lines

- **PolicyDenialReason** — Why a privileged action was refused.
- **PolicyDecision**
  - `allowed`
  - `required`
  - `satisfied`
  - `reason`
  - `missingFactors`
  - `expiresIn`
  - `needsReVerification`
  - `toString`
- **RiskPolicy** — The single place where A.R.M.X decides how much verification an action needs.
  - `allowVoiceOnlyForLowTier`
  - `trustWindow`
  - `requiredFactors`
  - `requiresSystemBiometric`
  - `evaluate`
- **_FactorState**
  - `fresh`

### `lib/core/security/risk_tier.dart` · 39 lines

- **RiskTier** — Action risk classification used across chat tool calls, device commands, rules and unlock.
  - `wireName`
  - `isAtLeast`
  - `fromWire`

### `lib/core/security/secure_screen.dart` · 127 lines

- **ScreenSecurity** — Contract for blocking screenshots/screen recording on sensitive screens.
  - `enable`
  - `disable`
  - `isSupported`
- **PlatformScreenSecurity** — Android implementation using `FLAG_SECURE`.
  - `isSupported`
  - `enable`
  - `disable`
- **NoopScreenSecurity** — [ScreenSecurity] that does nothing (tests, unsupported platforms).
  - `NoopScreenSecurity`
  - `isSupported`
  - `enable`
  - `disable`
- **SecureScreen** — Wraps a subtree and keeps the screenshot flag enabled while it is mounted.
  - `SecureScreen`
  - `child`
  - `security`
  - `enabled`
  - `createState`
- **_SecureScreenState**
  - `initState`
  - `didUpdateWidget`
  - `dispose`
  - `build`

### `lib/core/security/secure_store.dart` · 171 lines

- **SecureKeys** — Every key A.R.M.X writes into platform secure storage.
  - `accessToken`
  - `refreshToken`
  - `accessTokenExpiry`
  - `deviceKey`
  - `deviceId`
  - `devicePrivateKey`
  - `devicePublicKey`
  - `ownerAssertionKey`
  - `installSalt`
  - `all`
  - `biometricRelated`
- **SecureStore** — Minimal key/value contract over platform secure storage.
  - `read`
  - `write`
  - `delete`
  - `clear`
  - `deleteKeys`
- **PlatformSecureStore** — [SecureStore] backed by `flutter_secure_storage`
  - `read`
  - `write`
  - `delete`
  - `deleteKeys`
  - `clear`
- **InMemorySecureStore** — Non-persistent [SecureStore] for tests and for mock mode on machines without a keyring.
  - `snapshot`
  - `read`
  - `write`
  - `delete`
  - `deleteKeys`
  - `clear`

### `lib/core/security/security_constants.dart` · 38 lines

- **SecurityConstants** — Single source of truth for the security-relevant numbers in the product spec.
  - `verificationTrustWindow`
  - `unlockTokenTtl`
  - `ownerVerifiedTtl`
  - `clockSkewAllowance`
  - `faceEnrolmentAngles`
  - `minFaceThreshold`
  - `maxFaceThreshold`
  - `defaultFaceThreshold`
  - `minVoiceSampleDuration`
  - `killSwitchHoldDuration`
  - `minPasswordLength`

### `lib/core/security/verification_evidence.dart` · 148 lines

- **VerificationFactor** — The three verification factors A.R.M.X can ask for.
- **FactorResult**
  - `FactorResult`
  - `isFreshAt`
  - `ageAt`
- **VerificationEvidence**
  - `VerificationEvidence`
  - `latest`
  - `hasFresh`
  - `hasFreshAfter`
  - `withResult`
  - `satisfiedTier`
  - `secondsRemaining`
  - `cleared`

### `lib/core/theme/armx_colors.dart` · 266 lines

- **ArmxPalette** — The A.R.M.X brand palette, exactly as specified in the brand PDF.
  - `darkBackground`
  - `darkPanel`
  - `darkPanel2`
  - `darkCyan`
  - `darkViolet`
  - `darkText`
  - `darkMuted`
  - `darkBorder`
  - `darkAmber`
  - `darkGreen`
  - `darkRed`
  - `lightBackground`
  - `lightPanel`
  - `lightPanel2`
  - `lightCyan`
  - `lightViolet`
  - `lightText`
  - `lightMuted`
  - `lightBorder`
  - `lightAmber`
  - `lightGreen`
  - `lightRed`
- **ArmxColors**
  - `ArmxColors`
  - `dark`
  - `light`
  - `background`
  - `panel`
  - `panel2`
  - `cyan`
  - `violet`
  - `text`
  - `muted`
  - `border`
  - `amber`
  - `green`
  - `red`
  - `isDark`
  - `of`
  - `glassFill`
  - `glassBorder`
  - `scrim`
  - `severity`
  - `copyWith`
  - `lerp`
- **SeverityTone** — Semantic colour intents, so widgets ask for meaning instead of a specific hue.

### `lib/core/theme/armx_effects.dart` · 79 lines

- **ArmxEffects** — Glows, gradients and shadow recipes used by the signature widgets.
  - `cyanGlow`
  - `tintGlow`
  - `panelShadow`
  - `brandGradient`
  - `orbCore`
  - `ambientBackground`

### `lib/core/theme/armx_theme.dart` · 203 lines

- **ArmxTheme** — Material 3 [ThemeData] for A.R.M.X AI, dark-first with a matching light variant.
  - `minimumTouchTarget`
  - `panelRadius`
  - `pillRadius`
  - `dark`
  - `light`
  - `themeModeFromName`
  - `themeModeToName`

### `lib/core/theme/armx_typography.dart` · 116 lines

- **ArmxTypography** — Typography for A.R.M.X AI.
  - `bodyFamily`
  - `monoFamily`
  - `textTheme`
  - `inter`
  - `mono`
  - `wordmark`

### `lib/core/theme/motion.dart` · 57 lines

- **ArmxMotion** — Motion tokens for the whole app.
  - `quick`
  - `standard`
  - `gentle`
  - `breath`
  - `pulse`
  - `enter`
  - `exit`
  - `breathe`
  - `reduceMotion`
  - `respect`
  - `respectAnimation`
  - `pageTransitions`

### `lib/core/utils/clock.dart` · 56 lines

- **Clock** — Injectable time source.
  - `now`
- **SystemClock** — [Clock] backed by the system wall clock.
  - `SystemClock`
  - `now`
- **FixedClock** — [Clock] whose time only moves when a test asks it to.
  - `instant`
  - `now`
  - `advance`
  - `set`
- **StopwatchClock** — Monotonic stopwatch used for latency badges; independent from wall-clock changes.
  - `start`
  - `elapsed`
  - `stop`

### `lib/core/utils/formatters.dart` · 75 lines

- **ArmxFormatters** — Presentation helpers shared by dashboard, audit log and diagnostics.
  - `time`
  - `dateTime`
  - `date`
  - `countdown`
  - `relative`
  - `decimal`
  - `percent`
  - `bytes`

### `lib/core/utils/hex.dart` · 69 lines

- **Hex** — Byte/hex helpers used for key fingerprints, nonces and pins.
  - `encode`
  - `decode`
  - `group`
  - `constantTimeEquals`

### `lib/core/utils/json_utils.dart` · 116 lines

- **JsonUtils** — Defensive readers for JSON that arrives from the network.
  - `maxStringLength`
  - `string`
  - `integer`
  - `number`
  - `boolean`
  - `dateTime`
  - `asMap`
  - `asMapList`
  - `stringList`

### `lib/core/utils/platform_capabilities.dart` · 169 lines

- **PlatformFeature** — A capability the product would like to use, but which is not available everywhere.
- **PlatformCapabilities** — Answers "can this build use feature X on this platform, and if not, why?".
  - `supports`
  - `unsupportedReason`
  - `isDesktop`
  - `isMobile`

### `lib/core/utils/responsive.dart` · 53 lines

- **ArmxBreakpoint** — Layout breakpoints. Phone is the primary target, desktop must look intentional.
  - `fromWidth`
- **ArmxResponsive** — Convenience accessors for responsive layout decisions.
  - `breakpoint`
  - `isCompact`
  - `isExpanded`
  - `pagePadding`
  - `maxContentWidth`

### `lib/core/utils/validators.dart` · 125 lines

- **ValidationIssue** — Reason a piece of user input was rejected. UI code maps these to ARB strings.
- **Validators** — Pure input validation shared by every form in the app.
  - `serverUrl`
  - `normaliseServerUrl`
  - `deviceKey`
  - `nonEmpty`
  - `matchThreshold`
  - `wakeWord`

### `lib/core/widgets/ambient_background.dart` · 59 lines

- **ArmxBackground** — Paints the A.R.M.X ambient background (violet-to-background radial gradient) behind a page.
  - `ArmxBackground`
  - `child`
  - `showGrid`
  - `build`
- **_GridPainter**
  - `color`
  - `spacing`
  - `paint`
  - `shouldRepaint`

### `lib/core/widgets/armx_app_bar.dart` · 83 lines

- **ArmxAppBar** — Standard app bar with an optional wordmark title and a slot for the kill-switch.
  - `ArmxAppBar`
  - `title`
  - `useWordmark`
  - `actions`
  - `leading`
  - `subtitle`
  - `bottom`
  - `automaticallyImplyLeading`
  - `preferredSize`
  - `build`

### `lib/core/widgets/armx_button.dart` · 136 lines

- **ArmxButtonVariant** — Visual variants of [ArmxButton].
- **ArmxButton** — The app's button: 48 dp minimum height, optional spinner, explicit semantics.
  - `ArmxButton`
  - `label`
  - `onPressed`
  - `icon`
  - `variant`
  - `loading`
  - `expanded`
  - `tooltip`
  - `build`

### `lib/core/widgets/armx_controls.dart` · 8 lines

_Barrel file: re-exports only._

### `lib/core/widgets/armx_glow_button.dart` · 49 lines

- **ArmxGlowButton** — Glowing primary CTA used for the single most important action on a screen.
  - `ArmxGlowButton`
  - `label`
  - `onPressed`
  - `icon`
  - `loading`
  - `build`

### `lib/core/widgets/armx_orb.dart` · 206 lines

- **ArmxOrbState** — Assistant states rendered by [ArmxOrb].
- **ArmxOrb** — The glowing assistant orb — the signature widget of A.R.M.X AI.
  - `ArmxOrb`
  - `state`
  - `size`
  - `onTap`
  - `showLabel`
  - `createState`
- **_ArmxOrbState**
  - `initState`
  - `didUpdateWidget`
  - `dispose`
  - `build`

### `lib/core/widgets/armx_text_field.dart` · 136 lines

- **ArmxTextField** — Branded text field. Styles `InputDecoration` inline so no theme extension is required
  - `ArmxTextField`
  - `controller`
  - `label`
  - `hint`
  - `helper`
  - `errorText`
  - `obscure`
  - `enabled`
  - `maxLines`
  - `keyboardType`
  - `textInputAction`
  - `autofillHints`
  - `prefixIcon`
  - `suffix`
  - `onChanged`
  - `onSubmitted`
  - `focusNode`
  - `build`

### `lib/core/widgets/armx_tile.dart` · 103 lines

- **ArmxTile** — Rounded icon + text tile used by settings rows and quick actions.
  - `ArmxTile`
  - `title`
  - `subtitle`
  - `leading`
  - `trailing`
  - `onTap`
  - `accent`
  - `build`
- **MinTouchTarget** — Applies the theme's minimum touch target to any child.
  - `MinTouchTarget`
  - `child`
  - `build`

### `lib/core/widgets/armx_wordmark.dart` · 53 lines

- **ArmxWordmark** — The `A.R.M.X AI` wordmark: dark wordmark with the cyan "AI", per brand guidelines.
  - `ArmxWordmark`
  - `fontSize`
  - `showAi`
  - `color`
  - `semanticsLabel`
  - `build`

### `lib/core/widgets/glass_panel.dart` · 95 lines

- **GlassPanel** — The signature frosted panel used by every card in A.R.M.X.
  - `GlassPanel`
  - `child`
  - `padding`
  - `margin`
  - `accent`
  - `onTap`
  - `elevated`
  - `semanticLabel`
  - `build`
- **ArmxMotionDurations** — Motion durations re-exported so widgets do not import the motion module twice.
  - `quick`

### `lib/core/widgets/layout_blocks.dart` · 90 lines

- **SectionHeader** — A themed "section" heading used above lists and grouped settings.
  - `SectionHeader`
  - `title`
  - `subtitle`
  - `trailing`
  - `build`
- **ArmxPageBody** — Convenience wrapper that applies the standard page padding and max content width.
  - `ArmxPageBody`
  - `child`
  - `scrollable`
  - `build`

### `lib/core/widgets/risk_tier_chip.dart` · 102 lines

- **RiskTierChip** — The mandatory risk badge: LOW = green, MEDIUM = amber, HIGH = red.
  - `RiskTierChip`
  - `tier`
  - `showRequirements`
  - `compact`
  - `requirementsFor`
  - `build`

### `lib/core/widgets/sanitized_markdown.dart` · 266 lines

- **SanitizedMarkdown** — Renders **untrusted** assistant/tool text with a deliberately tiny Markdown subset.
  - `SanitizedMarkdown`
  - `text`
  - `textStyle`
  - `maxBlocks`
  - `maxCharacters`
  - `build`
- **_BulletRow**
  - `bullet`
  - `child`
  - `color`
  - `build`

### `lib/core/widgets/state_views.dart` · 244 lines

- **LoadingView** — Centred progress indicator with a localized accessibility label.
  - `LoadingView`
  - `message`
  - `compact`
  - `build`
- **EmptyView** — Empty-state card with an optional call to action.
  - `EmptyView`
  - `title`
  - `message`
  - `icon`
  - `action`
  - `build`
- **ErrorView** — Error card with a localized title/body and a retry button.
  - `ErrorView`
  - `error`
  - `onRetry`
  - `compact`
  - `build`
- **UnsupportedView** — "This platform cannot do that" card, used by every feature that degrades gracefully.
  - `UnsupportedView`
  - `feature`
  - `reason`
  - `build`

### `lib/core/widgets/status_pill.dart` · 84 lines

- **StatusPill** — Small rounded status indicator ("Connected", "Offline", "KILL-SWITCH", …).
  - `StatusPill`
  - `label`
  - `tone`
  - `icon`
  - `showDot`
  - `compact`
  - `semanticLabel`
  - `build`

### `lib/data/api/armx_api.dart` · 137 lines

- **ArmxApi** — The complete backend contract of A.R.M.X AI.
  - `probe`
  - `login`
  - `pair`
  - `logout`
  - `devices`
  - `sendCommand`
  - `activateScene`
  - `audit`
  - `adminState`
  - `setKillSwitch`
  - `setToolEnabled`
  - `revokeDevice`
  - `unlockTargets`
  - `requestUnlock`
  - `revokeUnlockTarget`
  - `rules`
  - `upsertRule`
  - `deleteRule`
  - `dryRunRule`
  - `events`
  - `sendChatMessage`
  - `decideToolCall`
  - `dispose`

### `lib/data/api/mock/mock_admin_data.dart` · 59 lines

- **MockAdminData** — Seeded tool switches for the admin panel of the mock backend.
  - `tools`

### `lib/data/api/mock/mock_admin_domain.dart` · 127 lines

- **MockAdminDomain** — MockAdminDomain — one slice of [MockArmxApi].
  - `audit`
  - `adminState`
  - `setKillSwitch`
  - `setToolEnabled`
  - `revokeDevice`

### `lib/data/api/mock/mock_api.dart` · 251 lines

- **MockBackendControl** — Fault-injection and pacing knobs for the mock backend.
  - `latency`
  - `offline`
  - `failNext`
  - `toolCallDelay`
  - `tokenInterval`
- **MockArmxApi** — Deterministic in-memory implementation of [ArmxApi].
  - `deterministicRandom`
  - `config`
  - `control`
  - `localeCode`
  - `conversationId`
  - `dispose`

### `lib/data/api/mock/mock_assistant.dart` · 166 lines

- **MockAssistantScript** — A scripted assistant turn produced by the mock backend.
  - `MockAssistantScript`
  - `replyText`
  - `messageId`
  - `toolCall`
- **MockAssistant** — Deterministic, offline stand-in for the real assistant.
  - `scriptFor`
  - `tokenize`
  - `messageIdFor`
  - `userIdFor`
  - `conversationIdFor`
  - `assistantReplies`

### `lib/data/api/mock/mock_audit_data.dart` · 135 lines

- **MockAuditData** — Seeded audit trail for the mock backend (newest first once a consumer sorts it).
  - `audit`

### `lib/data/api/mock/mock_auth_domain.dart` · 77 lines

- **MockAuthDomain** — MockAuthDomain — one slice of [MockArmxApi].
  - `probe`
  - `login`
  - `pair`
  - `logout`

### `lib/data/api/mock/mock_chat_domain.dart` · 128 lines

- **MockChatDomain** — MockChatDomain — one slice of [MockArmxApi].
  - `events`
  - `sendChatMessage`
  - `decideToolCall`

### `lib/data/api/mock/mock_data.dart` · 151 lines

- **MockData** — Seed data for the in-app mock backend: the four fake ESP32 nodes.
  - `devices`

### `lib/data/api/mock/mock_device_domain.dart` · 58 lines

- **MockDeviceDomain** — MockDeviceDomain — one slice of [MockArmxApi].
  - `devices`
  - `sendCommand`
  - `activateScene`

### `lib/data/api/mock/mock_rule_data.dart` · 78 lines

- **MockRuleData** — Seeded automation rules and geofences for the mock backend.
  - `rules`
  - `geofences`

### `lib/data/api/mock/mock_rule_domain.dart` · 53 lines

- **MockRuleDomain** — MockRuleDomain — one slice of [MockArmxApi].
  - `rules`
  - `upsertRule`
  - `deleteRule`
  - `dryRunRule`

### `lib/data/api/mock/mock_unlock_data.dart` · 38 lines

- **MockUnlockData** — Seeded unlock targets for the mock backend.
  - `unlockTargets`

### `lib/data/api/mock/mock_unlock_domain.dart` · 76 lines

- **MockUnlockDomain** — MockUnlockDomain — one slice of [MockArmxApi].
  - `unlockTargets`
  - `requestUnlock`
  - `revokeUnlockTarget`

### `lib/data/api/ws_events.dart` · 145 lines

- **WsEventType** — Wire names of the WebSocket events (mirrors `docs/api.md`).
  - `assistantToken`
  - `assistantDone`
  - `toolRequest`
  - `toolResult`
  - `deviceState`
  - `systemKilled`
  - `heartbeat`
  - `unknown`
- **WsEvent**
  - `WsEvent`
  - `receivedAt`
  - `type`
  - `toJson`
  - `decode`
  - `fromJson`

### `lib/data/api/ws_events_assistant.dart` · 149 lines

- **AssistantTokenEvent** — One token of a streaming assistant reply.
  - `AssistantTokenEvent`
  - `messageId`
  - `conversationId`
  - `token`
  - `index`
  - `type`
  - `toJson`
- **AssistantDoneEvent** — End of a streaming reply.
  - `AssistantDoneEvent`
  - `messageId`
  - `text`
  - `finishReason`
  - `blocked`
  - `type`
  - `toJson`
- **ToolRequestEvent** — The assistant requests a tool run; MEDIUM/HIGH tiers need explicit approval.
  - `ToolRequestEvent`
  - `toolCallId`
  - `toolName`
  - `parameters`
  - `riskTier`
  - `reason`
  - `type`
  - `toJson`
- **ToolResultEvent** — Result of a tool run.
  - `ToolResultEvent`
  - `toolCallId`
  - `success`
  - `summary`
  - `type`
  - `toJson`

### `lib/data/api/ws_events_system.dart` · 120 lines

- **DeviceStateEvent** — A device reported new state.
  - `DeviceStateEvent`
  - `deviceId`
  - `online`
  - `relayStates`
  - `payload`
  - `type`
  - `toJson`
- **SystemKilledEvent** — The global kill-switch changed state.
  - `SystemKilledEvent`
  - `engaged`
  - `reason`
  - `actor`
  - `type`
  - `toJson`
- **HeartbeatEvent** — Keep-alive frame.
  - `HeartbeatEvent`
  - `type`
  - `toJson`
- **UnknownEvent** — An event this client version does not understand. Kept, never acted upon.
  - `UnknownEvent`
  - `rawType`
  - `payload`
  - `type`
  - `toJson`

### `lib/data/db/armx_database.dart` · 165 lines

- **ArmxDatabase**
  - `schemaVersion`
  - `migration`
  - `readSetting`
  - `readAllSettings`
  - `writeSetting`
  - `deleteSetting`
  - `recentMessages`
  - `clearConversation`
  - `cachedAudit`
  - `clearAudit`
  - `pendingOutbox`
  - `enqueueOutbox`
  - `completeOutbox`
  - `failOutbox`
  - `wipeCaches`
  - `clearChat`

### `lib/data/db/tables.dart` · 169 lines

- **SettingsEntries**
  - `key`
  - `value`
  - `updatedAt`
  - `primaryKey`
- **ChatMessagesCache**
  - `id`
  - `conversationId`
  - `role`
  - `body`
  - `at`
  - `status`
  - `riskTier`
  - `toolCallId`
  - `pending`
  - `primaryKey`
- **AuditCache**
  - `id`
  - `at`
  - `actor`
  - `action`
  - `target`
  - `riskTier`
  - `outcome`
  - `detail`
  - `payload`
  - `primaryKey`
- **DeviceCache** — Offline cache of device state.
  - `id`
  - `name`
  - `site`
  - `kind`
  - `online`
  - `riskTier`
  - `lastSeenAt`
  - `payload`
  - `primaryKey`
- **RuleCache** — Offline cache of automation rules.
  - `id`
  - `name`
  - `enabled`
  - `dryRun`
  - `riskTier`
  - `payload`
  - `primaryKey`
- **OutboxEntries** — Queued side effects that must reach the server (chat send, command, unlock request).
  - `id`
  - `kind`
  - `payload`
  - `createdAt`
  - `attempts`
  - `lastError`

### `lib/data/models/admin.dart` · 117 lines

- **ToolId** — Tools the assistant may use. Mirrors the admin panel toggles.
- **ToolToggle**
  - `ToolToggle`
- **AdminState**
  - `AdminState`
  - `isOperational`
  - `enabledTools`
- **KillSwitchState**
  - `KillSwitchState`
- **RevokedCredential**
  - `RevokedCredential`

### `lib/data/models/audit_entry.dart` · 89 lines

- **AuditOutcome** — How an audited action ended.
- **AuditEntry**
  - `AuditEntry`
  - `summary`
- **AuditQuery**
  - `AuditQuery`
  - `toQueryParameters`

### `lib/data/models/auth.dart` · 107 lines

- **UserProfile**
  - `UserProfile`
  - `isAdmin`
- **AuthSession**
  - `AuthSession`
  - `isExpiredAt`
  - `safeDescription`
- **PairingChallenge**
  - `PairingChallenge`
- **PairingResult**
  - `PairingResult`
- **ServerProbe**
  - `ServerProbe`

### `lib/data/models/chat.dart` · 163 lines

- **ChatRole** — Who produced a chat message.
- **ChatMessageStatus** — Delivery state of a message bubble.
- **ChatMessage**
  - `ChatMessage`
  - `isStreaming`
  - `isFailed`
- **ToolCallStatus** — Lifecycle of a tool call requested by the assistant.
- **ToolCall**
  - `ToolCall`
  - `needsDecision`
  - `requiresVerification`
- **ToolDescriptor**
  - `ToolDescriptor`

### `lib/data/models/converters.dart` · 34 lines

_Barrel file: re-exports only._

### `lib/data/models/device.dart` · 169 lines

- **DeviceKind** — What kind of node an [ArmxDevice] is.
- **RelayState** — State of a relay channel.
- **SensorKind** — Physical quantity reported by a sensor.
- **Relay**
  - `Relay`
- **SensorReading**
  - `SensorReading`
- **ArmxDevice**
  - `ArmxDevice`
  - `isLikelyOnline`
  - `primaryRelay`
- **DeviceCommandResult**
  - `DeviceCommandResult`

### `lib/data/models/preferences.dart` · 95 lines

- **PreferenceKeys** — Storage keys for the preferences table. Namespaced so a future export/import is easy.
  - `themeMode`
  - `language`
  - `wakeWordEnabled`
  - `wakeWordPhrase`
  - `wakeWordSensitivity`
  - `faceMatchThreshold`
  - `palmGestureEnabled`
  - `cameraEnabled`
  - `microphoneEnabled`
  - `ttsAutoSpeak`
  - `hapticsEnabled`
  - `appLockEnabled`
  - `activityRecognitionEnabled`
  - `lastServerUrl`
  - `exportable`
- **AppPreferences**
  - `AppPreferences`
  - `hasValidThreshold`

### `lib/data/models/rules.dart` · 212 lines

- **ActivityKind** — Activity classes the OS reports (and that rule triggers can match).
- **RuleTriggerType** — What starts a rule.
- **RuleActionType** — What a rule does when it fires.
- **GeofenceKind** — Kind of place a geofence represents.
- **Geofence**
  - `Geofence`
  - `containsApprox`
- **AutomationRule**
  - `AutomationRule`
  - `whenLabel`
  - `thenLabel`
- **ActivitySnapshot**
  - `ActivitySnapshot`
- **RuleDryRunResult**
  - `RuleDryRunResult`

### `lib/data/models/unlock.dart` · 183 lines

- **UnlockTargetKind** — Machine types A.R.M.X can be asked to unlock.
- **UnlockTarget**
  - `UnlockTarget`
- **UnlockStatus** — Progress of an unlock attempt, rendered as a four-step timeline.
- **UnlockTokenPayload**
  - `UnlockTokenPayload`
  - `secondsRemaining`
- **SignedUnlockToken**
  - `SignedUnlockToken`
  - `toRequestBody`
- **UnlockRequestOutcome**
  - `UnlockRequestOutcome`
- **OwnerVerifiedToken**
  - `OwnerVerifiedToken`
  - `isValidAt`

### `lib/data/models/vision.dart` · 158 lines

- **FaceEnrolmentAngle** — The five angles captured during face enrolment.
- **LivenessChallengeKind** — Liveness challenge presented to the user.
- **FaceTemplateMeta**
  - `FaceTemplateMeta`
  - `isComplete`
  - `missingAngles`
- **VisionMatch**
  - `VisionMatch`
- **LivenessChallenge**
  - `LivenessChallenge`
  - `isValidAt`
- **LivenessResult**
  - `LivenessResult`
- **PalmGesture** — Palm gesture recognised by the pose model.
- **CameraPrivacyState**
  - `CameraPrivacyState`

### `lib/data/repositories/preferences_repository.dart` · 135 lines

- **PreferencesRepository** — Reads and writes the user's app preferences.
  - `load`
  - `watch`
  - `writeAll`
  - `setThemeMode`
  - `setLanguage`
  - `setWakeWordEnabled`
  - `setWakeWordPhrase`
  - `setWakeWordSensitivity`
  - `setFaceMatchThreshold`
  - `setPalmGestureEnabled`
  - `setCameraEnabled`
  - `setMicrophoneEnabled`
  - `setTtsAutoSpeak`
  - `setHapticsEnabled`
  - `setAppLockEnabled`
  - `setActivityRecognitionEnabled`
  - `setLastServerUrl`
  - `resetAll`

### `lib/features/bootstrap/bootstrap.dart` · 96 lines

- **BootstrapReport** — Outcome of the launch sequence, consumed by the splash gate.
  - `BootstrapReport`
  - `config`
  - `preferences`
  - `secureStorageAvailable`
  - `warnings`
  - `duration`
  - `started`
  - `logger`
  - `config`
  - `warnings`
  - `secureStorageAvailable`
  - `repository`
  - `preferences`
  - `report`
  - `report`

### `lib/features/bootstrap/bootstrap_gate.dart` · 57 lines

- **BootstrapGate** — Shows the splash while the launch sequence runs, then enters the shell.
  - `BootstrapGate`
  - `createState`
- **_BootstrapGateState**
  - `build`

### `lib/features/common/placeholder_page.dart` · 57 lines

- **PlaceholderPage** — Honest placeholder for a screen scheduled for a later delivery step.
  - `PlaceholderPage`
  - `title`
  - `step`
  - `icon`
  - `build`

### `lib/features/dev/design_system_page.dart` · 219 lines

- **DesignSystemPage** — Design-system gallery: the fastest way to eyeball every token and signature widget.
  - `DesignSystemPage`
  - `build`
- **_Swatch**
  - `name`
  - `color`
  - `build`

### `lib/features/settings/about_page.dart` · 193 lines

- **AboutPage** — About page: identity, ownership, the mandatory credit line and the licence viewer.
  - `AboutPage`
  - `build`
- **_LabelledRow**
  - `label`
  - `value`
  - `mono`
  - `build`

### `lib/features/settings/diagnostics_page.dart` · 233 lines

- **DiagnosticsPage** — Diagnostics: redacted configuration, bootstrap warnings, mock-backend controls and the
  - `build`
- **_MockControls**
  - `build`
- **_MonoLine**
  - `text`
  - `build`

### `lib/features/settings/settings_page.dart` · 278 lines

- **SettingsPage** — Settings: language, theme, voice, privacy and the security switches.
  - `SettingsPage`
  - `stepBadge`
  - `build`

### `lib/features/shell/app_shell.dart` · 157 lines

- **ShellDestination** — One entry of the primary navigation.
  - `ShellDestination`
  - `path`
  - `icon`
  - `selectedIcon`
- **AppShell** — The persistent navigation shell: bottom bar on phones, rail on desktop.
  - `AppShell`
  - `navigationShell`
  - `destinations`
  - `build`

### `lib/features/splash/splash_page.dart` · 120 lines

- **SplashPage** — Launch screen: wordmark, assistant orb and initialization status.
  - `SplashPage`
  - `statusMessage`
  - `failed`
  - `createState`
- **_SplashPageState**
  - `dispose`
  - `build`

### `lib/main.dart` · 140 lines

  - `config`
  - `logger`
  - `previousHandler`
- **FatalConfigApp** — Last-resort screen shown when the build configuration itself is unusable.
  - `FatalConfigApp`
  - `exception`
  - `build`

### `test/`

- `test/support/fixtures.dart` · 83 lines
- `test/support/test_harness.dart` · 116 lines
- `test/unit/core/security/risk_policy_test.dart` · 193 lines
  - group `tier requirements`
  - group `expiry`
  - group `tier escalation`
  - group `tier ordering`
- `test/unit/core/utils/validators_and_hex_test.dart` · 96 lines
  - group `Validators.serverUrl`
  - group `Validators.deviceKey`
  - group `Validators thresholds and wake word`
  - group `Hex`
- `test/unit/data/mock_api_chat_test.dart` · 199 lines
  - group `unlock tokens`
  - group `rules`
  - group `chat streaming`
  - group `audit queries`
- `test/unit/data/mock_api_test.dart` · 225 lines
  - group `determinism`
  - group `auth and pairing`
  - group `devices`
  - group `kill-switch`
- `test/unit/data/ws_events_test.dart` · 144 lines

Non-Dart deliverables: `analysis_options.yaml` (flutter_lints + strict casts/inference/raw
types + 50 explicit rules), `build.yaml` (snake_case wire names, drift text datetimes),
`l10n.yaml`, `.gitignore`, `README.md`, `docs/run.md`, `docs/api.md`,
`docs/decisions/0002-dependency-pins.md`, `assets/**` (fonts + two README placeholders).

## 4. Deliberate deviations, flagged

1. **ARB files carry no header comment.** ARB is strict JSON with no comment syntax; adding an
   unknown `@@`-attribute risks `flutter gen-l10n` failing. The proprietary header for the
   localization layer lives in `l10n.yaml` and `lib/core/l10n/l10n.dart`.
2. **`assets/fonts/*.ttf` are binaries**, shipped with their SIL OFL license texts.
3. **`flutter_markdown` is not used** — assistant/tool text is untrusted and renders through
   the local `SanitizedMarkdown` (links stay inert).
4. **No face-embedding model is bundled**; Vision reports `ModelStatus.missing` until
   `assets/models/face_embedding.tflite` is added.
5. **Generated code is not committed**, so the first analyzer run needs `flutter pub get` and
   `dart run build_runner build --delete-conflicting-outputs`.
6. **`integration_test/` and `tool/` are empty placeholders** — the integration flow arrives
   with step 10; `tool/` is reserved for the release/coverage scripts.

## 5. To confirm on the first analyzer run

1. `flutter pub get` then `dart run build_runner build --delete-conflicting-outputs` —
   `*.freezed.dart`, `*.g.dart` (riverpod/drift) and `lib/l10n/generated/` do not exist yet,
   so missing-part and missing-import errors are expected until then.
2. `Validator.serverUrl` port edge cases: Dart may reject `https://host:70000` and
   `https://:8443` while parsing, which would surface as `notAbsoluteUrl` rather than
   `badPort`/`missingHost` in `test/unit/core/utils/validators_and_hex_test.dart`.
3. Widget→theme references (`ArmxColors`, `ArmxEffects`, `ArmxMotion`, `ArmxTypography`)
   and the ARB key set (`lib/l10n/app_en.arb` / `app_bn.arb`, 140 keys each).
4. `armx_button.dart` uses `ArmxPalette.darkBackground` / `Colors.white` for on-accent
   contrast — the future "no literal colours" widget test must allow those two.
5. Run `flutter analyze` and `flutter test --coverage`; the ≥70 % gate covers `core/` and
   `data/` only. Golden/widget tests and the integration flow arrive with step 10.

