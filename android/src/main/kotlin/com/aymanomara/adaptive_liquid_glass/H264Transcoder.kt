package com.aymanomara.adaptive_liquid_glass

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer

/**
 * Re-encodes HEVC videos as H.264 `.mp4` for `compatibleFormat`, with the
 * platform codecs only (MediaExtractor, MediaCodec, MediaMuxer).
 *
 * The decoder renders each frame into a [SurfaceTexture]; it is drawn with
 * GLES into the encoder's input surface, one frame at a time, so no frame
 * is dropped. The audio track is copied as it is. Blocking: call it off
 * the main thread.
 */
internal object H264Transcoder {
    private const val HEVC = MediaFormat.MIMETYPE_VIDEO_HEVC
    private const val AVC = MediaFormat.MIMETYPE_VIDEO_AVC
    private const val TIMEOUT_US = 10_000L

    /** Whether the first video track of [file] is HEVC. */
    fun isHevc(file: File): Boolean {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(file.absolutePath)
            val index = track(extractor, "video/")
            index >= 0 && extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) == HEVC
        } catch (e: Exception) {
            false
        } finally {
            extractor.release()
        }
    }

    /**
     * Writes [src] re-encoded as H.264 to [dest]; false (deleting any
     * partial [dest]) when a codec, the muxer or the audio format refuses.
     */
    fun transcode(src: File, dest: File): Boolean = try {
        run(src, dest)
        true
    } catch (e: Exception) {
        dest.delete()
        false
    }

    private fun track(extractor: MediaExtractor, prefix: String): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith(prefix) == true) return i
        }
        return -1
    }

    private fun rotation(src: File, format: MediaFormat): Int {
        if (format.containsKey(MediaFormat.KEY_ROTATION)) {
            return format.getInteger(MediaFormat.KEY_ROTATION)
        }
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(src.absolutePath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
        } catch (e: Exception) {
            0
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                // Already released.
            }
        }
    }

    private fun run(src: File, dest: File) {
        val video = MediaExtractor().apply { setDataSource(src.absolutePath) }
        val audio = MediaExtractor().apply { setDataSource(src.absolutePath) }
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        var gl: GlBridge? = null
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        try {
            val videoIndex = track(video, "video/")
            require(videoIndex >= 0) { "No video track" }
            video.selectTrack(videoIndex)
            val inFormat = video.getTrackFormat(videoIndex)
            // Encoders want even sizes.
            val width = inFormat.getInteger(MediaFormat.KEY_WIDTH) and 1.inv()
            val height = inFormat.getInteger(MediaFormat.KEY_HEIGHT) and 1.inv()
            val fps = frameRate(inFormat)
            // H.264 needs about half again HEVC's bit rate for the same look.
            val bitRate = if (inFormat.containsKey(MediaFormat.KEY_BIT_RATE)) {
                inFormat.getInteger(MediaFormat.KEY_BIT_RATE) * 3 / 2
            } else {
                (width.toLong() * height * fps.coerceIn(1, 60) / 7).toInt()
            }.coerceIn(1_000_000, 40_000_000)

            val outFormat = MediaFormat.createVideoFormat(AVC, width, height).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps.coerceIn(1, 60))
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            encoder = MediaCodec.createEncoderByType(AVC).apply {
                configure(outFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            }
            gl = GlBridge(encoder.createInputSurface())
            encoder.start()
            val rotation = (rotation(src, inFormat) % 360 + 360) % 360
            // A decoder rendering to a surface turns the frames itself; keep
            // them as stored and let the muxer carry the rotation instead.
            inFormat.setInteger(MediaFormat.KEY_ROTATION, 0)
            decoder = MediaCodec.createDecoderByType(inFormat.getString(MediaFormat.KEY_MIME)!!)
                .apply {
                    configure(inFormat, gl.decoderSurface, null, 0)
                    start()
                }

            muxer = MediaMuxer(dest.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer.setOrientationHint(rotation)
            val audioIndex = track(audio, "audio/")
            var audioOut = -1
            if (audioIndex >= 0) {
                audio.selectTrack(audioIndex)
                audioOut = muxer.addTrack(audio.getTrackFormat(audioIndex))
            }

            var videoOut = -1
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var decoderDone = false
            var encoderDone = false
            while (!encoderDone) {
                if (!inputDone) {
                    val i = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (i >= 0) {
                        val size = video.readSampleData(decoder.getInputBuffer(i)!!, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(
                                i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(i, 0, size, video.sampleTime, 0)
                            video.advance()
                        }
                    }
                }
                // Drain the encoder first, then feed it one decoded frame.
                var progress = true
                while (progress && !encoderDone) {
                    progress = false
                    val e = encoder.dequeueOutputBuffer(info, TIMEOUT_US)
                    if (e == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        check(videoOut < 0) { "Encoder format changed twice" }
                        videoOut = muxer.addTrack(encoder.outputFormat)
                        muxer.start()
                        muxerStarted = true
                        progress = true
                    } else if (e >= 0) {
                        val data = encoder.getOutputBuffer(e)!!
                        val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                        if (info.size > 0 && !config) {
                            check(muxerStarted) { "Encoder output before its format" }
                            data.position(info.offset)
                            data.limit(info.offset + info.size)
                            muxer.writeSampleData(videoOut, data, info)
                        }
                        encoder.releaseOutputBuffer(e, false)
                        encoderDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        progress = true
                    }
                    if (progress || decoderDone) continue
                    val d = decoder.dequeueOutputBuffer(info, TIMEOUT_US)
                    if (d >= 0) {
                        val render = info.size > 0
                        decoder.releaseOutputBuffer(d, render)
                        if (render) gl.draw(info.presentationTimeUs * 1000)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            encoder.signalEndOfInputStream()
                            decoderDone = true
                        }
                        progress = true
                    } else if (d == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        progress = true
                    }
                }
            }

            if (audioOut >= 0) {
                val format = audio.getTrackFormat(audioIndex)
                val capacity = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                } else 1 shl 20
                val buffer = ByteBuffer.allocateDirect(capacity)
                while (true) {
                    val size = audio.readSampleData(buffer, 0)
                    if (size < 0) break
                    info.set(0, size, audio.sampleTime, audio.sampleFlags.toCodecFlags())
                    muxer.writeSampleData(audioOut, buffer, info)
                    audio.advance()
                }
            }
            check(muxerStarted) { "No video was encoded" }
            muxer.stop()
            muxerStarted = false
        } finally {
            fun quietly(block: () -> Unit) = try {
                block()
            } catch (e: Exception) {
                // Releasing after a failure.
            }
            quietly { decoder?.stop() }
            quietly { decoder?.release() }
            quietly { encoder?.stop() }
            quietly { encoder?.release() }
            quietly { gl?.release() }
            if (muxerStarted) quietly { muxer?.stop() }
            quietly { muxer?.release() }
            video.release()
            audio.release()
        }
    }

    /** The frame rate, stored as an int or a float depending on the file. */
    private fun frameRate(format: MediaFormat): Int {
        if (!format.containsKey(MediaFormat.KEY_FRAME_RATE)) return 30
        return try {
            format.getInteger(MediaFormat.KEY_FRAME_RATE)
        } catch (e: ClassCastException) {
            format.getFloat(MediaFormat.KEY_FRAME_RATE).toInt()
        }.takeIf { it > 0 } ?: 30
    }

    /** MediaExtractor's sync flag as MediaCodec's key-frame flag. */
    private fun Int.toCodecFlags(): Int =
        if (this and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
}
