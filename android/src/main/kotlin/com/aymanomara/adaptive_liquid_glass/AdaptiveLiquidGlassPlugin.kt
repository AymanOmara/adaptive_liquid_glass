package com.aymanomara.adaptive_liquid_glass

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

/**
 * The Android side of `adaptive_liquid_glass`. Android draws Material 3 in
 * Dart; native work hosts the system photo picker and stores the colour palette.
 */
class AdaptiveLiquidGlassPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var photosPicker: GlassPhotosPicker? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var savedColors: GlassSavedColors? = null
    private var storage = Executors.newSingleThreadExecutor()
    private var captureMessenger: BinaryMessenger? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        captureMessenger = binding.binaryMessenger
        photosPicker = GlassPhotosPicker(binding.applicationContext)
        savedColors = GlassSavedColors(binding.applicationContext)
        if (storage.isShutdown) storage = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, "adaptive_liquid_glass").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        photosPicker = null
        savedColors = null
        storage.shutdown()
        captureMessenger = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "captureApp" -> GlassAppCapture.capture(activityBinding?.activity, captureMessenger, result)
            "getSavedColors", "setSavedColors" -> {
                val palette = savedColors
                if (palette == null) {
                    result.error("palette_unavailable", "The plugin is detached.", null)
                    return
                }
                val colors = if (call.method == "setSavedColors") {
                    val values = call.arguments as? List<*>
                    if (values == null || values.any {
                        (it !is Int && it !is Long) || (it as Number).toLong() !in 0L..0xFFFFFFFFL
                    }) {
                        result.error("invalid_palette", "Expected ARGB colour integers.", null)
                        return
                    }
                    values.map { (it as Number).toLong() }
                } else null
                storage.execute {
                    try {
                        val response = if (colors == null) palette.load() else {
                            palette.save(colors)
                            null
                        }
                        Handler(Looper.getMainLooper()).post { result.success(response) }
                    } catch (error: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("palette_storage_failed", error.message, null)
                        }
                    }
                }
            }
            "pickPhotos" -> {
                val picker = photosPicker
                if (picker == null) {
                    result.error("no_activity", "The plugin is detached.", null)
                    return
                }
                val imports = call.argument<String>("importChannel")?.let { name ->
                    captureMessenger?.let { MethodChannel(it, name) }
                }
                picker.pick(
                    maxSelection = call.argument<Int>("maxSelection") ?: 1,
                    filter = call.argument<String>("filter") ?: "images",
                    options = GlassPhotosPicker.Options(
                        maxWidth = call.argument<Int>("maxWidth"),
                        maxHeight = call.argument<Int>("maxHeight"),
                        quality = call.argument<Int>("imageQuality"),
                        compatible = call.argument<Boolean>("compatibleFormat") ?: false,
                    ),
                    result = result,
                    importChannel = call.argument<String>("importChannel"),
                    onEvent = imports?.let { events ->
                        { method, args -> events.invokeMethod(method, args) }
                    },
                )
            }
            "cancelPhotoImport" -> {
                call.argument<String>("importChannel")?.let { photosPicker?.cancel(it) }
                result.success(null)
            }
            "clearPickedPhotos" -> {
                val picker = photosPicker
                if (picker == null) {
                    result.error("no_activity", "The plugin is detached.", null)
                    return
                }
                picker.clearCopies(result)
            }
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        photosPicker?.let {
            it.activity = binding.activity
            binding.addActivityResultListener(it)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        photosPicker?.let {
            activityBinding?.removeActivityResultListener(it)
            it.activity = null
        }
        activityBinding = null
    }
}
