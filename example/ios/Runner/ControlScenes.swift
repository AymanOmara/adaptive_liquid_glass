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
    case "accessory": root = AnyView(AccessoryReference(accessory: true))
    case "tabbar": root = AnyView(AccessoryReference(accessory: false))
    case "tabbarphoto": root = AnyView(TabBarBackdropReference(photo: true, dark: false))
    case "tabbardark": root = AnyView(TabBarBackdropReference(photo: false, dark: true))
    case "tabbarphotodark": root = AnyView(TabBarBackdropReference(photo: true, dark: true))
    case "sheet": root = AnyView(SheetReference(large: false))
    case "menu": root = AnyView(MenuReference())
    case "search": root = AnyView(SearchReference())
    case "sheetlarge": root = AnyView(SheetReference(large: true))
    case "alert": root = AnyView(AlertReference())
    case "dialog": root = AnyView(DialogReference())
    case "popover": root = AnyView(PopoverReference())
    case "contextmenu": root = AnyView(ContextMenuReference())
    case "stepper": root = AnyView(StepperReference())
    case "picker": root = AnyView(PickerReference())
    case "datepicker": root = AnyView(DatePickerReference())
    case "searchtab": root = AnyView(SearchTabReference())
    case "swipe": root = AnyView(SwipeReference(tall: false))
    case "swipetall": root = AnyView(SwipeReference(tall: true))
    case "textfield": root = AnyView(TextFieldReference())
    case "list": root = AnyView(ListReference())
    case "progress": root = AnyView(ProgressReference())
    case "pagecontrol": root = AnyView(PageControlReference())
    case "actionsheet": root = AnyView(ActionSheetReference())
    case "badge": root = AnyView(BadgeReference())
    case "disclosure": root = AnyView(DisclosureReference())
    case "emptystate": root = AnyView(EmptyStateReference())
    case "fullscreencover": root = AnyView(FullScreenCoverReference())
    case "gauge": root = AnyView(GaugeReference())
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
  /// Without it (`-controls tabbar`), the plain tab bar.
  let accessory: Bool
  var body: some View {
    if accessory { tabs.tabViewBottomAccessory { bar } } else { tabs }
  }

  var tabs: some View {
    TabView {
      Tab("Home", systemImage: "house.fill") { Color.white.ignoresSafeArea() }
      Tab("Music", systemImage: "music.note") { Color.white.ignoresSafeArea() }
      Tab("Settings", systemImage: "gearshape.fill") { Color.white.ignoresSafeArea() }
    }
    .environment(\.colorScheme, .light)
  }

  var bar: some View {
    HStack {
      Image(systemName: "music.note")
      Text("Now Playing")
      Spacer()
      Image(systemName: "play.fill")
    }
    .padding(.horizontal, 16)
  }
}

/// The `-controls tabbar` bar over a page that shows the glass:
/// `tabbarphoto` the striped, colourful `assets/backgrounds/photo.png`
/// (full screen), `tabbardark` a black page in dark mode,
/// `tabbarphotodark` the photo in dark mode.
@available(iOS 26.0, *)
struct TabBarBackdropReference: View {
  let photo: Bool
  let dark: Bool
  var body: some View {
    TabView {
      Tab("Home", systemImage: "house.fill") { page }
      Tab("Music", systemImage: "music.note") { page }
      Tab("Settings", systemImage: "gearshape.fill") { page }
    }
    .environment(\.colorScheme, dark ? .dark : .light)
  }

  @ViewBuilder var page: some View {
    if photo, let image = ReferenceAssets.image("photo") {
      // Resizable fills the proposal, which is the whole screen once the
      // safe area is ignored (a fixed 402 x 874 frame sat 10 pt high).
      Image(uiImage: image).resizable().interpolation(.none).ignoresSafeArea()
    } else {
      (dark ? Color.black : Color.white).ignoresSafeArea()
    }
  }
}

