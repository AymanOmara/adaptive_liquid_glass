package com.aymanomara.adaptive_liquid_glass

import java.io.File
import java.io.IOException
import java.util.UUID

/** Each import owns a directory so a failed batch cannot strand earlier items. */
internal object GlassPhotoCache {
    fun <I, T> importItems(
        root: File,
        items: List<I>,
        load: (I, File) -> T,
        onItemReady: ((T) -> Unit)? = null,
    ): List<T> = if (onItemReady == null) {
        importing(root) { session -> items.map { load(it, session) } }
    } else items.map { input ->
        val item = importing(root) { session -> load(input, session) }
        onItemReady(item)
        item
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
