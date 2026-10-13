package com.aymanomara.adaptive_liquid_glass

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ext.SdkExtensions
import android.provider.MediaStore
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
 * is copied into `cacheDir/adaptive_liquid_glass_picker`.
 */
internal class GlassPhotosPicker(private val context: Context) :
    PluginRegistry.ActivityResultListener {
    var activity: Activity? = null

    private var pending: MethodChannel.Result? = null
    private var pendingMax = 1
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun pick(maxSelection: Int, filter: String, result: MethodChannel.Result) {
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
        pending = result
        pendingMax = maxSelection
        try {
            host.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.error("no_picker", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Any>())
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
        // The document picker has no selection limit.
        if (pendingMax > 0 && uris.size > pendingMax) uris = uris.take(pendingMax)
        io.execute {
            try {
                val items = uris.map { copy(it) }
                main.post { result.success(items) }
            } catch (e: Exception) {
                main.post { result.error("load_failed", e.message, null) }
            }
        }
        return true
    }

    private fun copy(uri: Uri): Map<String, Any?> {
        val resolver = context.contentResolver
        val mime = resolver.getType(uri)
        val ext = mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        val dir = File(context.cacheDir, "adaptive_liquid_glass_picker").apply { mkdirs() }
        val dest = File(dir, UUID.randomUUID().toString() + (ext?.let { ".$it" } ?: ""))
        val input = resolver.openInputStream(uri)
            ?: throw IllegalStateException("Cannot open $uri")
        input.use { src -> dest.outputStream().use { src.copyTo(it) } }
        val isVideo = mime?.startsWith("video/") == true
        val item = mutableMapOf<String, Any?>(
            "path" to dest.absolutePath,
            "isVideo" to isVideo,
            "mimeType" to mime,
        )
        if (!isVideo) {
            // The header only, no decode.
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(dest.absolutePath, bounds)
            if (bounds.outWidth > 0 && bounds.outHeight > 0) {
                item["width"] = bounds.outWidth
                item["height"] = bounds.outHeight
            }
        }
        return item
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

    private companion object {
        /** Arbitrary, below 0xFFFF as `startActivityForResult` requires. */
        const val REQUEST_CODE = 0x4C47
    }
}
