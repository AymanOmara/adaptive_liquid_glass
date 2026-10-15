# Update brief — 2026-10-14

Merged into local `main` (not pushed, not published, version unchanged at 0.2.1).
Analyze clean, 1308 package + 5 example tests pass.

## New / changed
- **GlassRefresh** holds the list down while refreshing, then snaps back,
  as SwiftUI's `.refreshable` (hold 60.0 vs 60.3 pt). New `edgeOffset`.
- **Photos picker**: video `width`/`height`/`duration`; `maxWidth`,
  `maxHeight`, `imageQuality`, `compatibleFormat` (HEIC→JPEG, HEVC→H.264
  on iOS); `clearGlassPickedPhotos()` deletes the temporary copies.
- **Measured against SwiftUI and fixed**: date wheel time columns, search
  (scopes appear after typing; suggestions are a plain list), colour
  picker grid, context menu.
- **Usability**: `initialize()` sets up the Flutter binding itself;
  `tint` is the accent parameter on every control (old names deprecated);
  menu button and alert get defaults; shorter README Getting started.
- **Refactor**: one class per file, all colours via `GlassColors`,
  constants data split out. No behaviour change.

## Round 2
- **Android crash fixed**: the shader tab bar's label snapshot could crash
  Impeller OpenGL ES before the first frame or in the background (1 in 8
  cold launches → 0 in 12).
- **Photos picker**: `conversionFailed` per item, `droppedCount` on the
  result; Android now converts HEVC→H.264 (platform APIs, no new dependency).
- **Measured vs SwiftUI**: refresh triggers mid-drag at 173 pt with a 30-pt
  spinner and no disk; search close-button reveal fitted; colour sheet
  layout within ~1 pt (new `slidersLabel`, `closeLabel`).
- **Fixed**: search suggestions sat ~100 pt low under a navigation bar;
  example quick-start test (failed since 0.2.0).

## Round 3 (2026-10-15)
- **Android shared glass layer**: one glass layer per route draws all
  shader glass in shared passes; Gallery peak +3.9 GB → +0.9 GB, no kills.
  Covered routes free their layer. iOS fidelity unchanged (59/75).
- **`supportLiquidGlassOnAndroid`** in `LiquidGlassThemeData` (and
  `initialize`): iOS look on Android; iOS unaffected.
- **`androidShaderBudget`**: safety cap, now null (off) by default.
- **Colour sheet**: 8-pt inset, saved colours, UIKit spectrum, in-app
  eyedropper. **Refresh**: UIKit rubber band (`GlassRefreshScrollPhysics`),
  dark spinner measured. **Search**: hide motion fitted.
- Shared-layer limits: tab labels not vibrant, rectangular clips, overlapping
  glass shares the largest blur.

## Breaking
- No longer exported: `DatePickerMetrics`, `DatePickerWheelMetrics`,
  `WheelPickerMetrics`, `pressableGlass`.
- Search: the glass suggestions panel is gone; `glass` now styles only the field.

## Findings
- Android vibrancy: was not upside down; README limitation removed.
- Native touch glow: not possible with public APIs
  (`native-touch-glow.md`).
- Android shader mode profiled only on a software emulator
  (`android-shader-profile.md`); a real phone is still needed.

## Left for 1.0
Renames such as `selected` → `value` and `onSelected` → `onPressed`, and
`showGlassToast`'s `context` argument (see `usability-audit.md`).

## Verification
iOS 26.4 simulator: native integration test 3/3, gallery renders clean,
photos picker with real HEIC/JPEG/HEVC (resize, JPEG, H.264, cleanup) pass.
Android: emulator only; a real phone is still untested.
