package com.aymanomara.adaptive_liquid_glass

import java.io.File
import java.io.IOException
import java.util.Collections
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/** Each import owns a directory so a failed batch cannot strand earlier items. */
internal object GlassPhotoCache {
    data class Imported<T>(val items: List<T>, val cancelled: Boolean)

    /**
     * Imports each item into its own session, up to [concurrency] at once,
     * started in selection order. [onItemReady] fires as each item finishes
     * (completion order); [Imported.items] is in selection order. After a
     * failure or cancel no new item starts and running ones finish. Without
     * [onItemReady] a failure rolls back every finished item (one result or
     * none); a cancel keeps them, because the user chose to stop.
     */
    fun <I, T> importItems(
        root: File,
        items: List<I>,
        load: (Int, I, File) -> T,
        onItemReady: ((T) -> Unit)? = null,
        cancelled: () -> Boolean = { false },
        concurrency: Int = 1,
    ): Imported<T> {
        require(concurrency > 0)
        val results = arrayOfNulls<Result<T>>(items.size)
        val sessions = Collections.synchronizedList(mutableListOf<File>())
        val next = AtomicInteger()
        val failure = AtomicReference<Throwable?>()
        val lock = Any()
        val worker = Runnable {
            while (failure.get() == null && !cancelled()) {
                val index = next.getAndIncrement()
                if (index >= items.size) return@Runnable
                val item = try {
                    importing(root) { session ->
                        sessions += session
                        load(index, items[index], session)
                    }
                } catch (error: Throwable) {
                    failure.compareAndSet(null, error)
                    return@Runnable
                }
                synchronized(lock) {
                    results[index] = Result.success(item)
                    onItemReady?.invoke(item)
                }
            }
        }
        val helpers = (1 until minOf(concurrency, items.size)).map {
            Thread(worker, "adaptive_liquid_glass-import").apply {
                isDaemon = true
                start()
            }
        }
        worker.run()
        helpers.forEach { it.join() }
        val done = synchronized(lock) { results.mapNotNull { it?.getOrThrow() } }
        val error = failure.get() ?: return Imported(done, done.size < items.size)
        if (cancelled() && error is Exception) return Imported(done, true)
        if (onItemReady == null) {
            for (session in sessions.toList()) {
                try {
                    clear(session)
                } catch (cleanup: Exception) {
                    error.addSuppressed(cleanup)
                }
            }
        }
        throw error
    }

    fun clear(directory: File) {
        if (!directory.deleteRecursively() && directory.exists()) {
            throw IOException("Unable to delete picked photo copies.")
        }
    }

    fun <T> importing(root: File, load: (File) -> T): T {
        val session = File(root, UUID.randomUUID().toString())
        if (!session.mkdirs()) throw IOException("Unable to create photo import directory.")
        try {
            return load(session)
        } catch (error: Exception) {
            try {
                clear(session)
            } catch (cleanup: Exception) {
                error.addSuppressed(cleanup)
            }
            throw error
        }
    }
}
