package com.aymanomara.adaptive_liquid_glass

import java.io.File
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class H264TranscoderTest {
    @Test fun stalledConversionDeletesPartialOutputAndKeepsOriginalForFallback() {
        val root = Files.createTempDirectory("glass-codec").toFile()
        try {
            val source = File(root, "original.hevc").apply { writeText("original") }
            val destination = File(root, "converted.mp4")
            var time = 0L
            val activity = TranscodeProgress(timeoutNanos = 10, now = { time })
            val converted = H264Transcoder.transcode(source, destination) { _, output ->
                output.writeText("partial")
                time = 10
                activity.checkActive()
            }
            assertFalse(converted)
            assertFalse(destination.exists())
            assertEquals("original", source.readText())

            // The same import can retry after a failed codec session.
            assertTrue(H264Transcoder.transcode(source, destination) { _, output ->
                output.writeText("complete")
            })
            assertEquals("complete", destination.readText())
            assertEquals("original", source.readText())
        } finally {
            root.deleteRecursively()
        }
    }
}
