# adaptive_liquid_glass — Photos import: progress, cancel, killable codec, parallel iOS

Status: draft for review (2026-11-04). Narrows the "Photos picker" entry of
README → Limitations and TODO.md "Photos import".

## 1. Intent

A large pick (many photos, long HEVC videos) currently shows a spinner with
no progress and cannot be stopped. On Android a hung codec call can stall the
import forever. On iOS items import one at a time. This work closes those
three gaps without changing the result contract existing apps rely on.

### What the user decided

- Scope: **progress + cancel**, **killable Android codec**, **parallel iOS
  import**. Out of scope: the selection cap and the document-picker fallback
  (both platform-owned), and Android parallel copy.
- Trade-offs are delegated: pick for usability first, then performance, then
  functionality. The decisions below follow that order.

### Success criteria

1. `onProgress` reports per-item and overall progress on both platforms.
   It is throttled to ≤ 10 events/s and is determinate whenever sizes or
   durations are known.
2. `GlassPhotoImportController.cancel()` stops an import within 1 s on both
   platforms, outside a blocking native call. The result keeps the finished
   items, deletes partial files and sets `cancelled`.
3. Android: a codec call that never returns can no longer hang the import.
   The item is delivered as the original with `conversionFailed` within the
   30 s stall window (or at once on cancel), and later items keep importing.
4. iOS: a 20-photo batch imports measurably faster than the sequential
   baseline (target ≥ 2× on iPhone 17 Pro sim, recorded in the plan). Peak
   memory stays bounded.
5. No breaking change. Existing calls behave identically, final lists stay
   in selection order, and every `itemReady` arrives before the final result.

## 2. Public API (Dart)

```dart
final controller = GlassPhotoImportController();

final photos = await pickGlassPhotos(
  maxSelection: 0,
  controller: controller,                 // new, optional
  onProgress: (p) => setState(() => _p = p), // new, optional
  onItemReady: (photo) => _grid[photo.index] = photo,
);
if (photos.cancelled) { /* finished items only */ }

controller.cancel(); // from anywhere, e.g. a "Stop" button
```

- **`GlassPhotoImportProgress`** (immutable):
  - `total`: number of selected items.
  - `completed`: items finished, failed or skipped.
  - `currentIndex`: selection index of the most recently updated item.
  - `itemFraction`: `double?`, 0–1. It covers copy bytes and then conversion
    (copy 0–0.5 and conversion 0.5–1 when conversion runs). It is null when
    the size is unknown.
  - `fraction`: overall value, `(completed + Σ in-flight itemFraction) / total`.
    It is always non-null once `total` is known.
  - `phase`: `selecting | importing | done`.
  - Why: an app needs one number for a bar (`fraction`), and the parts for a
    detailed UI.
- **`GlassPhotoImportController`**:
  - `cancel()` is idempotent and safe before or after the import.
  - `isActive` and `progress` are exposed as `ValueListenable`s, so apps can
    use `ValueListenableBuilder` without managing callbacks.
  - One controller drives one import at a time. Reusing it after completion
    is allowed.
- **`GlassPickedPhoto.index`** (new, `int`): selection order. iOS delivers
  `itemReady` in completion order (§4), so a UI places items by `index`.
  Amendment: `index` stays `int?` in Dart. Older native plugins cannot supply
  it, and a default of 0 would put the item in the wrong slot.
- **`GlassPickedPhotos.cancelled`** (new, `bool`, default false).
- **`GlassPhotosPicker` widget**: new `controller`, `onProgress` and
  `showProgress` (default true).
  - While importing, the trigger shows a determinate progress ring instead of
    the spinner.
  - Tapping the busy trigger cancels the import. The semantics label switches
    to "Cancel import" so this is discoverable. This is the cheapest cancel
    affordance; no extra UI is needed.
  - The progress ring uses the existing `GlassButton(loading:)` visual,
    extended with an optional `loadingValue`.

## 3. Channel protocol

- A per-call import channel is now created when `onItemReady`, `onProgress`
  **or** `controller` is set. Today it is created only for `onItemReady`.
- Native → Dart on the import channel:
  - `itemReady`: unchanged, plus `index`.
  - New `progress` with payload `{index, total, completed, itemFraction?}`,
    throttled natively to 10 Hz with a guaranteed final event per item.
  - Dart computes `fraction`.
- Dart → native: a new `cancelPhotoImport` method on the main channel, with
  `{importChannel}`. A stale name is a no-op, which keeps cancel race-free.
  - If cancel arrives while the system picker is still showing, the picker is
    dismissed and the result is an empty list with `cancelled: true`.
- Final reply: iOS moves from a bare list to the Android map shape
  `{items, dropped, cancelled}`. Dart still accepts a bare list from older
  plugins.

