package com.aymanomara.adaptive_liquid_glass

import java.io.File
import java.io.IOException
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class GlassPhotoCacheTest {
    @Test fun incrementalImportKeepsDeliveredFilesWhenLaterItemFails() {
        val root = Files.createTempDirectory("glass-photos").toFile()
        val delivered = mutableListOf<File>()
        try {
            try {
                GlassPhotoCache.importItems(root, listOf(1, 2), { _, index, session ->
                    if (index == 2) {
                        assertEquals(1, delivered.size)
                        assertEquals("ready", delivered.single().readText())
                        File(session, "partial").writeText("unfinished")
                        throw IOException("second item unavailable")
                    }
                    File(session, "ready.jpg").apply { writeText("ready") }
                }, { delivered.add(it) })
                fail("Second item must fail")
            } catch (_: IOException) {
                assertEquals("ready", delivered.single().readText())
                assertEquals(listOf(delivered.single().parentFile), root.listFiles()!!.toList())
            }
        } finally {
            root.deleteRecursively()
        }
    }

    @Test fun batchImportStillRollsBackEarlierItemsWithoutIncrementalCallback() {
        val root = Files.createTempDirectory("glass-photos").toFile()
        try {
            try {
                GlassPhotoCache.importItems(root, listOf(1, 2), { _, index, session ->
                    File(session, "$index.jpg").writeText("copy")
                    if (index == 2) throw IOException("second item unavailable")
                })
                fail("Second item must fail")
            } catch (_: IOException) {
                assertEquals(0, root.listFiles()!!.size)
            }
        } finally {
            root.deleteRecursively()
        }
    }

    @Test fun failedBatchRemovesSuccessfulAndPartialCopiesButKeepsEarlierPicks() {
        val root = Files.createTempDirectory("glass-photos").toFile()
        try {
            val earlier = GlassPhotoCache.importing(root) { session ->
                File(session, "earlier.jpg").apply { writeText("keep") }
            }
            val failure = IOException("provider disconnected")
            try {
                GlassPhotoCache.importing(root) { session ->
                    File(session, "ready.jpg").writeText("complete")
                    File(session, "partial.mp4").writeText("partial")
                    throw failure
                }
                fail("Import must fail")
            } catch (error: IOException) {
                assertSame(failure, error)
            }
            assertEquals("keep", earlier.readText())
            assertEquals(listOf(earlier.parentFile), root.listFiles()!!.toList())
            val retried = GlassPhotoCache.importing(root) { session ->
                File(session, "retry.jpg").apply { writeText("retry") }
            }
            assertEquals("retry", retried.readText())
            assertTrue(earlier.exists())
            GlassPhotoCache.clear(root)
            assertFalse(root.exists())
            GlassPhotoCache.clear(root) // Already absent is successful.
        } finally {
            root.deleteRecursively()
        }
    }

    @Test fun deniedCleanupReportsFailureInsteadOfSuccess() {
        val denied = object : File("denied-photo-cache") {
            override fun exists() = true
            override fun isDirectory() = false
            override fun isFile() = true
            override fun delete() = false
        }
        try {
            GlassPhotoCache.clear(denied)
            fail("Cleanup must report the failure")
        } catch (_: IOException) {
            // Expected even when the host runs with elevated file permissions.
        }
    }

    @Test fun invalidCacheRootDoesNotTouchExistingFile() {
        val root = Files.createTempFile("glass-photos", ".file").toFile()
        try {
            root.writeText("keep")
            try {
                GlassPhotoCache.importing(root) { fail("Must not start copying") }
                fail("Import must fail")
            } catch (_: IOException) {
                assertEquals("keep", root.readText())
            }
        } finally {
            root.delete()
        }
    }

    @Test fun cancelBeforeFirstItemReturnsEmptyCancelled() {
        val root = Files.createTempDirectory("glass-photos").toFile()
        try {
            val result = GlassPhotoCache.importItems(root, listOf(1, 2), { _, _, _ -> error("not called") }, cancelled = { true })
            assertEquals(emptyList<Int>(), result.items)
            assertTrue(result.cancelled)
        } finally {
            root.deleteRecursively()
        }
    }

    @Test fun cancelMidBatchKeepsFinishedAndDropsPartial() {
        val root = Files.createTempDirectory("glass-photos").toFile()
        try {
            var stop = false
            val result = GlassPhotoCache.importItems(root, listOf("a", "b", "c"), { i, name, session ->
                val f = File(session, name).apply { writeText(name) }
                if (i == 1) { stop = true; throw java.util.concurrent.CancellationException() }
                f
            }, cancelled = { stop })
            assertEquals(listOf("a"), result.items.map { it.name })
            assertTrue(result.cancelled)
            assertTrue(result.items.single().exists())
            assertEquals(1, root.listFiles()!!.size) // b's session removed
        } finally {
            root.deleteRecursively()
        }
    }

    @Test fun batchFailureStillRollsBackEverything() {
        val root = Files.createTempDirectory("glass-photos").toFile()
        try {
            try {
                GlassPhotoCache.importItems(root, listOf("a", "b"), { i, name, session ->
                    if (i == 1) throw IOException("boom")
                    File(session, name).apply { writeText(name) }
                })
                fail()
            } catch (e: IOException) {
                assertEquals(0, root.listFiles()!!.size)
            }
        } finally {
            root.deleteRecursively()
        }
    }
}
