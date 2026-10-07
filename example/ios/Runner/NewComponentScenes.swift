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
