import SwiftUI
import TipKit

// MARK: - References for the new components. Laid out the same way in the
// Flutter twins for side-by-side checks.

/// An inset-grouped list, nav bar hidden, with one "Settings" section: an
/// expanded disclosure group (gearshape label, Proxy/DNS LabeledContent
/// rows) above a collapsed "Network" group (Wi-Fi row), plus header and
/// footer text.
@available(iOS 26.0, *)
struct DisclosureReference: View {
  @State private var advanced = true
  var body: some View {
    NavigationStack {
      List {
        Section {
          DisclosureGroup(isExpanded: $advanced) {
            LabeledContent("Proxy", value: "Off")
            LabeledContent("DNS", value: "Automatic")
          } label: {
            Label("Advanced", systemImage: "gearshape")
          }
          DisclosureGroup("Network") {
            Text("Wi-Fi")
          }
        } header: { Text("Settings") } footer: { Text("Footer text") }
      }
      .listStyle(.insetGrouped)
      .toolbar(.hidden, for: .navigationBar)
    }
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// Top half: the "No Mail" empty state (tray icon, description, glass
/// Refresh button) in a 437 pt band; bottom half: the search empty state
/// for "kiwi" in another 437 pt band. White 402 x 874 page.
@available(iOS 26.0, *)
struct EmptyStateReference: View {
  var body: some View {
    VStack(spacing: 0) {
      ContentUnavailableView {
        Label("No Mail", systemImage: "tray")
      } description: {
        Text("New messages you receive will appear here.")
      } actions: {
        Button("Refresh") {}.buttonStyle(.glass)
      }
      .frame(height: 437)
      ContentUnavailableView.search(text: "kiwi")
        .frame(height: 437)
    }
    .frame(width: 402, height: 874)
    .background(Color.white)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// The bands of `EmptyStateReference` swapped and varied: the search empty
/// state for "kiwi" in the top 437 pt band, "No Mail" without actions in the
/// bottom one; measures the block's placement without actions and lower on
/// the screen.
@available(iOS 26.0, *)
struct EmptyStateSwapReference: View {
  var body: some View {
    VStack(spacing: 0) {
      ContentUnavailableView.search(text: "kiwi")
        .frame(height: 437)
      ContentUnavailableView(
        "No Mail",
        systemImage: "tray",
        description: Text("New messages you receive will appear here.")
      )
      .frame(height: 437)
    }
    .frame(width: 402, height: 874)
    .background(Color.white)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// A white "Home" page that, 0.3 s after launch, presents a full-screen
/// cover: a Done glass button top-trailing (16 pt horizontal padding) and
/// a bold large "Cover" title centred, on the default system background.
@available(iOS 26.0, *)
struct FullScreenCoverReference: View {
  @State private var shown = false
  var body: some View {
    Color.white
      .ignoresSafeArea()
      .overlay(Text("Home"))
      .fullScreenCover(isPresented: $shown) { cover }
      .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shown = true } }
      .statusBarHidden(true)
      .environment(\.colorScheme, .light)
  }

  var cover: some View {
    VStack {
      HStack {
        Spacer()
        Button("Done") {}.buttonStyle(.glass)
      }
      .padding(.horizontal, 16)
      Spacer()
      Text("Cover").font(.largeTitle.bold())
      Spacer()
    }
    .statusBarHidden(true)
    .environment(\.colorScheme, .light)
  }
}

/// The full-screen cover's motion, for recording: a white page presents a
/// solid blue cover 1 s after launch and dismisses it 2.5 s later
/// (`tool/reference` timing capture tracks the cover's top edge).
@available(iOS 26.0, *)
struct CoverTimingReference: View {
  @State private var shown = false
  var body: some View {
    Color.white
      .ignoresSafeArea()
      .fullScreenCover(isPresented: $shown) {
        Color.blue.ignoresSafeArea().statusBarHidden(true)
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { shown = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { shown = false }
      }
      .statusBarHidden(true)
      .environment(\.colorScheme, .light)
  }
}

/// A linear capacity battery gauge (62%, 0/100 labels, 300 wide) above a
/// pair of circular gauges — an orange accessoryCircular temp gauge (21 of
/// 0…40, 0/40 labels) and an accessoryCircularCapacity battery gauge (62)
/// — in a VStack (spacing 48) centred at 201, 300. White 402 x 874 page.
@available(iOS 26.0, *)
struct GaugeReference: View {
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      VStack(spacing: 48) {
        Gauge(value: 0.62) {
          Text("Battery")
        } currentValueLabel: {
          Text("62%")
        } minimumValueLabel: {
          Text("0")
        } maximumValueLabel: {
          Text("100")
        }
        .frame(width: 300)
        HStack(spacing: 48) {
          Gauge(value: 21, in: 0...40) {
            Text("Temp")
          } currentValueLabel: {
            Text("21")
          } minimumValueLabel: {
            Text("0")
          } maximumValueLabel: {
            Text("40")
          }
          .gaugeStyle(.accessoryCircular)
          .tint(.orange)
          Gauge(value: 0.62) {
            Text("Battery")
          } currentValueLabel: {
            Text("62")
          }
          .gaugeStyle(.accessoryCircularCapacity)
        }
      }
      .position(x: 201, y: 300)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

/// Motion: a plain list of 30 rows whose `.refreshable` action takes 1 s;
/// pull it down to record the indicator's hold and snap-back
/// (`tool/fidelity/record_component_motion.sh`). Light.
@available(iOS 26.0, *)
struct RefreshMotionReference: View {
  /// Dark mode (`-controls refreshmotiondark`), its refresh taking 3 s so
  /// the spinner can be sampled.
  var dark = false
  var body: some View {
    List(0..<30) { i in Text("Row \(i)") }
      .listStyle(.plain)
      .refreshable { try? await Task.sleep(for: .seconds(dark ? 3 : 1)) }
      .environment(\.colorScheme, dark ? .dark : .light)
      // The window's own style too: the pulled gap shows its background.
      .preferredColorScheme(dark ? .dark : nil)
      .statusBarHidden(true)
  }
}

/// Motion: a ColorPicker well centred at 201, 300; tap it to open the
/// system picker and pick a swatch to record its selection ring. Light.
@available(iOS 26.0, *)
struct ColorMotionReference: View {
  @State private var color = Color.blue
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.white
      ColorPicker("Tint", selection: $color).labelsHidden().position(x: 201, y: 300)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

// MARK: - Geometry references for the remaining components (measured by
// tool/reference/measure_components.py).

/// A 402 x 874 page, light, en_US, status bar hidden, children placed by
/// centre.
@available(iOS 26.0, *)
private struct Page<Content: View>: View {
  var background: Color = .white
  @ViewBuilder let content: Content
  var body: some View {
    ZStack(alignment: .topLeading) {
      background
      content
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, .light)
    .environment(\.locale, Locale(identifier: "en_US"))
    .statusBarHidden(true)
  }
}

/// `Label("Label", systemImage: "star.fill")` at the body size, centred at
/// 201, 100. White page.
@available(iOS 26.0, *)
struct LabelReference: View {
  var body: some View {
    Page {
      Label("Label", systemImage: "star.fill").fixedSize().position(x: 201, y: 100)
    }
  }
}

/// On a mid-grey page: a glass `Link("Link")` centred at 201, 100, a glass
/// `ShareLink` (its default "Share" label) at 201, 200 and a glass Link
/// labelled with `arrow.up.right` at 201, 300.
@available(iOS 26.0, *)
struct LinkReference: View {
  let url = URL(string: "https://www.apple.com")!
  var body: some View {
    Page(background: Color(white: 0.5)) {
      Link("Link", destination: url).buttonStyle(.glass).fixedSize().position(x: 201, y: 100)
      ShareLink(item: url).buttonStyle(.glass).fixedSize().position(x: 201, y: 200)
      Link(destination: url) { Label("Link", systemImage: "arrow.up.right") }
        .buttonStyle(.glass).fixedSize().position(x: 201, y: 300)
    }
  }
}

/// A wheel picker of the numbers 0…30 (10 selected) at its own size,
/// centred at 201, 300. White page. `step`: 1.5 s in, VoiceOver's
/// increase (WheelStepProbe).
@available(iOS 26.0, *)
struct WheelReference: View {
  var step = false
  @State private var choice = 10
  var body: some View {
    Page {
      Picker("Number", selection: $choice) {
        ForEach(0..<31) { Text("\($0)").tag($0) }
      }
      .pickerStyle(.wheel).fixedSize().position(x: 201, y: 300)
    }
    .onAppear {
      guard step else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { WheelStepProbe.run() }
    }
  }
}

/// Performs VoiceOver's increase on the key window's UIPickerView (its
/// adjustable accessibility element, as VoiceOver's swipe up does) and
/// logs each of the column's tables' scroll offset (presentation/model)
/// and the element's value every display frame for 1 s to
/// `<tmp>/wheel-step` (t from the increase). Reference harness only.
enum WheelStepProbe {
  private static var link: CADisplayLink?
  private static var start = 0.0
  private static var lines: [String] = []
  private static var columns: [UIScrollView] = []
  private static weak var element: NSObject?

  static func run() {
    // The UIKit accessibility bundle carries UIPickerView's elements; it
    // loads with VoiceOver, so load it here.
    Bundle(path: "/System/Library/AccessibilityBundles/UIKit.axbundle")?.load()
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
      let picker = find(UIPickerView.self, in: window) else {
      return NSLog("WheelStepProbe: no UIPickerView")
    }
    let scrolls = all(UIScrollView.self, in: picker)
    columns = scrolls
    NSLog("WheelStepProbe: scroll views \(scrolls.map { "\(type(of: $0)) \($0.frame)" })")
    guard let found = adjustable(in: picker) else {
      return NSLog("WheelStepProbe: no adjustable element")
    }
    element = found
    lines = []
    start = CACurrentMediaTime()
    sample()
    found.accessibilityIncrement()
    sample()
    let l = CADisplayLink(target: Ticker.shared, selector: #selector(Ticker.tick))
    l.add(to: .main, forMode: .common)
    link = l
  }

  fileprivate static func sample() {
    let ys = columns.map { c in
      String(format: "%.3f/%.3f", c.layer.presentation()?.bounds.origin.y ?? .nan, c.contentOffset.y)
    }
    lines.append(String(format: "%.4f ", CACurrentMediaTime() - start)
      + ys.joined(separator: " ") + " " + (element?.accessibilityValue ?? "-"))
    if CACurrentMediaTime() - start > 1 {
      link?.invalidate()
      link = nil
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("wheel-step")
      try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
      NSLog("WheelStepProbe: wrote \(lines.count) samples")
    }
  }

  private final class Ticker: NSObject {
    static let shared = Ticker()
    @objc func tick() { WheelStepProbe.sample() }
  }

  private static func adjustable(in root: NSObject) -> NSObject? {
    var queue: [NSObject] = [root]
    while !queue.isEmpty {
      let o = queue.removeFirst()
      if o !== root, o.accessibilityTraits.contains(.adjustable) { return o }
      if let v = o as? UIView { queue += v.subviews }
      let n = o.accessibilityElementCount()
      if n != NSNotFound, n > 0 {
        queue += (0..<n).compactMap { o.accessibilityElement(at: $0) as? NSObject }
      } else if let e = o.accessibilityElements {
        queue += e.compactMap { $0 as? NSObject }
      }
    }
    return root.accessibilityTraits.contains(.adjustable) ? root : nil
  }

  private static func find<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
    if let v = view as? T { return v }
    for sub in view.subviews { if let f = find(type, in: sub) { return f } }
    return nil
  }

  private static func all<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
    ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { all(type, in: $0) }
  }
}

/// en_US, 30 Sep 2026 10:41: a `.wheel` date picker (date only) centred at
/// 201, 200, a `.wheel` time picker at 201, 480 and a compact time capsule
/// at 201, 720. White page.
@available(iOS 26.0, *)
struct DateWheelReference: View {
  @State private var date = Calendar(identifier: .gregorian).date(
    from: DateComponents(year: 2026, month: 9, day: 30, hour: 10, minute: 41))!
  var body: some View {
    Page {
      DatePicker("", selection: $date, displayedComponents: .date)
        .datePickerStyle(.wheel).labelsHidden().fixedSize().position(x: 201, y: 200)
      DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
        .datePickerStyle(.wheel).labelsHidden().fixedSize().position(x: 201, y: 480)
      DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
        .labelsHidden().fixedSize().position(x: 201, y: 720)
    }
  }
}

/// The search scene activated 0.6 s after launch, with three suggestions
/// and All/Mail/Notes scopes. Light.
@available(iOS 26.0, *)
struct SearchActiveReference: View {
  @State private var query = ""
  @State private var active = false
  @State private var scope = 0
  var body: some View {
    NavigationStack {
      List(0..<20) { i in Text("Row \(i)") }
        .navigationTitle("Search")
        .searchable(text: $query, isPresented: $active)
        .searchSuggestions {
          Text("Apple").searchCompletion("Apple")
          Text("Banana").searchCompletion("Banana")
          Text("Cherry").searchCompletion("Cherry")
        }
        .searchScopes($scope) {
          Text("All").tag(0)
          Text("Mail").tag(1)
          Text("Notes").tag(2)
        }
    }
    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { active = true } }
    .environment(\.colorScheme, .light)
  }
}

/// A plain list whose refresh lasts 60 s. 1 s after launch it starts the
/// list's refresh control (`.refreshable` is backed by UIRefreshControl)
/// and scrolls it into view, as a pull would. Light.
@available(iOS 26.0, *)
struct RefreshReference: View {
  var body: some View {
    NavigationStack {
      List(0..<30) { i in Text("Row \(i)") }
        .listStyle(.plain)
        .refreshable { try? await Task.sleep(for: .seconds(60)) }
        .navigationTitle("Refresh")
    }
    .environment(\.colorScheme, .light)
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        guard let window = UIApplication.shared.connectedScenes
          .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
          let scroll = Self.scrollView(in: window),
          let control = scroll.refreshControl else { return }
        control.beginRefreshing()
        scroll.setContentOffset(
          CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: false)
      }
    }
  }

  static func scrollView(in view: UIView) -> UIScrollView? {
    if let s = view as? UIScrollView, s.refreshControl != nil { return s }
    for sub in view.subviews { if let s = scrollView(in: sub) { return s } }
    return nil
  }
}

/// A list with a `ColorPicker` row (red); with `present`, 1 s after launch
/// it presents the system colour picker (UIColorPickerViewController,
/// what `ColorPicker` opens) over it. Light, or dark with `dark`.
@available(iOS 26.0, *)
struct ColorSheetReference: View {
  @State private var colour = Color.red
  let present: Bool
  var dark = false
  var body: some View {
    List { ColorPicker("Colour", selection: $colour) }
      .onAppear {
        guard present else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          let picker = UIColorPickerViewController()
          picker.selectedColor = .red
          picker.overrideUserInterfaceStyle = dark ? .dark : .light
          UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?.present(picker, animated: false)
        }
      }
      .preferredColorScheme(dark ? .dark : .light)
  }
}

/// A white page that presents a full-screen cover 0.3 s after launch: a
/// navigation stack with a close-role toolbar button (iOS 26's xmark
/// circle) top-trailing.
@available(iOS 26.0, *)
struct CoverCloseReference: View {
  @State private var shown = false
  var body: some View {
    Color.white
      .ignoresSafeArea()
      .fullScreenCover(isPresented: $shown) {
        NavigationStack {
          Color.white.ignoresSafeArea()
            .toolbar {
              ToolbarItem(placement: .topBarTrailing) { Button(role: .close) {} }
            }
        }
        .environment(\.colorScheme, .light)
      }
      .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shown = true } }
      .environment(\.colorScheme, .light)
  }
}

