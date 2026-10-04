import Flutter
import UIKit

/// Creates `adaptive_liquid_glass/native_glass` platform views.
final class GlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    GlassPlatformView(
      frame: frame, viewId: viewId,
      args: args as? [String: Any] ?? [:], messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// Apple's glass (`UIGlassContainerEffect` holding one `UIGlassEffect` view
/// per shape) for a Flutter `GlassGroup`. Shapes arrive in view-local points
/// through `setShapes`.
final class GlassPlatformView: NSObject, FlutterPlatformView {
  private let root: UIView
  private let channel: FlutterMethodChannel
  private var container: UIVisualEffectView?
  private var glassViews: [UIVisualEffectView] = []
  private var lastStyles: [String] = []
  private var lastSpacing: Double?

  init(frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    root = UIView(frame: frame)
    root.backgroundColor = .clear
    root.isUserInteractionEnabled = false
    channel = FlutterMethodChannel(
      name: "adaptive_liquid_glass/native_glass_\(viewId)", binaryMessenger: messenger)
    super.init()
    if #available(iOS 26.0, *) {
      let c = UIVisualEffectView(effect: UIGlassContainerEffect())
      c.frame = root.bounds
      c.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      root.addSubview(c)
      container = c
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setShapes", let a = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.apply(a)
      result(nil)
    }
    apply(args)
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { root }

  private func apply(_ args: [String: Any]) {
    guard #available(iOS 26.0, *), let container else { return }
    let spacing = args["spacing"] as? Double ?? 0
    // Replacing the container effect restarts UIKit's merging; do it only
    // when the spacing actually changes.
    if spacing != lastSpacing {
      let effect = UIGlassContainerEffect()
      effect.spacing = spacing
      container.effect = effect
      lastSpacing = spacing
    }

    let shapes = args["shapes"] as? [[String: Any]] ?? []
    while glassViews.count < shapes.count {
      let v = UIVisualEffectView(effect: nil)
      container.contentView.addSubview(v)
      glassViews.append(v)
      lastStyles.append("")
    }
    while glassViews.count > shapes.count {
      glassViews.removeLast().removeFromSuperview()
      lastStyles.removeLast()
    }
    for (i, s) in shapes.enumerated() {
      let v = glassViews[i]
      let variant = s["variant"] as? Int ?? 0
      let tint = s["tint"] as? Int
      let interactive = s["interactive"] as? Bool ?? false
      let style = "\(variant)|\(tint ?? -1)|\(interactive)"
      if style != lastStyles[i] {
        let g = UIGlassEffect(style: variant == 1 ? .clear : .regular)
        if let tint { g.tintColor = UIColor(argb: tint) }
        g.isInteractive = interactive
        v.effect = g
        lastStyles[i] = style
      }
      v.frame = CGRect(
        x: s["x"] as? Double ?? 0, y: s["y"] as? Double ?? 0,
        width: s["w"] as? Double ?? 0, height: s["h"] as? Double ?? 0)
      if s["capsule"] as? Bool == true {
        v.cornerConfiguration = .capsule()
      } else {
        v.cornerConfiguration = .corners(radius: .fixed(s["radius"] as? Double ?? 0))
      }
    }
  }
}

private extension UIColor {
  convenience init(argb: Int) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }
}
