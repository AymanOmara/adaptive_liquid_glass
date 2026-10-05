import Flutter
import SwiftUI
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

/// SwiftUI's own Liquid Glass for a Flutter `GlassGroup`: a
/// `UIHostingController` whose root is one `GlassEffectContainer` holding a
/// `.glassEffect(_:in:)` view per shape. Shapes arrive in view-local points
/// through `setShapes`; Flutter drives the geometry every frame, so updates
/// apply without animation. Below iOS 26 the view stays empty (Dart never
/// asks for it there).
final class GlassPlatformView: NSObject, FlutterPlatformView {
  private let root: GlassRootView
  private let channel: FlutterMethodChannel
  /// `SwiftUIGlass` on iOS 26+ (stored untyped for the availability check).
  private var glass: AnyObject?

  init(frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    root = GlassRootView(frame: frame)
    root.backgroundColor = .clear
    root.isUserInteractionEnabled = false
    channel = FlutterMethodChannel(
      name: "adaptive_liquid_glass/native_glass_\(viewId)", binaryMessenger: messenger)
    super.init()
    if #available(iOS 26.0, *) {
      let g = SwiftUIGlass(root: root)
      root.onSettled = { [weak g] in g?.show() }
      glass = g
    }
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setShapes":
        guard let a = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad-args", message: "setShapes needs a map", details: nil))
          return
        }
        self?.apply(a)
        result(nil)
      case "debugState":
        // For the example's integration tests: what SwiftUI is drawing.
        result(self?.debugState())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    apply(args)
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { root }

  private func apply(_ args: [String: Any]) {
    guard #available(iOS 26.0, *) else { return }
    (glass as? SwiftUIGlass)?.apply(args)
  }

  private func debugState() -> [String: Any] {
    var state: [String: Any] = [
      "bounds": [root.bounds.width, root.bounds.height],
      "interactive": root.isUserInteractionEnabled,
    ]
    if #available(iOS 26.0, *), let g = glass as? SwiftUIGlass {
      state.merge(g.debugState()) { $1 }
    }
    return state
  }
}

/// One shape of a `setShapes` payload.
@available(iOS 26.0, *)
struct GlassSpec: Identifiable, Equatable {
  let id: Int
  let frame: CGRect
  let radius: Double
  let capsule: Bool
  let clear: Bool
  let tint: Int?
  let interactive: Bool
  /// Shapes with the same union index merge (`glassEffectUnion`).
  let union: Int?

  init(id: Int, _ s: [String: Any]) {
    self.id = id
    frame = CGRect(
      x: s["x"] as? Double ?? 0, y: s["y"] as? Double ?? 0,
      width: s["w"] as? Double ?? 0, height: s["h"] as? Double ?? 0)
    radius = s["radius"] as? Double ?? 0
    capsule = s["capsule"] as? Bool ?? false
    clear = (s["variant"] as? Int ?? 0) == 1
    tint = s["tint"] as? Int
    interactive = s["interactive"] as? Bool ?? false
    union = s["union"] as? Int
  }
}

@available(iOS 26.0, *)
final class GlassModel: ObservableObject {
  @Published var spacing: Double = 0
  @Published var dark = false
  @Published var shapes: [GlassSpec] = []
  /// False until the view has been on screen for a few frames.
  @Published var visible = false
}

/// The group's glass, drawn the way the SwiftUI reference host draws it.
@available(iOS 26.0, *)
struct GlassHostView: View {
  @ObservedObject var model: GlassModel
  @Namespace private var unions

