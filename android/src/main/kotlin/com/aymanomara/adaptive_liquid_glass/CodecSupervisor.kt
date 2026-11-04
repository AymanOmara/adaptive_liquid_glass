package com.aymanomara.adaptive_liquid_glass

import android.util.Log
import java.util.concurrent.CancellationException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** A blocking codec or I/O call was given up on; its thread may still be running. */
internal class CodecAbandonedException : Exception("Codec call abandoned after it stopped responding.")

/**
 * Runs blocking codec and I/O calls on daemon threads so a call that never
 * returns cannot hang the import. On a stall or cancel the thread is
 * interrupted, given [graceMillis], then abandoned: it releases its own
 * codec if it ever returns.
 */
internal class CodecSupervisor(
    private val graceMillis: Long = 500,
    private val pollMillis: Long = 50,
) {
    private val pool = Executors.newCachedThreadPool { work ->
        Thread(work, "adaptive_liquid_glass-codec").apply { isDaemon = true }
    }

    fun <T> run(
        cancel: ImportCancel,
        activity: TranscodeProgress,
        onAbandon: () -> Unit = {},
        work: () -> T,
    ): T {
        val finished = CountDownLatch(1)
        val future = pool.submit<T> {
            try {
                work()
            } finally {
                finished.countDown()
            }
        }
        while (true) {
            try {
                return future.get(pollMillis, TimeUnit.MILLISECONDS)
            } catch (e: ExecutionException) {
                throw (e.cause as? Exception) ?: e
            } catch (e: TimeoutException) {
                val stopped = cancel.cancelled
                if (!stopped && !activity.stalled()) continue
                if (!future.cancel(true)) {
                    // Finished between the timeout and now: keep its outcome.
                    try {
                        return future.get()
                    } catch (x: ExecutionException) {
                        throw (x.cause as? Exception) ?: x
                    }
                }
                activity.abandoned = true
                // An interruptible call unwinds within the grace period and
                // releases its own codec; anything still running is abandoned.
                if (!finished.await(graceMillis, TimeUnit.MILLISECONDS)) {
                    runCatching { onAbandon() }
                    runCatching {
                        if (Log.isLoggable(TAG, Log.WARN)) Log.w(TAG, "Abandoned a codec call (cancel=$stopped).")
                    }
                }
                if (stopped) throw CancellationException("Photo import cancelled.")
                throw CodecAbandonedException()
            }
        }
    }

    companion object {
        private const val TAG = "AdaptiveLiquidGlass"
        val shared = CodecSupervisor()
    }
}
