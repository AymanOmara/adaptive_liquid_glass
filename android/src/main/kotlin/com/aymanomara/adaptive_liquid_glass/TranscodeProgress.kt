package com.aymanomara.adaptive_liquid_glass

import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** Measures inactivity rather than total duration, so long videos can finish. */
internal class TranscodeProgress(
    private val timeoutNanos: Long = TimeUnit.SECONDS.toNanos(30),
    private val now: () -> Long = System::nanoTime,
) {
    init {
        require(timeoutNanos > 0)
    }

    private var lastProgress = now()

    fun advanced() {
        lastProgress = now()
    }

    fun checkActive() {
        if (now() - lastProgress >= timeoutNanos) {
            throw TimeoutException("Video codec stopped making progress.")
        }
    }
}
