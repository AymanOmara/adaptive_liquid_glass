# Refactor backlog (post-Task-17d review, 2026-10-05)

P2 items were fixed on `feat/phase1-core` (see CHANGELOG). The P3 items
below are recorded, not scheduled — do them opportunistically.

- **P3-5** Swift-side native logic (settle frames `GlassPlatformView.swift:
  299-350`, dark-retheme generation rebuild :221-241, deinit/host
  containment :247-267) runs only in `example/integration_test/
  native_swiftui_test.dart` on a simulator — never in `flutter test`.
  Inherent (no Swift unit target), but these are the least-protected paths
  of the N1 merge; touch them only with that test running.
  Coverage extended 2026-10-30: seven consecutive appearance flips without
  per-flip settling, disposal immediately after rearming, and recreation with
  a fresh generation/settle count. All four native SwiftUI integration tests
  passed on the iPhone 17 Pro / iOS 26.4 simulator. A standalone Swift unit
  target remains absent. `tool/native/run_ios_tests.sh` and
  `.github/workflows/native-ios.yml` now run lifecycle, batching, tab-bar and
  Swift photo-cache checks together. The first hosted CI run remains unverified.

Done 2026-10-08: P3-2b (already split), P3-3 (`GlassProgram.memberProgram`),
P3-4 (kept `.then`: cancel must not snap; documented in press_controller).

Done 2026-10-14: P3-1 (the model classes were already in their own files;
the frozen `GlassConstants.standard` data moved to the part file
`glass_constants_standard.dart`), P3-6 (kept the full export: the README
documents `GlassForeground.labelColorOf`, and `show` cannot hide a class's
members; documented on the class as deliberate helper API).

Clean, do-not-refactor (from the same review): `lib/src/shader/` (uniform
layout documented in one place, mirrored in the frag header), the iOS Swift
layer's lifecycle, the `Widget.glassEffect → LiquidGlass → GlassMember` API
funnel, deprecation/Reduce-Transparency guards, and the test coverage of
all three merged features (native default, motion, Android Material path).
