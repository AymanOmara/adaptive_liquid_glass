import Flutter
import UIKit

public class AdaptiveLiquidGlassPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  /// The open photo picker; one at a time.
  private var photosPicker: GlassPhotosPicker?
  private var clearingPhotos = false
  private var captureRegistrar: FlutterPluginRegistrar?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AdaptiveLiquidGlassPlugin()
    instance.captureRegistrar = registrar
    let method = FlutterMethodChannel(
      name: "adaptive_liquid_glass", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)
    let events = FlutterEventChannel(
      name: "adaptive_liquid_glass/reduce_transparency",
      binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.register(
      GlassNativeTabBarFactory(messenger: registrar.messenger()),
      withId: "adaptive_liquid_glass/native_tabs",
      // Public Flutter ABI value 2 is the synchronous hit-test policy. Dart
      // creates this view only when its matching framework API is available;
      // using the raw value keeps compilation compatible with older SDKs.
      gestureRecognizersBlockingPolicy: FlutterPlatformViewGestureRecognizersBlockingPolicy(rawValue: 2))
    registrar.register(
      GlassViewFactory(messenger: registrar.messenger()),
      withId: "adaptive_liquid_glass/native_glass")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    #if DEBUG
    case "debugNativeTabHosts":
      result(captureRegistrar?.viewController?.children.filter { $0 is UITabBarController }.count ?? 0)
    #endif
    case "getEnvironment":
      result([
        "iosMajorVersion": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      ])
    case "symbol":
      result(Self.symbol(call.arguments as? [String: Any] ?? [:]))
    case "captureApp":
      GlassAppCapture.capture(view: captureRegistrar?.viewController?.view, result: result)
    case "getSavedColors":
      DispatchQueue.global(qos: .utility).async {
        do {
          let colors = try GlassSavedColors.load()
          DispatchQueue.main.async { result(colors) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "palette_read_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    case "setSavedColors":
      guard let colors = call.arguments as? [Int64],
            colors.allSatisfy({ $0 >= 0 && $0 <= 0xFFFFFFFF }) else {
        result(FlutterError(code: "invalid_palette", message: "Expected ARGB colour integers.", details: nil))
        return
      }
      DispatchQueue.global(qos: .utility).async {
        do {
          try GlassSavedColors.save(colors)
          DispatchQueue.main.async { result(nil) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "palette_write_failed", message: error.localizedDescription, details: nil))
          }
        }
      }
    case "pickPhotos":
      if photosPicker != nil || clearingPhotos {
        result(FlutterError(
          code: "already_active", message: "Photo picking or cleanup is already active.", details: nil))
        return
      }
      let importName = (call.arguments as? [String: Any])?["importChannel"] as? String
      let imports = importName.flatMap { name in
        captureRegistrar.map { FlutterMethodChannel(name: name, binaryMessenger: $0.messenger()) }
      }
      let onEvent: ((String, [String: Any]) -> Void)? = imports.map { channel in
        { method, args in channel.invokeMethod(method, arguments: args) }
      }
      // Registered before the picker shows, so a cancel while it is open is honoured.
      photosPicker = GlassPhotosPicker.present(
        arguments: call.arguments, result: result, importName: importName, onEvent: onEvent) {
        [weak self] in self?.photosPicker = nil
      }
    case "cancelPhotoImport":
      // A stale or unknown name does nothing.
      let name = (call.arguments as? [String: Any])?["importChannel"] as? String
      if let picker = photosPicker, name != nil, picker.importName == name { picker.cancel() }
      result(nil)
    case "clearPickedPhotos":
      guard photosPicker == nil && !clearingPhotos else {
        result(FlutterError(
          code: "already_active",
          message: "Wait for the photo import, or call controller.cancel(), before clearing picked files.",
          details: nil))
        return
      }
      clearingPhotos = true
      DispatchQueue.global(qos: .utility).async {
        let failure: FlutterError?
        do {
          try GlassPhotosPicker.clearCopies()
          failure = nil
        } catch {
          failure = FlutterError(
            code: "cleanup_failed", message: error.localizedDescription, details: nil)
        }
        DispatchQueue.main.async {
          self.clearingPhotos = false
          result(failure)
        }
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
