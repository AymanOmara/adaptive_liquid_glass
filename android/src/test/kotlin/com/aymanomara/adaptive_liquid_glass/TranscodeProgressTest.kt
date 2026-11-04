package com.aymanomara.adaptive_liquid_glass

import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import org.junit.Assert.*
import org.junit.Test

class TranscodeProgressTest {
    @Test fun stalledCodecTimesOutAtThirtySeconds() {
        var time = 0L
        val progress = TranscodeProgress(now = { time })
        time = TimeUnit.SECONDS.toNanos(30) - 1
        progress.checkActive()
        time++
        try {
            progress.checkActive()
            fail("A stalled codec must time out")
        } catch (_: TimeoutException) {
            // The transcoder handles this as a failed conversion.
        }
    }

    @Test fun slowConversionWithProgressCanRunForHours() {
        var time = 0L
        val progress = TranscodeProgress(now = { time })
        repeat(1000) {
            time += TimeUnit.SECONDS.toNanos(29)
            progress.checkActive()
            progress.advanced()
        }
        time += TimeUnit.SECONDS.toNanos(30)
        try {
            progress.checkActive()
            fail("Inactivity after progress must still time out")
        } catch (_: TimeoutException) {
        }
    }

    @Test fun monotonicClockWrapDoesNotDisableStallDetection() {
        var time = Long.MAX_VALUE - 5
        val progress = TranscodeProgress(timeoutNanos = 10, now = { time })
        time += 9
        progress.checkActive()
        time++
        try {
            progress.checkActive()
            fail("Elapsed time must survive nanoTime wrap")
        } catch (_: TimeoutException) {
        }
    }

    @Test fun timeoutMustBePositive() {
        for (timeout in listOf(0L, -1L)) {
            try {
                TranscodeProgress(timeoutNanos = timeout)
                fail("Timeout must be positive")
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    @Test fun cancelledProgressThrowsCancellation() {
        val cancel = ImportCancel().apply { cancelled = true }
        try {
            TranscodeProgress(cancel = cancel).checkActive()
            fail()
        } catch (e: java.util.concurrent.CancellationException) {
        }
    }

    @Test fun advancedReportsPresentationTime() {
        val seen = mutableListOf<Long>()
        val p = TranscodeProgress(onAdvance = { seen += it })
        p.advanced()
        p.advanced(5_000)
        assertEquals(listOf(5_000L), seen)
    }
}
