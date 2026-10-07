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
