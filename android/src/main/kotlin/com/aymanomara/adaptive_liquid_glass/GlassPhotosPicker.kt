package com.aymanomara.adaptive_liquid_glass

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ext.SdkExtensions
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * The system photo picker behind `pickGlassPhotos`, the Android side of
 * SwiftUI's `PhotosPicker`.
 *
 * Uses the Photo Picker (`MediaStore.ACTION_PICK_IMAGES`) on Android 13+
 * and on Android 11-12 with SDK extension 2, else the document picker
 * (`ACTION_OPEN_DOCUMENT`). Neither needs a storage permission. Runs from
 * `startActivityForResult`, so it works with a plain `FlutterActivity`
 * (the AndroidX result APIs need a `ComponentActivity`). Each chosen item
 * is copied into `cacheDir/adaptive_liquid_glass_picker`; photos are
 * downscaled or converted to JPEG, and HEVC videos re-encoded as H.264
 * ([H264Transcoder]), when asked. Up to [COPY_CONCURRENCY] items import
 * at once; video conversion runs one at a time and photo re-encodes two at
 * a time, as on iOS, to bound codec and bitmap memory.
 */
internal class GlassPhotosPicker(private val context: Context) :
    PluginRegistry.ActivityResultListener {
    /** How `pickGlassPhotos` asked for the photos to be delivered. */
    data class Options(
        val maxWidth: Int? = null,
        val maxHeight: Int? = null,
        /** 0-100. */
        val quality: Int? = null,
        /** HEIC/HEIF photos as JPEG, HEVC videos as H.264. */
        val compatible: Boolean = false,
    )

    var activity: Activity? = null

    private var pending: MethodChannel.Result? = null
    private var pendingMax = 1
    private var pendingOptions = Options()
    private var pendingName: String? = null
    private var pendingOnEvent: ((String, Map<String, Any?>) -> Unit)? = null
    private var pendingCancelled = false

    @Volatile
    private var job: PhotoImportJob? = null
    private val io = Executors.newSingleThreadExecutor()
    private val transcodeGate = ImportGate(TRANSCODE_CONCURRENCY)
    private val reencodeGate = ImportGate(REENCODE_CONCURRENCY)
    private val main = Handler(Looper.getMainLooper())
    private val dir get() = File(context.cacheDir, "adaptive_liquid_glass_picker")

    fun pick(
        maxSelection: Int,
        filter: String,
        options: Options,
        result: MethodChannel.Result,
        importChannel: String? = null,
        onEvent: ((String, Map<String, Any?>) -> Unit)? = null,
    ) {
        val host = activity
        if (host == null) {
            result.error("no_activity", "No activity to present the photo picker from.", null)
            return
        }
        if (pending != null) {
            result.error("already_active", "A photo picker is already open.", null)
            return
        }
        val intent = if (hasPhotoPicker()) photoPickerIntent(maxSelection, filter)
        else documentIntent(maxSelection, filter)
        job = null
        pending = result
        pendingMax = maxSelection
        pendingOptions = options
        // Registered before the picker opens so a cancel during selection counts.
        pendingName = importChannel
        pendingOnEvent = onEvent
        pendingCancelled = false
        try {
            host.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pending = null
            pendingName = null
            pendingOnEvent = null
            result.error("no_picker", e.message, null)
        }
    }

    /** Stops the import named [importChannel]; a stale name does nothing. */
    fun cancel(importChannel: String) {
        job?.takeIf { it.name == importChannel }?.let {
            it.cancel.cancelled = true
            return
        }
        if (pending != null && pendingName == importChannel) {
            pendingCancelled = true
            activity?.finishActivity(REQUEST_CODE)
        }
    }

    /** Deletes every copy made so far, off the main thread. */
    fun clearCopies(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("already_active", "Wait for the photo import, or call controller.cancel(), before clearing picked files.", null)
            return
        }
        io.execute {
            try {
                GlassPhotoCache.clear(dir)
                main.post { result.success(null) }
            } catch (e: Exception) {
                main.post { result.error("cleanup_failed", e.message, null) }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        if (resultCode != Activity.RESULT_OK || data == null || pendingCancelled) {
            val cancelled = pendingCancelled
            pending = null
            pendingName = null
            pendingOnEvent = null
            pendingCancelled = false
            result.success(mapOf("items" to emptyList<Any>(), "dropped" to 0, "cancelled" to cancelled))
            return true
        }
        var uris = buildList {
            val clip = data.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) add(clip.getItemAt(i).uri)
            } else {
                data.data?.let { add(it) }
            }
        }
        // The document picker has no selection limit: keep the first ones
        // and report the rest as `GlassPickedPhotos.droppedCount`.
        var dropped = 0
        if (pendingMax > 0 && uris.size > pendingMax) {
            dropped = uris.size - pendingMax
            uris = uris.take(pendingMax)
        }
        val options = pendingOptions
        val events = pendingOnEvent
        val delivered = java.util.Collections.synchronizedList(mutableListOf<Map<String, Any?>>())
        val current = PhotoImportJob(pendingName, uris.size, emit = { e -> main.post { events?.invoke("progress", e) } })
        job = current
        pendingName = null
        pendingOnEvent = null
        io.execute {
            try {
                val imported = GlassPhotoCache.importItems(
                    dir, uris, { index, uri, session -> copy(index, uri, options, session, current).also { delivered += it } },
                    events?.let { notify ->
                        { item ->
                            main.post { notify("itemReady", item) }
                            Unit
                        }
                    },
                    cancelled = { current.cancel.cancelled },
                    concurrency = COPY_CONCURRENCY,
                )
                main.post {
                    pending = null
                    job = null
                    result.success(
                        mapOf(
                            "items" to imported.items,
                            "dropped" to dropped,
                            "cancelled" to imported.cancelled,
                        ),
                    )
                }
            } catch (e: Exception) {
                main.post {
                    pending = null
                    job = null
                    if (current.cancel.cancelled) {
                        // Only incremental imports keep finished items after a failure.
                        val kept = if (events != null) delivered.sortedBy { it["index"] as Int } else emptyList()
                        result.success(mapOf("items" to kept, "dropped" to dropped, "cancelled" to true))
                    } else {
                        result.error("load_failed", e.message, null)
                    }
                }
            }
        }
        return true
    }

    private fun copy(
        index: Int,
        uri: Uri,
        options: Options,
        directory: File,
        job: PhotoImportJob,
    ): Map<String, Any?> {
        try {
            return copyItem(index, uri, options, directory, job)
        } catch (e: Exception) {
            // The final event still counts a failed item, so `completed` reaches
            // `total`; a cancelled item is not counted.
            if (e !is java.util.concurrent.CancellationException && !job.cancel.cancelled) {
                job.progress.finish(index)
            }
            throw e
        }
    }

    private fun copyItem(
        index: Int,
        uri: Uri,
        options: Options,
        directory: File,
        job: PhotoImportJob,
    ): Map<String, Any?> {
        val resolver = context.contentResolver
        var mime = resolver.getType(uri)
        val ext = mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        var dest = File(directory, UUID.randomUUID().toString() + (ext?.let { ".$it" } ?: ""))
        val isVideo = mime?.startsWith("video/") == true
        // Copy is the whole item unless a conversion will actually follow.
        val hevc = isVideo && options.compatible && !job.quarantined &&
            H264Transcoder.isHevc(context, uri)
        val copyShare = copyShareFor(isVideo, mime, hevc, options, job.quarantined)
        val size = size(uri)
        val copying = TranscodeProgress(cancel = job.cancel)
        job.io(copying) {
            val input = resolver.openInputStream(uri) ?: throw IllegalStateException("Cannot open $uri")
            input.use { src ->
                dest.outputStream().use { out ->
                    ChunkedCopy.copy(
                        src, out, size, job.cancel,
                        { f -> job.progress.update(index, f?.let { it * copyShare }) },
                        { copying.advanced() },
                    )
                }
            }
        }
        val item = mutableMapOf<String, Any?>("isVideo" to isVideo, "index" to index)
        if (isVideo) {
            if (options.compatible && H264Transcoder.isHevc(dest)) {
                val out = File(directory, dest.nameWithoutExtension + ".out.mp4")
                val durationUs = H264Transcoder.durationUs(dest)
                val converted = transcodeGate.run(job.cancel) {
                    // Created inside the gate, just before the codec call, so
                    // copy and queue time are not counted as a stall.
                    val activity = TranscodeProgress(cancel = job.cancel, onAdvance = { us ->
                        if (durationUs > 0) {
                            job.progress.update(
                                index,
                                copyShare + (1 - copyShare) * minOf(1.0, us.toDouble() / durationUs),
                            )
                        }
                    })
                    job.convert(activity) { H264Transcoder.transcode(dest, out, activity) }
                }
                if (converted == true) {
                    dest.delete()
                    dest = out
                    mime = "video/mp4"
                } else {
                    // Delivered as HEVC; `GlassPickedPhoto.conversionFailed`.
                    // An abandoned call can leave a complete or partial output behind.
                    out.delete()
                    item["conversionFailed"] = true
                }
            }
            videoInfo(dest, item)
        } else {
            val encoded = reencodeGate.run(job.cancel) { reencode(dest, mime, options) }
            if (encoded != null) {
                dest = encoded.first
                mime = encoded.second
            } else if (options.compatible && (mime == "image/heic" || mime == "image/heif")) {
                item["conversionFailed"] = true
            }
            imageSize(dest)?.let { (w, h) ->
                item["width"] = w
                item["height"] = h
            }
        }
        item["path"] = dest.absolutePath
        item["mimeType"] = mime
        job.progress.finish(index)
        return item
    }

    /** The provider's byte size, or null when it does not say. */
    private fun size(uri: Uri): Long? = try {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) c.getLong(0).takeIf { it > 0 } else null
        }
    } catch (e: Exception) {
        null
    }

    /**
     * Writes a downscaled or converted copy of the photo [file] (upright,
     * JPEG unless it was PNG) and deletes the original; null when [options]
     * leave it as it is or it cannot be decoded.
     */
    private fun reencode(file: File, mime: String?, options: Options): Pair<File, String>? {
        if (mime == "image/gif") return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        val w = bounds.outWidth
        val h = bounds.outHeight
        if (w <= 0 || h <= 0) return null
        val orientation = orientation(file)
        val (uw, uh) = if (swapsSides(orientation)) h to w else w to h
        val scale = minOf(
            1.0,
            options.maxWidth?.let { it.toDouble() / uw } ?: 1.0,
            options.maxHeight?.let { it.toDouble() / uh } ?: 1.0,
        )
        val isHeif = mime == "image/heic" || mime == "image/heif"
        val lossy = isHeif || mime == "image/jpeg"
        val resize = scale < 1
        val convert = options.compatible && isHeif
        if (!resize && !convert && !(options.quality != null && lossy)) return null
        // Decode at the largest power-of-two reduction still above the target.
        var sample = 1
        while (w / (sample * 2) >= w * scale && h / (sample * 2) >= h * scale) sample *= 2
        val decoded = BitmapFactory.decodeFile(
            file.absolutePath,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        val matrix = Matrix().apply {
            setScale(
                (w * scale / decoded.width).toFloat(),
                (h * scale / decoded.height).toFloat(),
            )
            when (orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
                ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(180f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> {
                    postRotate(90f)
                    postScale(-1f, 1f)
                }
                ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(90f)
                ExifInterface.ORIENTATION_TRANSVERSE -> {
                    postRotate(-90f)
                    postScale(-1f, 1f)
                }
                ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(270f)
            }
        }
        val upright =
            Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        val png = mime == "image/png"
        val out = File(file.parentFile, file.nameWithoutExtension + if (png) ".out.png" else ".out.jpg")
        val written = try {
            out.outputStream().use {
                upright.compress(
                    if (png) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG,
                    options.quality ?: DEFAULT_QUALITY,
                    it,
                )
            }
        } finally {
            if (upright !== decoded) upright.recycle()
            decoded.recycle()
        }
        if (!written) {
            out.delete()
            return null
        }
        file.delete()
        return out to if (png) "image/png" else "image/jpeg"
    }

    /** The upright pixel size from the image header, without decoding. */
    private fun imageSize(file: File): Pair<Int, Int>? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        return if (swapsSides(orientation(file))) bounds.outHeight to bounds.outWidth
        else bounds.outWidth to bounds.outHeight
    }

    /** The EXIF orientation; normal when there is none or it is unreadable. */
    private fun orientation(file: File): Int = try {
        ExifInterface(file.absolutePath)
            .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
    } catch (e: Exception) {
        ExifInterface.ORIENTATION_NORMAL
    }

    /** EXIF orientations 5-8 turn the image by 90 degrees. */
    private fun swapsSides(orientation: Int) =
        orientation in ExifInterface.ORIENTATION_TRANSPOSE..ExifInterface.ORIENTATION_ROTATE_270

    /** Adds the upright size and the duration of the video [file] to [item]. */
    private fun videoInfo(file: File, item: MutableMap<String, Any?>) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.absolutePath)
            fun read(key: Int) = retriever.extractMetadata(key)?.toIntOrNull()
            val w = read(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val h = read(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rotation = read(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: 0
            if (w != null && h != null && w > 0 && h > 0) {
                val turned = rotation % 180 != 0
                item["width"] = if (turned) h else w
                item["height"] = if (turned) w else h
            }
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()?.let { item["durationMs"] = it }
        } catch (e: Exception) {
            // Unreadable metadata: the size and duration stay unknown.
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                // Already released.
            }
        }
    }

    @SuppressLint("NewApi")
    private fun photoPickerIntent(maxSelection: Int, filter: String): Intent {
        val intent = Intent(MediaStore.ACTION_PICK_IMAGES)
        when (filter) {
            "videos" -> intent.type = "video/*"
            "any" -> Unit // images and videos
            else -> intent.type = "image/*"
        }
        if (maxSelection != 1) {
            val limit = MediaStore.getPickImagesMaxLimit()
            val max = if (maxSelection == 0) limit else minOf(maxSelection, limit)
            intent.putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, max)
        }
        return intent
    }

    private fun documentIntent(maxSelection: Int, filter: String): Intent =
        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = when (filter) {
                "videos" -> "video/*"
                "any" -> "*/*"
                else -> "image/*"
            }
            if (filter == "any") {
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            }
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, maxSelection != 1)
        }

    /** The Photo Picker: Android 13+, or 11-12 with SDK extension 2. */
    private fun hasPhotoPicker(): Boolean = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> true
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
            SdkExtensions.getExtensionVersion(Build.VERSION_CODES.R) >= 2
        else -> false
    }

    internal companion object {
        /** Share of an item's progress taken by the copy: 0.5 only when a conversion will run. */
        fun copyShareFor(
            isVideo: Boolean,
            mime: String?,
            hevc: Boolean,
            options: Options,
            quarantined: Boolean,
        ): Double {
            val converts = if (isVideo) {
                options.compatible && hevc && !quarantined
            } else {
                options.maxWidth != null || options.maxHeight != null || options.quality != null ||
                    (options.compatible && (mime == "image/heic" || mime == "image/heif"))
            }
            return if (converts) 0.5 else 1.0
        }

        /** Items copied at once; copies are I/O-bound. */
        const val COPY_CONCURRENCY = 3

        /** Video conversions at once: the hardware codec is the memory and thermal hog. */
        const val TRANSCODE_CONCURRENCY = 1

        /** Photo decodes and re-encodes at once, bounding bitmap memory. */
        const val REENCODE_CONCURRENCY = 2

        /** Arbitrary, below 0xFFFF as `startActivityForResult` requires. */
        const val REQUEST_CODE = 0x4C47

        /** JPEG quality when converting without an `imageQuality`. */
        const val DEFAULT_QUALITY = 90
    }
}
