package com.aymanomara.adaptive_liquid_glass

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.CancellationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class PhotoImportJobTest {
    @Test
    fun throttleDropsBurstsButKeepsFinalEvent() {
        var time = 0L
        val events = mutableListOf<Map<String, Any?>>()
        val throttle = ProgressThrottle(2, intervalNanos = 100, now = { time }) { events += it }
        throttle.update(0, 0.1) // emits (first)
        time = 50
        throttle.update(0, 0.2) // dropped
        throttle.finish(0) // always emits
        assertEquals(listOf(0.1, 1.0), events.map { it["itemFraction"] })
        assertEquals(1, events.last()["completed"])
        assertEquals(2, events.last()["total"])
        assertEquals(0, events.last()["index"])
    }

    @Test
    fun throttleEmitsAgainAfterInterval() {
        var time = 0L
        val events = mutableListOf<Map<String, Any?>>()
        val throttle = ProgressThrottle(1, intervalNanos = 100, now = { time }) { events += it }
        throttle.update(0, 0.1)
        time = 100
        throttle.update(0, null)
        assertEquals(2, events.size)
        assertTrue("itemFraction" !in events.last() || events.last()["itemFraction"] == null)
    }

    @Test
    fun chunkedCopyReportsFractionAndCopiesAll() {
        val data = ByteArray(ChunkedCopy.CHUNK * 2 + 10) { it.toByte() }
        val out = ByteArrayOutputStream()
        val fractions = mutableListOf<Double?>()
        ChunkedCopy.copy(ByteArrayInputStream(data), out, data.size.toLong(), ImportCancel(), { fractions += it })
        assertTrue(data.contentEquals(out.toByteArray()))
        assertEquals(1.0, fractions.last()!!, 1e-9)
        assertEquals(3, fractions.size)
    }

    @Test
    fun chunkedCopyUnknownSizeReportsNull() {
        val fractions = mutableListOf<Double?>()
        ChunkedCopy.copy(ByteArrayInputStream(ByteArray(10)), ByteArrayOutputStream(), null, ImportCancel(), { fractions += it })
        assertEquals(listOf<Double?>(null), fractions)
    }

    @Test
    fun chunkedCopyHonoursCancelBetweenChunks() {
        val cancel = ImportCancel()
        val data = ByteArray(ChunkedCopy.CHUNK * 4)
        val out = ByteArrayOutputStream()
        try {
            ChunkedCopy.copy(ByteArrayInputStream(data), out, data.size.toLong(), cancel, { cancel.cancelled = true })
            fail("expected CancellationException")
        } catch (e: CancellationException) {
            assertEquals(ChunkedCopy.CHUNK, out.size())
        }
    }

    @Test
    fun quarantineSkipsLaterConversions() {
        var time = 0L
        val job = PhotoImportJob("c", 2, {}, CodecSupervisor(graceMillis = 20))
        val release = java.util.concurrent.CountDownLatch(1)
        val first = job.convert(TranscodeProgress(timeoutNanos = 10, now = { time })) {
            time = 100
            while (!release.await(10, java.util.concurrent.TimeUnit.SECONDS)) Unit
            true
        }
        release.countDown()
        assertEquals(null, first)
        assertTrue(job.quarantined)
        var ran = false
        assertEquals(null, job.convert(TranscodeProgress()) { ran = true; true })
        assertTrue(!ran)
    }

    @Test
    fun convertPassesThroughWhenHealthy() {
        val job = PhotoImportJob(null, 1, {})
        assertEquals(true, job.convert(TranscodeProgress()) { true })
        assertTrue(!job.quarantined)
    }
}
