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
