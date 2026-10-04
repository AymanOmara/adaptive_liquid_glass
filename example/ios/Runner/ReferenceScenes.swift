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

extension Color {
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
    guard arg("renderer") == "swiftui", let window else { return }
    guard #available(iOS 26.0, *) else {
      return fail(window, "SwiftUI reference needs iOS 26 or later")
    }
    guard let id = arg("scene") else { return fail(window, "-renderer swiftui without -scene") }
    guard let scene = ReferenceAssets.scene(id: id) else {
      return fail(window, "scene not found: \(id)")
    }
    guard let bg = ReferenceAssets.image(scene.background) else {
      return fail(window, "background missing: \(scene.background)")
    }
    window.rootViewController = UIHostingController(
      rootView: ReferenceSceneView(scene: scene, background: bg))
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
