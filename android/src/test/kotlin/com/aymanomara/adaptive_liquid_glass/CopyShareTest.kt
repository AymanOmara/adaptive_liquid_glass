package com.aymanomara.adaptive_liquid_glass

import com.aymanomara.adaptive_liquid_glass.GlassPhotosPicker.Companion.copyShareFor
import com.aymanomara.adaptive_liquid_glass.GlassPhotosPicker.Options
import org.junit.Assert.assertEquals
import org.junit.Test

class CopyShareTest {
    private val compat = Options(compatible = true)

    @Test fun hevcVideoCompatibleConverts() =
        assertEquals(0.5, copyShareFor(true, "video/mp4", true, compat, false), 0.0)

    @Test fun h264VideoCompatibleDoesNotConvert() =
        assertEquals(1.0, copyShareFor(true, "video/mp4", false, compat, false), 0.0)

    @Test fun quarantinedVideoDoesNotConvert() =
        assertEquals(1.0, copyShareFor(true, "video/mp4", true, compat, true), 0.0)

    @Test fun videoWithoutCompatibleDoesNotConvert() =
        assertEquals(1.0, copyShareFor(true, "video/mp4", true, Options(), false), 0.0)

    @Test fun resizedImageConverts() {
        assertEquals(0.5, copyShareFor(false, "image/png", false, Options(maxWidth = 10), false), 0.0)
        assertEquals(0.5, copyShareFor(false, "image/jpeg", false, Options(quality = 80), false), 0.0)
    }

    @Test fun heicCompatibleConverts() =
        assertEquals(0.5, copyShareFor(false, "image/heic", false, compat, false), 0.0)

    @Test fun jpegCompatibleDoesNotConvert() =
        assertEquals(1.0, copyShareFor(false, "image/jpeg", false, compat, false), 0.0)

    @Test fun plainImageDoesNotConvert() =
        assertEquals(1.0, copyShareFor(false, "image/jpeg", false, Options(), false), 0.0)
}
