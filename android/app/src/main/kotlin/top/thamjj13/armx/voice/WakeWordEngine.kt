// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

package top.thamjj13.armx.voice

import top.thamjj13.armx.ArmxListenService

/**
 * Lifecycle contract for an on-device wake-word detector owned by [ArmxListenService].
 *
 * A production adapter must only invoke [Listener.onWakeWordDetected] after its local
 * detector recognizes the phrase. It must never persist raw PCM or send pre-wake audio to
 * Dart, a server, telemetry, or logs. [pause] and [close] must release microphone resources.
 */
internal interface WakeWordEngine : AutoCloseable {
    /** Stable adapter identifier, for diagnostics only. */
    val engineId: String

    /** Whether a real on-device detector is installed and ready. */
    val isAvailable: Boolean

    /** Starts local detection, or does nothing for an unavailable stub. */
    fun start(listener: Listener)

    /** Suspends detection and releases any active microphone capture. */
    fun pause()

    /** Resumes detection after a pause. */
    fun resume()

    /** Listener for events which contain no audio or transcript payload. */
    interface Listener {
        /** Called after local wake-word detection succeeds. */
        fun onWakeWordDetected()

        /** Called with a stable, non-sensitive adapter error code. */
        fun onError(code: String)
    }

    /** Releases all audio buffers and native resources. */
    override fun close()
}

/** Safe default: no audio input, no worker thread, and no wake-word event. */
internal class StubWakeWordEngine : WakeWordEngine {
    override val engineId: String = "stub"
    override val isAvailable: Boolean = false

    @Suppress("UNUSED_PARAMETER")
    override fun start(listener: WakeWordEngine.Listener) = Unit

    override fun pause() = Unit

    override fun resume() = Unit

    override fun close() = Unit
}

/** Factory kept as the single explicit point where a reviewed adapter may be selected. */
internal object WakeWordEngineFactory {
    fun create(): WakeWordEngine = StubWakeWordEngine()
}
