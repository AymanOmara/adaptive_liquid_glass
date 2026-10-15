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
      root.onWindowChange = { [weak g] in g?.windowChanged() }
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
        // Test hook, not API: the example's integration tests ask what
        // SwiftUI is drawing. The package's Dart code never calls it.
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
      "settled": root.settledCount,
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
  /// System fills drawn as the glass's own content (vibrant, as iOS 26's
  /// tab bar pill), in points relative to the shape.
  let fills: [GlassFill]
  /// Opacity of the Flutter ancestors between the shape and a batch's view
  /// (`GlassBatch`); 1 when Dart sends none.
  let opacity: Double

  /// [fallbackId] (the payload index) is used only when Dart sends no `id`.
  init(fallbackId: Int, _ s: [String: Any]) {
    id = s["id"] as? Int ?? fallbackId
    frame = CGRect(
      x: s["x"] as? Double ?? 0, y: s["y"] as? Double ?? 0,
      width: s["w"] as? Double ?? 0, height: s["h"] as? Double ?? 0)
    radius = s["radius"] as? Double ?? 0
    capsule = s["capsule"] as? Bool ?? false
    clear = (s["variant"] as? Int ?? 0) == 1
    tint = s["tint"] as? Int
    interactive = s["interactive"] as? Bool ?? false
    union = s["union"] as? Int
    opacity = s["opacity"] as? Double ?? 1
    let f = s["fills"] as? [Double] ?? []
    fills = stride(from: 0, to: f.count - 5, by: 6).enumerated().map { i, k in
      GlassFill(
        id: i,
        frame: CGRect(x: f[k], y: f[k + 1], width: f[k + 2], height: f[k + 3]),
        opacity: f[k + 4], style: Int(f[k + 5]))
    }
  }
}

/// A capsule of a system fill inside a glass shape (`GlassContentFill`).
@available(iOS 26.0, *)
struct GlassFill: Identifiable, Equatable {
  let id: Int
  let frame: CGRect
  let opacity: Double
  /// 0 `.fill`, 1 `.fill.secondary`, 2 `.fill.tertiary`, 3 `.fill.quaternary`,
  /// 4 white added (`.plusLighter`), 5 black subtracted (`.plusDarker`),
  /// 6 a 1-pt white ring along the capsule, added.
  let style: Int

  var shapeStyle: AnyShapeStyle {
    switch style {
    case 0: AnyShapeStyle(.fill)
    case 1: AnyShapeStyle(.fill.secondary)
    case 3: AnyShapeStyle(.fill.quaternary)
    case 4: AnyShapeStyle(Color.white)
    case 5: AnyShapeStyle(Color.black)
    default: AnyShapeStyle(.fill.tertiary)
    }
  }

  var blendMode: BlendMode {
    switch style {
    case 4, 6: .plusLighter
    case 5: .plusDarker
    default: .normal
    }
  }
}

