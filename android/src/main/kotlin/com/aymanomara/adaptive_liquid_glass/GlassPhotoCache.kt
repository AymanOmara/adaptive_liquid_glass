package com.aymanomara.adaptive_liquid_glass

import java.io.File
import java.io.IOException
import java.util.UUID

/** Each import owns a directory so a failed batch cannot strand earlier items. */
internal object GlassPhotoCache {
    data class Imported<T>(val items: List<T>, val cancelled: Boolean)

    /**
     * Imports each item into its own session. Without [onItemReady] a
     * failure rolls back every finished item (one result or none); a
     * cancel keeps them, because the user chose to stop.
     */
    fun <I, T> importItems(
        root: File,
        items: List<I>,
        load: (Int, I, File) -> T,
        onItemReady: ((T) -> Unit)? = null,
        cancelled: () -> Boolean = { false },
    ): Imported<T> {
        val done = mutableListOf<T>()
        val sessions = mutableListOf<File>()
        for ((index, input) in items.withIndex()) {
            if (cancelled()) return Imported(done, true)
            val item = try {
                importing(root) { session ->
                    sessions += session
                    load(index, input, session)
                }
            } catch (error: Exception) {
                if (cancelled()) return Imported(done, true)
                if (onItemReady == null) {
                    for (session in sessions) {
                        try {
                            clear(session)
                        } catch (cleanup: Exception) {
                            error.addSuppressed(cleanup)
                        }
                    }
                }
                throw error
            }
            done += item
            onItemReady?.invoke(item)
        }
        return Imported(done, false)
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
