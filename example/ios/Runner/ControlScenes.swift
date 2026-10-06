import SwiftUI
import UIKit

/// `-controls buttons`, `-controls navbar [-scrollY <pt>]` and the
/// component screens below: SwiftUI reference screens for the metrics in
/// tool/reference/.
enum ControlScenes {
  static func install(in window: UIWindow?) -> Bool {
    guard #available(iOS 26.0, *), let which = LaunchArgs.arg("controls") else { return false }
    let root: AnyView
    switch which {
    case "buttons": root = AnyView(ButtonsReference())
    case "navbar":
      let y = Double(LaunchArgs.arg("scrollY") ?? "0") ?? 0
      root = AnyView(NavBarReference(scrollY: y))
    case "controls": root = AnyView(ControlsReference())
    case "toolbar": root = AnyView(ToolbarReference())
    case "accessory": root = AnyView(AccessoryReference())
    case "sheet": root = AnyView(SheetReference())
    case "menu": root = AnyView(MenuReference())
    case "search": root = AnyView(SearchReference())
    case "swipe": root = AnyView(SwipeReference(tall: false))
    case "swipetall": root = AnyView(SwipeReference(tall: true))
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

/// Toggles (on at y = 100, off at y = 200, x = 201), a slider (300 wide,
/// value 0.5, y = 300) and a segmented picker (300 wide, y = 400), light;
/// the same picker in dark at y = 500 on black; in dark on black below, an
/// off toggle (y = 640) and the slider (y = 740). White page.
@available(iOS 26.0, *)
struct ControlsReference: View {
  @State private var on = true
  @State private var off = false
  @State private var value = 0.5
  @State private var segment = 1
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      Color.black.frame(width: 402, height: 100).position(x: 201, y: 500)
      Toggle("", isOn: $on).labelsHidden().fixedSize().position(x: 201, y: 100)
      Toggle("", isOn: $off).labelsHidden().fixedSize().position(x: 201, y: 200)
      Slider(value: $value).frame(width: 300).position(x: 201, y: 300)
      picker.frame(width: 300).position(x: 201, y: 400)
      picker.frame(width: 300).position(x: 201, y: 500)
        .environment(\.colorScheme, .dark)
      Color.black.frame(width: 402, height: 200).position(x: 201, y: 700)
      Toggle("", isOn: $off).labelsHidden().fixedSize().position(x: 201, y: 640)
        .environment(\.colorScheme, .dark)
      Slider(value: $value).frame(width: 300).position(x: 201, y: 740)
        .environment(\.colorScheme, .dark)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }

  var picker: some View {
    Picker("", selection: $segment) {
      Text("Day").tag(0)
      Text("Week").tag(1)
      Text("Month").tag(2)
    }
    .pickerStyle(.segmented)
  }
}

/// A bottom toolbar: two items, a flexible spacer, one item. White page.
@available(iOS 26.0, *)
struct ToolbarReference: View {
  var body: some View {
    NavigationStack {
      Color.white.ignoresSafeArea()
        .toolbar {
          ToolbarItem(placement: .bottomBar) {
            Button {} label: { Image(systemName: "arrowshape.turn.up.left") }
          }
          ToolbarItem(placement: .bottomBar) {
            Button {} label: { Image(systemName: "flag") }
          }
          ToolbarSpacer(.flexible, placement: .bottomBar)
          ToolbarItem(placement: .bottomBar) {
            Button {} label: { Image(systemName: "square.and.pencil") }
          }
        }
    }
    .environment(\.colorScheme, .light)
  }
}

/// A three-tab TabView with a bottom accessory. White page.
@available(iOS 26.0, *)
struct AccessoryReference: View {
  var body: some View {
    TabView {
      Tab("Home", systemImage: "house.fill") { Color.white.ignoresSafeArea() }
      Tab("Music", systemImage: "music.note") { Color.white.ignoresSafeArea() }
      Tab("Settings", systemImage: "gearshape.fill") { Color.white.ignoresSafeArea() }
    }
    .tabViewBottomAccessory {
      HStack {
        Image(systemName: "music.note")
        Text("Now Playing")
        Spacer()
        Image(systemName: "play.fill")
      }
      .padding(.horizontal, 16)
    }
    .environment(\.colorScheme, .light)
  }
}

/// A medium-detent sheet with a grabber, shown at launch, over a mid-grey
/// page.
@available(iOS 26.0, *)
struct SheetReference: View {
  @State private var shown = false
  var body: some View {
    Color(white: 0.5).ignoresSafeArea()
      .onAppear { shown = true }
      .sheet(isPresented: $shown) {
        Text("Glass sheet").font(.title2.bold())
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(24)
          .presentationDetents([.medium])
          .presentationDragIndicator(.visible)
          .environment(\.colorScheme, .light)
      }
      .environment(\.colorScheme, .light)
  }
}

/// A trailing toolbar menu (tap it to open): Copy, Share, Delete. Mid-grey
/// page.
@available(iOS 26.0, *)
struct MenuReference: View {
  var body: some View {
    NavigationStack {
      Color(white: 0.5).ignoresSafeArea()
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Copy", systemImage: "doc.on.doc") {}
              Button("Share", systemImage: "square.and.arrow.up") {}
              Button("Delete", systemImage: "trash", role: .destructive) {}
            } label: { Image(systemName: "ellipsis") }
          }
        }
    }
    .environment(\.colorScheme, .light)
  }
}

/// A searchable list; iOS 26 puts the field at the bottom. White page.
@available(iOS 26.0, *)
struct SearchReference: View {
  @State private var query = ""
  var body: some View {
    NavigationStack {
      List(0..<20) { i in Text("Row \(i)") }
        .navigationTitle("Search")
        .searchable(text: $query)
    }
    .environment(\.colorScheme, .light)
  }
}

/// A plain list whose rows have leading (Pin) and trailing (Delete, Share)
/// swipe actions; swipe a row to measure. `-controls swipetall` uses
/// two-line rows. Light.
@available(iOS 26.0, *)
struct SwipeReference: View {
  /// Two-line rows (about 60 pt) instead of one-line (44 pt).
  let tall: Bool
  var body: some View {
    List(0..<12) { i in
      HStack {
        Image(systemName: "doc.text")
        VStack(alignment: .leading) {
          Text("Item \(i)")
          if tall { Text("2 days ago · iPhone").font(.caption).foregroundStyle(.secondary) }
        }
      }
      .swipeActions(edge: .leading) {
        Button("Pin", systemImage: "pin.fill") {}.tint(.orange)
      }
      .swipeActions(edge: .trailing) {
        Button("Delete", systemImage: "trash", role: .destructive) {}
        Button("Share", systemImage: "square.and.arrow.up") {}.tint(.blue)
      }
    }
    .listStyle(.plain)
    .environment(\.colorScheme, .light)
  }
}