@available(iOS 26.0, *)
final class GlassModel: ObservableObject {
  @Published var spacing: Double = 0
  @Published var dark = false
  @Published var shapes: [GlassSpec] = []
  /// False until the view has been on screen for a few frames.
  @Published var visible = false
  /// Bumped when `dark` changes after the first draw: the container is
  /// rebuilt (`.id`), since Apple's glass keeps the look it first drew with.
  @Published var generation = 0
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
    .id(model.generation)
    .ignoresSafeArea()
    // The Flutter side's platform brightness, like the shader path; UIKit
    // traits would follow the system instead of the app.
    .environment(\.colorScheme, model.dark ? .dark : .light)
  }

  @ViewBuilder private func shapeView(_ s: GlassSpec) -> some View {
    let base = ZStack(alignment: .topLeading) {
      Color.clear
      ForEach(s.fills) { f in
        fillShape(f)
          .opacity(f.opacity)
          .blendMode(f.blendMode)
          .frame(width: f.frame.width, height: f.frame.height)
          .offset(x: f.frame.minX, y: f.frame.minY)
      }
    }
      .frame(width: s.frame.width, height: s.frame.height)
      // Fills belong to the glass: none reaches past its outline.
      .clipShape(shape(s))
      .glassEffect(glass(s), in: shape(s))
    let united = Group {
      if let u = s.union {
        base.glassEffectUnion(id: u, namespace: unions)
      } else {
        base
      }
    }
    // Only batched glass under a Flutter fade carries an opacity; other
    // shapes take no modifier at all.
    Group {
      if s.opacity < 1 {
        united.opacity(s.opacity)
      } else {
        united
      }
    }
    .position(x: s.frame.midX, y: s.frame.midY)
  }

  @ViewBuilder private func fillShape(_ f: GlassFill) -> some View {
    if f.style == 6 {
      Capsule().strokeBorder(Color.white, lineWidth: 0.67)
    } else {
      Capsule().fill(f.shapeStyle)
    }
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
  private weak var root: GlassRootView?
  /// False until the creation payload has been applied.
  private var configured = false

  init(root: GlassRootView) {
    self.root = root
    host = Self.makeHost(model, in: root)
  }

  private static func makeHost(
    _ model: GlassModel, in root: UIView
  ) -> UIHostingController<GlassHostView> {
    let host = UIHostingController(rootView: GlassHostView(model: model))
    host.sizingOptions = []
    host.safeAreaRegions = []
    host.view.backgroundColor = .clear
    host.view.isUserInteractionEnabled = false
    host.view.frame = root.bounds
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    root.addSubview(host.view)
    return host
  }

  func apply(_ args: [String: Any]) {
    let shapes = (args["shapes"] as? [[String: Any]] ?? []).enumerated().map {
      GlassSpec(fallbackId: $0.offset, $0.element)
    }
    let spacing = args["spacing"] as? Double ?? 0
    let dark = args["dark"] as? Bool ?? false
    let rethemed = configured && model.dark != dark
    configured = true
    // UIKit traits under the host follow the app's brightness too, not the
    // system's (the SwiftUI colour scheme alone leaves them on the system).
    host.overrideUserInterfaceStyle = dark ? .dark : .light
    // Flutter animates; SwiftUI must not add its own transitions on top.
    var t = Transaction(animation: nil)
    t.disablesAnimations = true
    withTransaction(t) {
      if model.spacing != spacing { model.spacing = spacing }
      if model.dark != dark { model.dark = dark }
      if model.shapes != shapes { model.shapes = shapes }
      if rethemed {
        // Glass already drawn keeps its old look: hide it, rebuild the
        // container and draw again once the re-themed Flutter content
        // beneath has been on screen for the settle frames.
        model.generation += 1
        model.visible = false
      }
    }
    if rethemed { root?.rearm() }
  }

  /// Flutter can release the platform view while it is still in a window;
  /// never leave the hosting controller behind in the Flutter view
  /// controller then.
  deinit {
    if host.parent != nil {
      host.willMove(toParent: nil)
      host.removeFromParent()
    }
  }

  /// Contains the hosting controller in the view controller that shows the
  /// platform view (found through the responder chain), so SwiftUI gets
  /// appearance and trait updates; released again when the view leaves.
  func windowChanged() {
    guard let root else { return }
    if root.window != nil {
      guard host.parent == nil, let parent = root.owningViewController else { return }
      parent.addChild(host)
      host.didMove(toParent: parent)
    } else if host.parent != nil {
      host.willMove(toParent: nil)
      host.removeFromParent()
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
      "generation": model.generation,
      "contained": host.parent != nil,
      "style": host.overrideUserInterfaceStyle == .dark ? "dark" : "light",
      "ids": model.shapes.map { $0.id },
      "shapes": model.shapes.map {
        [$0.frame.minX, $0.frame.minY, $0.frame.width, $0.frame.height]
      },
      "unions": model.shapes.map { $0.union ?? -1 },
    ]
  }
}

/// The platform view's root. Reports once it has been in a window for a
/// few display frames, and again after each `rearm`: glass that first draws
/// before Flutter's content beneath it is on screen can settle on the wrong
/// (light) look for good, even under a dark colour scheme, so the glass
/// waits for that.
final class GlassRootView: UIView {
  /// Display frames to wait after entering a window.
  static let settleFrames = 3

  /// Called each time the wait completes (first draw, and after `rearm`).
  var onSettled: (() -> Void)?
  var onWindowChange: (() -> Void)?
  private var link: CADisplayLink?
  private var frames = 0
  private var armed = true
  /// How many times the wait has completed (for `debugState`).
  private(set) var settledCount = 0

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onWindowChange?()
    start()
  }

  /// Waits the settle frames again (after a brightness change).
  func rearm() {
    armed = true
    link?.invalidate()
    link = nil
    start()
  }

  private func start() {
    guard armed, window != nil, onSettled != nil, link == nil else { return }
    frames = 0
    let l = CADisplayLink(target: self, selector: #selector(tick))
    l.add(to: .main, forMode: .common)
    link = l
  }

  @objc private func tick() {
    frames += 1
    guard frames >= Self.settleFrames else { return }
    link?.invalidate()
    link = nil
    armed = false
    settledCount += 1
    onSettled?()
  }

  deinit { link?.invalidate() }
}

private extension UIView {
  /// The nearest view controller up the responder chain.
  var owningViewController: UIViewController? {
    var r: UIResponder? = next
    while let current = r {
      if let vc = current as? UIViewController { return vc }
      r = current.next
    }
    return nil
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