/// A medium-detent sheet with a grabber, shown at launch, over a mid-grey
/// page.
@available(iOS 26.0, *)
struct SheetReference: View {
  /// The large detent (`-controls sheetlarge`) instead of the medium one.
  let large: Bool
  @State private var shown = false
  var body: some View {
    Color(white: 0.5).ignoresSafeArea()
      .onAppear { shown = true }
      .sheet(isPresented: $shown) {
        Text("Glass sheet").font(.title2.bold())
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(24)
          .presentationDetents([large ? .large : .medium])
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

/// An alert (title, message, Cancel and a destructive Delete) shown at
/// launch over a mid-grey page.
@available(iOS 26.0, *)
struct AlertReference: View {
  @State private var shown = false
  var body: some View {
    Color(white: 0.5).ignoresSafeArea()
      .onAppear { shown = true }
      .alert("Delete photo?", isPresented: $shown) {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {}
      } message: {
        Text("This photo will be deleted from all your devices.")
      }
      .environment(\.colorScheme, .light)
  }
}

/// A confirmation dialog (title, two actions and Cancel) shown at launch
/// over a mid-grey page.
@available(iOS 26.0, *)
struct DialogReference: View {
  @State private var shown = false
  var body: some View {
    Color(white: 0.5).ignoresSafeArea()
      .onAppear { shown = true }
      .confirmationDialog("Photo", isPresented: $shown, titleVisibility: .visible) {
        Button("Share") {}
        Button("Delete", role: .destructive) {}
        Button("Cancel", role: .cancel) {}
      }
      .environment(\.colorScheme, .light)
  }
}

/// A popover from a toolbar button, shown at launch, kept a popover on
/// iPhone. Mid-grey page.
@available(iOS 26.0, *)
struct PopoverReference: View {
  @State private var shown = false
  var body: some View {
    NavigationStack {
      Color(white: 0.5).ignoresSafeArea()
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {} label: { Image(systemName: "info.circle") }
              .popover(isPresented: $shown) {
                Text("Liquid Glass popover").padding()
                  .presentationCompactAdaptation(.popover)
              }
          }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shown = true } }
    }
    .environment(\.colorScheme, .light)
  }
}

/// A card with a context menu (Copy, Share, Delete); long-press it
/// (centre 201, 300) to measure. Mid-grey page.
@available(iOS 26.0, *)
struct ContextMenuReference: View {
  var body: some View {
    ZStack {
      Color(white: 0.5).ignoresSafeArea()
      RoundedRectangle(cornerRadius: 20).fill(.white)
        .frame(width: 200, height: 120)
        .overlay(Text("Long-press me"))
        .contextMenu {
          Button("Copy", systemImage: "doc.on.doc") {}
          Button("Share", systemImage: "square.and.arrow.up") {}
          Button("Delete", systemImage: "trash", role: .destructive) {}
        }
        .position(x: 201, y: 300)
    }
    .environment(\.colorScheme, .light)
  }
}

/// Steppers (light at y = 100, dark at y = 200 on black). White page.
@available(iOS 26.0, *)
struct StepperReference: View {
  @State private var value = 3
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      Color.black.frame(width: 402, height: 100).position(x: 201, y: 200)
      Stepper("", value: $value).labelsHidden().fixedSize().position(x: 201, y: 100)
      Stepper("", value: $value).labelsHidden().fixedSize().position(x: 201, y: 200)
        .environment(\.colorScheme, .dark)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// A menu-style picker (centre 201, 300); tap it to open. White page.
@available(iOS 26.0, *)
struct PickerReference: View {
  @State private var choice = 1
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      Picker("Period", selection: $choice) {
        Text("Day").tag(0)
        Text("Week").tag(1)
        Text("Month").tag(2)
      }
      .pickerStyle(.menu).fixedSize().position(x: 201, y: 300)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// A compact date picker (centre 201, 300) for 6 Oct 2026; tap it to
/// open. White page.
@available(iOS 26.0, *)
struct DatePickerReference: View {
  @State private var date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 6))!
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      DatePicker("", selection: $date, displayedComponents: .date)
        .labelsHidden().fixedSize().position(x: 201, y: 300)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// A tab bar with three tabs and a search tab. White page.
@available(iOS 26.0, *)
struct SearchTabReference: View {
  @State private var query = ""
  var body: some View {
    TabView {
      Tab("Home", systemImage: "house.fill") { Color.white.ignoresSafeArea() }
      Tab("Music", systemImage: "music.note") { Color.white.ignoresSafeArea() }
      Tab("Settings", systemImage: "gearshape.fill") { Color.white.ignoresSafeArea() }
      Tab(role: .search) {
        NavigationStack { List(0..<10) { Text("Result \($0)") } }
          .searchable(text: $query)
      }
    }
    .environment(\.colorScheme, .light)
  }
}

// MARK: - References for the components borrowed in feat/borrow-lgw.
// Laid out the same way in lib/reference_twin.dart for side-by-side checks.

/// A text field (centre 201, 120) and a secure field (201, 200) on white,
/// then the same pair in dark on a black band (y 300-460).
@available(iOS 26.0, *)
struct TextFieldReference: View {
  @State private var text = ""
  @State private var secret = "secret"
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      Color.black.frame(width: 402, height: 160).position(x: 201, y: 380)
      fields.position(x: 201, y: 160)
      fields.position(x: 201, y: 380).environment(\.colorScheme, .dark)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }

