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

System button fills and disabled labels (measured 2026-10-30): build/install
once, then capture `-controls systembuttons` and `systembuttonsdark` both
with and without `-buttonBackground gray`. Save these as
`systembuttons-light.png`, `systembuttons-dark.png`,
`systembuttons-light-gray.png`, `systembuttons-dark-gray.png`, then run:

```sh
tool/fidelity/.venv/bin/python tool/reference/measure_system_buttons.py <captures> > tool/reference/system_buttons.json
flutter test test/reference/system_buttons_reference_test.dart
```

The fixture samples enabled/disabled default bordered, tinted bordered,
destructive bordered, tinted prominent and destructive prominent buttons.
The independent regression composites the Flutter fills/ink over both
backgrounds and permits one channel value of raster rounding. Pressed states,
high-contrast colours and non-glass geometry are not measured by this fixture.

System-button presses (iOS 26.4, measured 2026-10-30): the reference scene
also has borderless, plain and destructive-borderless rows at y=600/700/800.
For each light/dark scene, capture x=100 at these rows:
neutral=100, tinted=200, destructive=300, prominent=400,
destructive-prominent=500, borderless=600, plain=700,
destructive-borderless=800. Example for the light neutral button:

```sh
UDID=<simulator> SKIP_BUILD=1 TAKES=ref WARMUP=0 \
  GESTURE='tap 100 100 --duration 0.8' SPAN=0.8 POST=2 \
  CROP=180,225,240,150 tool/fidelity/record_component_motion.sh \
  build/motion/system-buttons-v2 systembuttons neutral-light
```

Use `systembuttonsdark` and `*-dark` for dark mode. Crop top is `y*3-75`.
After all 16 takes (each must include a held plateau and return to idle):

```sh
tool/fidelity/.venv/bin/python tool/reference/measure_system_button_press.py build/motion/system-buttons-v2 > tool/reference/system_button_press.json
flutter test test/reference/system_button_press_reference_test.dart
```

`TAKES=twin WARMUP=1` records the Flutter counterpart in the same layout.
The fixture's release samples are the plain light label's red channel,
starting at its last held frame and ending at its first idle frame at 60 Hz.
The fit measures visual release after highlight recognition; it does not
measure pointer-to-highlight latency. Repeated display frames remain in the
samples, so tests use RMS error rather than requiring every frame identical.

Default system-button layout (measured 2026-10-30): build and install the
example on the booted iPhone 17 Pro/iOS 26.4 reference simulator, then run:

```sh
python3 tool/reference/capture_system_button_geometry.py <simulator-uuid> --output tool/reference/system_button_geometry.json
flutter test test/reference/system_button_geometry_reference_test.dart
```

This launches four native scenes (`systembuttongeometry`,
`systemprominentgeometry`, `systemborderlessgeometry`, `systemplaingeometry`).
Each observes the intrinsic text/icon label and styled-button size for all
five control sizes using GeometryReader backgrounds before positioning.
Unlike screenshot ink bounds, these yield actual horizontal layout padding:
10/12/20 points for small/regular/large groups. Plain ignores control size.
Heights and icon-only capsule sizes agree with the glass reference.
The widget reference tests compare rendered padding, heights, inherited font
selection and icon-only bounds; they do not compare Cupertino glyph artwork
to SF Symbols or non-default Dynamic Type sizes.

Touch-to-highlight latency (measured 2026-10-30) uses the simulator-only
passive `FrameDumpTouchObserver`. It records `CACurrentMediaTime()` when UIKit
receives down, then immediately fails its recognizer without delaying or
cancelling other gestures. The component recorder preserves actual image
capture times (`frameTimes`) and observed touches in `times.json`, including
when display frames are repeated. This removes host/idb launch time from the
latency calculation.

Capture three warmed light borderless takes at (100,600), with `TAKES='ref
twin' WARMUP=1 GESTURE='tap 100 600 --duration 0.5' SPAN=0.5 POST=1
CROP=180,1725,240,150`, then score them:

```sh
tool/fidelity/.venv/bin/python tool/reference/measure_button_onset.py build/motion/button-onset-after/take-*.ref build/motion/button-onset-after/take-*.twin
```

`system_button_onset.json` preserves before/after data from three takes per
renderer: Flutter median 149 ms before, 49 ms after immediate pointer visuals;
SwiftUI median about 15 ms in both sets. The residual two-frame gap is an
observation in simulator debug builds, not a hardware latency measurement or
an attribution to a particular rendering stage. The scorer rejects missing
labels, ambiguous touches and highlights preceding touch delivery by more
than a display frame.
