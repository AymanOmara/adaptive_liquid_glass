package com.aymanomara.adaptive_liquid_glass

import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CodecSupervisorTest {
    @get:Rule val tmp = TemporaryFolder()

    /** A codec call that ignores interrupts until [release] counts down. */
    private fun stuck(release: CountDownLatch, entered: CountDownLatch? = null): () -> Unit = {
        entered?.countDown()
        while (true) {
            try {
                if (release.await(10, TimeUnit.SECONDS)) break
            } catch (e: InterruptedException) {
                // A hung hardware codec does not honour interrupts.
            }
        }
    }

    @Test
    fun returnsTheResultOfWorkThatFinishes() {
        val result = CodecSupervisor().run(ImportCancel(), TranscodeProgress()) { 42 }
        assertEquals(42, result)
    }

    @Test
    fun abandonsAStalledCallWithinTheWindow() {
        var time = 0L
        val activity = TranscodeProgress(timeoutNanos = 10, now = { time })
        val release = CountDownLatch(1)
        val entered = CountDownLatch(1)
        var abandoned = false
        val started = System.nanoTime()
        try {
            CodecSupervisor(graceMillis = 50).run(ImportCancel(), activity, { abandoned = true }) {
                time = 100 // no advanced() from here on: a stall
                stuck(release, entered)()
            }
            fail("expected CodecAbandonedException")
        } catch (e: CodecAbandonedException) {
            assertTrue(abandoned)
        } finally {
            release.countDown()
        }
        assertTrue(System.nanoTime() - started < TimeUnit.SECONDS.toNanos(2))
    }

    @Test
    fun cancelAbandonsAtOnce() {
        val cancel = ImportCancel()
        val release = CountDownLatch(1)
        val entered = CountDownLatch(1)
        Thread { entered.await(); cancel.cancelled = true }.start()
        try {
            CodecSupervisor(graceMillis = 50).run(cancel, TranscodeProgress()) { stuck(release, entered)() }
            fail("expected CancellationException")
        } catch (e: CancellationException) {
            // Delivered as the original by the caller.
        } finally {
            release.countDown()
        }
    }

    @Test
    fun lateReturnOfAbandonedWorkDeletesItsOutput() {
        var time = 0L
        val activity = TranscodeProgress(timeoutNanos = 10, now = { time })
        val src = tmp.newFile("in.mov").apply { writeText("hevc") }
        val out = File(tmp.root, "in.out.mp4")
        val release = CountDownLatch(1)
        val done = CountDownLatch(1)
        try {
            CodecSupervisor(graceMillis = 20).run(ImportCancel(), activity) {
                H264Transcoder.transcode(src, out, activity) { _, dest, _ ->
                    time = 100 // stall
                    stuck(release)()
                    dest.writeText("late")
                    throw IllegalStateException("released after abandon")
                }.also { done.countDown() }
            }
            fail("expected CodecAbandonedException")
        } catch (e: CodecAbandonedException) {
            release.countDown()
            assertTrue(done.await(2, TimeUnit.SECONDS))
            assertFalse(out.exists())
            assertEquals("hevc", src.readText())
        }
    }
}