## 4. iOS

- Replace the sequential loop with a bounded `withThrowingTaskGroup`:
  - **3 concurrent file loads/copies**.
  - **1 concurrent `AVAssetExportSession`** and **2 concurrent HEIC
    re-encodes**, gated by small async semaphores (actor-based). Export is the
    memory and thermal hog; copies are I/O-bound. This gives most of the win
    and keeps the existing "bounded decoding" guarantee.
- Results are collected by selection index, so the final array stays in order.
- `itemReady` is sent on completion. Usability rationale: the user sees
  thumbnails sooner, and `index` lets the UI slot them.
- Progress sources:
  - Copy: `NSItemProvider.loadFileRepresentation` returns a `Progress`;
    observe `fractionCompleted`.
  - Export: poll `exportSession.progress` every 100 ms.
  - Image re-encode: phase change only (0.5 → 1).
- Cancel: cancel the task group. Each child checks `Task.isCancelled`,
  calls `Progress.cancel()` on the load and `cancelExport()` on the export,
  and deletes its partial file. Finished files are kept.
- Per-item session directories, like Android, so a cancel cleans up only that
  import's partial files.

## 5. Android

- **Codec supervisor.**
  - Each `H264Transcoder.transcode` runs on a dedicated daemon thread from a
    small cached pool. The import thread waits on a `Future` with the
    existing `TranscodeProgress` stall window.
  - On stall or cancel: set the cancel flag, `interrupt()`, wait up to 500 ms,
    then **abandon** the thread. The codec/muxer is released by that thread if
    it ever returns. The output is deleted and the original is delivered with
    `conversionFailed`.
  - Why not a separate process: process start-up plus IPC adds latency to
    every conversion and needs a Service and manifest entries. Thread abandon
    keeps the fast path free. (Rejected: `:transcoder` process.)
  - **Quarantine:** once a thread has been abandoned, the rest of that import
    skips conversion and delivers originals with `conversionFailed`. A hung
    hardware codec instance would likely block the next one too, and the
    user's import must still finish. The flag resets on the next pick.
- **Interruptible copy.** Replace `copyTo` with a chunked copy (256 KiB) that
  checks cancel between chunks and reports bytes against
  `OpenableColumns.SIZE`. A blocking `read` is guarded the same way: run it
  on the supervisor and abandon it after the stall window.
- **Progress.**
  - Copy bytes as above.
  - Conversion: `presentationTimeUs / durationUs` from the existing
    `advanced()` hook.
  - Events are posted to main, throttled at 10 Hz.
- **Cancel.**
  - A volatile flag is checked by the import loop, the copy and
    `TranscodeProgress.checkActive()`.
  - The single-thread `io` executor stays, so items still finish in order and
    there are no new ordering semantics on Android.
  - With incremental delivery, finished items are kept. In batch mode (no
    callback), cancel keeps finished files too: the user explicitly stopped,
    so this is not a failure rollback.

## 6. Error handling

- Cancel is not an error: `onError` is not called.
- An item failing after cancel is swallowed.
- An abandoned codec thread is logged once per import (debug only).
- Pick while active keeps `already_active`. `clearGlassPickedPhotos` during
  an import keeps throwing `already_active`, and its message now suggests
  `controller.cancel()`.

## 7. Testing

- **Dart** (`test/photos_picker/`), using mocks:
  - `progress` parsing and `fraction` maths.
  - Throttling is native, so Dart handles bursts.
  - `cancelPhotoImport` args.
  - `cancelled` parsing from both reply shapes.
  - `index` placement.
  - Widget: ring value, tap-to-cancel, semantics label.
  - Controller: reuse, cancel before start.
- **Android JVM:**
  - Supervisor abandons a thread blocked in a fake codec call and delivers the
    original.
  - Quarantine skips later conversions.
  - Chunked copy honours cancel.
  - Progress throttle emits a final event.
- **iOS:**
  - Add a `RunnerTests` case for the semaphore/ordering helper: out-of-order
    completion gives an in-order result, and concurrency never exceeds the
    limits. This logic is extracted into a pure Swift type so it is testable
    without PhotosUI.
- **Manual / bench:**
  - Example app gets a progress bar and Stop button on the components demo
    picker.
  - Time a 20-photo and a 5×HEVC batch before/after on the iPhone 17 Pro sim
    and on an Android emulator. Record the numbers in the plan.

## 8. Docs

- README Photos picker section: document `controller`, `onProgress` and
  `index`.
- Limitations entry: shrink it to the residuals:
  - copy/conversion still take real time;
  - an abandoned codec thread may hold a hardware codec until process exit;
  - the selection cap is platform-owned.
- TODO.md: update the "Photos import" item.
- CHANGELOG: one entry under the next minor.
