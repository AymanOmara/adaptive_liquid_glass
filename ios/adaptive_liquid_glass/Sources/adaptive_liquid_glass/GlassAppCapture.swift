import Flutter
import UIKit

/// Captures the app's Flutter view together with its embedded UIKit views.
enum GlassAppCapture {
  static func capture(view: UIView?, result: @escaping FlutterResult) {
    guard let view = view, let window = view.window,
          !view.bounds.isEmpty else {
      result(nil)
      return
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = window.screen.scale
    format.opaque = false
    var drawn = false
    let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
      drawn = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
    guard drawn else {
      result(nil)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      guard let png = image.pngData() else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      DispatchQueue.main.async {
        result([
          "png": FlutterStandardTypedData(bytes: png),
          "scale": image.scale,
          "width": image.cgImage?.width ?? 0,
          "height": image.cgImage?.height ?? 0,
          "originX": 0.0,
          "originY": 0.0,
        ])
      }
    }
  }
}
