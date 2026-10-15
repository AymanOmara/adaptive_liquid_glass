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

## Real device, partial (2026-10-14)

Samsung SM-S731B (Exynos 2400e, `erd9945`), Android 17 / API 37, 1080x2340,
120 Hz. Impeller backend: **Vulkan** (`android_context_vk_impeller.cc:
Using the Impeller rendering backend (Vulkan)`). Profile build, temporary
variant of `native_perf_test.dart` (8 flings + 6 slow drags over the
Gallery, then a `GlassScaffold` + 4-tab `GlassTabBar` over a list of
photos: 8 flings, 8 tab switches). Jank = total span over 16.7 ms (60 Hz)
and over 8.3 ms (120 Hz budget).

| scene (material) | frames | build p50/p90/p99 | raster p50/p90/p99 | total p50/p90/p99 | >16.7 | >8.3 |
|---|--:|--:|--:|--:|--:|--:|
| gallery fling  | 2100 | 0.79/1.46/2.40 | 3.67/4.90/6.59 | 5.62/7.76/11.54 | 0.7% | 5.5% |
| gallery drag   | 1418 | 0.92/1.53/2.17 | 3.67/4.61/6.76 | 5.74/7.54/10.84 | 0.3% | 4.0% |
| tab bar scroll | 2133 | 0.46/0.78/1.00 | 2.24/2.52/2.77 | 4.17/4.92/5.53 | 0.0% | 0.0% |
| tab bar switch |  867 | 1.01/1.45/1.92 | 2.23/2.69/3.20 | 4.44/5.60/7.15 | 0.0% | 0.6% |