/// en_GB (24-hour) `.wheel` time picker centred at 201, 200 and an en_US
/// date-and-time `.wheel` picker at 201, 480; 30 Sep 2026 10:41. White
/// page.
@available(iOS 26.0, *)
struct TimeWheelReference: View {
  @State private var date = Calendar(identifier: .gregorian).date(
    from: DateComponents(year: 2026, month: 9, day: 30, hour: 10, minute: 41))!
  var body: some View {
    Page {
      DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
        .datePickerStyle(.wheel).labelsHidden().fixedSize()
        .environment(\.locale, Locale(identifier: "en_GB"))
        .position(x: 201, y: 200)
      DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
        .datePickerStyle(.wheel).labelsHidden().fixedSize().position(x: 201, y: 480)
    }
  }
}

/// The search scene with All/Mail/Notes scopes and no suggestions,
/// activated 0.6 s after launch, `query` already typed. Light. `drawer`
/// puts the field in the navigation bar's drawer (iPad / Mac style).
@available(iOS 26.0, *)
struct SearchScopesReference: View {
  @State private var query: String
  @State private var active = false
  @State private var scope = 0
  var drawer = false
  var plain = false
  init(query: String, drawer: Bool = false, plain: Bool = false) {
    _query = State(initialValue: query)
    self.drawer = drawer
    self.plain = plain
  }
  var body: some View {
    NavigationStack {
      Group {
        if plain {
          // Red rows from the content's top edge: where the content starts.
          List(0..<20) { i in Text("Row \(i)").listRowBackground(Color.red) }
            .listStyle(.plain)
        } else {
          List(0..<20) { i in Text("Row \(i)") }
        }
      }
        .navigationTitle("Search")
        .searchable(text: $query, isPresented: $active,
                    placement: drawer ? .navigationBarDrawer(displayMode: .always) : .automatic)
        .searchScopes($scope) {
          Text("All").tag(0)
          Text("Mail").tag(1)
          Text("Notes").tag(2)
        }
    }
    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { active = true } }
    .environment(\.colorScheme, .light)
  }
}

