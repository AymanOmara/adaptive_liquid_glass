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
