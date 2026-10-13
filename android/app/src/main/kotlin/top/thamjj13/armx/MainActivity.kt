// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

package top.thamjj13.armx

import io.flutter.embedding.android.FlutterActivity

/**
 * The single Android activity.
 *
 * Deliberately empty: every platform capability this app uses — camera, microphone, overlay,
 * notifications, secure storage, biometrics — is reached through a Flutter plugin, so there is
 * no bespoke channel to keep in sync here. Adding logic to this class would mean a second place
 * where behaviour can differ per platform, which is exactly what the layout rules avoid too.
 *
 * Deep links (`armx://reset-password?token=…`, `armx://verify-email?token=…`) arrive as intents
 * and are handed to the Flutter engine by the embedding; `go_router` routes them, and the reset
 * screen validates the token before showing a form.
 */
class MainActivity : FlutterActivity()