/// ContextMenuReference's card and menu built on UIKit's own
/// UIContextMenuInteraction (what SwiftUI's `.contextMenu` rides on), so
/// ContextMenuOpener can open it: SwiftUI's delegate ignores a
/// programmatic presentation. Mid-grey page (or `white`), the card
/// `size` centred at `x`, `y` in the safe area (`y` + 62 on screen).
@available(iOS 26.0, *)
struct UIKitContextMenuReference: View {
  var x: CGFloat = 201
  var y: CGFloat = 300
  var size = CGSize(width: 200, height: 120)
  var white = false
  /// Black and white stripes 100 pt wide behind the card: sharp edges
  /// whose spread measures the page's blur.
  var stripes = false
  /// Opens on a tap on the page instead of 1.5 s after launch, so a
  /// motion recording can start it (`-controls contextmenuuikitmotion`).
  var openOnTap = false
  var body: some View {
    ZStack {
      Color(white: white ? 1 : 0.5).ignoresSafeArea()
        .onTapGesture {
          if openOnTap { ContextMenuOpener.open(at: CGPoint(x: x, y: y + 62)) }
        }
      if stripes {
        HStack(spacing: 0) {
          ForEach(0..<5) { i in (i % 2 == 0 ? Color.black : Color.white).frame(width: 100) }
        }
        .frame(width: 402, alignment: .leading)
        .ignoresSafeArea()
      }
      UIKitMenuCard().frame(width: size.width, height: size.height)
        .border(white ? Color.black : Color.clear, width: white ? 1 : 0)
        .position(x: x, y: y)
    }
    .environment(\.colorScheme, .light)
    .onAppear {
      guard !openOnTap else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        ContextMenuOpener.open(at: CGPoint(x: x, y: y + 62))
      }
    }
  }
}

