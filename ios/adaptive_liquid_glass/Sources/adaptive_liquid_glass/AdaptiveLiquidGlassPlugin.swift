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
    case "symbol":
      result(Self.symbol(call.arguments as? [String: Any] ?? [:]))
    case "pickPhotos":
      if photosPicker != nil {
        result(FlutterError(
          code: "already_active", message: "A photo picker is already open.", details: nil))
        return
      }
      photosPicker = GlassPhotosPicker.present(arguments: call.arguments, result: result) {
        [weak self] in self?.photosPicker = nil
      }
    case "clearPickedPhotos":
      DispatchQueue.global(qos: .utility).async {
        GlassPhotosPicker.clearCopies()
        DispatchQueue.main.async { result(nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Renders the system symbol `name` white on transparent at the screen's
  /// scale, laid out in its own frame (UIKit's alignment rect kept, so it
  /// centres as a tab bar's symbol does). Nil when there is no such symbol.
  static func symbol(_ args: [String: Any]) -> Any? {
    guard let name = args["name"] as? String else { return nil }
    let size = CGFloat(args["pointSize"] as? Double ?? 17)
    let weights: [String: UIImage.SymbolWeight] = [
      "ultraLight": .ultraLight, "thin": .thin, "light": .light,
      "regular": .regular, "medium": .medium, "semibold": .semibold,
      "bold": .bold, "heavy": .heavy, "black": .black,
    ]
    let scales: [String: UIImage.SymbolScale] = [
      "small": .small, "medium": .medium, "large": .large,
    ]
    let config = UIImage.SymbolConfiguration(
      pointSize: size,
      weight: weights[args["weight"] as? String ?? "regular"] ?? .regular,
      scale: scales[args["scale"] as? String ?? "medium"] ?? .medium)
    guard
      let image = UIImage(systemName: name, withConfiguration: config)?
        .withTintColor(.white, renderingMode: .alwaysOriginal)
    else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = CGFloat(args["scale_px"] as? Double ?? Double(UIScreen.main.scale))
    let png = UIGraphicsImageRenderer(size: image.size, format: format).pngData { _ in
      image.draw(at: .zero)
    }
    let inset = image.alignmentRectInsets
    return [
      "png": FlutterStandardTypedData(bytes: png),
      "width": image.size.width,
      "height": image.size.height,
      "baseline": image.baselineOffsetFromBottom ?? 0,
      "alignTop": inset.top, "alignLeft": inset.left,
      "alignBottom": inset.bottom, "alignRight": inset.right,
    ]
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
