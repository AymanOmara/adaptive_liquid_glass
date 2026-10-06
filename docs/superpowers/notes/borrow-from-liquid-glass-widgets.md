# What to borrow from liquid_glass_widgets 1.10.0 (2026-10-06)

Source: pub.dev `liquid_glass_widgets` 1.10.0, MIT (Sebastian Degenaar; engine
from `liquid_glass_renderer`, Tim Lehmann, MIT). Copied code keeps its
copyright header plus an ATTRIBUTION note. No dependency is added: their
look is hand-tuned, ours is fitted to SwiftUI, and they need Flutter ≥ 3.41.

Rule for every item: our fitted constants and the fidelity bars stay the
judge. An item lands only if `tool/fidelity` shows no scene regresses.

## A. Fidelity fixes (shader)

| # | Borrow | From | Our gap |
|---|---|---|---|
| A1 | Continuous corner: corner zone `1.528·r`, exponent derived from `r/zone` so the curve meets the circle's 45° point and decays to n=2 on pills | `shaders/sdf.glsl` `sdfSquircle` | `sdSuperellipseBox` uses zone = r + fixed `cornerExponent`; clear-rect16/28 edge band ΔE 6-7 (8 scenes) |
| A2 | Size/fill from the merged blob, not per shape | `liquid_glass_geometry_blended.frag` | merge-gap4/16 interior too bright |

## B. Enhance existing components

| # | Component | Borrow | From |
|---|---|---|---|
| B1 | GlassButton / pressable | Anchor stretch: capsule rubber-bands toward a finger dragged past the edge, springs back on release (ours stretches only by touch position inside) | `src/engine/stretch.dart` |
| B2 | GlassPressable | Visible keyboard focus ring (iPad/macOS, hardware keyboard); we take focus but draw nothing | `widgets/shared/glass_focus_ring_painter.dart` |
| B3 | All controls | Semantics audit per their #381/#387: one node per control, label replaces visible text, `semanticLabel` overrides on picker/menu/popover/search, dismiss action on barriers | CHANGELOG 1.10.0 |
| B4 | GlassToggle | Controlled-value reconcile after a rejected/unchanged drag (their #383) | `glass_switch.dart` |
| B5 | GlassMenu | `glideTo / endGlide / cancelGlide` on a controller, so an outer long-press can drive slide-to-select | `glass_menu.dart` (PR #384) |
| B6 | Scroll edge | Progressive (graduated) blur shader for the edge instead of a uniform blur + fade | `shaders/progressive_blur.frag`, `effects/progressive_blur.dart` |
| B7 | Sheet | Dark colour that follows appearance changes while open | `glass_modal_sheet.dart` (PR #385) |
| B8 | Startup | `initialize()` preloads `FragmentProgram`s async before frame 1 | `liquid_glass_setup.dart` |

## C. New components (they have, we don't)

Each needs a Material counterpart for Android, like every component we ship.

| Priority | Component | Notes |
|---|---|---|
| high | GlassTextField / password / text area | we only have the search field |
| high | GlassListTile + grouped section | Settings-style lists |
| high | GlassToast | |
| medium | GlassChip, GlassBadge | |
| medium | GlassPageControl | |
| medium | GlassActionSheet | |
| medium | GlassProgressIndicator | |
| low | GlassButtonGroup | may be covered by GlassToolbar |

## Skip

Adaptive quality/benchmarking, content-adaptive strength (1.2×/0.8×), iOS 27
presets, gyroscope lighting, iPhone Duo vertical bars: either already measured
by us, or out of scope.

## Last: usability pass (queued, see memory)

After A-C: borrow their onboarding shape — one-call setup
(`initialize()` + wrap), a "choose the right widget" table in the README,
and a consumer `skills/SKILL.md` for AI coding tools.
