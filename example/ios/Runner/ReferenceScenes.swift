import Flutter
import SwiftUI
import UIKit

struct RefShape: Decodable {
  let x, y, w, h, radius: Double
  let shape, variant: String
  let tint: String?
}

struct RefScene: Decodable {
  let id, background, brightness: String
  let spacing: Double?
  let shapes: [RefShape]
}

struct RefFile: Decodable { let scenes: [RefScene] }

enum ReferenceAssets {
  static func path(_ asset: String) -> String? {
    let key = FlutterDartProject.lookupKey(forAsset: asset)
    return Bundle.main.path(forResource: key, ofType: nil)
  }

  /// `-sceneFile <asset>` picks another scene list (for example
  /// `assets/measure.json`); the default is the fidelity matrix.
  static func scene(id: String) -> RefScene? {
    guard let p = path(LaunchArgs.arg("sceneFile") ?? "assets/scenes.json"),
          let data = FileManager.default.contents(atPath: p),
          let file = try? JSONDecoder().decode(RefFile.self, from: data) else { return nil }
    return file.scenes.first { $0.id == id }
  }

  static func image(_ name: String) -> UIImage? {
    path("assets/backgrounds/\(name).png").flatMap(UIImage.init(contentsOfFile:))
  }
}

@available(iOS 26.0, *)
struct ReferenceSceneView: View {
  let scene: RefScene
  let background: UIImage

  var body: some View {
    ZStack(alignment: .topLeading) {
      Image(uiImage: background).resizable().interpolation(.none)
        .frame(width: 402, height: 874)
      if let spacing = scene.spacing {
        GlassEffectContainer(spacing: spacing) { shapes }
      } else {
        shapes
      }
    }
    .frame(width: 402, height: 874, alignment: .topLeading)
    .ignoresSafeArea()
    .environment(\.colorScheme, scene.brightness == "dark" ? .dark : .light)
    .statusBarHidden(true)
  }

  private var shapes: some View {
    ZStack(alignment: .topLeading) {
      ForEach(scene.shapes.indices, id: \.self) { i in
        let s = scene.shapes[i]
        Color.clear
          .frame(width: s.w, height: s.h)
          .glassEffect(glass(s), in: shape(s))
          .position(x: s.x + s.w / 2, y: s.y + s.h / 2)
      }
    }
    .frame(width: 402, height: 874, alignment: .topLeading)
  }

  private func glass(_ s: RefShape) -> Glass {
    var g: Glass = s.variant == "clear" ? .clear : .regular
    if let t = s.tint { g = g.tint(Color(rgbaHex: t)) }
    return g
  }

  private func shape(_ s: RefShape) -> AnyShape {
    switch s.shape {
    case "capsule": AnyShape(Capsule())
    case "circle": AnyShape(Circle())
    default: AnyShape(RoundedRectangle(cornerRadius: s.radius, style: .continuous))
    }
  }
}

/// Draws the scene with Apple's UIKit glass APIs (Task 17d noise floor:
/// SwiftUI vs UIKit is one of Apple's own cross-API error bars): a
/// `UIGlassContainerEffect` host when the scene merges, one `UIGlassEffect`
/// view per shape with matching corner configurations. The plugin no longer
/// draws this way — its native mode hosts SwiftUI `.glassEffect` (Task N1) —
/// so this is a measurement reference only. Tinted shapes carry their tint
/// here, and tinted scenes ARE included in the committed cross-API floor
/// (tool/fidelity/floors/simulator-swiftui-uikit.json): SwiftUI and UIKit
/// render tint differently by design, which is why the global floor's
/// ΔE/FLIP p90 legs are report-only and only the SSIM leg (p90 0.99999)
/// is meaningful. See the per-variant floor ruling in
/// .superpowers/sdd/2026-10-05-task-17d-noise-floor-and-scoring/progress.md
/// (Task 4/6 rulings).
@available(iOS 26.0, *)
final class UIKitSceneView: UIView {
  init(scene: RefScene, background: UIImage) {
    super.init(frame: UIScreen.main.bounds)
    backgroundColor = .systemBackground

    let image = UIImageView(image: background)
    image.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
    image.contentMode = .scaleToFill
    addSubview(image)

    let host: UIView = self
    var container: UIVisualEffectView?
    if let spacing = scene.spacing {
      let c = UIVisualEffectView(effect: nil)
      c.frame = bounds
      c.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      addSubview(c)
      let e = UIGlassContainerEffect()
      e.spacing = spacing
      c.effect = e
      container = c
    }
    let parent = container?.contentView ?? host
    for s in scene.shapes {
      let v = UIVisualEffectView(effect: nil)
      let g = UIGlassEffect(style: s.variant == "clear" ? .clear : .regular)
      if let t = s.tint { g.tintColor = Color.uiColor(rgbaHex: t) }
      v.effect = g
      v.frame = CGRect(x: s.x, y: s.y, width: s.w, height: s.h)
      switch s.shape {
      case "capsule", "circle": v.cornerConfiguration = .capsule()
      default: v.cornerConfiguration = .corners(radius: .fixed(s.radius))
      }
      parent.addSubview(v)
    }
  }

