# Zoom transition Implementation Plan

> Executed natively in this session (brief: don't block on the user).

**Goal:** `GlassZoomSource` + `GlassZoomPageRoute`/`pushGlassZoom`.
**Spec:** docs/superpowers/specs/2026-11-08-zoom-transition-design.md

## Review Focus
- Source scrolled off / disposed before pop → fallback, no crash.
- Two sources with the same id in different namespaces → right one.
- Route popped by `Navigator.pop` while a drag is in progress.
- RTL: edge drag from the right only.
- Reduce Motion toggled: fade, no flight.

## Tasks
1. Native reference scenes `zoommotion` / `zoomdrag`; record; fit timing
   (`tool/reference/measure_zoom.py`, `tool/reference/zoom_motion.json`).
2. `lib/src/zoom_transition/`: registry + `GlassZoomSource` (tests first:
   `test/zoom_transition/glass_zoom_source_test.dart`).
3. `GlassZoomPageRoute` flight geometry, source hiding, fallback, Reduce
   Motion, Material path (tests first: `glass_zoom_page_route_test.dart`).
4. Drag-to-dismiss (`zoom_drag_dismiss.dart`; tests first).
5. Metrics from task 1 + reference test.
6. Export, example demo + `zoommotion` twin, docs (component-gap, TODO,
   README, CHANGELOG Unreleased). `flutter analyze`, `flutter test`, commit.
