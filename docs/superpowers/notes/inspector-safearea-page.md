# Inspector, safeAreaBar, page style (2026-11-13)

Closes three `component-gap.md` rows: `.inspector`, `.safeAreaBar`, and
`TabView` `.page`. All three APIs are additive.

## What shipped

| SwiftUI | Flutter | File |
|---|---|---|
| `.inspector(isPresented:)` | `GlassInspector` | `lib/src/inspector/` |
| `.safeAreaBar(edge:alignment:spacing:)` | `GlassSafeAreaBar` | `lib/src/safe_area_bar/` |
| `TabView` + `.tabViewStyle(.page)` | `GlassPageView`, `GlassPageIndexDisplayMode` | `lib/src/page_control/glass_page_view.dart` |

Each one has a demo in `example/lib/inspector_safe_area_page_demo.dart` (linked
from the components page) and a SwiftUI reference scene in
`example/ios/Runner/NewComponentScenes.swift`. Launch the scenes with
`-controls inspector | inspectordark | inspectortoggle | safeareabar |
safeareabardark | pagestyle | pagestylebackground`. The Flutter twins use the
same scene names.

## Native observations (iPhone 17 Pro, iOS 26.4)

- **Inspector at compact width:** a sheet that opens at the **large** detent
  (`images/native-inspector-iphone.png`; dark in `native-inspectordark-iphone.png`;
  toggling in `native-inspector-toggle-iphone.mp4`). The Flutter default
  `detents` is `[large]` to match.
- **safeAreaBar:**
  - The top bar sits at the safe top, and the content inset equals the bar's
    height (spacing 0).
  - At rest there is no top fade.
  - The bottom bar sits above the safe bottom. A bottom scroll-edge fade shows
    while content is beneath it.
  - Captures: `native-safeareabar-iphone.png` and `native-safeareabardark-iphone.png`.
- **Page style:** on a plain background the default dots are not visible
  (`native-pagestyle-iphone.png`); `native-pagestylebackground-iphone.png`
  shows them over content.

## Estimated, not measured

- `InspectorMetrics.columnWidth` (320) and `columnAnimation` (350 ms).
- `PageControlMetrics.pageViewBottom` (12 pt above the safe bottom).
- `SafeAreaBarMetrics.topEdgeOverhang` (16): how far the top fade runs past
  the bar.

## Open items

- **No iPad capture of the regular-width inspector column.** The iPad
  simulator kept shutting down, and its recording came out corrupt. The column
  geometry is still estimated.
- **The page-swipe recording was blank** (a 6 KB file), so it was dropped.
  Re-record it when disks and simulators allow.
- **`test/refresh/glass_refresh_scroll_physics_test.dart` ("a release short of the refresh bounces back") fails on Flutter 3.50.0** (62.7 vs >82.3). The refresh code is untouched here, so this predates the work.
- **No pixel side-by-side scores yet** for the three twins (`tool/reference/side_by_side.sh`).