  var body: some View {
    GlassEffectContainer(spacing: model.spacing) {
      ZStack(alignment: .topLeading) {
        if model.visible {
          ForEach(model.shapes) { shapeView($0) }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .ignoresSafeArea()
    // The Flutter side's platform brightness, like the shader path; UIKit
    // traits would follow the system instead of the app.
    .environment(\.colorScheme, model.dark ? .dark : .light)
  }

  @ViewBuilder private func shapeView(_ s: GlassSpec) -> some View {
    let base = Color.clear
      .frame(width: s.frame.width, height: s.frame.height)
      .glassEffect(glass(s), in: shape(s))
    Group {
      if let u = s.union {
        base.glassEffectUnion(id: u, namespace: unions)
      } else {
        base
      }
    }
    .position(x: s.frame.midX, y: s.frame.midY)
  }

  private func glass(_ s: GlassSpec) -> Glass {
    var g: Glass = s.clear ? .clear : .regular
    if let t = s.tint { g = g.tint(Color(uiColor: UIColor(argb: t))) }
    if s.interactive { g = g.interactive() }
    return g
  }

  private func shape(_ s: GlassSpec) -> AnyShape {
    s.capsule
      ? AnyShape(Capsule())
      : AnyShape(RoundedRectangle(cornerRadius: s.radius, style: .continuous))
  }
}

/// Hosts [GlassHostView] in a plain view: clear, not interactive, no safe
/// area and no intrinsic sizing, so frames are exactly the pushed points.
@available(iOS 26.0, *)
final class SwiftUIGlass {
  private let model = GlassModel()
  private let host: UIHostingController<GlassHostView>

  init(root: UIView) {
    host = UIHostingController(rootView: GlassHostView(model: model))
    host.sizingOptions = []
    host.safeAreaRegions = []
    host.view.backgroundColor = .clear
    host.view.isUserInteractionEnabled = false
    host.view.frame = root.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    root.addSubview(host.view)
  }

  func apply(_ args: [String: Any]) {
    let shapes = (args["shapes"] as? [[String: Any]] ?? []).enumerated().map {
      GlassSpec(id: $0.offset, $0.element)
    }
    let spacing = args["spacing"] as? Double ?? 0
    let dark = args["dark"] as? Bool ?? false
    // Flutter animates; SwiftUI must not add its own transitions on top.
    var t = Transaction(animation: nil)
    t.disablesAnimations = true
    withTransaction(t) {
      if model.spacing != spacing { model.spacing = spacing }
      if model.dark != dark { model.dark = dark }
      if model.shapes != shapes { model.shapes = shapes }
    }
  }

  /// Starts drawing the glass (see `GlassRootView.onSettled`).
  func show() {
    var t = Transaction(animation: nil)
    t.disablesAnimations = true
    withTransaction(t) { model.visible = true }
  }

  func debugState() -> [String: Any] {
    let v = host.view!
    let insets = v.safeAreaInsets
    return [
      "hosted": v.superview != nil,
      "hostFrame": [v.frame.minX, v.frame.minY, v.frame.width, v.frame.height],
      "safeArea": [insets.top, insets.left, insets.bottom, insets.right],
      "clearBackground": v.backgroundColor == .clear,
      "spacing": model.spacing,
      "dark": model.dark,
      "visible": model.visible,
      "shapes": model.shapes.map {
        [$0.frame.minX, $0.frame.minY, $0.frame.width, $0.frame.height]
      },
      "unions": model.shapes.map { $0.union ?? -1 },
    ]
  }
}

/// The platform view's root. Reports once it has been in a window for a
/// few display frames: glass that first draws before Flutter's content
/// beneath it is on screen can settle on the wrong (light) look for good,
/// even under a dark colour scheme, so the glass waits for that.
final class GlassRootView: UIView {
  /// Display frames to wait after entering a window.
  static let settleFrames = 3

  var onSettled: (() -> Void)?
  private var link: CADisplayLink?
  private var frames = 0

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil, onSettled != nil, link == nil else { return }
    let l = CADisplayLink(target: self, selector: #selector(tick))
    l.add(to: .main, forMode: .common)
    link = l
  }

  @objc private func tick() {
    frames += 1
    guard frames >= Self.settleFrames else { return }
    link?.invalidate()
    onSettled?()
    onSettled = nil
  }

  deinit { link?.invalidate() }
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
