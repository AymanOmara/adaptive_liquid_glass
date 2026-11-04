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
            val converted = H264Transcoder.transcode(source, destination, activity) { _, output, progress ->
                output.writeText("partial")
                time = 10
                progress.checkActive()
            }
            assertFalse(converted)
            assertFalse(destination.exists())
            assertEquals("original", source.readText())

            // The same import can retry after a failed codec session.
            assertTrue(H264Transcoder.transcode(source, destination) { _, output, _ ->
                output.writeText("complete")
            })
            assertEquals("complete", destination.readText())
            assertEquals("original", source.readText())
        } finally {
            root.deleteRecursively()
        }
    }

    /** An encoder limited to 1920x1088 in either orientation, like many AVC encoders. */
    private val upTo1080p = { w: Int, h: Int -> maxOf(w, h) <= 1920 && minOf(w, h) <= 1088 }

    @Test fun supportedSourceSizeIsTriedFirstUnchanged() {
        val sizes = H264Transcoder.encoderSizes(1920, 1080, 2, 2) { _, _ -> true }
        assertEquals(1920 to 1080, sizes.first())
    }

    @Test fun landscape4kStepsDownToLargestSupportedSizeKeepingAspect() {
        val sizes = H264Transcoder.encoderSizes(3840, 2160, 2, 2, upTo1080p)
        assertEquals(listOf(1920 to 1080, 1280 to 720), sizes)
    }

    @Test fun portrait4kStepsDownKeepingOrientation() {
        val sizes = H264Transcoder.encoderSizes(2160, 3840, 2, 2, upTo1080p)
        assertEquals(1080 to 1920, sizes.first())
    }

    @Test fun ladderDescendsThroughEachLongEdge() {
        val sizes = H264Transcoder.encoderSizes(3840, 2160, 2, 2) { _, _ -> true }
        assertEquals(listOf(3840 to 2160, 2560 to 1440, 1920 to 1080, 1280 to 720), sizes)
    }

    @Test fun oddDimensionsBecomeEven() {
        val sizes = H264Transcoder.encoderSizes(3841, 2161, 2, 2) { _, _ -> true }
        assertEquals(3840 to 2160, sizes.first())
        sizes.forEach { (w, h) -> assertTrue(w % 2 == 0 && h % 2 == 0) }
    }

    @Test fun sizesHonourTheEncoderAlignment() {
        val sizes = H264Transcoder.encoderSizes(3840, 2160, 16, 16, upTo1080p)
        assertEquals(1920 to 1072, sizes.first())
        sizes.forEach { (w, h) -> assertTrue(w % 16 == 0 && h % 16 == 0) }
    }

    @Test fun nothingSupportedGivesNoCandidates() {
        assertTrue(H264Transcoder.encoderSizes(3840, 2160, 2, 2) { _, _ -> false }.isEmpty())
    }

    @Test fun smallSourceIsNeverUpscaled() {
        val sizes = H264Transcoder.encoderSizes(1280, 720, 2, 2) { _, _ -> true }
        assertEquals(listOf(1280 to 720), sizes)
    }

    @Test fun bitRateScalesWithPixelCount() {
        assertEquals(10_000_000, H264Transcoder.scaledBitRate(40_000_000, 3840 * 2160, 1920 * 1080))
        // Never below the floor.
        assertEquals(1_000_000, H264Transcoder.scaledBitRate(2_000_000, 3840 * 2160, 640 * 360))
        assertEquals(8_000_000, H264Transcoder.scaledBitRate(8_000_000, 100, 100))
    }
}
