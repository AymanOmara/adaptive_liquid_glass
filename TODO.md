1- match the flutter shader with native navigation bar  
2-check the other main components that could be added
3-[done 2026-10-07] update the readme according the current code status
4-add more Swift-UI components
5-tab bar vs native iOS 26 (details: docs/superpowers/notes/tabbar-todo.md)
  [done 2026-10-07] easy round 2: badge size/numerals/anchor, search magnifier
  size/weight, lower shader-mode shadow, quick-tap lens hold (~230 ms on iOS 26.4;
  TabBarMetrics.tapHold 200 ms), pill width/spacing/label+icon placement
  (pillExtra 7.98, itemWidth 86.0, pillExtraFilled 10.1, iconDrop 1/3 pt)
  Bar-region mean |diff| native/shader: white 1.24/1.35, photo 1.93/5.14,
  dark 1.23/1.60, dark photo 2.27/3.95, badge 1.65/1.77, searchtab 1.97/2.33,
  accessory 4.48/4.73
  Open: label offsets beside the search tab (~1 pt, UIKit pixel rounding)
  Medium:
  - unselected labels sometimes flip to white in native mode over the photo
  - accessory scene (4.48 native / 4.73 shader)
  - frame-by-frame comparison of press and drag motion
  Hard:
  - selected blue shifting with the colours behind it, as native's does
  - retune the shader-mode glass over photos (5.14 light, 3.95 dark)

6-fidelity group 4: clear glass edges (~11 scenes: clear text + photo, all shapes)
  - deltaE already passes (0.7-2.1); SSIM fails at the edge band (0.90-0.94)
  - measure SwiftUI's edge lens precisely (tool/fidelity/measure_lens.py), then refit
    edge refraction + rim; try liquid_glass_widgets' curved-glass lens profile
  - research task; baseline build/fidelity/g13-2 (55/75)

7-components from docs/superpowers/notes/component-gap.md (2026-10-07)
  [done 2026-10-07] GlassDisclosureGroup, GlassEmptyState (+ .search),
  showGlassFullScreenCover + GlassFullScreenCoverHandle, GlassGauge
  Follow-ups:
  - [done] empty state placement (title/description within 0.33 pt)
  - full-screen cover: transition timing estimated; drag-to-dismiss and
    glass close button not built
  - [done] GlassButton label black like SwiftUI (was 85% black)
  Next (medium): pull to refresh (refreshable), searchable presentation,
  GlassWheelPicker, date picker upgrades (graphical, time, wheel)
  Later: keyboard toolbar, share link, colour picker, tabBarMinimizeBehavior,
  sidebarAdaptable, zoom transitions, TipKit tips

8-fidelity groups 1+3 colour refit [done 2026-10-07]: device 47/75 -> 55/75
  (8 gains, 0 losses), min SSIM 0.9525 (build/fidelity/g13-2)
  Remaining failures:
  - regular rect photo-dark (deltaE ~3.4)
  - regular rect photo-light (deltaE ~2.6)
  - capsule and tinted-capsule photo scenes
  - clear family = item 6
