# Tab Bar Lens — Dedicated Shader Settings Fitted to Kept

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status (rebased 2026-10-06, after the one-class-per-file split and 0.1.0-dev.5):**
> the goal shipped, but not the way this plan first proposed it. Tasks 1–2
> landed in a different design (below). Task 3's fit was made from the
> Kept frames but never written up. What remains is that write-up and the
> verification in Tasks 3 and 5.

**Goal:** Give `GlassTabBar`'s held lens its own shader settings — strong refraction across a ~6–8 pt edge band, visible colour separation, no frosting — fitted to Kept's lens, drawn through the shader even where the bar itself keeps another mode (notably iOS 26 native).

**Architecture (as built):** No shader-file or uniform-layout changes for the lens glass itself. The lens is a `Glass.clear` draw in its own `GlassGroup`, forced to `GlassRenderMode.shader` whenever shaders are supported. `withTabLens` scopes a `LiquidGlassTheme` over that group whose `clear`/`clearDark` slots are replaced by the tab-lens constants. The constants live with the tab bar, not on `GlassConstants`, so the public constants API is unchanged. Separately, a content shader (`shaders/tab_lens_content.frag`) draws the magnified tabs inside the lens, bent inward.

**Tech Stack:** Flutter/Dart (package `adaptive_liquid_glass`), Python fidelity tooling (`tool/fidelity/`), iOS simulator (iPhone 17 Pro, iOS 26.4), ffmpeg for frame extraction.

## Where things live now (post-split)

| Concern | File / symbol |
|---|---|
| Lens constants (light / dark) | `lib/src/tab_bar/tab_lens.dart` — `tabLensLight`, `tabLensDark` |
| Theme scope for the lens group | `tab_lens.dart` — `withTabLens(context, child)` |
| Bar's own glass overrides (UIKit bar fit, pressed fill) | `tab_lens.dart` — `withTabBarGlass(context, child, light:)` |
| Lens wiring in the bar | `lib/src/tab_bar/glass_tab_bar.dart` — `_GlassTabBarState._bar` (`lensShown`, `_shaderLens`, `lensContent`) |
| Magnified tabs inside the lens | `tab_lens_content.dart` (`TabLensContent`) + `tab_lens_program.dart` (`TabLensProgram`) + `shaders/tab_lens_content.frag` |
| Lens / bar geometry | `tab_bar_metrics.dart` — `TabBarMetrics.inset`, `lensRim`, … |
| Fallback (no shader) sharp overlay | `rim_fade.dart` (`RimFade`), used when `!_shaderLens` |
| Hole / end clipping | `hole_clipper.dart`, `lens_ends_clipper.dart`, `capsule_clipper.dart` |
| Bar light while held | `bar_glow.dart` |
| Tests | `test/tab_bar/shader_lens_test.dart` (lens path), `test/tab_bar/glass_tab_bar_test.dart` (bar behaviour) |

## Global Constraints

- Regular and clear glass outside the tab bar render bit-identically: no edits to `shaders/liquid_glass.frag`, `glass_uniforms.dart`, or `tool/fidelity/glass_model.py` for lens work. Lens tuning edits only `tab_lens.dart` numbers.
- No new package dependencies.
- The Material (Android) path keeps `NavigationBar` in a capsule; the lens never forces shader there.
- Kept comparison material: `~/Downloads/edge_zoom.png`, `spike_zoom.png`, and `WhatsApp Video 2026-10-02 at 18.17.00.mp4` (384×848, ~59 fps).

---

### Task 1: Lens constants — **DONE (different design)**

Planned: `GlassConstants.lens` / `lensDark` / `lensOverride` + JSON keys.
Built: `tabLensLight` / `tabLensDark` in `lib/src/tab_bar/tab_lens.dart` (commit `a4abbbd`, refined through `4623aeb`). Final values: `lensBand` 8.25, `lensStrength` 4, `dispersion` 0.3, light `blurSigma` 0.75 with `postBlurShare` 0.9 (see the file's comments for the fit rationale). `GlassConstants` is unchanged, so no JSON migration was needed.

### Task 2: Lens through the shader over any bar mode — **DONE**

Built in `glass_tab_bar.dart` `_bar`: when `_shaderLens` (environment supports shaders), the lens is `withTabLens(context, GlassGroup(mode: shader, child: LiquidGlass(glass: Glass.clear, mode: shader)))`; otherwise it keeps `widget.mode` plus the `RimFade` sharp overlay. Pinned by `shader_lens_test.dart`:
- "on iOS 26 the lens is shader glass over the native bar"
- "an explicit mode wins for the bar"
- "without shader support the lens keeps the native approach"

### Task 3: Kept fit record

The fit was done against the Kept frames (commits `a4abbbd`, `bd0b00f`, `b40ed7f`, `4623aeb`) but no note records it.

**Files:**
- Create: `docs/superpowers/notes/kept-lens-fit.md`

- [ ] **Step 1:** Re-extract 2–3 held-lens frames (`ffmpeg -i "<Kept video>" -vf fps=15 build/fidelity/lens-fit/kept/f%03d.png`) and capture ours on the probe (`cd example && flutter run -t lib/tab_bar_probe.dart`, hold the lens over History, `xcrun simctl io booted screenshot ../build/fidelity/lens-fit/probe-held.png`).
- [ ] **Step 2:** Compose an edge-zoom side-by-side (Kept left, ours right) at the zoom of `edge_zoom.png`.
- [ ] **Step 3:** Write `kept-lens-fit.md`: measured band width, rim pull-in, fringe width for both, the current `tabLensLight`/`tabLensDark` values, and the side-by-side path. Note any remaining mismatch as a follow-up, tuning only `tab_lens.dart`.
- [ ] **Step 4:** Commit `docs: Kept lens fit record`.

### Task 4: Fit loop — **DONE**

Tuned in place in `tab_lens.dart`. Re-open only if Task 3's side-by-side shows a mismatch; use the same one-knob-per-symptom table:

| Symptom | Knob (`tabLensLight` / `tabLensDark`) |
|---|---|
| rim bend too weak / strong | `lensStrength` |
| band too narrow / wide | `lensBand` |
| bend reaches too deep | `lensDecay` |
| fringe missing / too rainbow | `dispersion` |
| milky lens body | `blurSigma`, `postBlurShare`, `frostWide*` |
| edge highlight wrong | `rimWidth`, `rimIntensity` |

### Task 5: Verification still owed

- [ ] **Step 1: Package checks** — `flutter analyze`, `flutter test`, `cd tool/fidelity && .venv/bin/python -m pytest`.
- [ ] **Step 2: Demo** (`~/Android Studio Projects/liquid_glass_demo`, path dependency, `flutter pub get` first):
  - `lib/main_ios26.dart`: native bar, shader lens. Review focus: the rim over the native bar (a platform view) must show refracted Flutter content, not a black or empty band.
  - `lib/main_below26.dart`: everything shader; lens uses the tab-lens set.
  - Reduce Transparency ON → opaque lens, no crash.
- [ ] **Step 3:** CHANGELOG already describes the shader lens (0.1.0-dev.4 entry); add a line only if Task 3/4 changes values.