**Shader mode: no numbers — the app is killed.** Twice, within ~5-30 s
of the first Gallery fling, `lmkd` killed the foreground app ("min
watermark is breached"). `dumpsys meminfo` during the run: `GL mtrack`
7.5 MB at start, **2.71 GB** five seconds later (TOTAL PSS 2.9 GB, 7.4 GB
phone). Material mode on the same run stays at about 30 MB EGL / 0 GL
growth. The shader tab bar alone (`vibrancy_flip_probe.dart`,
`PHOTO=true`) idles at 159 MB `GL mtrack` and spikes to 570-650 MB while
switching tabs, falling back to 190-290 MB when idle: transient, not a
leak, but large. Suspects (not yet bisected): per-frame GPU allocations
in the glass backdrop path under Vulkan (Gallery has many glass groups
plus two tab bars); `RenderVibrantBlend.paint` builds a new
`FragmentShader` every paint and never disposes the previous one (it
holds the glyph image sampler). Next: bisect the Gallery recipes with
`GL mtrack` sampling, and repeat on OpenGL ES.

### Bisect (2026-10-14, same phone, profile, Vulkan)

`GL mtrack` sampled every second (`dumpsys meminfo`). Gallery with an
auto-scroll loop: **3.2 GB** peak, oscillating 1.1-3.2 GB, already 1.1 GB
at t=2 s before any scroll. With the tab vibrancy shader off: 2.9 GB. With
the glass backdrop reusing one `FragmentShader` (no per-paint shader):
3.0 GB, so **per-paint shaders are not the cause**. Sections alone (vibrancy
off): none (photo + app bar) 132 MB; glass button only 376 MB; tab bar only
391 MB; recipes 0-5 1.1-1.5 GB; recipes 8-10 1.9 GB. Growth tracks how
many shader backdrops are on screen, not time.

Minimal probe (full-screen photo, 120x50 `ClipRect` + `BackdropFilter`):

| filter | GL mtrack |
|---|--:|
| none | 127 MB |
| blur x1 / x3 / x3 in `BackdropGroup` | 240 / 360 / 238 MB |
| `ImageFilter.shader` x1 | 240 MB |
| compose(shader, blur) x1 / x3 | 358 / 712 MB |
| `LiquidGlass` x1 / x3 / x3 in `BackdropGroup` | 386 / 781 / 672 MB |

Each shader-filter backdrop costs ~110-200 MB on a 1080x2340 screen,
whatever its size: Impeller's `RuntimeEffectFilterContents` ignores the
coverage hint and draws the whole input snapshot (the full screen, grown by
the blur), so every shader stage gets full-screen offscreen targets, which
the render-target cache keeps while each frame needs them. `BackdropGroup`
shares the capture (free for blurs) but not the shader passes. Vibrancy
probe tab switching: 536-586 MB with and without reusing the vibrancy
shader (no change). Not a Dart-side leak: a working set that scales with
the number of shader backdrops, so the Gallery (10+ groups, two tab bars)
exceeds what lmkd allows. A package fix needs the shader passes bounded to
the glass (an engine change, or a different backdrop architecture).

## Shared glass layer (2026-10-15)

Design: `docs/superpowers/plans/2026-10-15-shared-glass-layer.md`.

Spike (`example/lib/shared_layer_spike.dart`, Pixel 8 API 35 emulator,
`-gpu host`, cold boot; the guest reports no GL mtrack there, so this is
the host qemu process's graphics footprint over the launcher):

| scene | MB |
|---|--:|
| photo only | +82 |
| 2 groups (per-group backdrops) | +508 |
| 1 group, 2 shapes (one backdrop) | +375 |
| 10 groups | +1857 |
| 1 group, 10 shapes | +664 |

Gallery (shader mode, profile, open Gallery then 20 flings; peak over the
launcher, same emulator):

| build | peak | glass |
|---|--:|---|
| per-group path, no budget | +3906 MB | all shader |
| per-group path, budget 4 | +922 MB | frosted past 4 groups |
| shared layer, 3 blurs per stratum | +1641 / +1676 MB | all shader |
| shared layer, 1 blur per stratum (default) | +913 / +943 / +970 MB | all shader |

The app stayed alive in every run. The Gallery plans as one stratum of
10-15 groups; passes = one per distinct shader globals (the two tab bars
carry their own constants) over one blur.

Found on the way: a backdrop filter reads its `FragmentShader`'s uniforms
at raster time, so each pass needs its own shader object; and a backdrop
filter inside content composited by the slot (the tab bar's vibrancy)
draws nothing, so vibrancy paints plain on the shared layer. (Wrong, see
below.)

Vibrancy on the shared layer (2026-10-15, later): the backdrop filter of
`RenderVibrantBlend` does draw in slot-composited content, reading the
glass the layer drew before it. What "drew nothing" was a bug of both
paths: the shader's glyph origin (`uBox`) is the box's screen position at
paint time, and a viewport scroll or route animation moves the blend
without repainting it, so the shader looked for the glyphs where they had
been (the Gallery's bars are in a `ListView`: empty after scrolling, on
the layer and off it, until a tap repainted them). The blend now listens
to the enclosing scroll positions and route animations and repaints with
the same glyph image; `GlassLayerDeferred` is gone. Probe (red page,
blue band) and photo bar: layer on vs off, mean difference 0.000 over the
bar; Gallery bars after scrolling 0.065 (max 4). Memory (Gallery script
above, host graphics over idle; mean of the 20 samples, peak):

| build | mean | peak |
|---|--:|--:|
| vibrancy plain on the layer | +762 / +840 MB | +1171 / +1108 MB |
| vibrancy on | +883 / +929 MB | +1018 / +1254 MB |

About +100 MB: the vibrancy shader backdrops of the two bars (labels,
tint, pill) each get their own target. A key shared between them would not
help (the capture is shared, the shader stage is not), and the pill must
be read by the labels over it.

Commits: 6408e55 (design, spike), bb08440 (shader per-shape group /
smoothing / opacity / clip, 24 shapes), 424e427 (`computeGroupFrame`),
be1ad88 (planner), 35e8ee1 (paint chain), 511bc19 (layer, slot, wiring),
6d10543 (menus opt out), b1f3f73 (shader per pass), a9876ad (budget
default null), a9d2481 (one blur per stratum), d494e4b
(`GlassLayerContent`), 3d6e68e (vibrancy plain when deferred).

Covered routes: a route under an opaque route is offstage, so its slot
(an `OverlayPortal` child of the route's entry) is not painted and its
backdrop layers leave the scene; Impeller frees their targets. Measured
(host graphics over idle): home +393 MB, Gallery +648, Gallery covered by
the large-title page +424, back to Gallery +674. Steady state holds one
route's layer; two only while a transition shows both.

Fidelity (iOS 26.4 sim, shader mode, against `g8-3` SwiftUI captures):
59/75 with the switch on and off, same failing scenes.
