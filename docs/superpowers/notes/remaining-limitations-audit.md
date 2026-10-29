# Remaining limitations audit — 2026-10-23

Progress: 3/3 (100%).

- [x] Recheck the remaining README entries against their implementation and existing device evidence.
- [x] Run regressions for native press, tab fallbacks, photo imports, capture and palette storage.
- [x] Reconcile documentation with verified behavior and record the remaining boundaries.

Android's iOS styling remains outside this follow-up, as requested.

Rechecked all five remaining entries. The four in-scope entries remain accurate:

- Generic glass still uses Flutter-owned touches and measured press approximation.
  Existing device captures record the remaining optical/geometry differences.
- Custom tab layouts still take the Flutter renderer; native eligibility explicitly
  excludes custom content, dimensions, accessories and adapted layouts. The suite
  exercises these fallbacks, controlled selection, route transitions and disposal.
- Photo results remain local copies; native imports serialize work and Android
  codecs remain device-dependent. The document fallback truncates and reports the
  extra count. Clarified a previously unstated boundary: Android's system picker
  limits even an app-unlimited request to `getPickImagesMaxLimit()`.
- Capture still excludes other apps and separate/protected surfaces. Android's
  production helper rejects unsupported surface geometry/order. Updated stale
  eyedropper API docs to include the already-validated opaque SurfaceView path.
  Native palette persistence is covered alongside malformed stores, delayed
  loads, write order and pluginless fallback.

Validation: 211 targeted Flutter tests passed in
`/tmp/remaining-limitations-audit-tests.log`. This audit reran Flutter regressions;
it did not repeat the earlier device recordings or native integration runs.
No remaining limitation was removed or claimed fixed by these documentation edits.
Static analysis passed with no issues; `git diff --check` passed.
