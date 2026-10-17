import SwiftUI

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
/// `size` centred at `x`, 300 in the safe area (362 on screen).
@available(iOS 26.0, *)
struct UIKitContextMenuReference: View {
  var x: CGFloat = 201
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
          if openOnTap { ContextMenuOpener.open(at: CGPoint(x: x, y: 362)) }
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
        .position(x: x, y: 300)
    }
    .environment(\.colorScheme, .light)
    .onAppear {
      guard !openOnTap else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        ContextMenuOpener.open(at: CGPoint(x: x, y: 362))
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
