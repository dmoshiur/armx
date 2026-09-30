// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

package top.thamjj13.armx

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flutter host for the listening-service MethodChannel and EventChannel. */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result -> handleMethodCall(call, result) }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                ArmxListenEventBus.attach(events)
                events.success(
                    mapOf(
                        "type" to "status",
                        "status" to ArmxListenService.snapshot(this@MainActivity),
                    ),
                )
            }

            override fun onCancel(arguments: Any?) {
                ArmxListenEventBus.detach()
            }
        })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(ArmxListenService.snapshot(this))
            "start" -> startListening(call, result)
            "pause" -> sendServiceCommand(ArmxListenService.ACTION_PAUSE, result)
            "resume" -> sendServiceCommand(ArmxListenService.ACTION_RESUME, result)
            "stop" -> sendServiceCommand(ArmxListenService.ACTION_STOP, result)
            "killSwitch" -> sendServiceCommand(ArmxListenService.ACTION_KILL_SWITCH, result)
            else -> result.notImplemented()
        }
    }

    private fun startListening(call: MethodCall, result: MethodChannel.Result) {
        call.argument<String>("languageCode")
            ?.takeIf { it == "en" || it == "bn" }
            ?.let { ArmxListenService.setLanguage(this, it) }

        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error(
                "microphone_permission_required",
                "Microphone permission is required before starting the service.",
                null,
            )
            return
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "notification_permission_required",
                "Notification permission is required for the ongoing service notification.",
                null,
            )
            return
        }

        val intent = Intent(this, ArmxListenService::class.java).setAction(ArmxListenService.ACTION_START)
        ArmxListenService.setPhase(this, ArmxListenService.PHASE_STARTING)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success(ArmxListenService.snapshot(this))
        } catch (error: SecurityException) {
            ArmxListenService.reportError(this, "foreground_start_denied")
            result.error(
                "foreground_start_denied",
                "Android denied the microphone foreground-service start.",
                null,
            )
        } catch (error: IllegalStateException) {
            ArmxListenService.reportError(this, "background_start_blocked")
            result.error(
                "background_start_blocked",
                "Android blocked a background microphone-service start.",
                null,
            )
        }
    }

    private fun sendServiceCommand(action: String, result: MethodChannel.Result) {
        val active = ArmxListenService.isExpectedActive(this)
        if (!active && action != ArmxListenService.ACTION_STOP && action != ArmxListenService.ACTION_KILL_SWITCH) {
            result.success(ArmxListenService.snapshot(this))
            return
        }

        if (!active) {
            val phase = if (action == ArmxListenService.ACTION_KILL_SWITCH) {
                ArmxListenService.PHASE_KILLED
            } else {
                ArmxListenService.PHASE_STOPPED
            }
            ArmxListenService.setPhase(this, phase)
            stopService(Intent(this, ArmxListenService::class.java))
            result.success(ArmxListenService.snapshot(this))
            return
        }

        try {
            startService(Intent(this, ArmxListenService::class.java).setAction(action))
            // The service publishes the resulting status event after applying the command.
            result.success(ArmxListenService.snapshot(this))
        } catch (error: IllegalStateException) {
            val code = "background_start_blocked"
            ArmxListenService.reportError(this, code)
            result.error(code, "Android blocked the service command.", null)
        } catch (error: SecurityException) {
            val code = "foreground_start_denied"
            ArmxListenService.reportError(this, code)
            result.error(code, "Android denied the service command.", null)
        }
    }

    private companion object {
        const val METHOD_CHANNEL = "top.thamjj13.armx/assistant_listening"
        const val EVENT_CHANNEL = "top.thamjj13.armx/assistant_listening_events"
    }
}
