package com.aymanomara.adaptive_liquid_glass

import android.app.Activity
import android.graphics.Canvas
import android.graphics.Bitmap
import android.graphics.Rect
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterImageView
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** Captures Flutter and ordinary native window views, composing a separate Flutter surface if needed. */
internal object GlassAppCapture {
    private val encoding = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun capture(activity: Activity?, messenger: BinaryMessenger?, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity == null || messenger == null) {
            result.success(null)
            return
        }
        val window = activity.window
        val flutter = descendants(window.decorView).filterIsInstance<FlutterView>().firstOrNull {
            it.attachedFlutterEngine?.dartExecutor?.let { executor ->
                executor === messenger || executor.binaryMessenger === messenger
            } == true
        }
        if (flutter == null || flutter.width <= 0 || flutter.height <= 0 ||
            !flutter.isAttachedToWindow || !flutter.isShown || !hasPlainAncestors(flutter)) {
            result.success(null)
            return
        }
        // Window PixelCopy includes hybrid/image/texture composition. A
        // FlutterSurfaceView needs a separate copy, composited in its real
        // order relative to that window to retain native overlay alpha.
        val inWindow = descendants(flutter).any {
            it.isShown && it.alpha > 0 && (it is FlutterImageView || it is FlutterTextureView)
        }
        val surface = if (inWindow) null else descendants(flutter)
            .filterIsInstance<FlutterSurfaceView>().singleOrNull { it.isShown && it.alpha == 1f }
        if (!inWindow && (surface == null || !surface.holder.surface.isValid ||
                surface.width != flutter.width || surface.height != flutter.height || !hasPlainAncestors(surface))) {
            result.success(null)
            return
        }
        val location = IntArray(2)
        flutter.getLocationInWindow(location)
        val rect = Rect(location[0], location[1], location[0] + flutter.width, location[1] + flutter.height)
        val surfaceRect = if (surface != null) {
            val surfaceLocation = IntArray(2)
            surface.getLocationInWindow(surfaceLocation)
            val bounds = Rect(
                surfaceLocation[0] - location[0], surfaceLocation[1] - location[1],
                surfaceLocation[0] - location[0] + surface.width,
                surfaceLocation[1] - location[1] + surface.height)
            val custom = bounds != Rect(0, 0, flutter.width, flutter.height)
            // Public ordering plus direct containment makes clipping/mapping
            // unambiguous. Older hosts retain the original full-size path.
            if (custom && (Build.VERSION.SDK_INT < 36 || surface.parent !== flutter)) {
                result.success(null)
                return
            }
            bounds
        } else null
        val visibleSurface = surface?.let {
            Rect().apply {
                if (!it.getLocalVisibleRect(this)) {
                    result.success(null)
                    return
                }
            }
        }
        val compositionOrder = if (Build.VERSION.SDK_INT >= 36) surface?.compositionOrder else null
        val surfaceParent = surface?.parent
        val bitmap = Bitmap.createBitmap(flutter.width, flutter.height, Bitmap.Config.ARGB_8888)
        try {
            PixelCopy.request(window, rect, bitmap, { status ->
                if (status != PixelCopy.SUCCESS) {
                    bitmap.recycle()
                    result.success(null)
                    return@request
                }
                if (surface != null) {
                    // API 36 exposes the real requested order. Older versions
                    // must prove that the window has a hole for a lower surface;
                    // otherwise keep the Flutter fallback instead of guessing.
                    if (compositionOrder == null && !hasTransparentHole(bitmap)) {
                        bitmap.recycle()
                        result.success(null)
                        return@request
                    }
                    val underlying = Bitmap.createBitmap(surfaceRect!!.width(), surfaceRect.height(), Bitmap.Config.ARGB_8888)
                    try {
                        PixelCopy.request(surface, underlying, { surfaceStatus ->
                            if (surfaceStatus != PixelCopy.SUCCESS) {
                                underlying.recycle()
                                bitmap.recycle()
                                result.success(null)
                            } else if (surface.parent !== surfaceParent || !sameGeometry(flutter, surface, rect, surfaceRect, visibleSurface!!) ||
                                (Build.VERSION.SDK_INT >= 36 && surface.compositionOrder != compositionOrder)) {
                                // Geometry or order changed between snapshots.
                                underlying.recycle()
                                bitmap.recycle()
                                result.success(null)
                            } else {
                                val paint = if (compositionOrder != null && compositionOrder >= 0) null
                                else Paint().apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_OVER) }
                                Canvas(bitmap).apply {
                                    clipRect(
                                        surfaceRect.left + visibleSurface.left,
                                        surfaceRect.top + visibleSurface.top,
                                        surfaceRect.left + visibleSurface.right,
                                        surfaceRect.top + visibleSurface.bottom)
                                    drawBitmap(underlying, surfaceRect.left.toFloat(), surfaceRect.top.toFloat(), paint)
                                }
                                underlying.recycle()
                                val scale = flutter.resources.displayMetrics.density.toDouble()
                                encode(bitmap, scale, result, surfaceRect.left / scale, surfaceRect.top / scale)
                            }
                        }, main)
                    } catch (_: IllegalArgumentException) {
                        underlying.recycle()
                        bitmap.recycle()
                        result.success(null)
                    }
                } else {
                    encode(bitmap, flutter.resources.displayMetrics.density.toDouble(), result)
                }
            }, main)
        } catch (_: IllegalArgumentException) {
            bitmap.recycle()
            result.success(null)
        }
    }

    private fun sameGeometry(flutter: FlutterView, surface: FlutterSurfaceView, viewRect: Rect, surfaceRect: Rect, visible: Rect): Boolean {
        if (!surface.isShown || !surface.isAttachedToWindow || !hasPlainAncestors(surface) ||
            surface.width != surfaceRect.width() || surface.height != surfaceRect.height() ||
            flutter.width != viewRect.width() || flutter.height != viewRect.height()) return false
        val point = IntArray(2)
        flutter.getLocationInWindow(point)
        if (point[0] != viewRect.left || point[1] != viewRect.top) return false
        surface.getLocationInWindow(point)
        val currentVisible = Rect()
        return point[0] == viewRect.left + surfaceRect.left && point[1] == viewRect.top + surfaceRect.top &&
            surface.getLocalVisibleRect(currentVisible) && currentVisible == visible
    }

    private fun hasPlainAncestors(view: View): Boolean {
        var current: View? = view
        while (current != null) {
            if (current.alpha != 1f || !current.matrix.isIdentity || current.clipBounds != null || current.clipToOutline) return false
            current = current.parent as? View
        }
        return true
    }

    private fun hasTransparentHole(bitmap: Bitmap): Boolean {
        // Sample evenly; missed tiny holes safely fall back to Flutter capture.
        for (row in 0 until 16) {
            for (column in 0 until 16) {
                val x = (column * (bitmap.width - 1)) / 15
                val y = (row * (bitmap.height - 1)) / 15
                if ((bitmap.getPixel(x, y) ushr 24) == 0) return true
            }
        }
        return false
    }

    private fun encode(bitmap: Bitmap, scale: Double, result: MethodChannel.Result,
        flutterOffsetX: Double = 0.0, flutterOffsetY: Double = 0.0) {
        encoding.execute {
            try {
                val bytes = ByteArrayOutputStream()
                if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)) {
                    main.post { result.success(null) }
                } else {
                    val response = mapOf(
                        "png" to bytes.toByteArray(),
                        "width" to bitmap.width,
                        "height" to bitmap.height,
                        "scale" to scale,
                        "originX" to 0.0,
                        "originY" to 0.0,
                        "flutterOffsetX" to flutterOffsetX,
                        "flutterOffsetY" to flutterOffsetY,
                    )
                    main.post { result.success(response) }
                }
            } catch (_: Exception) {
                main.post { result.success(null) }
            } finally {
                bitmap.recycle()
            }
        }
    }

    private fun descendants(view: View): Sequence<View> = sequence {
        yield(view)
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) yieldAll(descendants(view.getChildAt(i)))
        }
    }
}
