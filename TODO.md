1- match the flutter shader with native navigation bar  
2-check the other main components that could be added
3-[done 2026-10-07] update the readme according the current code status
4-add more Swift-UI components
5-tab bar vs native iOS 26 (details: docs/superpowers/notes/tabbar-todo.md)
  Medium:
  - unselected labels sometimes flip to white in native mode over the photo
  - accessory scene (5.06 native / 6.21 shader)
  - frame-by-frame comparison of press and drag motion
  Hard:
  - selected blue shifting with the colours behind it, as native's does
  - retune the shader-mode glass over photos (5.44 light, 4.50 dark)

6-fidelity group 4: clear glass edges (~11 scenes: clear text + photo, all shapes)
  - deltaE already passes (0.7-2.1); SSIM fails at the edge band (0.90-0.94)
  - measure SwiftUI's edge lens precisely (tool/fidelity/measure_lens.py), then refit
    edge refraction + rim; try liquid_glass_widgets' curved-glass lens profile
  - research task; baseline build/fidelity/release-dev7 (46/75)

7-components from docs/superpowers/notes/component-gap.md (2026-10-07)
  In progress: GlassDisclosureGroup, GlassEmptyState, showGlassFullScreenCover, GlassGauge
  Next (medium): pull to refresh (refreshable), searchable presentation,
  GlassWheelPicker, date picker upgrades (graphical, time, wheel)
  Later: keyboard toolbar, share link, colour picker, tabBarMinimizeBehavior,
  sidebarAdaptable, zoom transitions, TipKit tips