  var fields: some View {
    VStack(spacing: 24) {
      TextField("Name", text: $text).textFieldStyle(.roundedBorder)
      SecureField("Password", text: $secret).textFieldStyle(.roundedBorder)
    }
    .frame(width: 362)
  }
}

/// An inset-grouped list: one section with an icon row + chevron, a value
/// row and a toggle row, with header and footer.
@available(iOS 26.0, *)
struct ListReference: View {
  @State private var on = true
  var body: some View {
    // NavigationStack so the NavigationLink renders enabled (outside one it
    // greys out); the bar is hidden so the twin needs none.
    NavigationStack {
      List {
        Section {
          Label("Wi-Fi", systemImage: "wifi")
            .badge("Home")
          NavigationLink(value: 1) { Label("General", systemImage: "gear") }
          Toggle(isOn: $on) { Label("Airplane Mode", systemImage: "airplane") }
        } header: { Text("Connections") } footer: { Text("Footer text") }
      }
      .listStyle(.insetGrouped)
      .navigationDestination(for: Int.self) { _ in EmptyView() }
      .toolbar(.hidden, for: .navigationBar)
    }
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// Linear progress at 40% (y 120), an indeterminate spinner (y 200),
/// then both in dark on a black band (y 300-460).
@available(iOS 26.0, *)
struct ProgressReference: View {
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      Color.black.frame(width: 402, height: 160).position(x: 201, y: 380)
      pair.position(x: 201, y: 160)
      pair.position(x: 201, y: 380).environment(\.colorScheme, .dark)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }

  var pair: some View {
    VStack(spacing: 40) {
      ProgressView(value: 0.4).frame(width: 300)
      ProgressView()
    }
  }
}

/// A paged view of five grey pages, page 2 selected, with the always-on
/// page indicator background.
@available(iOS 26.0, *)
struct PageControlReference: View {
  @State private var page = 1
  var body: some View {
    TabView(selection: $page) {
      ForEach(0..<5) { i in
        Color(white: 0.85 - Double(i) * 0.05).tag(i)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .always))
    .indexViewStyle(.page(backgroundDisplayMode: .always))
    .ignoresSafeArea()
    .statusBarHidden(true)
  }
}

/// A confirmation dialog (action sheet) open over a white page.
@available(iOS 26.0, *)
struct ActionSheetReference: View {
  @State private var shown = false
  var body: some View {
    Color.white
      .ignoresSafeArea()
      .confirmationDialog("Delete photo?", isPresented: $shown, titleVisibility: .visible) {
        Button("Delete", role: .destructive) {}
        Button("Duplicate") {}
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This photo will be removed from all your devices.")
      }
      .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shown = true } }
      .statusBarHidden(true)
  }
}

/// A tab bar whose second tab carries a badge of 3.
@available(iOS 26.0, *)
struct BadgeReference: View {
  var body: some View {
    TabView {
      Tab("Home", systemImage: "house") { Color.white }
      Tab("Inbox", systemImage: "tray") { Color.white }.badge(3)
      Tab("Settings", systemImage: "gear") { Color.white }
    }
    .statusBarHidden(true)
  }
}
