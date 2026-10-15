# Shared glass layer (Android shader memory)

Date: 2026-10-15. Status: Phase 1 (design + spike) done; Phase 2 in
progress, see "Progress" at the end.

## Problem

Under Impeller every `BackdropFilter(ImageFilter.shader(...))` renders into
full-screen offscreen targets whatever the glass's size
(`docs/superpowers/notes/android-shader-profile.md`, "Bisect"): about
110-200 MB of GPU memory per shader glass group on a 1080x2340 phone. The
Gallery (10+ groups, two tab bars) reached 2.7-3.2 GB `GL mtrack` and was
killed by `lmkd`. The stop-gap `androidShaderBudget` (default 4) frosts the
groups past the fourth.

Goal: all shader glass of one route draws through **one shared layer**: one
backdrop capture and as few shader passes as z-order allows, so GPU memory
is about one pass per *stratum* (see below) instead of one per group.

## Spike (done 2026-10-15)

`example/lib/shared_layer_spike.dart`: full-screen photo, N = 10 capsules
(120x50) drifting so every frame repaints. `per` puts each capsule in its own
group (today: one backdrop filter + shader each); `shared` puts all ten in
one `GlassGroup` with spacing 0 (one backdrop filter, one shader pass
drawing ten shapes, which is what the shared layer does).

Emulator `Pixel_8_API_35`, `-gpu host`, Impeller OpenGL ES, profile. The
guest reports no `GL mtrack` with host GPU, so the number is the host
emulator process's graphics footprint (`footprint <qemu pid>`: IOAccelerator
+ owned unmapped graphics), each run on a cold-booted emulator, peak over
10 s minus the value before launch:

| scene | graphics MB |
|---|--:|
| photo only | +82 |
| 2 shapes, 2 groups | +508 |
| 2 shapes, 1 group | +375 |
| 10 shapes, 10 groups | **+1857** |
| 10 shapes, 1 group | **+664** |

One pass drawing ten shapes costs about a third of ten passes, and the
pass grows with the area it covers (2 -> 10 shapes over 1 -> 5 rows:
+375 -> +664), not with the shape count. Each extra pass costs about
150-170 MB here, close to the phone's 110-200 MB. The memory win is real;
go ahead.

## Where the layer lives

**One layer per route** (per `ModalRoute`, so per overlay entry of a
Navigator), found without any app code:

- Each shader `GlassGroup` that resolves to the shared path wraps its
  backdrop in an `OverlayPortal`. Its overlay child is a tiny
  `GlassLayerSlot` render box. Flutter paints an `OverlayPortal`'s overlay
  child **after the whole overlay entry of the enclosing route and before
  the next entry** (a dialog, sheet or pushed page). Every slot of one
  route registers with that route's `GlassLayer`; the first live slot is the
  painter, the others paint nothing (no rebuild when the painter goes: the
  next slot takes over and repaints).
