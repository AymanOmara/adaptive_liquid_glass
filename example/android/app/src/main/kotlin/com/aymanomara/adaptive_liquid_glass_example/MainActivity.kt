package com.aymanomara.adaptive_liquid_glass_example

import android.content.pm.ApplicationInfo
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        // Real native pixels for the eyedropper integration test. Never expose
        // the fixture in a release example, and keep it absent unless requested.
        if ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0) return
        var overlay: View? = null
        var originalSurfaceLayout: FrameLayout.LayoutParams? = null
        var originalBackground: android.graphics.drawable.Drawable? = null
        MethodChannel(engine.dartExecutor.binaryMessenger, "example/capture_test")
            .setMethodCallHandler { call, result ->
                fun flutterView(view: View): FlutterView? {
                    if (view is FlutterView) return view
                    if (view is ViewGroup) for (i in 0 until view.childCount) {
                        flutterView(view.getChildAt(i))?.let { return it }
                    }
                    return null
                }
                when (call.method) {
                    "geometry" -> {
                        val flutter = flutterView(window.decorView)
                        val surface = flutter?.let { parent ->
                            (0 until parent.childCount).map { parent.getChildAt(it) }
                                .filterIsInstance<FlutterSurfaceView>().singleOrNull()
                        }
                        result.success(mapOf(
                            "view" to "${flutter?.width}x${flutter?.height}",
                            "surface" to "${surface?.width}x${surface?.height}",
                            "alpha" to surface?.alpha,
                            "matrix" to surface?.matrix?.toShortString(),
                            "visible" to surface?.isShown,
                        ))
                    }
                    "surfaceGeometry" -> {
                        val flutter = flutterView(window.decorView)
                        val surface = flutter?.let { parent ->
                            (0 until parent.childCount).map { parent.getChildAt(it) }
                                .filterIsInstance<FlutterSurfaceView>().singleOrNull()
                        }
                        if (surface == null || flutter == null) {
                            result.error("no_surface", "Expected a direct Flutter surface", null)
                            return@setMethodCallHandler
                        }
                        if (call.arguments == null) {
                            originalSurfaceLayout?.let {
                                surface.layoutParams = it
                                flutter.background = originalBackground
                            }
                            originalSurfaceLayout = null
                        } else {
                            if (originalSurfaceLayout == null) {
                                originalSurfaceLayout = FrameLayout.LayoutParams(surface.layoutParams as FrameLayout.LayoutParams)
                                originalBackground = flutter.background
                            }
                            val density = resources.displayMetrics.density
                            val left = call.argument<Int>("left") ?: 40
                            val resize = call.argument<Boolean>("resize") ?: false
                            flutter.setBackgroundColor(0xFFFF00FF.toInt())
                            surface.layoutParams = FrameLayout.LayoutParams(
                                if (resize) (250 * density).toInt() else flutter.width,
                                if (resize) (500 * density).toInt() else flutter.height,
                            ).apply {
                                leftMargin = (left * density).toInt()
                                topMargin = (80 * density).toInt()
                            }
                        }
                        result.success(null)
                    }
                    "sdk" -> result.success(android.os.Build.VERSION.SDK_INT)
                    "imageComposition" -> {
                        val flutter = flutterView(window.decorView)
                        if (call.arguments == true) flutter?.convertToImageView()
                        else flutter?.revertImageView { }
                        result.success(null)
                    }
                    "imageFrame" -> result.success(flutterView(window.decorView)?.acquireLatestImageViewFrame())
                    "coverWindow" -> {
                        (overlay?.parent as? ViewGroup)?.removeView(overlay)
                        overlay = View(this).apply { setBackgroundColor(0xFF00FF00.toInt()) }
                        addContentView(overlay, FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
                        result.success(null)
                    }
                    "overlay" -> {
                        (overlay?.parent as? ViewGroup)?.removeView(overlay)
                        overlay = View(this).apply { setBackgroundColor(0x8000FF00.toInt()) }
                        val density = resources.displayMetrics.density
                        val params = FrameLayout.LayoutParams((120 * density).toInt(), (100 * density).toInt())
                        params.leftMargin = (50 * density).toInt()
                        params.topMargin = (300 * density).toInt()
                        addContentView(overlay, params)
                        result.success(null)
                    }
                    "surfaceOnTop" -> {
                        fun surfaces(view: View): List<FlutterSurfaceView> =
                            if (view is FlutterSurfaceView) listOf(view)
                            else if (view is ViewGroup) (0 until view.childCount).flatMap { surfaces(view.getChildAt(it)) }
                            else emptyList()
                        surfaces(window.decorView).forEach { it.setZOrderOnTop(call.arguments == true) }
                        result.success(null)
                    }
                    "clear" -> {
                        (overlay?.parent as? ViewGroup)?.removeView(overlay)
                        overlay = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
