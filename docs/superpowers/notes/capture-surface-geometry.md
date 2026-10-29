# Capture surface geometry — 2026-10-24

Progress: 4/4 (100%).

- [x] Map full-size repositioned direct Flutter surfaces into the captured view.
- [x] Add native-pixel checks for offsets, clipping and composition order.
- [x] Run real Android integration and colour-picker regressions.
- [x] Narrow the README after validation.

Scope: full-size untransformed direct-child SurfaceViews on API 36+ with public
composition order. Resized surfaces, native transforms, explicit clip shapes and
older-host custom geometry keep fallback.

The initial resize prototype passed background/overlay checks but failed a
stricter foreground-block check. The missing block also reproduced in a normal
app capture, including a fresh API 37 AVD and a forced paint. The cause remains
unresolved. An existing read-only
emulator additionally showed a System UI ANR, so the final checks use a new
task-owned device. The package retains its original resize rejection instead of
claiming arbitrary surface-size support based on background-only samples.

Final implementation carries the native surface's logical offset with the PNG.
The eyedropper applies that translation before sampling, so the colour beneath
the displayed loupe remains aligned. Android composites at the surface's actual
position, clips to its visible parent region, and rejects a changed parent,
geometry, clipping region or order during the asynchronous capture. Non-finite
coordinate metadata falls back; legacy replies default to zero offset.

Validation before narrowing README:

- Full Flutter suite: 1,540 passed, including positive/negative native offset
  decoding, invalid offset rejection and zero-offset compatibility.
- Real API 37 integration on the task-owned fresh AVD passed: ordinary/above
  window composition, native 50% green alpha, fully covered windows, positive
  and negative full-size surface offsets, clipped edges and image composition.
  The Flutter blue foreground block must remain present. Both offset cases
  use the public eyedropper to pick the native green-over-red colour (7F8000),
  which neither a Flutter-only fallback nor an unadjusted mapping can supply.
- Real API 35 regression passed: legacy native composition remains exact;
  offset/above-window/fully covered cases safely reject native capture and
  return to the supported full-size path after reset.
- 10 Android JVM tests passed; final production native code compiled. Static
  analysis and `git diff --check` passed.
- Final logs: `/tmp/capture-offset-api37-final.log`,
  `/tmp/capture-offset-api35-final.log`, `/tmp/capture-offset-full-suite.log`,
  `/tmp/capture-offset-native-tests.log`, `/tmp/capture-offset-analyze.log`.

The normal-app probe is `example/integration_test/surface_capture_geometry_app.dart`.
It uses position offsets by default. Its `RESIZE_SURFACE` Dart define remains
an explicit diagnostic for the rejected resize case; it is not a supported mode.

Cleanup: both task-started emulators were shut down. The fresh task-owned AVD
`alg-capture-geometry-api37-20261024` was deleted; the user's existing AVDs were
preserved. The normal example debug APK was rebuilt successfully after testing
(`/tmp/capture-offset-main-build.log`).
