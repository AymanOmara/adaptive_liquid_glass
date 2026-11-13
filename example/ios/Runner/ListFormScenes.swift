import SwiftUI
import UIKit

/// `-listform <scene>`: SwiftUI references for the plain and sidebar list
/// styles, `Form` and `GroupBox`, measured for `GlassPlainList`,
/// `GlassSidebarList`, `GlassForm` and `GlassGroupBox`; each has a twin
/// (`-twin <scene>`, example/lib/list_form_twins.dart). Append `dark` to a
/// scene for its dark appearance. The status bar is hidden so the content
/// starts at the same y in both.
enum ListFormScenes {
  static func install(in window: UIWindow?) -> Bool {
    guard #available(iOS 26.0, *), var which = LaunchArgs.arg("listform") else { return false }
    let dark = which.hasSuffix("dark")
    if dark { which = String(which.dropLast(4)) }
    let root: AnyView
    switch which {
    case "plain": root = AnyView(PlainListReference())
    case "plainswipe": root = AnyView(PlainListReference(swipe: true))
    case "sidebar": root = AnyView(SidebarListReference(collapsed: false))
    case "sidebarcollapsed": root = AnyView(SidebarListReference(collapsed: true))
    case "form": root = AnyView(FormReference())
    case "groupbox": root = AnyView(GroupBoxReference())
    default: return false
    }
    let host = UIHostingController(
      rootView: root
        .environment(\.colorScheme, dark ? .dark : .light)
        .statusBarHidden(true))
    host.overrideUserInterfaceStyle = dark ? .dark : .light
    window?.rootViewController = host
    window?.makeKeyAndVisible()
    return true
  }
}

/// A plain list: a header, three text rows, an icon row and a subtitle
/// row; `swipe` opens the second row's trailing actions with a scripted
/// drag (see `swipeActions` below, opened by the test harness).
@available(iOS 26.0, *)
struct PlainListReference: View {
  var swipe = false
  @State private var items = ["Inbox", "Drafts", "Sent", "Junk", "Archive", "Trash"]
  var body: some View {
    List {
      Section {
        ForEach(items, id: \.self) { item in
          Text(item)
            .swipeActions(edge: .trailing) {
              Button(role: .destructive) { items.removeAll { $0 == item } } label: {
                Label("Delete", systemImage: "trash")
              }
              Button {} label: { Label("Flag", systemImage: "flag") }.tint(.orange)
            }
            .swipeActions(edge: .leading) {
              Button {} label: { Label("Unread", systemImage: "envelope.badge") }.tint(.blue)
            }
        }
      } header: { Text("Mailboxes") }
      Section {
        Label("Favourites", systemImage: "star")
        VStack(alignment: .leading, spacing: 2) {
          Text("Subtitle row")
          Text("Secondary line").font(.subheadline).foregroundStyle(.secondary)
        }
      } header: { Text("More") }
    }
    .listStyle(.plain)
  }
}

/// A sidebar list: two collapsible sections of icon rows, the first row
/// selected; `collapsed` starts with the second section collapsed.
@available(iOS 26.0, *)
struct SidebarListReference: View {
  @State private var selection: String? = "Inbox"
  @State private var libraryOpen = true
  @State private var tagsOpen: Bool
  init(collapsed: Bool) { _tagsOpen = State(initialValue: !collapsed) }
  var body: some View {
    NavigationStack {
      List(selection: $selection) {
        Section(isExpanded: $libraryOpen) {
          Label("Inbox", systemImage: "tray").tag("Inbox")
          Label("Drafts", systemImage: "doc").tag("Drafts")
          Label("Sent", systemImage: "paperplane").tag("Sent")
        } header: { Text("Library") }
        Section(isExpanded: $tagsOpen) {
          Label("Work", systemImage: "folder").tag("Work")
          Label("Family", systemImage: "folder").tag("Family")
        } header: { Text("Tags") }
      }
      .listStyle(.sidebar)
      .toolbar(.hidden, for: .navigationBar)
    }
  }
}

/// A form: a text-field section with header and footer, a toggle and
/// picker section, and a button section.
@available(iOS 26.0, *)
struct FormReference: View {
  @State private var name = ""
  @State private var email = "ayman@example.com"
  @State private var notify = true
  @State private var size = 1
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Name", text: $name)
          TextField("Email", text: $email)
        } header: { Text("Account") } footer: { Text("Used to sign in on your devices.") }
        Section {
          Toggle("Notifications", isOn: $notify)
          Picker("Text size", selection: $size) {
            Text("Small").tag(0); Text("Medium").tag(1); Text("Large").tag(2)
          }
        } header: { Text("Preferences") }
        Section {
          Button("Sign Out", role: .destructive) {}
        }
      }
      .toolbar(.hidden, for: .navigationBar)
    }
  }
}

/// GroupBoxes on the system background: one with a label, one without,
/// and one inside a grouped list for comparison with the list platter.
@available(iOS 26.0, *)
struct GroupBoxReference: View {
  var body: some View {
    ZStack(alignment: .top) {
      Color(uiColor: .systemBackground).ignoresSafeArea()
      VStack(spacing: 20) {
        GroupBox {
          Text("Your storage is almost full. Free up space or upgrade your plan.")
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("Storage", systemImage: "internaldrive")
        }
        GroupBox {
          Text("A group box without a label.")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        GroupBox("Nested") {
          GroupBox {
            Text("Inner box").frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 60)
    }
  }
}
