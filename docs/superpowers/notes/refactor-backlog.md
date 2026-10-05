# Refactor backlog (post-Task-17d review, 2026-10-05)

P2 items were fixed on `feat/phase1-core` (see CHANGELOG). The P3 items
below are recorded, not scheduled — do them opportunistically.

- **P3-1** `lib/src/core/glass_constants.dart` (769 lines): three types +
  ~170 lines of frozen fitted data. Optional split of the model classes
  from `GlassConstants.standard`; or generate the Dart data from
  `tool/fidelity/standard_constants.json`. Only worth it if the 17-series
  keeps editing constants.
- **P3-2b** (re-review follow-up): extract `GlassGroupScope` to its own
  `glass_group_scope.dart` to break the (safe, const-only) import cycle
  native_glass_layer ⇄ glass_group.dart. Mechanical import shuffle; three
  consumers.
- **P3-3** `lib/src/group/glass_member.dart:27-28`: mutable top-level
  `glassShaderProgram` is a test seam living in shipped code. Move to a
  `@visibleForTesting` static on `GlassProgram`.
- **P3-4** `lib/src/interaction/press_controller.dart:59-67` vs
  `morph_controller.dart:168-175`: press uses `.then` on a `TickerFuture`
  where morph uses `whenCompleteOrCancel`; unify on the morph shape.
- **P3-5** Swift-side native logic (settle frames `GlassPlatformView.swift:
  299-350`, dark-retheme generation rebuild :221-241, deinit/host
  containment :247-267) runs only in `example/integration_test/
  native_swiftui_test.dart` on a simulator — never in `flutter test`.
  Inherent (no Swift unit target), but these are the least-protected paths
  of the N1 merge; touch them only with that test running.
- **P3-6** `lib/src/foreground/glass_foreground.dart`: `GlassForeground` is
  fully exported from the barrel though only `labelColorOf` /
  `backgroundBrightnessOf` are plausibly public. Either `show` those or
  document it as deliberate helper API.

Clean, do-not-refactor (from the same review): `lib/src/shader/` (uniform
layout documented in one place, mirrored in the frag header), the iOS Swift
layer's lifecycle, the `Widget.glassEffect → LiquidGlass → GlassMember` API
funnel, deprecation/Reduce-Transparency guards, and the test coverage of
all three merged features (native default, motion, Android Material path).