@available(iOS 26.0, *)
private struct UIKitMenuCard: UIViewRepresentable {
  func makeCoordinator() -> Delegate { Delegate() }
  func makeUIView(context: Context) -> UIView {
    let card = TouchLoggingView()
    card.backgroundColor = .white
    card.layer.cornerRadius = 20
    card.layer.cornerCurve = .continuous
    let label = UILabel()
    label.text = "Long-press me"
    label.textColor = .black
    label.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: card.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
    ])
    card.addInteraction(UIContextMenuInteraction(delegate: context.coordinator))
    return card
  }
  func updateUIView(_ view: UIView, context: Context) {}

  final class Delegate: NSObject, UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
      _ interaction: UIContextMenuInteraction,
      configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
      UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
        UIMenu(children: [
          UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in },
          UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in },
          UIAction(title: "Delete", image: UIImage(systemName: "trash"),
                   attributes: .destructive) { _ in },
        ])
      }
    }
  }
}

/// Writes each touch-down's and touch-up's `CACurrentMediaTime` to
/// `<tmp>/touch-down` and `<tmp>/touch-up`, so a recording of the press
/// before the lift finds the touch on the frame dump's clock (idb's touch
/// lands some frames after it is sent).
private final class TouchLoggingView: UIView {
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    log("touch-down")
  }
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    log("touch-up")
  }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    log("touch-cancel")
  }
  private func log(_ name: String) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try? "\(CACurrentMediaTime())".write(to: url, atomically: true, encoding: .utf8)
  }
}