- The layer is keyed by the nearest `GlassLayerBoundary` (internal
  inherited widget) or else `ModalRoute.of(context)`. Package overlay
  content that is not a route (the menu's `OverlayPortal`) gets its own
  boundary, so its glass is a separate layer above the page's.
- No route or no `Overlay` (glass above the Navigator, in an `OverlayEntry`
  toast, tests without a Navigator), or the switch off: the group keeps the
  per-group path unchanged (and the budget applies to it).

Rejected: a host inside `LiquidGlassTheme`/`MaterialApp.builder` (above the
Navigator: page glass would draw over dialogs); a host in `GlassScaffold`
only (the Gallery, the screen that is killed, uses Material's `Scaffold`);
wrapping the slot in `route.buildTransitions` (Cupertino's edge shadow and
Material backgrounds would paint twice).

## What the layer paints

For each route the painter paints, after all of the route's content:

```
for each stratum s (in order):
  for each pass p of s:        ClipRect(p.bounds) > BackdropFilter(blur + shader, backdropKey_s)
  for each group g of s:       ClipRect(g.clip) > Opacity(g.opacity) > Transform(g -> painter) > g's content layer
```

**Deferred content.** A shared group does not paint its child in place. The
child is a repaint boundary (a `RepaintBoundary` is always inserted under
`GlassBackdrop`, so switching paths never remounts content), and the
painter composites its layer after the glass pass, so labels stay above
their glass and out of its backdrop. Hit testing and semantics use the
render tree, which does not change.

**Strata (z-order).** Groups are sorted in paint order (child order along
the render tree from their common ancestor). A group joins the lowest
stratum after every earlier group whose region (glass bounds + shadow and
merge margin, clipped) it overlaps. So content glass that scrolls under a
glass tab bar is stratum 0 and the bar stratum 1: the bar's pass samples
the content glass and its labels, as today. Nested groups (glass inside the
content of other glass) land in a later stratum the same way. A typical
screen has 1-2 strata.

**Passes within a stratum.** The pre-blur is an `ImageFilter` composed
before the shader, one sigma per filter; the sigma depends on the variant,
the brightness and, below `blurSizeRef`, the shape's size. A stratum's
groups split by (blur sigma, aspect, and the shader's per-pass globals:
constants, brightness, light angle, contrast, opaque colour, dpr). Up to
`kMaxPassesPerStratum` blurs (default 1, set with
`--dart-define=ADAPTIVE_LIQUID_GLASS_LAYER_BLURS=n`); with more distinct
sigmas the closest (log scale) merge and use the larger. Each blur costs a
full-screen target, so 3 blurs measured +1.65 GB on the Gallery against
+0.93 GB for 1. Passes that differ only in the shader globals share the
stratum's blur cluster. One key = exact fidelity: every
fidelity scene has one group, so the harness is unaffected. A pass holds
up to `kMaxPassShapes` (24) shapes; more start another pass.

All passes of a stratum share one `BackdropKey` (one capture; free for the
blur, as the bisect measured for `BackdropGroup`).

**Per group in a pass** (new per-shape uniforms, `uExtra`, `uClip`):

- group index: the smooth union (`smin`, `mergeFactor` x spacing) and the
  attribute blend run within a group only; groups combine with `min`, so
  separate groups never merge (as today);
- the group's smoothing (its own spacing);
- clip: the intersection of the ancestors' `describeApproximatePaintClip`
  rects between the group and the route (scroll viewports), in screen px;
  a pixel is cut when it is outside the clip of the group of its nearest
  shape (rounded clips become their bounds: limitation);
- opacity: the product of `RenderOpacity`/`RenderAnimatedOpacity`
  (`FadeTransition`) ancestors up to the first ancestor shared with the
  painter (route transitions: the page's `FadeTransition` fades the page's
  glass; the slot is outside it); a pixel's output is multiplied by it.
  Ancestors that do not paint the group (`paintsChild` false: `Offstage`,
  zero opacity, non-selected `IndexedStack` child) drop the group.

With one group these reduce to the old shader exactly (`min(1e6, x) = x`,
opacity 1, clip unbounded), so the per-group path renders bit for bit as
before.

**Touch glow**: one per pass (the strongest pressed member), as one per
group today; two groups pressed at once in one pass lose the weaker glow.

## Geometry updates

The painter repaints when any member group's registry notifies (member
layout, press, morph, scroll positions between member and group, the
route's animations: the existing listeners, now forwarded to the layer)
and when a group joins or leaves. A group moved by layout without any of
those (a parent re-laid out) repaints its `GlassBackdrop` in place; it then
compares its global transform with the last one the painter used and asks
for a painter repaint after the frame (one frame late, the same rule
`RenderGlassMember` uses today).

## Interaction with existing features

- Merging/morphing: unchanged; `GlassRegistry`, `GlassMorphController`,
  ghosts and `lastDrawnLocal` work per group; the painter computes each
  group's frame with the same code as `RenderGlassBackdrop` (extracted to
  `computeGroupFrame`).
- Tab bar: its glass groups are ordinary groups (the bar is a later stratum
  than content under it). Its lens (`tab_lens_content.frag`) and vibrancy
  (`tab_vibrancy.frag`) backdrop shaders are inside the bar's content, so
  they are composited with it, after the bar's glass. The bar's row and
  lens content are siblings laid over the bar's glass, not its children:
  `GlassLayerContent` defers them as content-only clients, in paint order.
  Their vibrancy backdrop filters read the layer's glass, as in place
  (they repaint when a scroll or route moves them; see the notes).
- Progressive scroll-edge blur and other non-glass content painted after a
  group in the same route now paint *below* that group's glass where they
  overlap (limitation; the edge effect is under bars, which are glass).
- `Opacity`/`ShaderMask`/`ColorFiltered` ancestors other than opacity are
  not reproduced (limitation; rare around glass).
- Route transitions that snapshot the page (`ZoomPageTransitionsBuilder`,
  not the default since Flutter 3.29) show the page's glass outside the
  snapshot for the transition (limitation).
- iOS (shader path on iOS < 26 or `GlassRenderMode.shader`): same code;
  off by default on iOS (memory is not the problem there and Metal
  measurements are pending), on by default on Android. The internal switch
  `--dart-define=ADAPTIVE_LIQUID_GLASS_SHARED_LAYER=on|off` forces it
  either way (fidelity harness, A/B runs).
- `androidShaderBudget`: kept; groups on the shared layer do not take
  tickets; default becomes null (no cap) once the Gallery stays bounded.
- Native and Material paths: untouched.

## Fidelity

`tool/fidelity` scenes are single-group, single-route: with the switch on
they go through the shared layer (one stratum, one pass, one group).
Capture the Flutter side with the switch on and off against the committed
SwiftUI captures of `g8-3`; the bar is no regression from 59/75.

## Tasks (Phase 2, TDD, small commits)

1. Shader: `uExtra[24]` (group, smoothing, opacity, -), `uClip[24]`
   (x0, y0, x1, y1 px); arrays 16 -> 24; group-segmented `smin`, owner
   group's clip and opacity. `packGlassUniforms` packs them
   (`GlassShapeUniform.group/smoothing/opacity/clip`). Tests: float layout,
   per-group defaults reproduce the old layout's values.
2. Extract `computeGroupFrame(registry, config, toGlobal)` from
   `RenderGlassBackdrop._buildFrame`; old path uses it (tests unchanged).
3. `planGlassLayer(groups)`: pure strata + pass planner (paint order,
   overlap, blur keys, caps). Unit tests.
4. `paint_chain.dart`: ancestor clip / opacity / paints-child / paint-order
   path between a render object and a stop set. Widget tests with
   `ClipRect`, `ListView`, `Opacity`, `FadeTransition`, `Offstage`,
   `IndexedStack`.
5. `GlassLayer` registry (per key), `GlassLayerSlot` render box (painter
   election), `RenderGlassBackdrop` shared mode (no in-place paint, defers
   child), `GlassGroup` wiring (OverlayPortal, `RepaintBoundary`, switch,
   budget bypass). Widget tests: members of two groups in one route share
   one painter; dialog route gets its own layer; switch off = old layers;
   layer tree order (pass before content).
6. `androidShaderBudget` default null; README, CHANGELOG, notes.
7. Verify: analyze, tests, example tests, fidelity (switch on/off),
   Android Gallery peak memory before/after.

## Progress

See the end of `docs/superpowers/notes/android-shader-profile.md` for the
measurements and the commit list.
