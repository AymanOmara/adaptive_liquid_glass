# Remaining limitations work — 2026-10-18

First pass: 6/6 work areas verified. Follow-up requested: 4/4 investigations complete (100%). An item is complete only after its
changes and validation have been reviewed. Remaining platform constraints
stay documented; this work does not imply pixel parity or release readiness.
Scope confirmed by the user: README's Known limitations section; new
components, breaking API changes and the rest of the TODO roadmap are excluded.
Follow-up scope: the user excluded the README “iOS look on Android” section
on 2026-10-19; no further shader styling/memory/order work is included.

- [x] Native iOS limitations: investigate brightness state, press lighting,
  and native tab rendering; validate feasible corrections.
- [x] Android shader limitations: reduce overlay rendering costs while
  preserving positioning, clipping, and transitions.
- [x] Photo picker: bound resource use, expose loading state, and validate
  native builds and picker presentation where available.
- [x] Colour picker: persist the default saved palette across app launches,
  preserving app-controlled palettes and safe fallback without a plugin.
- [x] Eyedropper: test native app capture against actual Flutter/platform
  pixels; retain a wider capture path only if its output is correct.
- [x] Run combined checks, review changes, and update the remaining-work
  documentation with evidence and unresolved constraints.

Validation:

- Runtime native brightness: replacing the entire hosting controller fixed
  the reproduced regular-photo light-to-dark failure (SSIM 0.90125 →
  0.99999966). Required native integration passed 3/3, including repeated
  flips and disposal. Four regular/clear photo flip spot checks passed;
  this pass did not repeat the entire historical 72-case sweep. The README
  brightness limitation was removed only after these checks.
- Final combined Flutter suite: 1,488 tests passed; package and example
  analysis clean. Three press-light fitter tests passed. Latest Android native
  Kotlin compilation passed (41 seconds). Independent regression review passed
  63 focused tests across layers, palette storage/UI and the photos picker.
- iOS 26.4 production eyedropper integration passed: exact Flutter red/blue,
  native frosted-glass pixels, and loupe selection matching the native image.
  Capture/fallback and loupe tests passed, including malformed PNG, invalid
  scale, stale dimensions and missing-plugin fallbacks.

- 121 layer/menu/shader tests; 88 final layer/scaffold tests.
- 55 colour-picker tests, including ordered writes, delayed loading,
  persistence, missing-plugin fallback and app-controlled palettes.
- 36 photo-picker tests; full Android debug APK build; iOS SwiftPM
  simulator build and actual iOS picker presentation.
- iOS palette channel round trip and on-disk JSON contain unsigned ARGB
  colours correctly. Android API 35's actual system picker also presented;
  a cold process restart restored the palette, and cleanup rejected an
  active picker with `already_active`.
- Clear-glass native press lighting: fresh held-frame interior MAE
  6.858 → 6.251 (light), 7.246 → 6.378 (dark). Runs:
  `build/motion/press-clear-native` and
  `build/motion/clear-light-calibrated`; reports `light-fit.json`.

Remaining boundaries tracked during implementation:

- Custom-rendered native tab lenses cannot sample the UIKit bar as a
  Flutter texture. Stock native icon bars now use a complete system control;
  the rejected SwiftUI label-mask bridge remains removed.
- The shader still has 16/75 scenes outside the strict fidelity bars;
  this work does not change the calibrated static glass shader or claim
  that a Gaussian backdrop matches Apple's optical pipeline exactly.
- Full shader effects require engine shader-filter support. Local shared
  scopes preserve batching, but arbitrary overlapping Flutter siblings
  still use `GlassOverlayContent`; hardware GPU measurements remain open.
- Large media must be copied/converted before a usable local path can be
  returned. The old Android document-picker interface cannot enforce a
  multi-selection cap; excess selections remain counted and dropped.
- Optional full-screen-cover drag now has an independently configurable
  app-defined policy, with tested cancellation, resistance and release
  behavior; see `full-screen-cover-drag.md`. SwiftUI still has no such
  gesture, and the extension remains disabled by default.
- Device-only profiling, release/API decisions and new component roadmap
  items in `TODO.md` remain separate open work.

## Follow-up: continue remaining limits

- [x] Native tab vibrancy: test a supported UIKit alternative to the rejected SwiftUI mask bridge.
- [x] Extend the tested native control to bundled Cupertino/Material icon templates.
- [x] Native interactive glass: test whether compositing press transforms after the glass improves refraction and geometry.
- [x] Android eyedropper: validate SurfaceView and window capture composition against actual screen pixels.

The first pass is validated, but remaining README limitations are not treated as fixed.

Follow-up validation, 2026-10-19:

- Real Pixel 8/API 35 integration passed: Flutter red/blue, 50% native green
  overlay correctly composited to RGB 127/128/0, and above-window surface
  rejection. Native source is the compiled production helper, not a mock.
- Found and fixed executor/messenger identity mismatch: FlutterPluginBinding
  passes DartExecutor itself while DartExecutor.binaryMessenger is its inner
  messenger. Either belongs to the same engine; other engines stay excluded.
- The previous SurfaceView prototype's region check was invalid: Flutter's
  TalkBack workaround deliberately subtracts its bounds in
  gatherTransparentRegion. The retained path checks a real transparent window
  hole instead and falls back for custom geometry or reversed z-order.

- Generic clear press re-check: fitting a stretched rest image worsened
  interior MAE to 9.50/255 (current held frame about 6.3). Added blur made
  the error grow beyond a 0.5 px radius; that tiny radius improved less
  than 0.02/255. A free affine correction to held frames improved only
  about 0.03–0.05/255 on a disjoint held window. These offline fits do not
  justify a runtime change or removing the interactive-glass limitation.
- Follow-up combined Flutter regression: 1,495 tests passed, including
  seven new system-tab metadata/eligibility tests; previous 81 tab tests
  also passed independently. Native tab selection/re-theme/fallback
  integration passed, with visual and real-touch validation still pending.


Follow-up validation, 2026-10-23:

- Complete UIKit tab control validated against four SwiftUI stills and real
  press/tap/drag recordings. Native untinted SF Music glyph/label regions
  match exactly; the matched-selection rest recordings have MAE 0–0.0195/255.
- Bundled Cupertino and Material templates preserve Flutter's glyph box,
  normal/selected artwork and RTL direction. The real public GlassTabBar
  fixture contains one actual native controller and passes quick taps,
  opaque Flutter overlay exclusion, recovery, held lens and theme rebuild.
  Its untinted Music label matches the SwiftUI photo reference at MAE 0.
- Full combined Flutter suite: 1,507 tests passed. Final focused template/
  native-widget checks: 20 passed, including latest-wins icon/DPR/direction,
  disposal, reselect, controlled selection and route transitions. The tab
  directory's 100-test pass preceded the extra latest-wins regression.
- Final iOS regression: 7 passed (3 tab lifecycle/image-cache tests,
  3 existing native SwiftUI tests, 1 app-capture test). Actual template
  images are 28 logical points, cache size remains three in the fixture,
  and changing selection reuses native item controllers. A deliberately
  delayed native selection reply cannot replace a newer app update.
- Analysis clean. Flutter 3.35.0 source confirms the old gesture getter is
  absent, required IconData font metadata exists, and native factory
  registration only stores the policy. Minimum-SDK binary builds were not
  repeated; older versions take the existing Flutter-rendered tab path.
- README limitations were narrowed after each successful real-touch check;
  generic shared-glass press, custom tab rendering and platform/file-system
  boundaries remain. Android's iOS styling was left as requested.