/// Opens the first UIContextMenuInteraction under the key window at
/// `point` (window coordinates) through UIKit's private
/// `_presentMenuAtLocation:`, for captures without a press. idb's long
/// press (`tap 201 362 --duration 1.5`, on the card at 362 on screen)
/// opens SwiftUI's `.contextMenu` and this one alike. Reference harness
/// only.
enum ContextMenuOpener {
  static func open(at point: CGPoint) {
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
      let (view, interaction) = find(in: window) else {
      NSLog("ContextMenuOpener: no UIContextMenuInteraction")
      return
    }
    NSLog("ContextMenuOpener: \(type(of: interaction)) on \(type(of: view))")
    let sel = NSSelectorFromString("_presentMenuAtLocation:")
    guard interaction.responds(to: sel) else {
      var count: UInt32 = 0
      if let list = class_copyMethodList(UIContextMenuInteraction.self, &count) {
        for i in 0..<Int(count) {
          let name = NSStringFromSelector(method_getName(list[i]))
          if name.lowercased().contains("present") { NSLog("ContextMenuOpener: has \(name)") }
        }
        free(list)
      }
      return
    }
    typealias Fn = @convention(c) (AnyObject, Selector, CGPoint) -> Void
    let fn = unsafeBitCast(interaction.method(for: sel), to: Fn.self)
    fn(interaction, sel, view.convert(point, from: window))
  }

  private static func find(in view: UIView) -> (UIView, UIContextMenuInteraction)? {
    if let i = view.interactions.compactMap({ $0 as? UIContextMenuInteraction }).first {
      return (view, i)
    }
    for sub in view.subviews { if let f = find(in: sub) { return f } }
    return nil
  }
}

// MARK: - TipKit references (`-controls tips`, `tipsdark`, `tippopover`).

@available(iOS 26.0, *)
struct FavoriteReferenceTip: Tip {
  var title: Text { Text("Save as a Favorite") }
  var message: Text? { Text("Your favorite places always appear at the top of the list.") }
  var image: Image? { Image(systemName: "star") }
  var actions: [Action] {
    [Action(id: "learn", title: "Learn More"), Action(id: "later", title: "Not Now")]
  }
}

@available(iOS 26.0, *)
struct SwipeReferenceTip: Tip {
  var title: Text { Text("Swipe to Delete") }
  var message: Text? { Text("Swipe left on a row to remove it.") }
}

@available(iOS 26.0, *)
struct FilterReferenceTip: Tip {
  var title: Text { Text("Add a Filter") }
  var message: Text? { Text("Narrow the list down to what matters.") }
  var image: Image? { Image(systemName: "line.3.horizontal.decrease.circle") }
}

/// Resets TipKit and shows every tip, once per launch.
@available(iOS 26.0, *)
enum TipReferenceSetup {
  static let once: Void = {
    try? Tips.resetDatastore()
    Tips.showAllTipsForTesting()
    try? Tips.configure([.displayFrequency(.immediate)])
  }()
}

/// Two inline tips 16 pt from the sides, the first's top at y=100: an
/// image, title, message and two actions; then a title and message only
/// 40 pt below. White (or black when [dark]) 402 x 874 page.
@available(iOS 26.0, *)
struct TipsReference: View {
  var dark = false
  init(dark: Bool = false) { self.dark = dark; _ = TipReferenceSetup.once }
  var body: some View {
    VStack(spacing: 40) {
      TipView(FavoriteReferenceTip())
      TipView(SwipeReferenceTip())
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.top, 100)
    .frame(width: 402, height: 874, alignment: .top)
    .background(dark ? Color.black : Color.white)
    .ignoresSafeArea()
    .environment(\.colorScheme, dark ? .dark : .light)
    .statusBarHidden(true)
  }
}

/// A 44 pt filter glyph centred at (201, 300) on white with a popover tip.
@available(iOS 26.0, *)
struct TipPopoverReference: View {
  var dark = false
  init(dark: Bool = false) { self.dark = dark; _ = TipReferenceSetup.once }
  var body: some View {
    ZStack(alignment: .top) {
      (dark ? Color.black : Color.white).ignoresSafeArea()
      Image(systemName: "line.3.horizontal.decrease.circle")
        .font(.system(size: 28))
        .frame(width: 44, height: 44)
        .popoverTip(FilterReferenceTip())
        .position(x: 201, y: 300)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea()
    .environment(\.colorScheme, dark ? .dark : .light)
    .statusBarHidden(true)
  }
}

/// Zoom navigation transition (iOS 26 `.navigationTransition(.zoom)` +
/// `.matchedTransitionSource`): a 160 x 200 blue card (24 pt corners)
/// centred at (120, 300) on white; tapping it pushes a solid orange page
/// that zooms out of it. `-controls zoommotion` pops 1.5 s after the push
/// (push + pop timing); `-controls zoomdrag` stays for a drag-to-dismiss
/// take. `tool/reference/measure_zoom.py` tracks the orange box per frame.
@available(iOS 26.0, *)
struct ZoomMotionReference: View {
  var autoPop: Bool
  @Namespace private var ns
  @State private var path: [Int] = []
  var body: some View {
    NavigationStack(path: $path) {
      ZStack(alignment: .topLeading) {
        Color.white
        RoundedRectangle(cornerRadius: 24)
          .fill(Color.blue)
          .frame(width: 160, height: 200)
          .matchedTransitionSource(id: "card", in: ns)
          .position(x: 120, y: 300)
          .onTapGesture { path = [1] }
      }
      .frame(width: 402, height: 874)
      .ignoresSafeArea()
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: Int.self) { _ in
        Color.orange
          .ignoresSafeArea()
          .toolbar(.hidden, for: .navigationBar)
          .navigationTransition(.zoom(sourceID: "card", in: ns))
          .onAppear {
            guard autoPop else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { path = [] }
          }
      }
    }
    .environment(\.colorScheme, .light)
    .statusBarHidden(true)
  }
}

