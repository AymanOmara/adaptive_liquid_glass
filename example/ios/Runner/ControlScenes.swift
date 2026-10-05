import SwiftUI
import UIKit

/// `-controls buttons` and `-controls navbar [-scrollY <pt>]`: SwiftUI
/// reference screens for Phase 2a metrics (tool/reference/).
enum ControlScenes {
  static func install(in window: UIWindow?) -> Bool {
    guard #available(iOS 26.0, *), let which = LaunchArgs.arg("controls") else { return false }
    let root: AnyView
    switch which {
    case "buttons": root = AnyView(ButtonsReference())
    case "navbar":
      let y = Double(LaunchArgs.arg("scrollY") ?? "0") ?? 0
      root = AnyView(NavBarReference(scrollY: y))
    default: return false
    }
    window?.rootViewController = UIHostingController(rootView: root)
    window?.makeKeyAndVisible()
    return true
  }
}

/// One row per control size, mini…extraLarge, centred at y = 80 + i × 120
/// pt: a "Button" label button centred at x = 100 and an icon-only button
/// centred at x = 330. Mid-grey background so glass edges show.
@available(iOS 26.0, *)
struct ButtonsReference: View {
  let sizes: [ControlSize] = [.mini, .small, .regular, .large, .extraLarge]
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color(white: 0.5)
      ForEach(sizes.indices, id: \.self) { i in
        let y = 80 + Double(i) * 120
        Button("Button") {}.buttonStyle(.glass).controlSize(sizes[i])
          .fixedSize().position(x: 100, y: y)
        Button {} label: { Image(systemName: "plus") }
          .buttonStyle(.glass).controlSize(sizes[i])
          .fixedSize().position(x: 330, y: y)
      }
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// A large-title list scrolled to `scrollY`, two trailing toolbar buttons.
@available(iOS 26.0, *)
struct NavBarReference: View {
  let scrollY: Double
  @State private var position = ScrollPosition(y: 0)
  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(0..<60) { i in
            Text("Row \(i)").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
              .padding(.horizontal, 16)
          }
        }
      }
      .scrollPosition($position)
      .onAppear { position = ScrollPosition(y: scrollY) }
      .navigationTitle("Inbox")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {} label: { Image(systemName: "square.and.pencil") }
          Button {} label: { Image(systemName: "ellipsis") }
        }
      }
    }
    .environment(\.colorScheme, .light)
  }
}
