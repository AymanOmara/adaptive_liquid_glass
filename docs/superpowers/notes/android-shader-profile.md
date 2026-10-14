# Android shader-mode profile (rough)

Date: 2026-10-14. Flutter 3.47.7, profile build, arm64.

## Setup

- Device: Android emulator `Pixel_8_Pro` (API 37) on an Apple-silicon Mac.
  The emulator renders GLES in software ("API level 37 requires GLES 3.1,
  forcing software rendering": ANGLE over SwiftShader; Vulkan is
  lavapipe). Impeller picked OpenGL ES; asking for Vulkan through the
  `io.flutter.embedding.android.ImpellerBackend` meta-data still fell back
  to OpenGL ES.
- Test: `example/integration_test/native_perf_test.dart` (six flings over
  the Gallery, FrameTiming from Flutter's build and raster threads), run
  with `flutter drive --profile` and a one-line driver
  (`integrationDriver()`). As committed, its `pumpAndSettle` calls time out
  in shader mode on this emulator (10 min; the Gallery never settles at
  seconds per frame). The numbers below replace them with
  `pump(const Duration(seconds: 2))`.

## Numbers (ms)

| mode     | frames | build p50 / p90 | raster p50 / p90 | total p50 / p90 |
|----------|-------:|----------------:|-----------------:|----------------:|
| material |    134 |     0.99 / 12.7 |       180 / 260  |       370 / 462 |
| shader   |     68 |      5.6 / 34.7 |     3753 / 6528  |    6869 / 12732 |

## Reading

- Software rendering puts every number far off a real phone; only the
  ratio says something: shader glass costs about 20x the material
  fallback's raster time here (a blur plus the glass fragment shader over
  each group's bounds, every frame). Build time is small in both.
- Still unmeasured: a real mid-range phone, on Vulkan and on OpenGL ES.
  Re-run the same test there before quoting any frame budget.

## Why `pumpAndSettle` timed out (2026-10-14)

Not the glass: the Gallery's "Saving" button (`GlassButton(loading:
true)`) spins forever, in every mode, so the scheduler always has a ticker
once a fling scrolls it into view (a host widget test of the same Gallery
in shader and material mode stays unsettled after the first fling and
settles once it scrolls back; with `loading: false` both settle in 8
pumps). The perf test now pumps a fixed 2 s after each step.

## The launch crash with the forced GLES flip (2026-10-14)

Not the flip, and not a shader or uniform mismatch. Tombstones (profile
build, BuildId e154c644…, symbolised with the matching unstripped
`libflutter.so` from the Gradle cache) all show the same raster-thread
stack: `Layer.toImageSync` → `DlDeferredImageGPUImpeller` →
`Rasterizer::MakeImpellerSnapshotSync` → no onscreen surface yet, so
`AndroidSurfaceGLImpeller::CreateSnapshotSurface` builds a new
`AiksContext`/`ContentContext`, whose setup blit
(`BlitCopyBufferToTextureCommandGLES::Encode`) dereferences null. The
only `toImageSync` in the package is `RenderVibrantBlend` (the shader tab
bar's glyph image), painted in the first frames, before Android's surface
exists. The unmodified probe crashed the same way (1 cold launch in 8), so
it was a latent launch race for any app with a shader-mode tab bar on
Impeller GLES. Fix: `RasterSnapshotGate` keeps raster snapshots (the glyph
image, the `GlassBackdropSource` luminance readback) off until the first
frame is rasterised and while the app is in the background; the labels
paint flat until then.

Evidence: unmodified probe (profile) 1 crash in 8 cold launches
(tombstone_17); with the gate 0 in 12. A debug build from before the fix
(another session's run, tombstone_18, uptime 211 s) died in the same
`BlitCopyBufferToTextureCommandGLES::Encode`, so the crash is not only a
launch race.