// MARK: - TextEditor and scroll indicators (GlassTextEditor,
// GlassScrollIndicators). Laid out the same way in
// example/lib/editor_twins.dart.

/// `-controls <scene>` for the editor and scroll-indicator references,
/// chained after ControlScenes in SceneDelegate.
enum EditorScenes {
  static let sample = (1...24).map {
    "Line \($0): the quick brown fox jumps over the lazy dog."
  }.joined(separator: "\n")

  static func install(in window: UIWindow?) -> Bool {
    guard #available(iOS 26.0, *), let which = LaunchArgs.arg("controls") else { return false }
    let root: AnyView
    switch which {
    case "texteditor": root = AnyView(TextEditorReference(dark: false))
    case "texteditordark": root = AnyView(TextEditorReference(dark: true))
    case "texteditorfocus": root = AnyView(TextEditorReference(dark: false, focus: true))
    case "texteditorempty": root = AnyView(TextEditorReference(dark: false, empty: true))
    case "scrollindicators": root = AnyView(ScrollIndicatorsReference(dark: false))
    case "scrollindicatorsdark": root = AnyView(ScrollIndicatorsReference(dark: true))
    // Measurement scenes: each also writes its UIKit view tree to
    // `<tmp>/viewdump.json` every second, and the scroll ones trace the
    // indicator to `<tmp>/indicator-trace` (ViewDump below).
    case "calendargraphical": root = AnyView(GraphicalCalendarReference(time: false))
    case "calendargraphicaltime": root = AnyView(GraphicalCalendarReference(time: true))
    case "datewheeldump": root = AnyView(DateWheelReference())
    case "timewheeldump": root = AnyView(TimeWheelReference())
    case "scrollindicatorstrace": root = AnyView(ScrollIndicatorsReference(dark: false))
    case "scrollindicatorstracedark": root = AnyView(ScrollIndicatorsReference(dark: true))
    case "scrollindicatorslong": root = AnyView(ScrollIndicatorsReference(dark: false, rows: 2000))
    default: return false
    }
    window?.rootViewController = UIHostingController(rootView: root)
    window?.makeKeyAndVisible()
    if ["calendargraphical", "calendargraphicaltime", "datewheeldump", "timewheeldump"].contains(which) {
      ViewDump.start(scene: which)
    } else if which.hasPrefix("scrollindicatorstrace") || which == "scrollindicatorslong" {
      ViewDump.start(scene: which)
      ViewDump.traceIndicators()
    }
    return true
  }
}

/// en_US, 6 Oct 2026 09:41, white page: a `.graphical` date picker 370 pt
/// wide (16 pt from the sides) centred at 201, 230 and, below it, one at
/// its own size (`fixedSize`) centred at 201, 650. With `time`, a single
/// 370-pt date-and-time graphical picker centred at 201, 340.
@available(iOS 26.0, *)
struct GraphicalCalendarReference: View {
  let time: Bool
  @State private var date = Calendar(identifier: .gregorian).date(
    from: DateComponents(year: 2026, month: 10, day: 6, hour: 9, minute: 41))!
  var body: some View {
    Page {
      if time {
        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
          .datePickerStyle(.graphical).labelsHidden().frame(width: 370)
          .position(x: 201, y: 340)
      } else {
        DatePicker("", selection: $date, displayedComponents: .date)
          .datePickerStyle(.graphical).labelsHidden().frame(width: 370)
          .position(x: 201, y: 230)
        DatePicker("", selection: $date, displayedComponents: .date)
          .datePickerStyle(.graphical).labelsHidden().fixedSize()
          .position(x: 201, y: 650)
      }
    }
  }
}

/// Reference harness only. Writes the key window's visible UIKit views
/// (class, frame in window points, alpha, background RGBA, corner radius,
/// label text and font size) to `<tmp>/viewdump.json` every second for
/// 40 s, so geometry is read from UIKit rather than from pixels. Trace
/// mode also logs, every display frame for 20 s, the first scroll view's
/// offset and each `*Indicator*` view's window frame and presentation
/// opacity to `<tmp>/indicator-trace` (t from launch).
enum ViewDump {
  private static var timer: Timer?
  private static var link: CADisplayLink?
  private static var t0 = CACurrentMediaTime()
  private static var lines: [String] = []

