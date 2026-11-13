# List / Form / GroupBox measurements (iOS 26, SwiftUI)

References: `example/ios/Runner/ListFormScenes.swift` (`-listform <scene>`, `dark` suffix).
Captures: `images/listform-native-*.png` (form, groupbox, plain, sidebar, sidebarcollapsed; light and dark).

## Form (`FormMetrics`)
- First platter 42.33 pt below the safe top under an "Account" header → top inset 14.33 + header line 16 + header gap 11.83.
- Section to section without captions: 35. Across a footer and a header: 76 platter to platter (footer gap 10.33 + 16 footer line + 24 + 16 header line + 11.83 ≈ 76).
- Bottom inset 20; the keyboard inset replaces the bottom safe area.
- Material: 16 top/bottom, 24 between cards.

## GroupBox (`GroupBoxMetrics`)
- Corner radius 8 (superellipse), padding 16.
- Label 17 pt semibold; icon 20 pt, 13 pt to the title.
- Label → content 4.67; label → nested box 13.
- Fills alternate by nesting depth (`groupBoxBackground` / `groupBoxNestedBackground`).

## Separators
- A swipeable row (`GlassSwipeActions`) around a tile with a leading insets its separator under the title (`hasLeading`).

## Plain and sidebar lists

- `GlassPlainList` and `GlassSidebarList` are implemented. The reference
  scenes and Flutter twins include `plain`, `sidebar`, `sidebarcollapsed`
  and `sidebarsplit`.
- In the saved iPhone sidebar captures, the platter and row boundaries
  match within one physical pixel in both appearances. The selected-row
  fill matches at RGB (209, 209, 214) in light mode and (58, 58, 60) in dark
  mode. These samples come from x = 350 pt, clear of the row labels.
- The plain-list swipe-open pair is saved as
  `images/plain-swipe-open-swiftui.png` and
  `images/plain-swipe-open-flutter.png`.
- The expanded iPad sidebar pair is saved as `images/sidebar-ipad-swiftui.png`
  and `images/sidebar-ipad-flutter.png`; the dark pair uses the `-dark`
  filenames. These use `-listform sidebarsplit[dark]` and
  `-twin sidebarsplit[dark]` on iOS 26.4.
