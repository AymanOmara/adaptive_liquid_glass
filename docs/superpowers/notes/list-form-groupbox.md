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

## Open
- Plain list and sidebar list widgets (colours are in `GlassColors`: `plainListBackground`, `sidebarListBackground`, `sidebarListSelection`).
- Twins/demo page, README sections, swipe and sidebar-collapse recordings.
