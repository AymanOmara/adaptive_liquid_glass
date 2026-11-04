package com.aymanomara.adaptive_liquid_glass

import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * Measures inactivity rather than total duration, so long videos can
 * finish. Shared between the codec thread (which advances it) and the
 * supervisor (which reads [stalled]).
 */
internal class TranscodeProgress(
    private val timeoutNanos: Long = TimeUnit.SECONDS.toNanos(30),
    private val now: () -> Long = System::nanoTime,
    private val cancel: ImportCancel? = null,
    private val onAdvance: ((Long) -> Unit)? = null,
) {
    init {
        require(timeoutNanos > 0)
    }

    @Volatile
    private var lastProgress = now()

    /** [presentationTimeUs] of the frame just handled, or -1. */
    fun advanced(presentationTimeUs: Long = -1) {
        lastProgress = now()
        if (presentationTimeUs >= 0) onAdvance?.invoke(presentationTimeUs)
    }

    fun stalled(): Boolean = now() - lastProgress >= timeoutNanos

    fun checkActive() {
        cancel?.check()
        if (stalled()) throw TimeoutException("Video codec stopped making progress.")
    }
}
