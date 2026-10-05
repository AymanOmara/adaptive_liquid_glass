# Bars vs native iOS 26.4 — side-by-side re-check (2026-10-05)

iPhone 17 Pro simulator, recordings at 60 fps, frames aligned on the
first change after touch-down.

## Tab bar vs Kept (system tab bar)

| Finding | Before | After |
|---|---|---|
| After release, a lens a hair above zero kept drawing a blurred, refracted ghost of the tab over the pill | ghost stayed until the next touch | press snaps to 0 when the release spring ends; lens drawn only while held or > 2 % grown |
| Tap on another tab | lens slid in from the old selection; its wobble leaked into the pill (pill 61 pt tall ~0.4 s later) | lens grows under the finger; wobble scales with the lens (pill 54 pt) |
| Refraction at the lens's top/bottom rims | icon and label ghosted above and below the lens | only the rounded ends refract the tabs; rims refract the bar, as on iOS |
| Release | lens visible ~14 frames after lift | gone in ~8 frames (0.27 s spring), as on iOS |
| Pill at rest | tertiarySystemFill (42) | secondarySystemFill (Kept 58 on its bar) |
| Lens centre during drag (after alignment) | — | within 1–2.75 pt rms (earlier fit) |

Known residuals: Kept's lens rim shows a brighter, rainbow-fringed
highlight than SwiftUI's public `.glassEffect(.clear)` produces; Kept's
bar glass is a little lighter (25 vs 19 at the bar's middle); unselected
labels are 4 % greyer on iOS.

## Navigation bar vs SwiftUI `NavigationStack`

| Finding | Before | After |
|---|---|---|
| Content start under the large title | 7.4 pt too high | large-title area 59.67 pt (measured) |
| Large title after collapsing | still visible in the status-bar area | clipped below the status bar |
| Scroll edge | fade only | fade, plus blur once the title has collapsed |
| Toolbar icons | 16 pt of ink (too small) | 21 pt of ink, as SF |
| Inline title | plain 200 ms fade | blur-to-sharp fade over 230 ms, as iOS 26 |

Bar height, edge inset, action capsule (2 × 51.5 × 44), large-title
baseline and inset match `controls.json` (tested).

Not a bar difference: in the recorded swipe SwiftUI's list keeps its
momentum while the Flutter probe stops — Flutter's scroll physics read the
scripted swipe's final pause as zero velocity.