  required init?(coder: NSCoder) { fatalError("not used") }
}

extension Color {
  /// RGBA hex ("#AARRGGBB") → UIColor, for the UIKit reference's tint.
  static func uiColor(rgbaHex: String) -> UIColor {
    let v = UInt32(rgbaHex.dropFirst(), radix: 16) ?? 0
    return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255,
                   alpha: CGFloat((v >> 24) & 0xFF) / 255)
  }

  init(rgbaHex: String) {
    let v = UInt32(rgbaHex.dropFirst(), radix: 16) ?? 0
    self.init(.sRGB,
              red: Double((v >> 24) & 0xFF) / 255, green: Double((v >> 16) & 0xFF) / 255,
              blue: Double((v >> 8) & 0xFF) / 255, opacity: Double(v & 0xFF) / 255)
  }
}

/// Launch arguments (`-scene`, `-renderer`, `-constants`, `-motion`,
/// `-sceneFile`) shared by both renderers.
enum LaunchArgs {
  static func arg(_ name: String) -> String? {
    let a = ProcessInfo.processInfo.arguments
    guard let i = a.firstIndex(of: "-\(name)"), i + 1 < a.count else { return nil }
    return a[i + 1]
  }

  static var all: [String: String?] {
    ["scene": arg("scene"), "renderer": arg("renderer"),
     "constants": arg("constants"), "motion": arg("motion"),
     "sceneFile": arg("sceneFile")]
  }

  /// `-renderer swiftui -scene <id>`: replaces the Flutter root view
  /// controller with the SwiftUI reference scene. If that is impossible the
  /// screen turns solid magenta with the reason, so a capture can never pass
  /// Flutter off as the SwiftUI reference.
  static func installReferenceScene(in window: UIWindow?) {
    let renderer = arg("renderer")
    guard renderer == "swiftui" || renderer == "uikit", let window else { return }
    let r = renderer!
    guard #available(iOS 26.0, *) else {
      return fail(window, "\(r) reference needs iOS 26 or later")
    }
    guard let id = arg("scene") else { return fail(window, "-renderer \(r) without -scene") }
    guard let scene = ReferenceAssets.scene(id: id) else {
      return fail(window, "scene not found: \(id)")
    }
    guard let bg = ReferenceAssets.image(scene.background) else {
      return fail(window, "background missing: \(scene.background)")
    }
    if r == "uikit" {
      let vc = UIViewController()
      vc.view.addSubview(UIKitSceneView(scene: scene, background: bg))
      window.rootViewController = vc
    } else {
      window.rootViewController = UIHostingController(
        rootView: ReferenceSceneView(scene: scene, background: bg))
    }
  }

  private static func fail(_ window: UIWindow, _ message: String) {
    NSLog("ReferenceScenes: %@", message)
    let vc = UIViewController()
    vc.view.backgroundColor = .magenta
    let label = UILabel()
    label.text = "REFERENCE FAILED: \(message)"
    label.textColor = .red
    label.backgroundColor = .white
    label.numberOfLines = 0
    label.textAlignment = .center
    label.font = .boldSystemFont(ofSize: 24)
    label.translatesAutoresizingMaskIntoConstraints = false
    vc.view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 16),
      label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -16),
    ])
    window.rootViewController = vc
  }
}
