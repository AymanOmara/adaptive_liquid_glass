package com.aymanomara.adaptive_liquid_glass

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Android side of `adaptive_liquid_glass`. Android draws Material 3 in
 * Dart; the only native work is the system photo picker behind
 * `pickGlassPhotos`. Every other method is not implemented, as before.
 */
class AdaptiveLiquidGlassPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var photosPicker: GlassPhotosPicker? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        photosPicker = GlassPhotosPicker(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, "adaptive_liquid_glass").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        photosPicker = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickPhotos" -> {
                val picker = photosPicker
                if (picker == null) {
                    result.error("no_activity", "The plugin is detached.", null)
                    return
                }
                picker.pick(
                    maxSelection = call.argument<Int>("maxSelection") ?: 1,
                    filter = call.argument<String>("filter") ?: "images",
                    result = result,
                )
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
