# SwiftUI reference metrics (Phase 2a)

`controls.json` holds button and navigation-bar metrics measured from
SwiftUI on iPhone 17 Pro / iOS 26.4 (`example/ios/Runner/ControlScenes.swift`:
`-controls buttons`, `-controls navbar -scrollY <pt>`). Re-measure: build
the example for the simulator, install it, capture `buttons.png` and
`navbar_<y>.png` into `build/reference/` (Task 1, Step 2 of
`docs/superpowers/plans/2026-10-05-phase2a-button-navbar.md`), then run
`tool/fidelity/.venv/bin/python tool/reference/measure_controls.py build/reference`.
`lib/src/button/glass_button_metrics.dart` and
`lib/src/navigation/nav_bar_metrics.dart` are tested against this file.

Remaining components (label, link, wheel, datewheel, searchactive,
colorrow, coverclose): `tool/reference/capture_more.sh <UDID>` (or
`capture_one.sh <UDID> <scene>`) into `build/reference/swiftui/`, then
`measure_components.py build/reference`; it merges into the existing
"components" section and measures only the captures present.

Sheet side insets by detent height: `-controls sheetheight -height <pt>
[-grabber 0]` presents a SwiftUI `.height(<pt>)` sheet over mid-grey
(measured 2026-10-14: 300-765 float 8 pt in, 775 and up run edge to edge).
