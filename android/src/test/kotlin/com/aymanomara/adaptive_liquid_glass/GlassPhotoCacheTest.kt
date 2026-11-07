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

class GlassPhotoCacheParallelTest {
    private fun <T> withRoot(block: (File) -> T): T {
        val root = Files.createTempDirectory("glass-photos").toFile()
        try { return block(root) } finally { root.deleteRecursively() }
    }

    @Test fun runsUpToConcurrencyItemsAtOnceAndNeverMore() = withRoot { root ->
        val running = java.util.concurrent.atomic.AtomicInteger()
        val peak = java.util.concurrent.atomic.AtomicInteger()
        val result = GlassPhotoCache.importItems(root, (0 until 9).toList(), { _, n, _ ->
            val now = running.incrementAndGet()
            peak.accumulateAndGet(now) { a, b -> maxOf(a, b) }
            Thread.sleep(30)
            running.decrementAndGet()
            n
        }, concurrency = 3)
        assertEquals(3, peak.get())
        assertEquals((0 until 9).toList(), result.items)
    }

    @Test fun resultsStayInSelectionOrderWhileReadyFiresOnCompletion() = withRoot { root ->
        val ready = java.util.Collections.synchronizedList(mutableListOf<Int>())
        // Item 0 is slowest, so it finishes last.
        val result = GlassPhotoCache.importItems(root, listOf(0, 1, 2), { _, n, _ ->
            Thread.sleep(if (n == 0) 150L else 10L)
            n
        }, { ready.add(it) }, concurrency = 3)
        assertEquals(listOf(0, 1, 2), result.items)
        assertEquals(0, ready.last())
        assertEquals(3, ready.size)
    }

    @Test fun cancelKeepsFinishedItemsInOrderAndStartsNoMore() = withRoot { root ->
        val stop = java.util.concurrent.atomic.AtomicBoolean()
        val thirdStarted = java.util.concurrent.CountDownLatch(1)
        val started = java.util.Collections.synchronizedList(mutableListOf<Int>())
        val result = GlassPhotoCache.importItems(root, (0 until 6).toList(), { i, n, session ->
            started += i
            when (i) {
                2 -> {
                    thirdStarted.await()
                    stop.set(true)
                    throw java.util.concurrent.CancellationException()
                }
                3 -> {
                    thirdStarted.countDown()
                    while (!stop.get()) Thread.sleep(1)
                }
            }
            File(session, "$n").apply { writeText("x") }
        }, cancelled = { stop.get() }, concurrency = 2)
        assertTrue(result.cancelled)
        // Item 3 was already running at the cancel, so it finishes and is kept.
        assertEquals(listOf("0", "1", "3"), result.items.map { it.name })
        assertEquals(listOf(0, 1, 2, 3), started.sorted())
        assertEquals(3, root.listFiles()!!.size)
    }

    @Test fun batchFailureWaitsForRunningItemsThenRollsBackEverything() = withRoot { root ->
        try {
            GlassPhotoCache.importItems(root, (0 until 4).toList(), { i, n, session ->
                if (i == 1) throw IOException("boom")
                Thread.sleep(40)
                File(session, "$n").apply { writeText("x") }
            }, concurrency = 2)
            fail()
        } catch (e: IOException) {
            assertEquals("boom", e.message)
            assertEquals(0, root.listFiles()!!.size)
        }
    }

    @Test fun incrementalFailureKeepsDeliveredFiles() = withRoot { root ->
        val ready = java.util.Collections.synchronizedList(mutableListOf<File>())
        try {
            GlassPhotoCache.importItems(root, (0 until 3).toList(), { i, n, session ->
                if (i == 1) { Thread.sleep(20); throw IOException("boom") }
                File(session, "$n").apply { writeText("x") }
            }, { ready.add(it) }, concurrency = 2)
            fail()
        } catch (e: IOException) {
            assertTrue(ready.isNotEmpty())
            assertTrue(ready.all { it.exists() })
            assertEquals(ready.size, root.listFiles()!!.size)
        }
    }
}
