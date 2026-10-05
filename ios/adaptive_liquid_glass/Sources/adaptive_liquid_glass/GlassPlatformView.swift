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
  private let root: UIView
  private let channel: FlutterMethodChannel
  /// `SwiftUIGlass` on iOS 26+ (stored untyped for the availability check).
  private var glass: AnyObject?

  init(frame: CGRect, viewId: Int64, args: [String: Any], messenger: FlutterBinaryMessenger) {
    root = UIView(frame: frame)
    root.backgroundColor = .clear
    root.isUserInteractionEnabled = false
    channel = FlutterMethodChannel(
      name: "adaptive_liquid_glass/native_glass_\(viewId)", binaryMessenger: messenger)
    super.init()
    if #available(iOS 26.0, *) {
      glass = SwiftUIGlass(root: root)
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
    guard #available(iOS 26.0, *) else { return }
    (glass as? SwiftUIGlass)?.apply(args)
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
}

/// The group's glass, drawn the way the SwiftUI reference host draws it.
@available(iOS 26.0, *)
struct GlassHostView: View {
  @ObservedObject var model: GlassModel
  @Namespace private var unions

  var body: some View {
    GlassEffectContainer(spacing: model.spacing) {
      ZStack(alignment: .topLeading) {
        ForEach(model.shapes) { shapeView($0) }
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
