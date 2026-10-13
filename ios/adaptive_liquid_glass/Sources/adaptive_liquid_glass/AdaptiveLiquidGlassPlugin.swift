import Flutter
import UIKit

public class AdaptiveLiquidGlassPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  /// The open photo picker; one at a time.
  private var photosPicker: GlassPhotosPicker?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AdaptiveLiquidGlassPlugin()
    let method = FlutterMethodChannel(
      name: "adaptive_liquid_glass", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)
    let events = FlutterEventChannel(
      name: "adaptive_liquid_glass/reduce_transparency",
      binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.register(
      GlassViewFactory(messenger: registrar.messenger()),
      withId: "adaptive_liquid_glass/native_glass")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getEnvironment":
      result([
        "iosMajorVersion": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      ])
    case "pickPhotos":
      if photosPicker != nil {
        result(FlutterError(
          code: "already_active", message: "A photo picker is already open.", details: nil))
        return
      }
      photosPicker = GlassPhotosPicker.present(arguments: call.arguments, result: result) {
        [weak self] in self?.photosPicker = nil
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    NotificationCenter.default.addObserver(
      self, selector: #selector(reduceTransparencyChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self, name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
    sink = nil
    return nil
  }

  @objc private func reduceTransparencyChanged() {
    sink?(UIAccessibility.isReduceTransparencyEnabled)
  }
}