  private static var window: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
  }

  static func start(scene: String) {
    timer?.invalidate()
    link?.invalidate()
    link = nil
    t0 = CACurrentMediaTime()
    let directory = FileManager.default.temporaryDirectory
    for name in ["viewdump.json", "indicator-trace"] {
      try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
    try? scene.write(
      to: directory.appendingPathComponent("measurement-scene"),
      atomically: true, encoding: .utf8)
    var n = 0
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
      n += 1
      if n > 40 { t.invalidate() }
      write()
    }
  }

  private static func rgba(_ c: UIColor?) -> [Double]? {
    guard let c else { return nil }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    guard c.getRed(&r, green: &g, blue: &b, alpha: &a),
          [r, g, b, a].allSatisfy({ $0.isFinite }) else { return nil }
    return [r, g, b, a].map { Double($0) }
  }

  // UIKit can expose non-finite geometry while wheel rows are transformed.
  // Keep the hierarchy readable and mark those values explicitly as null.
  private static func jsonValue(_ value: Any) -> Any {
    if let number = value as? NSNumber {
      return number.doubleValue.isFinite ? value : NSNull()
    }
    if let values = value as? [Any] { return values.map(jsonValue) }
    if let values = value as? [String: Any] { return values.mapValues(jsonValue) }
    return value
  }

  private static func write() {
    guard let window else { return }
    var out: [[String: Any]] = []
    func walk(_ v: UIView, _ depth: Int) {
      if v.isHidden || v.alpha < 0.01 { return }
      let f = v.convert(v.bounds, to: window)
      var e: [String: Any] = [
        "c": String(describing: type(of: v)), "d": depth,
        "x": f.minX, "y": f.minY, "w": f.width, "h": f.height,
        "a": v.alpha, "r": v.layer.cornerRadius,
      ]
      if let bg = rgba(v.backgroundColor) { e["bg"] = bg }
      if let l = v as? UILabel {
        e["t"] = l.text ?? ""; e["fs"] = l.font.pointSize
        if let tc = rgba(l.textColor) { e["tc"] = tc }
      }
      if let s = v as? UIScrollView { e["oy"] = s.contentOffset.y; e["ch"] = s.contentSize.height }
      if let picker = v as? UIDatePicker {
        e["date"] = ISO8601DateFormatter().string(from: picker.date)
      }
      if let picker = v as? UIPickerView {
        e["components"] = (0..<picker.numberOfComponents).map { component in
          var value: [String: Any] = ["selectedRow": picker.selectedRow(inComponent: component)]
          let width = picker.rowSize(forComponent: component).width
          if width.isFinite { value["width"] = width }
          return value
        }
      }
      if let i = v as? UIImageView, let img = i.image { e["img"] = "\(img.size)" }
      out.append(e)
      for s in v.subviews { walk(s, depth + 1) }
    }
    walk(window, 0)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("viewdump.json")
    if let data = try? JSONSerialization.data(withJSONObject: jsonValue(out)) { try? data.write(to: url, options: .atomic) }
  }

  static func traceIndicators() {
    lines = []
    let l = CADisplayLink(target: Ticker.shared, selector: #selector(Ticker.tick))
    l.add(to: .main, forMode: .common)
    link = l
  }

  fileprivate static func sample() {
    let t = CACurrentMediaTime() - t0
    guard let window else { return }
    var scroll: UIScrollView?
    var bars: [UIView] = []
    func walk(_ v: UIView) {
      if scroll == nil, let s = v as? UIScrollView { scroll = s }
      if String(describing: type(of: v)).contains("Indicator") { bars.append(v) }
      v.subviews.forEach(walk)
    }
    walk(window)
    var line = String(
      format: "%.4f oy=%.2f dragging=%d decelerating=%d",
      t, scroll?.contentOffset.y ?? .nan,
      scroll?.isDragging == true ? 1 : 0, scroll?.isDecelerating == true ? 1 : 0)
    for b in bars {
      let f = b.convert(b.bounds, to: window)
      let op = b.layer.presentation()?.opacity ?? b.layer.opacity
      line += String(format: " | %@ x=%.2f y=%.2f w=%.2f h=%.2f op=%.3f a=%.3f hid=%d",
        String(describing: type(of: b)), f.minX, f.minY, f.width, f.height, op, b.alpha, b.isHidden ? 1 : 0)
    }
    lines.append(line)
    if t > 20 {
      link?.invalidate(); link = nil
      let url = FileManager.default.temporaryDirectory.appendingPathComponent("indicator-trace")
      try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
  }

  private final class Ticker: NSObject {
    static let shared = Ticker()
    @objc func tick() { ViewDump.sample() }
  }
}

/// Top: a bare TextEditor (362 x 160, centre 201, 130) on a yellow frame so
/// its text inset shows. Bottom: the same editor inside a 24 pt glass rect
/// (362 x 200, centre 201, 400), scrollContentBackground hidden, over a
/// mid-grey band (y 280-520). `focus` focuses the glass editor (keyboard
/// up); `empty` leaves both empty with a "Notes" placeholder overlay.
@available(iOS 26.0, *)
struct TextEditorReference: View {
  let dark: Bool
  var focus = false
  var empty = false
  @State private var top = ""
  @State private var text = ""
  @FocusState private var focused: Bool
  var body: some View {
    ZStack(alignment: .topLeading) {
      (dark ? Color.black : Color.white)
      Color(white: 0.5).frame(width: 402, height: 240).position(x: 201, y: 400)
      TextEditor(text: $top)
        .frame(width: 362, height: 160)
        .background(Color.yellow.opacity(0.4))
        .position(x: 201, y: 130)
      ZStack(alignment: .topLeading) {
        TextEditor(text: $text)
          .scrollContentBackground(.hidden)
          .focused($focused)
        if text.isEmpty {
          Text("Notes").foregroundStyle(.secondary)
            .padding(.top, 8).padding(.leading, 5)
            .allowsHitTesting(false)
        }
      }
      .padding(.horizontal, 11).padding(.vertical, 5)
      .frame(width: 362, height: 200)
      .glassEffect(.regular, in: .rect(cornerRadius: 24))
      .position(x: 201, y: 400)
    }
    .frame(width: 402, height: 874)
    .ignoresSafeArea(.container)
    .environment(\.colorScheme, dark ? .dark : .light)
    .preferredColorScheme(dark ? .dark : .light)
    .statusBarHidden(true)
    .onAppear {
      if !empty { top = EditorScenes.sample; text = EditorScenes.sample }
      if focus { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true } }
    }
  }
}

