// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

package top.thamjj13.armx

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.plugin.common.EventChannel
import java.util.Locale
import top.thamjj13.armx.voice.WakeWordEngine
import top.thamjj13.armx.voice.WakeWordEngineFactory

/**
 * Android foreground-service shell for A.R.M.X background listening.
 *
 * The default wake-word engine is a no-audio stub. The lifecycle is ready for a reviewed
 * on-device adapter, but no audio is opened or captured in this delivery.
 */
class ArmxListenService : Service() {
    private val mainThread = Handler(Looper.getMainLooper())
    private var wakeWordEngine: WakeWordEngine? = null
    private var wakeWordEngineStarted = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        setEngineStatus(this, "stub", false)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> activate(PHASE_RUNNING, startId)
            ACTION_RESUME -> activate(PHASE_RUNNING, startId)
            ACTION_PAUSE -> pause(startId)
            ACTION_STOP -> stopListening(killed = false, startId = startId)
            ACTION_KILL_SWITCH -> stopListening(killed = true, startId = startId)
            else -> restoreAfterProcessRestart(startId)
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        releaseWakeWordEngine()
        super.onDestroy()
    }

    private fun restoreAfterProcessRestart(startId: Int) {
        when (phase(this)) {
            PHASE_STARTING, PHASE_RUNNING -> activate(PHASE_RUNNING, startId)
            PHASE_PAUSED -> activate(PHASE_PAUSED, startId)
            else -> stopSelf(startId)
        }
    }

    private fun activate(nextPhase: String, startId: Int) {
        if (!hasRequiredPermissions()) {
            val code = if (isMicrophonePermissionGranted()) {
                "notification_permission_required"
            } else {
                "microphone_permission_required"
            }
            reportError(this, code)
            stopSelf(startId)
            return
        }

        try {
            val notification = buildNotification(nextPhase)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            setPhase(this, nextPhase)
            if (nextPhase == PHASE_RUNNING) {
                startWakeWordEngine()
            } else {
                wakeWordEngine?.pause()
            }
        } catch (error: SecurityException) {
            releaseWakeWordEngine()
            reportError(this, "foreground_start_denied")
            stopSelf(startId)
        } catch (error: IllegalStateException) {
            releaseWakeWordEngine()
            reportError(this, "background_start_blocked")
            stopSelf(startId)
        }
    }

    private fun startWakeWordEngine() {
        val engine = wakeWordEngine ?: WakeWordEngineFactory.create().also {
            wakeWordEngine = it
        }
        setEngineStatus(this, engine.engineId, engine.isAvailable)

        try {
            if (wakeWordEngineStarted) {
                engine.resume()
            } else {
                wakeWordEngineStarted = true
                engine.start(object : WakeWordEngine.Listener {
                    override fun onWakeWordDetected() {
                        mainThread.post {
                            if (phase(this@ArmxListenService) != PHASE_RUNNING ||
                                wakeWordEngine?.isAvailable != true
                            ) {
                                return@post
                            }
                            vibrateLightly()
                            // No transcript or audio data crosses the EventChannel.
                            ArmxListenEventBus.publish(mapOf("type" to "wakeWordDetected"))
                        }
                    }

                    override fun onError(code: String) {
                        val safeCode = when (code) {
                            "microphone_permission_denied" -> "microphone_permission_required"
                            "model_unavailable" -> "wake_word_model_unavailable"
                            else -> "wake_word_engine_error"
                        }
                        mainThread.post {
                            if (isExpectedActive(this@ArmxListenService)) {
                                failWakeWordEngine(safeCode)
                            }
                        }
                    }
                })
            }
        } catch (error: Exception) {
            failWakeWordEngine("wake_word_engine_start_failed")
        }
    }

    private fun failWakeWordEngine(errorCode: String) {
        releaseWakeWordEngine()
        reportError(this, errorCode)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun vibrateLightly() {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(55L, 72))
        } else {
            vibrator.vibrate(55L)
        }
    }

    private fun pause(startId: Int) {
        if (phase(this) != PHASE_RUNNING) {
            stopSelf(startId)
            return
        }
        try {
            wakeWordEngine?.pause()
        } catch (error: Exception) {
            failWakeWordEngine("wake_word_engine_pause_failed")
            return
        }
        setPhase(this, PHASE_PAUSED)
        notificationManager().notify(NOTIFICATION_ID, buildNotification(PHASE_PAUSED))
    }

    private fun stopListening(killed: Boolean, startId: Int) {
        val nextPhase = if (killed) PHASE_KILLED else PHASE_STOPPED
        releaseWakeWordEngine()
        setPhase(this, nextPhase)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf(startId)
    }

    private fun releaseWakeWordEngine() {
        val engine = wakeWordEngine
        wakeWordEngine = null
        wakeWordEngineStarted = false
        try {
            engine?.close()
        } catch (error: Exception) {
            // Resource cleanup is best-effort; exception text is never logged or persisted.
        }
        setEngineStatus(this, engine?.engineId ?: "stub", false)
    }

    private fun hasRequiredPermissions(): Boolean =
        isMicrophonePermissionGranted() && isNotificationPermissionGranted()

    private fun isMicrophonePermissionGranted(): Boolean =
        checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun isNotificationPermissionGranted(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            localizedString(R.string.listen_notification_channel),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = localizedString(R.string.listen_notification_channel_description)
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun buildNotification(currentPhase: String): Notification {
        val talkIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val talkPendingIntent = PendingIntent.getActivity(
            this,
            REQUEST_TALK,
            talkIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val isPaused = currentPhase == PHASE_PAUSED
        val actionIntent = Intent(this, ArmxListenService::class.java).setAction(
            if (isPaused) ACTION_RESUME else ACTION_PAUSE,
        )
        val actionPendingIntent = PendingIntent.getService(
            this,
            REQUEST_PAUSE_RESUME,
            actionIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val killPendingIntent = PendingIntent.getService(
            this,
            REQUEST_KILL_SWITCH,
            Intent(this, ArmxListenService::class.java).setAction(ACTION_KILL_SWITCH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val content = if (isPaused) {
            localizedString(R.string.listen_notification_paused)
        } else {
            localizedString(R.string.listen_notification_engine_pending)
        }
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(localizedString(R.string.listen_notification_title))
            .setContentText(content)
            .setContentIntent(talkPendingIntent)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .addAction(
                0,
                localizedString(R.string.listen_action_talk),
                talkPendingIntent,
            )
            .addAction(
                0,
                localizedString(if (isPaused) R.string.listen_action_resume else R.string.listen_action_pause),
                actionPendingIntent,
            )
            .addAction(
                0,
                localizedString(R.string.listen_action_kill_switch),
                killPendingIntent,
            )
            .build()
    }

    private fun localizedString(resourceId: Int): String {
        val languageCode = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_LANGUAGE_CODE, null)
            ?.takeIf { it == "en" || it == "bn" }
            ?: return getString(resourceId)
        val configuration = Configuration(resources.configuration).apply {
            setLocale(Locale.forLanguageTag(languageCode))
        }
        return createConfigurationContext(configuration).getString(resourceId)
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        const val ACTION_START = "top.thamjj13.armx.action.START_LISTENING"
        const val ACTION_PAUSE = "top.thamjj13.armx.action.PAUSE_LISTENING"
        const val ACTION_RESUME = "top.thamjj13.armx.action.RESUME_LISTENING"
        const val ACTION_STOP = "top.thamjj13.armx.action.STOP_LISTENING"
        const val ACTION_KILL_SWITCH = "top.thamjj13.armx.action.KILL_SWITCH"

        const val PHASE_STOPPED = "stopped"
        const val PHASE_STARTING = "starting"
        const val PHASE_RUNNING = "running"
        const val PHASE_PAUSED = "paused"
        const val PHASE_KILLED = "killed"
        const val PHASE_ERROR = "error"

        private const val CHANNEL_ID = "armx_assistant_listening"
        private const val NOTIFICATION_ID = 4101
        private const val PREFS_NAME = "armx_assistant_listening"
        private const val KEY_PHASE = "phase"
        private const val KEY_ERROR_CODE = "error_code"
        private const val KEY_LANGUAGE_CODE = "language_code"
        private const val KEY_ENGINE_ID = "wake_word_engine_id"
        private const val KEY_ENGINE_READY = "wake_word_engine_ready"
        private const val REQUEST_TALK = 4102
        private const val REQUEST_PAUSE_RESUME = 4103
        private const val REQUEST_KILL_SWITCH = 4104

        /** Persists the app locale used for future native notification text. */
        fun setLanguage(context: Context, languageCode: String) {
            if (languageCode != "en" && languageCode != "bn") return
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_LANGUAGE_CODE, languageCode)
                .apply()
        }

        /** Returns the persisted status map shared with the Dart MethodChannel. */
        fun snapshot(context: Context): Map<String, Any?> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val currentPhase = prefs.getString(KEY_PHASE, PHASE_STOPPED) ?: PHASE_STOPPED
            return mapOf(
                "phase" to currentPhase,
                "serviceRunning" to (currentPhase == PHASE_RUNNING || currentPhase == PHASE_PAUSED),
                "wakeWordEngineReady" to prefs.getBoolean(KEY_ENGINE_READY, false),
                "wakeWordEngineId" to prefs.getString(KEY_ENGINE_ID, "stub"),
                "microphonePermissionGranted" to isMicrophonePermissionGranted(context),
                "notificationPermissionGranted" to isNotificationPermissionGranted(context),
                "errorCode" to prefs.getString(KEY_ERROR_CODE, null),
            )
        }

        /** Whether the persisted service lifecycle is active or being started. */
        fun isExpectedActive(context: Context): Boolean = when (phase(context)) {
            PHASE_STARTING, PHASE_RUNNING, PHASE_PAUSED -> true
            else -> false
        }

        /** Persists a state transition and emits a privacy-safe status event. */
        fun setPhase(context: Context, nextPhase: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_PHASE, nextPhase)
                .remove(KEY_ERROR_CODE)
                .apply()
            publishStatus(context)
        }

        /** Stores a stable error code without persisting platform exception text. */
        fun reportError(context: Context, errorCode: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_PHASE, PHASE_ERROR)
                .putString(KEY_ERROR_CODE, errorCode)
                .apply()
            ArmxListenEventBus.publish(mapOf("type" to "error", "code" to errorCode))
            publishStatus(context)
        }

        /** Persists whether the selected local engine is available, without storing user data. */
        fun setEngineStatus(context: Context, engineId: String, ready: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString(KEY_ENGINE_ID, engineId)
                .putBoolean(KEY_ENGINE_READY, ready)
                .apply()
            publishStatus(context)
        }

        fun phase(context: Context): String =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_PHASE, PHASE_STOPPED) ?: PHASE_STOPPED

        private fun publishStatus(context: Context) {
            ArmxListenEventBus.publish(
                mapOf(
                    "type" to "status",
                    "status" to snapshot(context),
                ),
            )
        }

        private fun isMicrophonePermissionGranted(context: Context): Boolean =
            context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

        private fun isNotificationPermissionGranted(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }
}

/** Main-thread EventChannel publisher shared by the Activity and service. */
internal object ArmxListenEventBus {
    private val mainThread = Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    fun attach(sink: EventChannel.EventSink) {
        eventSink = sink
    }

    fun detach() {
        eventSink = null
    }

    fun publish(event: Map<String, Any?>) {
        mainThread.post {
            eventSink?.success(event)
        }
    }
}
