# Capture surface order — 2026-10-24

Progress: 4/4 (100%).

- [x] Read surface order through the public Android 16 API and compose accordingly.
- [x] Extend the real-pixel integration fixture for both surface orders.
- [x] Validate on isolated Android emulators and run regressions.
- [x] Narrow the README only after validation.

Android API 36 adds `SurfaceView.getCompositionOrder()`: non-negative means
above the window; negative means below it. Older hosts retain their measured
transparent-hole check and reject ambiguous ordering.

Source: https://developer.android.com/reference/android/view/SurfaceView#setCompositionOrder(int)

Implementation: retain full-size, untransformed surface validation. On API 36+
capture both surface and window, then blend in the public composition order.
Recheck the order after the asynchronous copies and reject a changed order.
On older versions the existing transparent-hole proof remains mandatory.

Newer-device validation passed on a read-only Pixel 8 Pro/API 37 emulator:
ordinary lower surface with a 50% native green overlay, an above-window surface
that correctly hides that overlay, restoration to lower order, a fully opaque
native cover with no window hole, and image composition with changed Flutter
background pixels. This exercises the production helper through its channel.
The API 35 regression passed on a read-only Pixel 8 emulator: the original
red/blue/50%-green samples, safe rejection of unknown above-window order and
fully covered windows, restoration and image-composition checks all passed.
The 59 Flutter colour-picker tests, 10 Android JVM tests, production Android
compilation and static analysis passed. The emulators were started for this
task on ports 5580/5582 and shut down after tests; read-only changes are discarded.

README and API docs were narrowed only after both real-pixel integration runs
passed. Custom surface sizes/transforms, older hosts with ambiguous ordering
and separate/protected surfaces remain unsupported.

Logs: `/tmp/capture-order-api37-test.log`, `/tmp/capture-order-api35-test.log`,
`/tmp/capture-order-android-build.log`, `/tmp/capture-order-flutter-tests.log`,
`/tmp/capture-order-analyze.log`. `git diff --check` passed.