/// A full-screen plain ScrollView of 60 rows (44 pt) that flashes its
/// indicators on appear; swipe it to record the indicator's fade.
@available(iOS 26.0, *)
struct ScrollIndicatorsReference: View {
  let dark: Bool
  var rows = 60
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(0..<rows, id: \.self) { i in
          Text("Row \(i)").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 16)
        }
      }
    }
    .scrollIndicators(.visible)
    .scrollIndicatorsFlash(onAppear: true)
    .background(dark ? Color.black : Color.white)
    .environment(\.colorScheme, dark ? .dark : .light)
    .preferredColorScheme(dark ? .dark : .light)
    .statusBarHidden(true)
  }
}

// MARK: - Inspector, safeAreaBar and the page-style TabView.

/// A "Notes" navigation stack over a white list with an `.inspector`
/// ("Details", Font/Size rows) presented 0.5 s after launch: a sheet on a
/// compact iPhone, a trailing column on a regular-width iPad. With
/// `autoToggle` it closes and reopens every 2.5 s for present/dismiss
/// recordings.
@available(iOS 26.0, *)
struct InspectorReference: View {
  var dark = false
  var autoToggle = false
  @State private var shown = false
  var body: some View {
    NavigationStack {
      List(0..<30) { i in Text("Note \(i + 1)") }
        .navigationTitle("Notes")
        .toolbar {
          Button {
            shown.toggle()
          } label: { Image(systemName: "info.circle") }
        }
        .inspector(isPresented: $shown) {
          Form {
            Section("Text") {
              LabeledContent("Font", value: "SF Pro")
              LabeledContent("Size", value: "17 pt")
            }
          }
          .navigationTitle("Details")
        }
    }
    .environment(\.colorScheme, dark ? .dark : .light)
    .statusBarHidden(true)
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shown = true }
      guard autoToggle else { return }
      Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in shown.toggle() }
    }
  }
}

/// 40 alternating orange/blue 60 pt rows under a `.safeAreaBar` at the top
/// (a glass "Filter" capsule) and another at the bottom (a glass "3 drafts"
/// capsule and a large glass "Compose" button). Drag the rows to see the
/// scroll edge effect under the bars.
@available(iOS 26.0, *)
struct SafeAreaBarReference: View {
  var dark = false
  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(0..<40) { i in
          Text("Row \(i + 1)")
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(.horizontal, 16)
            .background(i % 2 == 0 ? Color.orange : Color.blue)
        }
      }
    }
    .safeAreaBar(edge: .top) {
      Text("Filter")
        .padding(.horizontal, 16).frame(height: 44)
        .glassEffect()
    }
    .safeAreaBar(edge: .bottom) {
      HStack {
        Text("3 drafts").padding(.horizontal, 16).frame(height: 44).glassEffect()
        Spacer()
        Button("Compose") {}.buttonStyle(.glass).controlSize(.large)
      }
      .padding(.horizontal, 16)
    }
    .environment(\.colorScheme, dark ? .dark : .light)
    .statusBarHidden(true)
  }
}

/// A `.page` TabView of four colour pages ("Page 1"…"Page 4") filling the
/// screen, index dots at the default display mode; `background` adds
/// `.indexViewStyle(.page(backgroundDisplayMode: .always))`.
@available(iOS 26.0, *)
struct PageStyleReference: View {
  var background = false
  var dark = false
  @State private var page = 0
  let colors: [Color] = [.orange, .blue, .green, .purple]
  var body: some View {
    TabView(selection: $page) {
      ForEach(0..<4) { i in
        ZStack {
          colors[i]
          Text("Page \(i + 1)").font(.largeTitle).foregroundStyle(.white)
        }
        .tag(i)
      }
    }
    .tabViewStyle(.page)
    .indexViewStyle(.page(backgroundDisplayMode: background ? .always : .automatic))
    .ignoresSafeArea()
    .environment(\.colorScheme, dark ? .dark : .light)
    .statusBarHidden(true)
  }
}
