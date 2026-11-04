# Photos import: progress, cancel, killable codec, parallel iOS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `pickGlassPhotos` / `GlassPhotosPicker` determinate progress, a cancel that works on both platforms, an Android codec call that can never hang an import, and a bounded-parallel iOS import, without breaking any existing call.

**Architecture:** Dart owns the public API: `GlassPhotoImportController`, `GlassPhotoImportProgress`, and the `fraction` maths. Native sends raw `progress` events over the existing per-call import channel and honours a new `cancelPhotoImport` main-channel method.
- Android keeps its serial `io` executor. It runs each blocking step (copy, transcode) on a supervised daemon thread, which is abandoned on stall or cancel.
- iOS replaces its sequential loop with a `TaskGroup`. Small actor semaphores gate the group: 3 loads, 1 export and 2 re-encodes.

**Tech Stack:**
- Flutter/Dart (`flutter_test`);
- Kotlin, using MediaCodec/MediaMuxer, `java.util.concurrent` and JUnit 4;
- Swift 5.9 concurrency with PhotosUI, AVFoundation and XCTest (`RunnerTests`).

**Spec:** `docs/superpowers/specs/2026-11-04-photos-import-progress-cancel-design.md`. Read it before starting any task.

## Global Constraints

- No breaking change: existing calls behave identically, final lists stay in selection order, and every `itemReady` arrives before the final result.
- Progress events are throttled natively to ≤ 10 events/s (100 ms), with a guaranteed final event per item that carries `itemFraction: 1.0`.
- `itemFraction`: copy is 0–0.5 and conversion 0.5–1 when conversion runs; when no conversion runs, copy is 0–1. It is null when the size is unknown.
- `fraction = (completed + Σ in-flight itemFraction) / total`; it is never null once `total` is known.
- Cancel stops within 1 s outside a blocking native call. Finished items are kept, partial files are deleted, and `cancelled` is set.
- Cancel is not an error: `onError` is not called and errors after cancel are swallowed.
- Android stall window: 30 s (the existing `TranscodeProgress` default). Post-interrupt grace: 500 ms. Copy chunk: 256 KiB.
- iOS limits: 3 concurrent loads/copies, 1 `AVAssetExportSession`, 2 HEIC re-encodes.
- `cancelPhotoImport {importChannel}` with a stale or unknown name is a no-op on both platforms.
- The iOS reply becomes `{items, dropped, cancelled}`. Dart still accepts a bare list.
- The import channel is created when any of `onItemReady`, `onProgress` or `controller` is set.
- iOS minimum is 15.0 (Package.swift). Do not raise it.
- Do not run `pub publish`. Work on a feature branch or worktree, never on `main`.

## Review Focus

1. **Cancel racing the final reply.** `controller.cancel()` called after native has already replied (stale channel name) is a no-op. The result is not marked `cancelled`, and no exception escapes. Test: Task 2, step 1 (`cancel after completion is a no-op`).
2. **Widget disposed mid-import** (route popped while importing). There is no `setState` after dispose and no listener leak. Late `progress`/`itemReady` events are ignored. Test: Task 4, step 1 (`dispose during import is quiet`).
3. **Unknown sizes and bursts.** Events with `itemFraction: null`, duplicates, and an item's final event before its earlier ones leave `fraction` monotonic non-decreasing and within 0–1. Test: Task 1, step 1 (`fraction never decreases`).
4. **Cancel while the system picker is still showing.** The result is empty with `cancelled: true`, `onPicked` is not called, and the next pick works (the controller is not stuck active). Test: Task 4, step 1 (`cancel during selection`). The Android `pending` reset is covered by Task 8's `GlassPhotoCache` cancel-before-first test.
5. **An abandoned codec thread that returns later** must not leave its output on disk or touch the delivered original. Test: Task 7, step 1 (`late return of abandoned work deletes its output`).

---

### Task 1: Dart progress model and tracker

**Files:**
- Create: `lib/src/photos_picker/glass_photo_import_progress.dart`
- Create: `lib/src/photos_picker/photo_import_tracker.dart` (not exported)
- Modify: `lib/adaptive_liquid_glass.dart:90-94` (export the progress file)
- Test: `test/photos_picker/photo_import_tracker_test.dart`

**Interfaces:**
- Produces:
  - `enum GlassPhotoImportPhase { selecting, importing, done }`
  - `class GlassPhotoImportProgress`:
    - constructor: `{required int total, required int completed, int? currentIndex, double? itemFraction, required double fraction, required GlassPhotoImportPhase phase}`;
    - `static const selecting`;
    - `==`, `hashCode`, `toString`.
  - `class PhotoImportTracker`:
    - `GlassPhotoImportProgress onEvent(Map<Object?, Object?> args)`;
    - `GlassPhotoImportProgress done()`;
    - `GlassPhotoImportProgress get current`.

- [ ] **Step 1: Write the failing test**

```dart
// test/photos_picker/photo_import_tracker_test.dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/photos_picker/photo_import_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _e(int index, int total, int completed, [double? f]) => {
  'index': index,
  'total': total,
  'completed': completed,
  'itemFraction': ?f,
};

void main() {
  test('starts selecting with fraction 0', () {
    final t = PhotoImportTracker();
    expect(t.current, GlassPhotoImportProgress.selecting);
    expect(t.current.fraction, 0);
  });

  test('fraction sums completed and in-flight items', () {
    final t = PhotoImportTracker();
    t.onEvent(_e(0, 4, 0, 0.5));
    final p = t.onEvent(_e(1, 4, 0, 0.25));
    expect(p.phase, GlassPhotoImportPhase.importing);
    expect(p.total, 4);
    expect(p.currentIndex, 1);
    expect(p.itemFraction, 0.25);
    expect(p.fraction, closeTo((0.5 + 0.25) / 4, 1e-9));
  });

  test('a final event (itemFraction 1) moves the item to completed', () {
    final t = PhotoImportTracker();
    t.onEvent(_e(0, 2, 0, 0.9));
    final p = t.onEvent(_e(0, 2, 1, 1.0));
    expect(p.completed, 1);
    expect(p.fraction, closeTo(0.5, 1e-9));
  });

  test('fraction never decreases', () {
    final t = PhotoImportTracker();
    final seen = <double>[
      t.onEvent(_e(0, 3, 0, 0.6)).fraction,
      t.onEvent(_e(0, 3, 0)).fraction, // unknown size keeps the last value
      t.onEvent(_e(0, 3, 0, 0.3)).fraction, // stale, out of order
      t.onEvent(_e(0, 3, 1, 1.0)).fraction,
      t.onEvent(_e(0, 3, 1, 0.2)).fraction, // after its final event
      t.onEvent(_e(1, 3, 1, 0.1)).fraction,
    ];
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
    expect(seen.every((f) => f >= 0 && f <= 1), isTrue);
  });

  test('done reports phase done and fraction 1', () {
    final t = PhotoImportTracker();
    t.onEvent(_e(0, 2, 1, 1.0));
    final p = t.done();
    expect(p.phase, GlassPhotoImportPhase.done);
    expect(p.fraction, 1);
  });

  test('total 0 keeps fraction 0', () {
    expect(PhotoImportTracker().onEvent(_e(0, 0, 0)).fraction, 0);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/photos_picker/photo_import_tracker_test.dart`
Expected: FAIL to compile ("Target of URI doesn't exist: photo_import_tracker.dart").

- [ ] **Step 3: Implement**

```dart
// lib/src/photos_picker/glass_photo_import_progress.dart
import 'package:flutter/foundation.dart';

/// Where a `pickGlassPhotos` import is.
enum GlassPhotoImportPhase {
  /// The system picker is showing.
  selecting,

  /// Chosen items are being copied and converted.
  importing,

  /// The result has been delivered (or the import was cancelled).
  done,
}

/// A snapshot of an import's progress, for `onProgress` and
/// [GlassPhotoImportController.progress].
@immutable
class GlassPhotoImportProgress {
  const GlassPhotoImportProgress({
    required this.total,
    required this.completed,
    this.currentIndex,
    this.itemFraction,
    required this.fraction,
    required this.phase,
  });

  /// Before anything is chosen.
  static const selecting = GlassPhotoImportProgress(
    total: 0,
    completed: 0,
    fraction: 0,
    phase: GlassPhotoImportPhase.selecting,
  );

  /// Number of selected items.
  final int total;

  /// Items finished, failed or skipped.
  final int completed;

  /// Selection index of the most recently updated item.
  final int? currentIndex;

  /// 0-1 progress of [currentIndex]: copy, then conversion when it runs.
  /// Null when its size is unknown.
  final double? itemFraction;

  /// Overall 0-1 progress, for a single bar.
  final double fraction;

  final GlassPhotoImportPhase phase;

  @override
  bool operator ==(Object other) =>
      other is GlassPhotoImportProgress &&
      other.total == total &&
      other.completed == completed &&
      other.currentIndex == currentIndex &&
      other.itemFraction == itemFraction &&
      other.fraction == fraction &&
      other.phase == phase;

  @override
  int get hashCode =>
      Object.hash(total, completed, currentIndex, itemFraction, fraction, phase);

  @override
  String toString() =>
      'GlassPhotoImportProgress($phase, $completed/$total, '
      'item $currentIndex: $itemFraction, fraction: $fraction)';
}
```

```dart
// lib/src/photos_picker/photo_import_tracker.dart
import 'dart:math' as math;

import 'glass_photo_import_progress.dart';

/// Folds native `progress` events into [GlassPhotoImportProgress].
///
/// Native throttles; this tolerates bursts, duplicates, unknown sizes and
/// out-of-order events, and never lets [GlassPhotoImportProgress.fraction]
/// go backwards.
class PhotoImportTracker {
  final Map<int, double> _inFlight = {};
  final Set<int> _finished = {};
  GlassPhotoImportProgress _current = GlassPhotoImportProgress.selecting;

  GlassPhotoImportProgress get current => _current;

  GlassPhotoImportProgress onEvent(Map<Object?, Object?> args) {
    final index = (args['index'] as num?)?.toInt();
    final total = (args['total'] as num?)?.toInt() ?? _current.total;
    final completed = math.max(
      (args['completed'] as num?)?.toInt() ?? 0,
      _current.completed,
    );
    final item = (args['itemFraction'] as num?)?.toDouble().clamp(0.0, 1.0);
    if (index != null && !_finished.contains(index)) {
      if (item == 1.0) {
        _finished.add(index);
        _inFlight.remove(index);
      } else if (item != null) {
        _inFlight[index] = math.max(item, _inFlight[index] ?? 0);
      }
    }
    final inFlight = _inFlight.values.fold<double>(0, (a, b) => a + b);
    final raw = total <= 0 ? 0.0 : ((completed + inFlight) / total).clamp(0.0, 1.0);
    return _current = GlassPhotoImportProgress(
      total: total,
      completed: completed,
      currentIndex: index ?? _current.currentIndex,
      itemFraction: item ?? (index == null ? null : _inFlight[index]),
      fraction: math.max(raw, _current.fraction),
      phase: GlassPhotoImportPhase.importing,
    );
  }

  GlassPhotoImportProgress done() => _current = GlassPhotoImportProgress(
    total: _current.total,
    completed: _current.total,
    currentIndex: _current.currentIndex,
    itemFraction: _current.itemFraction,
    fraction: 1,
    phase: GlassPhotoImportPhase.done,
  );
}
```

Add `export 'src/photos_picker/glass_photo_import_progress.dart';` after line 89 of `lib/adaptive_liquid_glass.dart`. Keep the alphabetical order of the photos_picker block.

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/photos_picker/photo_import_tracker_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/photos_picker/glass_photo_import_progress.dart lib/src/photos_picker/photo_import_tracker.dart lib/adaptive_liquid_glass.dart test/photos_picker/photo_import_tracker_test.dart
git commit -m "feat(photos): import progress model and tracker"
```

---

### Task 2: Controller, `index`, `cancelled`, and the `pickGlassPhotos` protocol

**Files:**
- Create: `lib/src/photos_picker/glass_photo_import_controller.dart`
- Modify: `lib/src/photos_picker/glass_picked_photo.dart` (add `index`)
- Modify: `lib/src/photos_picker/glass_picked_photos.dart` (add `cancelled`)
- Modify: `lib/src/photos_picker/pick_glass_photos.dart`
- Modify: `lib/adaptive_liquid_glass.dart` (export with `show GlassPhotoImportController`)
- Test: `test/photos_picker/glass_photos_picker_test.dart` (append a `group('progress and cancel', ...)`)

**Interfaces:**
- Consumes: `PhotoImportTracker`, `GlassPhotoImportProgress` and `GlassPhotoImportPhase` (Task 1).
- Produces:
  - `class GlassPhotoImportController`:
    - `void cancel()`;
    - `ValueListenable<bool> get isActive`;
    - `ValueListenable<GlassPhotoImportProgress?> get progress`;
    - `void dispose()`.
  - Library-internal `GlassPhotoImportBinding attachImport(GlassPhotoImportController c, void Function() onCancel)`, where `GlassPhotoImportBinding` has `void update(GlassPhotoImportProgress p)` and `void detach()`. It is not exported (the barrel uses `show`).
  - `GlassPickedPhoto.index` (`int?`, null from older plugins).
  - `GlassPickedPhotos(items, {droppedCount = 0, cancelled = false})` and `.cancelled`.
  - The `pickGlassPhotos` signature gains `GlassPhotoImportController? controller` and `ValueChanged<GlassPhotoImportProgress>? onProgress`.
  - Main-channel call: `cancelPhotoImport` with `{'importChannel': String}`.

Note: `index` is `int?` rather than `int`. The spec calls it `int`, but an older native plugin cannot supply it, and a non-null default (0) would mis-slot items. Document it as "null only with an older native plugin".

- [ ] **Step 1: Write the failing tests** (append inside `main()` of `test/photos_picker/glass_photos_picker_test.dart`, which already has `_channel`, `_mock`, `_ready`, `_image`, `_video`)

```dart
  Future<void> push(String channel, String method, Object? args) {
    final done = Completer<void>();
    ui.channelBuffers.push(
      channel,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) => done.complete(),
    );
    return done.future;
  }

  group('progress and cancel', () {
    testWidgets('onProgress alone opens an import channel', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final seen = <GlassPhotoImportProgress>[];
      final future = pickGlassPhotos(maxSelection: 0, onProgress: seen.add);
      await tester.pump();
      final name = (calls.single.arguments as Map)['importChannel'] as String;
      await push(name, 'progress', {'index': 0, 'total': 2, 'completed': 0, 'itemFraction': 0.5});
      reply.complete({'items': [_image], 'dropped': 0});
      await future;
      expect(seen.first.fraction, closeTo(0.25, 1e-9));
      expect(seen.last.phase, GlassPhotoImportPhase.done);
    }, variant: _both);

    testWidgets('controller.cancel sends cancelPhotoImport with the channel', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((call) async {
        if (call.method == 'cancelPhotoImport') {
          reply.complete({'items': [_image], 'dropped': 0, 'cancelled': true});
          return null;
        }
        return reply.future;
      });
      final controller = GlassPhotoImportController();
      final future = pickGlassPhotos(maxSelection: 0, controller: controller);
      await tester.pump();
      expect(controller.isActive.value, isTrue);
      controller.cancel();
      controller.cancel(); // idempotent
      final photos = await future;
      final name = (calls.first.arguments as Map)['importChannel'];
      final cancels = calls.where((c) => c.method == 'cancelPhotoImport').toList();
      expect(cancels, hasLength(1));
      expect((cancels.single.arguments as Map)['importChannel'], name);
      expect(photos.cancelled, isTrue);
      expect(photos, hasLength(1));
      expect(controller.isActive.value, isFalse);
    }, variant: _both);

    testWidgets('a platform error after cancel is swallowed', (tester) async {
      final reply = Completer<Object?>();
      _mock((call) async {
        if (call.method == 'cancelPhotoImport') {
          reply.completeError(PlatformException(code: 'load_failed'));
          return null;
        }
        return reply.future;
      });
      final controller = GlassPhotoImportController();
      final delivered = <GlassPickedPhoto>[];
      final future = pickGlassPhotos(
        maxSelection: 0, controller: controller, onItemReady: delivered.add);
      await tester.pump();
      controller.cancel();
      final photos = await future;
      expect(photos.cancelled, isTrue);
      expect(photos, isEmpty);
    }, variant: _both);

    testWidgets('cancel after completion is a no-op', (tester) async {
      final calls = _mock((_) async => {'items': [_image], 'dropped': 0});
      final controller = GlassPhotoImportController();
      final photos = await pickGlassPhotos(controller: controller);
      controller.cancel();
      await tester.pump();
      expect(photos.cancelled, isFalse);
      expect(calls.where((c) => c.method == 'cancelPhotoImport'), isEmpty);
    }, variant: _both);

    testWidgets('cancel before any import does nothing', (tester) async {
      final calls = _mock((_) async => const <Object?>[]);
      GlassPhotoImportController().cancel();
      await tester.pump();
      expect(calls, isEmpty);
    }, variant: _both);

    testWidgets('a controller drives one import at a time, then is reusable', (tester) async {
      final reply = Completer<Object?>();
      _mock((_) => reply.future);
      final controller = GlassPhotoImportController();
      final first = pickGlassPhotos(controller: controller);
      await tester.pump();
      expect(() => pickGlassPhotos(controller: controller), throwsStateError);
      reply.complete(const <Object?>[]);
      await first;
      _mock((_) async => [_image]);
      expect(await pickGlassPhotos(controller: controller), hasLength(1));
    }, variant: _both);

    testWidgets('a bare list reply still parses, cancelled false', (tester) async {
      _mock((_) async => [_image, _video]);
      final photos = await pickGlassPhotos(maxSelection: 0);
      expect(photos, hasLength(2));
      expect(photos.cancelled, isFalse);
    }, variant: _both);

    testWidgets('itemReady carries index', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      final got = <GlassPickedPhoto>[];
      final future = pickGlassPhotos(maxSelection: 0, onItemReady: got.add);
      await tester.pump();
      final name = (calls.single.arguments as Map)['importChannel'] as String;
      await _ready(name, {..._video, 'index': 1});
      await _ready(name, {..._image, 'index': 0});
      reply.complete({'items': [{..._image, 'index': 0}, {..._video, 'index': 1}]});
      final photos = await future;
      expect(got.map((p) => p.index), [1, 0]);
      expect(photos.map((p) => p.index), [0, 1]);
    }, variant: _both);
  });
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/photos_picker/glass_photos_picker_test.dart`
Expected: FAIL to compile (`GlassPhotoImportController`, `onProgress` and `cancelled` undefined).

- [ ] **Step 3: Implement**

```dart
// lib/src/photos_picker/glass_photo_import_controller.dart
import 'package:flutter/foundation.dart';

import 'glass_photo_import_progress.dart';

/// Watches and stops a `pickGlassPhotos` import.
///
/// ```dart
/// final controller = GlassPhotoImportController();
/// pickGlassPhotos(maxSelection: 0, controller: controller);
/// // later, e.g. from a Stop button:
/// controller.cancel();
/// ```
///
/// One controller drives one import at a time; it can be reused once that
/// import has finished. [cancel] is safe at any time.
class GlassPhotoImportController {
  final ValueNotifier<bool> _active = ValueNotifier(false);
  final ValueNotifier<GlassPhotoImportProgress?> _progress = ValueNotifier(null);
  GlassPhotoImportBinding? _binding;

  /// Whether an import is running (including while the picker shows).
  ValueListenable<bool> get isActive => _active;

  /// The latest progress; null before the first import.
  ValueListenable<GlassPhotoImportProgress?> get progress => _progress;

  /// Stops the running import. Items already finished are kept and the
  /// result reports [GlassPickedPhotos.cancelled]. Does nothing when idle.
  void cancel() => _binding?._cancel();

  void dispose() {
    _active.dispose();
    _progress.dispose();
  }
}

/// Connects one import to a controller. Not exported.
GlassPhotoImportBinding attachImport(
  GlassPhotoImportController controller,
  void Function() onCancel,
) {
  if (controller._binding != null) {
    throw StateError('This GlassPhotoImportController is already driving an import.');
  }
  final binding = GlassPhotoImportBinding._(controller, onCancel);
  controller._binding = binding;
  controller._active.value = true;
  controller._progress.value = GlassPhotoImportProgress.selecting;
  return binding;
}

class GlassPhotoImportBinding {
  GlassPhotoImportBinding._(this._controller, this._onCancel);

  final GlassPhotoImportController _controller;
  final void Function() _onCancel;
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel();
  }

  void update(GlassPhotoImportProgress progress) {
    if (identical(_controller._binding, this)) _controller._progress.value = progress;
  }

  void detach() {
    if (!identical(_controller._binding, this)) return;
    _controller._binding = null;
    _controller._active.value = false;
  }
}
```

Because the binding needs its own cancel state when no controller is passed, `pickGlassPhotos` keeps a local `cancelled` flag and the binding only forwards to it.

`glass_picked_photo.dart`:
- add `this.index` to the constructor and the field `/// Selection order (0-based); null only with an older native plugin. final int? index;`;
- in `fromMap`: `index: (map['index'] as num?)?.toInt(),`;
- add `index` to `==`, `hashCode` (inside `Object.hash`) and `toString`.

`glass_picked_photos.dart`: the constructor becomes `GlassPickedPhotos(Iterable<GlassPickedPhoto> items, {this.droppedCount = 0, this.cancelled = false})`. Add the field `/// Whether the import was stopped with [GlassPhotoImportController.cancel]; only finished items are included. final bool cancelled;`.

`pick_glass_photos.dart`: replace from `final imports = ...` to the end of the function with:

```dart
  final tracker = PhotoImportTracker();
  var cancelled = false;
  late final GlassPhotoImportBinding? binding;
  void report(GlassPhotoImportProgress p) {
    binding?.update(p);
    if (onProgress == null) return;
    try {
      onProgress(p);
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'adaptive_liquid_glass',
          context: ErrorDescription('while reporting photo import progress'),
        ),
      );
    }
  }

  final imports = onItemReady == null && onProgress == null && controller == null
      ? null
      : MethodChannel(
          'adaptive_liquid_glass/photo_import/${DateTime.now().microsecondsSinceEpoch}_${_nextImport++}',
        );
  binding = controller == null
      ? null
      : attachImport(controller, () {
          cancelled = true;
          _channel
              .invokeMethod<void>('cancelPhotoImport', {'importChannel': imports!.name})
              .catchError((Object _) {}); // older plugin or stale name: no-op
        });
  imports?.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'itemReady':
        deliver(GlassPickedPhoto.fromMap(call.arguments as Map<Object?, Object?>));
      case 'progress':
        report(tracker.onEvent(call.arguments as Map<Object?, Object?>));
    }
  });
  try {
    // A list of items, or {items, dropped, cancelled}.
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('pickPhotos', {
        'maxSelection': maxSelection,
        'filter': filter.name,
        'maxWidth': ?maxWidth,
        'maxHeight': ?maxHeight,
        'imageQuality': ?imageQuality,
        if (compatibleFormat) 'compatibleFormat': true,
        if (imports != null) 'importChannel': imports.name,
      });
    } on PlatformException {
      // Cancel is not an error: keep what was delivered.
      if (!cancelled) rethrow;
      return GlassPickedPhotos(const [], cancelled: true);
    }
    final (items, dropped, nativeCancelled) = switch (reply) {
      final Map<Object?, Object?> map => (
        map['items'] as List<Object?>?,
        (map['dropped'] as num?)?.toInt() ?? 0,
        map['cancelled'] == true,
      ),
      final List<Object?> list => (list, 0, false),
      _ => (null, 0, false),
    };
    final photos = GlassPickedPhotos(
      [
        for (final item in items ?? const <Object?>[])
          GlassPickedPhoto.fromMap(item! as Map<Object?, Object?>),
      ],
      droppedCount: dropped,
      cancelled: nativeCancelled || (cancelled && reply == null),
    );
    for (final photo in photos) {
      deliver(photo);
    }
    report(tracker.done());
    return photos;
  } finally {
    imports?.setMethodCallHandler(null);
    binding?.detach();
  }
}
```

`binding` is `late final` because `report` runs only after it is assigned. Also update the doc comment:
- add `[controller]`: one sentence plus the cancel semantics from the spec §2;
- add `[onProgress]`: throttled, `fraction` for one bar;
- state that `itemReady` order may differ from selection order on iOS and to use `GlassPickedPhoto.index`.

Add the parameters after `onItemReady`:

```dart
  ValueChanged<GlassPickedPhoto>? onItemReady,
  ValueChanged<GlassPhotoImportProgress>? onProgress,
  GlassPhotoImportController? controller,
```

Add the imports `glass_photo_import_controller.dart`, `glass_photo_import_progress.dart` and `photo_import_tracker.dart`. In the barrel, add `export 'src/photos_picker/glass_photo_import_controller.dart' show GlassPhotoImportController;`.

- [ ] **Step 4: Run all photos tests and confirm they pass**

Run: `flutter test test/photos_picker/`
Expected: PASS. All pre-existing tests still pass (no breaking change).

- [ ] **Step 5: Commit**

```bash
git add lib/src/photos_picker lib/adaptive_liquid_glass.dart test/photos_picker/glass_photos_picker_test.dart
git commit -m "feat(photos): import controller, progress events and cancel protocol"
```

---

### Task 3: `GlassButton` determinate loading and press-while-loading

**Files:**
- Modify: `lib/src/button/glass_button.dart` (constructors at :50 and :72, fields near :101, `active` at :147, loading stack at :223, semantics at :289-293, and the tap gesture that reads `active`)
- Modify: `lib/src/button/system_style_button.dart:160` (indicator) and `:254-258` (semantics)
- Modify: `lib/src/button/material_glass_button.dart:84-128` (onPressed while loading, indicator) and `:188` (semantics)
- Test: `test/button/glass_button_loading_test.dart` (create)

**Interfaces:**
- Produces two new optional parameters on both `GlassButton` constructors:
  - `double? loadingValue`: a 0–1 determinate ring while `loading`; null keeps the spinner.
  - `VoidCallback? onLoadingPressed`: a tap while `loading` calls it. When it is set, the loading button stays an enabled button in semantics, labelled with `loadingLabel`.

- [ ] **Step 1: Write the failing test**

```dart
// test/button/glass_button_loading_test.dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));

  for (final style in [GlassButtonStyle.glass, GlassButtonStyle.bordered]) {
    testWidgets('$style: loadingValue shows a determinate ring', (tester) async {
      await tester.pumpWidget(host(GlassButton(
        onPressed: () {}, loading: true, loadingValue: 0.4, style: style,
        child: const Text('Go'),
      )));
      final cupertino = find.byType(CupertinoActivityIndicator);
      final material = find.byType(CircularProgressIndicator);
      expect(cupertino.evaluate().length + material.evaluate().length, 1);
      if (material.evaluate().isNotEmpty) {
        expect(tester.widget<CircularProgressIndicator>(material).value, 0.4);
      } else {
        expect(tester.widget<CupertinoActivityIndicator>(cupertino).progress, 0.4);
      }
    });

    testWidgets('$style: onLoadingPressed fires while loading', (tester) async {
      var pressed = 0, cancelled = 0;
      await tester.pumpWidget(host(GlassButton(
        onPressed: () => pressed++, onLoadingPressed: () => cancelled++,
        loading: true, loadingLabel: 'Cancel import', style: style,
        child: const Text('Go'),
      )));
      await tester.tap(find.byType(GlassButton));
      expect((pressed, cancelled), (0, 1));
      expect(
        tester.getSemantics(find.byType(GlassButton)),
        matchesSemantics(
          isButton: true, isEnabled: true, hasEnabledState: true, hasTapAction: true,
          label: 'Go', value: 'Cancel import',
        ),
      );
    });
  }

  testWidgets('without onLoadingPressed a loading tap does nothing', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(host(GlassButton(
      onPressed: () => pressed++, loading: true, child: const Text('Go'),
    )));
    await tester.tap(find.byType(GlassButton), warnIfMissed: false);
    expect(pressed, 0);
  });
}
```

`host(...)` comes from `test/api/hosts.dart`, which the photos test imports. If its name differs, use the helper that file exports. Pick the two styles so that one hits the glass path and one the system/material path: check `GlassButtonStyle` values, and on Android `TargetPlatformVariant` may be needed to reach `material_glass_button.dart`. Add `variant: TargetPlatformVariant.only(TargetPlatform.android)` to a third copy of the two tests if neither style reaches the material path on the default test platform.

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/button/glass_button_loading_test.dart`
Expected: FAIL to compile (`loadingValue` / `onLoadingPressed` undefined).

- [ ] **Step 3: Implement**

In `glass_button.dart`:

```dart
  /// 0-1 progress for a determinate ring while [loading]; null shows the
  /// spinner.
  final double? loadingValue;

  /// Called when the button is tapped while [loading], e.g. to cancel.
  /// Without it a loading button ignores taps.
  final VoidCallback? onLoadingPressed;

  bool get active => loading ? onLoadingPressed != null : onPressed != null;

  VoidCallback? get _tap => loading ? onLoadingPressed : onPressed;
```

- Replace every place the gesture invokes `onPressed` (find it with `grep -n "onPressed" lib/src/button/glass_button.dart`) with `_tap`.
- In the loading stack at :223:

```dart
          loadingValue == null
              ? CupertinoActivityIndicator(radius: m.fontSize * 0.5, color: labelColor)
              : CupertinoActivityIndicator.partiallyRevealed(
                  radius: m.fontSize * 0.5,
                  color: labelColor,
                  progress: loadingValue!.clamp(0.0, 1.0),
                ),
```

- Semantics at :289-293: `enabled: active` (it is already derived from `active`; if it reads `onPressed != null && !loading`, switch it to `active`) and `onTap: active ? _tap : null`.
- Thread both parameters through both constructors and the places that forward the button to `SystemStyleButton` / `MaterialGlassButton` (search for `b.loading`).

In `system_style_button.dart:160`, use the same `loadingValue` switch on the indicator. At :254-258, set `enabled`/`onTap` from `b.active` and `b._tap`. `_tap` is library-private, so instead make it public as `VoidCallback? get effectiveOnPressed`. Use that name in all three files.

In `material_glass_button.dart:84`: `final VoidCallback? onPressed = b.effectiveOnPressed;`. Keep the loading colours keyed on `b.loading`, not on the disabled state:
- when `b.loading && onPressed != null`, the button is enabled, so pass `backgroundColor`/`foregroundColor` from `loadingBackground`/`loadingForeground` directly instead of through `disabled*`;
- at :107, use `CircularProgressIndicator(value: b.loadingValue, strokeWidth: 2, color: loadingForeground)` wherever an indicator is built today.

- [ ] **Step 4: Run the test and the whole button suite**

Run: `flutter test test/button/`
Expected: PASS, including every pre-existing button test.

- [ ] **Step 5: Commit**

```bash
git add lib/src/button test/button/glass_button_loading_test.dart
git commit -m "feat(button): loadingValue ring and onLoadingPressed"
```

---

### Task 4: `GlassPhotosPicker` widget: ring, tap-to-cancel, controller

**Files:**
- Modify: `lib/src/photos_picker/glass_photos_picker.dart` (constructor :44-60, fields, `_GlassPhotosPickerState` :140-223)
- Test: `test/photos_picker/glass_photos_picker_test.dart` (append `group('widget progress', ...)`)

**Interfaces:**
- Consumes:
  - `GlassPhotoImportController` (Task 2);
  - `pickGlassPhotos(controller:, onProgress:)` (Task 2);
  - `GlassButton(loadingValue:, onLoadingPressed:, loadingLabel:)` (Task 3).
- Produces new widget parameters:
  - `GlassPhotoImportController? controller`;
  - `ValueChanged<GlassPhotoImportProgress>? onProgress`;
  - `bool showProgress = true`;
  - `String cancelLabel = 'Cancel import'`.

- [ ] **Step 1: Write the failing tests**

```dart
  group('widget progress', () {
    Widget picker({GlassPhotoImportController? controller, ValueChanged<GlassPickedPhotos>? onPicked}) =>
        host(GlassPhotosPicker(
          maxSelection: 0,
          controller: controller,
          onPicked: onPicked ?? (_) {},
          label: 'Photos',
        ));

    testWidgets('shows the ring value from progress', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      await tester.pumpWidget(picker());
      await tester.tap(find.byType(GlassPhotosPicker));
      await tester.pump();
      final name = (calls.single.arguments as Map)['importChannel'] as String;
      await push(name, 'progress', {'index': 0, 'total': 2, 'completed': 1, 'itemFraction': 1.0});
      await tester.pump();
      expect(tester.widget<GlassButton>(find.byType(GlassButton)).loadingValue, closeTo(0.5, 1e-9));
      reply.complete(const <Object?>[]);
      await tester.pumpAndSettle();
    }, variant: _both);

    testWidgets('tapping the busy trigger cancels', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((call) async {
        if (call.method == 'cancelPhotoImport') {
          reply.complete({'items': [_image], 'cancelled': true});
          return null;
        }
        return reply.future;
      });
      GlassPickedPhotos? got;
      await tester.pumpWidget(picker(onPicked: (p) => got = p));
      await tester.tap(find.byType(GlassPhotosPicker));
      await tester.pump();
      expect(tester.widget<GlassButton>(find.byType(GlassButton)).loadingLabel, 'Cancel import');
      await tester.tap(find.byType(GlassPhotosPicker));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'cancelPhotoImport'), hasLength(1));
      expect(got?.cancelled, isTrue); // finished items still reach onPicked
    }, variant: _both);

    testWidgets('cancel during selection', (tester) async {
      final reply = Completer<Object?>();
      _mock((call) async {
        if (call.method == 'cancelPhotoImport') {
          reply.complete({'items': [], 'dropped': 0, 'cancelled': true});
          return null;
        }
        return reply.future;
      });
      final controller = GlassPhotoImportController();
      var picked = 0;
      await tester.pumpWidget(picker(controller: controller, onPicked: (_) => picked++));
      await tester.tap(find.byType(GlassPhotosPicker));
      await tester.pump();
      controller.cancel();
      await tester.pumpAndSettle();
      expect(picked, 0);
      expect(controller.isActive.value, isFalse);
      _mock((_) async => [_image]);
      await tester.tap(find.byType(GlassPhotosPicker));
      await tester.pumpAndSettle();
      expect(picked, 1);
    }, variant: _both);

    testWidgets('dispose during import is quiet', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      await tester.pumpWidget(picker());
      await tester.tap(find.byType(GlassPhotosPicker));
      await tester.pump();
      final name = (calls.single.arguments as Map)['importChannel'] as String;
      await tester.pumpWidget(host(const SizedBox()));
      await push(name, 'progress', {'index': 0, 'total': 1, 'completed': 0, 'itemFraction': 0.5});
      reply.complete([_image]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, variant: _both);

    testWidgets('showProgress false keeps the spinner', (tester) async {
      final reply = Completer<Object?>();
      final calls = _mock((_) => reply.future);
      await tester.pumpWidget(host(GlassPhotosPicker(
        onPicked: (_) {}, label: 'Photos', showProgress: false)));
      await tester.tap(find.byType(GlassPhotosPicker));
      await tester.pump();
      final name = (calls.single.arguments as Map)['importChannel'] as String;
      await push(name, 'progress', {'index': 0, 'total': 1, 'completed': 0, 'itemFraction': 0.5});
      await tester.pump();
      expect(tester.widget<GlassButton>(find.byType(GlassButton)).loadingValue, isNull);
      reply.complete(const <Object?>[]);
      await tester.pumpAndSettle();
    }, variant: _both);
  });
```

`push` is the helper added in Task 2. The "finished items still reach onPicked" rule is deliberate: the user stopped, but the finished items are real results and the app expects them through the normal callback. `onPicked` is skipped only when the list is empty, as it is today.

- [ ] **Step 2: Run and confirm the tests fail**

Run: `flutter test test/photos_picker/glass_photos_picker_test.dart`
Expected: FAIL to compile (`controller`/`showProgress` undefined on `GlassPhotosPicker`).

- [ ] **Step 3: Implement**

Add the fields with doc comments: `controller` ("Watches or stops the import; the trigger itself cancels on tap while busy"), `onProgress`, `showProgress` and `cancelLabel`. Then rewrite the state:

```dart
class _GlassPhotosPickerState extends State<GlassPhotosPicker> {
  bool _open = false;
  GlassPhotoImportController? _own;
  GlassPhotoImportController get _controller =>
      widget.controller ?? (_own ??= GlassPhotoImportController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }
```

`_own?.dispose()` disposes the notifiers, so `GlassPhotoImportBinding` must not touch them afterwards. In `glass_photo_import_controller.dart`:

```dart
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _active.dispose();
    _progress.dispose();
  }

  // GlassPhotoImportBinding:
  void update(GlassPhotoImportProgress progress) {
    if (_controller._disposed || !identical(_controller._binding, this)) return;
    _controller._progress.value = progress;
  }

  void detach() {
    if (!identical(_controller._binding, this)) return;
    _controller._binding = null;
    if (!_controller._disposed) _controller._active.value = false;
  }
```

The "dispose during import" test covers this (a late progress event and the final reply both arrive after dispose).

In `_pick()`, pass:

```dart
        controller: _controller,
        onProgress: widget.onProgress == null
            ? null
            : (p) {
                if (mounted) widget.onProgress?.call(p);
              },
```

In `build`, wrap the `GlassButton` construction in a `ValueListenableBuilder<GlassPhotoImportProgress?>` on `_controller.progress`, and on both `GlassButton` and `GlassButton.icon` set:

```dart
        loadingValue: !widget.showProgress || p == null ||
                p.phase != GlassPhotoImportPhase.importing
            ? null
            : p.fraction,
        onLoadingPressed: _controller.cancel,
        loadingLabel: widget.cancelLabel,
```

- [ ] **Step 4: Run and confirm the tests pass**

Run: `flutter test test/photos_picker/ test/button/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/photos_picker test/photos_picker
git commit -m "feat(photos): picker trigger shows progress and cancels on tap"
```

---

### Task 5: Example demo and baseline bench (old native)

**Files:**
- Modify: `example/lib/components_demo.dart:723` (the `GlassPhotosPicker` demo)
- Modify: this plan's `## Bench` section (record the numbers)

**Interfaces:**
- Consumes: the widget parameters from Task 4.

- [ ] **Step 1: Add the progress bar, the Stop button and timing to the demo**

Near the existing picker at `components_demo.dart:723`, add a `GlassPhotoImportController _import = GlassPhotoImportController();` field to the demo's State, dispose it in `dispose()`, and render:

```dart
GlassPhotosPicker(
  maxSelection: 0,
  filter: GlassPhotosPickerFilter.any,
  compatibleFormat: true,
  controller: _import,
  onItemReady: (p) => debugPrint('ready #${p.index}: ${p.path}'),
  onPicked: (photos) {
    debugPrint('import: ${_stopwatch.elapsedMilliseconds} ms for '
        '${photos.length} items, cancelled: ${photos.cancelled}');
    // keep the demo's existing onPicked body here
  },
  label: 'Photos',
),
ValueListenableBuilder(
  valueListenable: _import.progress,
  builder: (context, p, _) => p == null || p.phase == GlassPhotoImportPhase.done
      ? const SizedBox.shrink()
      : Row(children: [
          Expanded(child: LinearProgressIndicator(value: p.fraction)),
          TextButton(onPressed: _import.cancel, child: const Text('Stop')),
        ]),
),
```

Add a `final _stopwatch = Stopwatch();` and restart it when the import becomes active: `_import.isActive.addListener(() { if (_import.isActive.value) _stopwatch..reset()..start(); });` in `initState`.

Note: `_stopwatch` starts while the picker shows. For the bench, read the time from the first `ready #` log line to the `import:` line instead. Add `debugPrint('first item at ${_stopwatch.elapsedMilliseconds} ms')` on the first `onItemReady`.

- [ ] **Step 2: Run the analyzer**

Run: `cd example && flutter analyze lib/components_demo.dart`
Expected: No issues.

- [ ] **Step 3: Record the baseline on unchanged native code**

Run the example on the iPhone 17 Pro simulator (`cd example && flutter run -d "iPhone 17 Pro"`).
- Pick 20 photos and log (import time − first-item time).
- Repeat for 5 HEVC videos with `compatibleFormat`.
- Do the same on an Android emulator.

The Android HEVC path needs an HEVC sample. Record any that is missing as "n/a: no sample" rather than guessing. Write the numbers into `## Bench → Before` at the end of this plan.

- [ ] **Step 4: Commit**

```bash
git add example/lib/components_demo.dart docs/superpowers/plans/2026-11-04-photos-import-progress-cancel.md
git commit -m "chore(example): import progress demo and baseline bench"
```

---

### Task 6: Android cancel token, progress throttle, chunked copy

**Files:**
- Create: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/PhotoImportJob.kt`
- Test: `android/src/test/kotlin/com/aymanomara/adaptive_liquid_glass/PhotoImportJobTest.kt`

**Interfaces:**
- Produces:
  - `internal class ImportCancel { @Volatile var cancelled: Boolean; fun check() }`. `check()` throws `java.util.concurrent.CancellationException` when cancelled.
  - `internal class ProgressThrottle(total: Int, intervalNanos: Long = 100ms, now: () -> Long = System::nanoTime, emit: (Map<String, Any?>) -> Unit)`:
    - `fun update(index: Int, itemFraction: Double?)` emits at most once per interval;
    - `fun finish(index: Int)` always emits, increments `completed` and sends `itemFraction 1.0`.
  - `internal object ChunkedCopy { const val CHUNK = 256 * 1024; fun copy(input: InputStream, output: OutputStream, size: Long?, cancel: ImportCancel, onFraction: (Double?) -> Unit, onChunk: () -> Unit = {}) }`.

- [ ] **Step 1: Write the failing tests**

```kotlin
package com.aymanomara.adaptive_liquid_glass

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.CancellationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class PhotoImportJobTest {
    @Test
    fun throttleDropsBurstsButKeepsFinalEvent() {
        var time = 0L
        val events = mutableListOf<Map<String, Any?>>()
        val throttle = ProgressThrottle(2, intervalNanos = 100, now = { time }) { events += it }
        throttle.update(0, 0.1) // emits (first)
        time = 50
        throttle.update(0, 0.2) // dropped
        throttle.finish(0) // always emits
        assertEquals(listOf(0.1, 1.0), events.map { it["itemFraction"] })
        assertEquals(1, events.last()["completed"])
        assertEquals(2, events.last()["total"])
        assertEquals(0, events.last()["index"])
    }

    @Test
    fun throttleEmitsAgainAfterInterval() {
        var time = 0L
        val events = mutableListOf<Map<String, Any?>>()
        val throttle = ProgressThrottle(1, intervalNanos = 100, now = { time }) { events += it }
        throttle.update(0, 0.1)
        time = 100
        throttle.update(0, null)
        assertEquals(2, events.size)
        assertTrue("itemFraction" !in events.last() || events.last()["itemFraction"] == null)
    }

    @Test
    fun chunkedCopyReportsFractionAndCopiesAll() {
        val data = ByteArray(ChunkedCopy.CHUNK * 2 + 10) { it.toByte() }
        val out = ByteArrayOutputStream()
        val fractions = mutableListOf<Double?>()
        ChunkedCopy.copy(ByteArrayInputStream(data), out, data.size.toLong(), ImportCancel(), { fractions += it })
        assertTrue(data.contentEquals(out.toByteArray()))
        assertEquals(1.0, fractions.last()!!, 1e-9)
        assertEquals(3, fractions.size)
    }

    @Test
    fun chunkedCopyUnknownSizeReportsNull() {
        val fractions = mutableListOf<Double?>()
        ChunkedCopy.copy(ByteArrayInputStream(ByteArray(10)), ByteArrayOutputStream(), null, ImportCancel(), { fractions += it })
        assertEquals(listOf<Double?>(null), fractions)
    }

    @Test
    fun chunkedCopyHonoursCancelBetweenChunks() {
        val cancel = ImportCancel()
        val data = ByteArray(ChunkedCopy.CHUNK * 4)
        val out = ByteArrayOutputStream()
        try {
            ChunkedCopy.copy(ByteArrayInputStream(data), out, data.size.toLong(), cancel, { cancel.cancelled = true })
            fail("expected CancellationException")
        } catch (e: CancellationException) {
            assertEquals(ChunkedCopy.CHUNK, out.size())
        }
    }
}
```

- [ ] **Step 2: Run and confirm the tests fail**

Run: `cd example/android && ./gradlew :adaptive_liquid_glass:testDebugUnitTest --tests '*PhotoImportJobTest*'`
Expected: FAIL to compile (unresolved `ProgressThrottle`, `ChunkedCopy`, `ImportCancel`).

- [ ] **Step 3: Implement**

```kotlin
package com.aymanomara.adaptive_liquid_glass

import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.CancellationException
import java.util.concurrent.TimeUnit

/** Set from the main thread by `cancelPhotoImport`; read by the import and codec threads. */
internal class ImportCancel {
    @Volatile
    var cancelled = false

    fun check() {
        if (cancelled) throw CancellationException("Photo import cancelled.")
    }
}

/**
 * Sends `progress` events at most every [intervalNanos], and always one
 * final event per item, so Dart never misses a completion.
 */
internal class ProgressThrottle(
    private val total: Int,
    private val intervalNanos: Long = TimeUnit.MILLISECONDS.toNanos(100),
    private val now: () -> Long = System::nanoTime,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private var completed = 0
    private var last = Long.MIN_VALUE

    @Synchronized
    fun update(index: Int, itemFraction: Double?) {
        val t = now()
        if (last != Long.MIN_VALUE && t - last < intervalNanos) return
        last = t
        emit(event(index, itemFraction))
    }

    @Synchronized
    fun finish(index: Int) {
        completed++
        last = now()
        emit(event(index, 1.0))
    }

    private fun event(index: Int, itemFraction: Double?) = buildMap<String, Any?> {
        put("index", index)
        put("total", total)
        put("completed", completed)
        if (itemFraction != null) put("itemFraction", itemFraction)
    }
}

/** A copy that can be stopped between 256 KiB chunks and reports its fraction. */
internal object ChunkedCopy {
    const val CHUNK = 256 * 1024

    fun copy(
        input: InputStream,
        output: OutputStream,
        size: Long?,
        cancel: ImportCancel,
        onFraction: (Double?) -> Unit,
        onChunk: () -> Unit = {},
    ) {
        val buffer = ByteArray(CHUNK)
        var copied = 0L
        while (true) {
            cancel.check()
            val n = input.read(buffer)
            if (n < 0) break
            output.write(buffer, 0, n)
            copied += n
            onChunk()
            onFraction(if (size != null && size > 0) minOf(1.0, copied.toDouble() / size) else null)
        }
        if (copied == 0L) onFraction(if (size != null && size > 0) 1.0 else null)
    }
}
```

`chunkedCopyUnknownSizeReportsNull` expects one `null` for a 10-byte stream: the single chunk reports `null` and the `copied == 0L` branch does not run. `chunkedCopyHonoursCancelBetweenChunks` sets cancel in the first `onFraction`, so the next `check()` throws after exactly one chunk.

- [ ] **Step 4: Run and confirm the tests pass**

Run: `cd example/android && ./gradlew :adaptive_liquid_glass:testDebugUnitTest --tests '*PhotoImportJobTest*'`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/PhotoImportJob.kt android/src/test/kotlin/com/aymanomara/adaptive_liquid_glass/PhotoImportJobTest.kt
git commit -m "feat(android): import cancel token, progress throttle, chunked copy"
```

---

### Task 7: Android codec supervisor (abandon and quarantine) and transcoder hooks

**Files:**
- Create: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/CodecSupervisor.kt`
- Modify: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/TranscodeProgress.kt`
- Modify: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/H264Transcoder.kt` (`transcode` :43-55, `run` :83, the loop :147-209)
- Modify: `android/src/test/kotlin/com/aymanomara/adaptive_liquid_glass/H264TranscoderTest.kt` (new `encode` signature)
- Modify: `android/src/test/kotlin/com/aymanomara/adaptive_liquid_glass/TranscodeProgressTest.kt` (new tests)
- Test: `android/src/test/kotlin/com/aymanomara/adaptive_liquid_glass/CodecSupervisorTest.kt`

**Interfaces:**
- Consumes: `ImportCancel` (Task 6).
- Produces:
  - `TranscodeProgress(timeoutNanos = 30s, now = System::nanoTime, cancel: ImportCancel? = null, onAdvance: ((Long) -> Unit)? = null)`, with:
    - `fun advanced(presentationTimeUs: Long = -1)`;
    - `fun checkActive()`, which throws `CancellationException` if cancelled and `TimeoutException` on a stall;
    - `fun stalled(): Boolean`.
  - `H264Transcoder.transcode(src: File, dest: File, activity: TranscodeProgress = TranscodeProgress(), encode: (File, File, TranscodeProgress) -> Unit = ::run): Boolean`.
  - `H264Transcoder.durationUs(file: File): Long` (0 when unknown).
  - `internal class CodecAbandonedException : Exception`.
  - `internal class CodecSupervisor(graceMillis: Long = 500, pollMillis: Long = 50)`:
    - `fun <T> run(cancel: ImportCancel, activity: TranscodeProgress, onAbandon: () -> Unit = {}, work: () -> T): T`;
    - throws `CodecAbandonedException` after a stall, or `CancellationException` after a cancel, once the work has been interrupted and the grace period has passed;
    - `companion object { val shared }`.

- [ ] **Step 1: Write the failing tests**

```kotlin
// CodecSupervisorTest.kt
package com.aymanomara.adaptive_liquid_glass

import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CodecSupervisorTest {
    @get:Rule val tmp = TemporaryFolder()

    /** A codec call that ignores interrupts until [release] counts down. */
    private fun stuck(release: CountDownLatch, entered: CountDownLatch? = null): () -> Unit = {
        entered?.countDown()
        while (true) {
            try {
                if (release.await(10, TimeUnit.SECONDS)) break
            } catch (e: InterruptedException) {
                // A hung hardware codec does not honour interrupts.
            }
        }
    }

    @Test
    fun returnsTheResultOfWorkThatFinishes() {
        val result = CodecSupervisor().run(ImportCancel(), TranscodeProgress()) { 42 }
        assertEquals(42, result)
    }

    @Test
    fun abandonsAStalledCallWithinTheWindow() {
        var time = 0L
        val activity = TranscodeProgress(timeoutNanos = 10, now = { time })
        val release = CountDownLatch(1)
        val entered = CountDownLatch(1)
        var abandoned = false
        val started = System.nanoTime()
        try {
            CodecSupervisor(graceMillis = 50).run(ImportCancel(), activity, { abandoned = true }) {
                time = 100 // no advanced() from here on: a stall
                stuck(release, entered)()
            }
            fail("expected CodecAbandonedException")
        } catch (e: CodecAbandonedException) {
            assertTrue(abandoned)
        } finally {
            release.countDown()
        }
        assertTrue(System.nanoTime() - started < TimeUnit.SECONDS.toNanos(2))
    }

    @Test
    fun cancelAbandonsAtOnce() {
        val cancel = ImportCancel()
        val release = CountDownLatch(1)
        val entered = CountDownLatch(1)
        Thread { entered.await(); cancel.cancelled = true }.start()
        try {
            CodecSupervisor(graceMillis = 50).run(cancel, TranscodeProgress()) { stuck(release, entered)() }
            fail("expected CancellationException")
        } catch (e: CancellationException) {
            // Delivered as the original by the caller.
        } finally {
            release.countDown()
        }
    }

    @Test
    fun lateReturnOfAbandonedWorkDeletesItsOutput() {
        var time = 0L
        val activity = TranscodeProgress(timeoutNanos = 10, now = { time })
        val src = tmp.newFile("in.mov").apply { writeText("hevc") }
        val out = File(tmp.root, "in.out.mp4")
        val release = CountDownLatch(1)
        val done = CountDownLatch(1)
        try {
            CodecSupervisor(graceMillis = 20).run(ImportCancel(), activity) {
                H264Transcoder.transcode(src, out, activity) { _, dest, _ ->
                    time = 100 // stall
                    stuck(release)()
                    dest.writeText("late")
                    throw IllegalStateException("released after abandon")
                }.also { done.countDown() }
            }
            fail("expected CodecAbandonedException")
        } catch (e: CodecAbandonedException) {
            release.countDown()
            assertTrue(done.await(2, TimeUnit.SECONDS))
            assertFalse(out.exists())
            assertEquals("hevc", src.readText())
        }
    }
}
```

```kotlin
// TranscodeProgressTest.kt — add
    @Test
    fun cancelledProgressThrowsCancellation() {
        val cancel = ImportCancel().apply { cancelled = true }
        try {
            TranscodeProgress(cancel = cancel).checkActive()
            org.junit.Assert.fail()
        } catch (e: java.util.concurrent.CancellationException) {
        }
    }

    @Test
    fun advancedReportsPresentationTime() {
        val seen = mutableListOf<Long>()
        val p = TranscodeProgress(onAdvance = { seen += it })
        p.advanced()
        p.advanced(5_000)
        org.junit.Assert.assertEquals(listOf(5_000L), seen)
    }
```

In `H264TranscoderTest.kt`, change each `encode` lambda from `{ src, dest -> ... }` to `{ src, dest, _ -> ... }`. Where the test builds `TranscodeProgress(timeoutNanos = 10, now = { time })` and calls `activity.checkActive()` inside `encode`, pass that progress as `activity =` and use the lambda's third parameter.

- [ ] **Step 2: Run and confirm the tests fail**

Run: `cd example/android && ./gradlew :adaptive_liquid_glass:testDebugUnitTest`
Expected: FAIL to compile (unresolved `CodecSupervisor`, `cancel =`, `onAdvance =`).

- [ ] **Step 3: Implement**

```kotlin
// TranscodeProgress.kt
package com.aymanomara.adaptive_liquid_glass

import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * Measures inactivity rather than total duration, so long videos can
 * finish. Shared between the codec thread (which advances it) and the
 * supervisor (which reads [stalled]).
 */
internal class TranscodeProgress(
    private val timeoutNanos: Long = TimeUnit.SECONDS.toNanos(30),
    private val now: () -> Long = System::nanoTime,
    private val cancel: ImportCancel? = null,
    private val onAdvance: ((Long) -> Unit)? = null,
) {
    init {
        require(timeoutNanos > 0)
    }

    @Volatile
    private var lastProgress = now()

    /** [presentationTimeUs] of the frame just handled, or -1. */
    fun advanced(presentationTimeUs: Long = -1) {
        lastProgress = now()
        if (presentationTimeUs >= 0) onAdvance?.invoke(presentationTimeUs)
    }

    fun stalled(): Boolean = now() - lastProgress >= timeoutNanos

    fun checkActive() {
        cancel?.check()
        if (stalled()) throw TimeoutException("Video codec stopped making progress.")
    }
}
```

```kotlin
// CodecSupervisor.kt
package com.aymanomara.adaptive_liquid_glass

import android.util.Log
import java.util.concurrent.CancellationException
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** A blocking codec or I/O call was given up on; its thread may still be running. */
internal class CodecAbandonedException : Exception("Codec call abandoned after it stopped responding.")

/**
 * Runs blocking codec and I/O calls on daemon threads so a call that never
 * returns cannot hang the import. On a stall or cancel the thread is
 * interrupted, given [graceMillis], then abandoned: it releases its own
 * codec if it ever returns.
 */
internal class CodecSupervisor(
    private val graceMillis: Long = 500,
    private val pollMillis: Long = 50,
) {
    private val pool = Executors.newCachedThreadPool { work ->
        Thread(work, "adaptive_liquid_glass-codec").apply { isDaemon = true }
    }

    fun <T> run(
        cancel: ImportCancel,
        activity: TranscodeProgress,
        onAbandon: () -> Unit = {},
        work: () -> T,
    ): T {
        val finished = CountDownLatch(1)
        val future = pool.submit<T> {
            try {
                work()
            } finally {
                finished.countDown()
            }
        }
        while (true) {
            try {
                return future.get(pollMillis, TimeUnit.MILLISECONDS)
            } catch (e: ExecutionException) {
                throw (e.cause as? Exception) ?: e
            } catch (e: TimeoutException) {
                val stopped = cancel.cancelled
                if (!stopped && !activity.stalled()) continue
                future.cancel(true)
                // An interruptible call unwinds within the grace period and
                // releases its own codec; anything still running is abandoned.
                if (!finished.await(graceMillis, TimeUnit.MILLISECONDS)) {
                    onAbandon()
                    if (Log.isLoggable(TAG, Log.DEBUG)) Log.w(TAG, "Abandoned a codec call (cancel=$stopped).")
                }
                if (stopped) throw CancellationException("Photo import cancelled.")
                throw CodecAbandonedException()
            }
        }
    }

    companion object {
        private const val TAG = "AdaptiveLiquidGlass"
        val shared = CodecSupervisor()
    }
}
```

Add `import java.util.concurrent.CountDownLatch`. The grace wait uses a latch because `future.get` after `cancel(true)` throws at once. `Log` calls in JVM unit tests need `testOptions.unitTests.isReturnDefaultValues = true` in `android/build.gradle`; add it to `android { testOptions { unitTests { ... } } }` if missing.

`H264Transcoder.kt`:

```kotlin
    fun transcode(
        src: File,
        dest: File,
        activity: TranscodeProgress = TranscodeProgress(),
        encode: (File, File, TranscodeProgress) -> Unit = ::run,
    ): Boolean = try {
        encode(src, dest, activity)
        true
    } catch (e: Exception) {
        dest.delete()
        if (e is java.util.concurrent.CancellationException) throw e
        false
    }

    /** The duration of [file] in microseconds; 0 when unknown. */
    fun durationUs(file: File): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L) * 1000
        } catch (e: Exception) {
            0L
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                // Already released.
            }
        }
    }
```

- `run(src, dest)` becomes `private fun run(src: File, dest: File, activity: TranscodeProgress)`, and the line `val activity = TranscodeProgress()` at :147 is deleted.
- In the decoder branch (`if (render) gl.draw(...)`), change `activity.advanced()` to `activity.advanced(info.presentationTimeUs)`. Leave the other `advanced()` calls bare.
- Because `transcode` rethrows `CancellationException`, the supervisor sees the cancel. The late-return test passes because `transcode`'s catch deletes `dest` when the abandoned work finally throws.

- [ ] **Step 4: Run and confirm the tests pass**

Run: `cd example/android && ./gradlew :adaptive_liquid_glass:testDebugUnitTest`
Expected: PASS: `CodecSupervisorTest` (4), `TranscodeProgressTest`, `H264TranscoderTest` and all others.

- [ ] **Step 5: Commit**

```bash
git add android/src
git commit -m "feat(android): supervised codec calls that can be abandoned"
```

---

### Task 8: Android picker wiring: job, progress, cancel, quarantine, `index`, reply

**Files:**
- Modify: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/PhotoImportJob.kt` (add the `PhotoImportJob` class)
- Modify: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/GlassPhotoCache.kt`
- Modify: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/GlassPhotosPicker.kt` (`pick` :60-90, `clearCopies` :93, `onActivityResult` :108-157, `copy` :159-201)
- Modify: `android/src/main/kotlin/com/aymanomara/adaptive_liquid_glass/AdaptiveLiquidGlassPlugin.kt:77-109`
- Modify: `android/src/test/kotlin/com/aymanomara/adaptive_liquid_glass/GlassPhotoCacheTest.kt`
- Test: `PhotoImportJobTest.kt` (append the quarantine tests)

**Interfaces:**
- Consumes: `ImportCancel`, `ProgressThrottle`, `ChunkedCopy` (Task 6); `CodecSupervisor`, `CodecAbandonedException`, `TranscodeProgress`, `H264Transcoder.transcode(src, dest, activity)` and `durationUs` (Task 7).
- Produces:
  - `internal class PhotoImportJob(val name: String?, total: Int, emit: (Map<String, Any?>) -> Unit, supervisor: CodecSupervisor = CodecSupervisor.shared)`, with:
    - `val cancel: ImportCancel`, `val progress: ProgressThrottle`, `var quarantined: Boolean`;
    - `fun <T> convert(activity: TranscodeProgress, work: () -> T): T?` returns null when quarantined or abandoned, and sets `quarantined` on abandon;
    - `fun <T> io(activity: TranscodeProgress, work: () -> T): T` throws on abandon and does not quarantine.
  - `GlassPhotoCache.importItems(root, items, load: (Int, I, File) -> T, onItemReady: ((T) -> Unit)? = null, cancelled: () -> Boolean = { false }): Imported<T>`, where `data class Imported<T>(val items: List<T>, val cancelled: Boolean)`.
  - `GlassPhotosPicker.pick(..., importChannel: String?, onEvent: ((String, Map<String, Any?>) -> Unit)?)`.
  - `GlassPhotosPicker.cancel(importChannel: String)`.
  - The plugin handles `"cancelPhotoImport"`.

- [ ] **Step 1: Write the failing tests**

Append to `PhotoImportJobTest.kt`:

```kotlin
    @Test
    fun quarantineSkipsLaterConversions() {
        var time = 0L
        val job = PhotoImportJob("c", 2, {}, CodecSupervisor(graceMillis = 20))
        val release = java.util.concurrent.CountDownLatch(1)
        val first = job.convert(TranscodeProgress(timeoutNanos = 10, now = { time })) {
            time = 100
            while (!release.await(10, java.util.concurrent.TimeUnit.SECONDS)) Unit
            true
        }
        release.countDown()
        assertEquals(null, first)
        assertTrue(job.quarantined)
        var ran = false
        assertEquals(null, job.convert(TranscodeProgress()) { ran = true; true })
        assertTrue(!ran)
    }

    @Test
    fun convertPassesThroughWhenHealthy() {
        val job = PhotoImportJob(null, 1, {})
        assertEquals(true, job.convert(TranscodeProgress()) { true })
        assertTrue(!job.quarantined)
    }
```

In `GlassPhotoCacheTest.kt`:
- update existing calls: `load` takes `(index, item, session)`, and `.items` is read off the result;
- add:

```kotlin
    @Test
    fun cancelBeforeFirstItemReturnsEmptyCancelled() {
        val root = tmp.newFolder()
        val result = GlassPhotoCache.importItems(root, listOf(1, 2), { _, _, _ -> error("not called") }, cancelled = { true })
        assertEquals(emptyList<Int>(), result.items)
        assertTrue(result.cancelled)
    }

    @Test
    fun cancelMidBatchKeepsFinishedAndDropsPartial() {
        val root = tmp.newFolder()
        var stop = false
        val result = GlassPhotoCache.importItems(root, listOf("a", "b", "c"), { i, name, session ->
            val f = File(session, name).apply { writeText(name) }
            if (i == 1) { stop = true; throw java.util.concurrent.CancellationException() }
            f
        }, cancelled = { stop })
        assertEquals(listOf("a"), result.items.map { it.name })
        assertTrue(result.cancelled)
        assertTrue(result.items.single().exists())
        assertEquals(1, root.listFiles()!!.size) // b's session removed
    }

    @Test
    fun batchFailureStillRollsBackEverything() {
        val root = tmp.newFolder()
        try {
            GlassPhotoCache.importItems(root, listOf("a", "b"), { i, name, session ->
                if (i == 1) throw java.io.IOException("boom")
                File(session, name).apply { writeText(name) }
            })
            fail()
        } catch (e: java.io.IOException) {
            assertEquals(0, root.listFiles()!!.size)
        }
    }
```

Use the existing test file's `tmp` rule name and imports (`File`, `fail`, `assertTrue`). Add any that are missing.

- [ ] **Step 2: Run and confirm the tests fail**

Run: `cd example/android && ./gradlew :adaptive_liquid_glass:testDebugUnitTest`
Expected: FAIL to compile (`PhotoImportJob`, `cancelled =`, `.items`).

- [ ] **Step 3: Implement**

Append to `PhotoImportJob.kt`:

```kotlin
/** One `pickPhotos` import: its cancel flag, progress and codec quarantine. */
internal class PhotoImportJob(
    val name: String?,
    total: Int,
    emit: (Map<String, Any?>) -> Unit,
    private val supervisor: CodecSupervisor = CodecSupervisor.shared,
) {
    val cancel = ImportCancel()
    val progress = ProgressThrottle(total, emit = emit)

    /** After a codec was abandoned, the rest of this import skips conversion. */
    @Volatile
    var quarantined = false
        private set

    fun <T> convert(activity: TranscodeProgress, work: () -> T): T? {
        if (quarantined) return null
        return try {
            supervisor.run(cancel, activity, { quarantined = true }, work)
        } catch (e: CodecAbandonedException) {
            quarantined = true
            null
        }
    }

    fun <T> io(activity: TranscodeProgress, work: () -> T): T = supervisor.run(cancel, activity, work = work)
}
```

`GlassPhotoCache.importItems`:

```kotlin
    data class Imported<T>(val items: List<T>, val cancelled: Boolean)

    /**
     * Imports each item into its own session. Without [onItemReady] a
     * failure rolls back every finished item (one result or none); a
     * cancel keeps them, because the user chose to stop.
     */
    fun <I, T> importItems(
        root: File,
        items: List<I>,
        load: (Int, I, File) -> T,
        onItemReady: ((T) -> Unit)? = null,
        cancelled: () -> Boolean = { false },
    ): Imported<T> {
        val done = mutableListOf<T>()
        val sessions = mutableListOf<File>()
        for ((index, input) in items.withIndex()) {
            if (cancelled()) return Imported(done, true)
            val item = try {
                importing(root) { session ->
                    sessions += session
                    load(index, input, session)
                }
            } catch (error: Exception) {
                if (cancelled()) return Imported(done, true)
                if (onItemReady == null) {
                    for (session in sessions) {
                        try {
                            clear(session)
                        } catch (cleanup: Exception) {
                            error.addSuppressed(cleanup)
                        }
                    }
                }
                throw error
            }
            done += item
            onItemReady?.invoke(item)
        }
        return Imported(done, false)
    }
```

`GlassPhotosPicker.kt`:
- Replace `pendingOnItemReady` with `pendingName: String?` and `pendingOnEvent: ((String, Map<String, Any?>) -> Unit)?`, and add `@Volatile private var job: PhotoImportJob? = null`.
- `pick(...)` takes `importChannel: String?, onEvent: ((String, Map<String, Any?>) -> Unit)? = null` and stores both.
- `clearCopies` message: `"Wait for the photo import, or call controller.cancel(), before clearing picked files."`.
- Add:

```kotlin
    /** Stops the import named [importChannel]; a stale name does nothing. */
    fun cancel(importChannel: String) {
        job?.takeIf { it.name == importChannel }?.let {
            it.cancel.cancelled = true
            return
        }
        if (pending != null && pendingName == importChannel) {
            pendingCancelled = true
            activity?.finishActivity(REQUEST_CODE)
        }
    }
```

with `private var pendingCancelled = false`, reset in `pick`.

In `onActivityResult`:
- the cancelled/empty branch replies `mapOf("items" to emptyList<Any>(), "dropped" to 0, "cancelled" to pendingCancelled)`, then clears `pending`, `pendingName` and `pendingOnEvent`;
- the old reply was `emptyList<Any>()`. The new map shape is accepted by Dart (Task 2) and by older Dart, which already parses `{items, dropped}`;
- after computing `uris`:

```kotlin
        val events = pendingOnEvent
        val current = PhotoImportJob(pendingName, uris.size, { e -> main.post { events?.invoke("progress", e) } })
        job = current
        pendingOnEvent = null
        io.execute {
            try {
                val imported = GlassPhotoCache.importItems(
                    dir, uris, { index, uri, session -> copy(index, uri, options, session, current) },
                    events?.let { notify -> { item -> main.post { notify("itemReady", item) }; Unit } },
                    cancelled = { current.cancel.cancelled },
                )
                main.post {
                    pending = null
                    job = null
                    result.success(mapOf(
                        "items" to imported.items,
                        "dropped" to dropped,
                        "cancelled" to imported.cancelled,
                    ))
                }
            } catch (e: Exception) {
                main.post {
                    pending = null
                    job = null
                    if (current.cancel.cancelled) {
                        result.success(mapOf("items" to emptyList<Any>(), "dropped" to dropped, "cancelled" to true))
                    } else {
                        result.error("load_failed", e.message, null)
                    }
                }
            }
        }
```

Reset `job = null` at the start of each `pick` as well (Global Constraint: quarantine resets on the next pick).

`copy(index, uri, options, directory, job)`, rewritten from :159:

```kotlin
    private fun copy(index: Int, uri: Uri, options: Options, directory: File, job: PhotoImportJob): Map<String, Any?> {
        val resolver = context.contentResolver
        var mime = resolver.getType(uri)
        val ext = mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        var dest = File(directory, UUID.randomUUID().toString() + (ext?.let { ".$it" } ?: ""))
        val isVideo = mime?.startsWith("video/") == true
        // Copy is the whole item unless a conversion may follow.
        val copyShare = if (isVideo && options.compatible) 0.5 else 1.0
        val size = size(uri)
        val copying = TranscodeProgress(cancel = job.cancel)
        job.io(copying) {
            val input = resolver.openInputStream(uri) ?: throw IllegalStateException("Cannot open $uri")
            input.use { src ->
                dest.outputStream().use { out ->
                    ChunkedCopy.copy(src, out, size, job.cancel,
                        { f -> job.progress.update(index, f?.let { it * copyShare }) },
                        { copying.advanced() })
                }
            }
        }
        val item = mutableMapOf<String, Any?>("isVideo" to isVideo, "index" to index)
        if (isVideo) {
            if (options.compatible && H264Transcoder.isHevc(dest)) {
                val out = File(directory, dest.nameWithoutExtension + ".out.mp4")
                val durationUs = H264Transcoder.durationUs(dest)
                val activity = TranscodeProgress(cancel = job.cancel, onAdvance = { us ->
                    if (durationUs > 0) {
                        job.progress.update(index, 0.5 + 0.5 * minOf(1.0, us.toDouble() / durationUs))
                    }
                })
                if (job.convert(activity) { H264Transcoder.transcode(dest, out, activity) } == true) {
                    dest.delete()
                    dest = out
                    mime = "video/mp4"
                } else {
                    // Delivered as HEVC; `GlassPickedPhoto.conversionFailed`.
                    out.delete()
                    item["conversionFailed"] = true
                }
            }
            videoInfo(dest, item)
        } else {
            // (image branch unchanged)
        }
        item["path"] = dest.absolutePath
        item["mimeType"] = mime
        job.progress.finish(index)
        return item
    }

    /** The provider's byte size, or null when it does not say. */
    private fun size(uri: Uri): Long? = try {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) c.getLong(0).takeIf { it > 0 } else null
        }
    } catch (e: Exception) {
        null
    }
```

- Add `import android.provider.OpenableColumns`.
- A failed item must still send its final event so `completed` counts it: wrap the whole body of `copy` in `try { ... } catch (e: Exception) { job.progress.finish(index); throw e }`, but do not call `finish` twice on success.
- Cancel mid-convert: `transcode` rethrows `CancellationException`, and `supervisor.run` also throws it. It propagates out of `job.convert` (only `CodecAbandonedException` is caught there), then out of `copy`, and `importItems` returns `Imported(done, true)`. The session (and the partial `out`) is cleared by `importing`.

`AdaptiveLiquidGlassPlugin.kt`:
- in `"pickPhotos"`, pass `importChannel = call.argument<String>("importChannel")` and `onEvent = imports?.let { events -> { method, args -> events.invokeMethod(method, args) } }`;
- add:

```kotlin
            "cancelPhotoImport" -> {
                call.argument<String>("importChannel")?.let { photosPicker?.cancel(it) }
                result.success(null)
            }
```

- [ ] **Step 4: Run the tests and build**

Run: `cd example/android && ./gradlew :adaptive_liquid_glass:testDebugUnitTest && cd .. && flutter build apk --debug`
Expected: all unit tests PASS and the APK builds.

- [ ] **Step 5: Manual check on an emulator**

Run the example and pick 10 items:
- the ring and bar advance;
- Stop keeps the finished items with `cancelled: true`;
- a cancel while the picker is open closes it and returns empty;
- the next pick works.

- [ ] **Step 6: Commit**

```bash
git add android/src
git commit -m "feat(android): import progress, cancel and codec quarantine"
```

---

### Task 9: iOS pure helpers: limiter, ordered results, throttle

**Files:**
- Create: `ios/adaptive_liquid_glass/Sources/adaptive_liquid_glass/GlassImportScheduling.swift`
- Modify: `example/ios/RunnerTests/RunnerTests.swift` (add a test class)

**Interfaces:**
- Produces:
  - `actor AsyncLimiter`:
    - `init(limit: Int)`;
    - `func acquire() async throws` (throws `CancellationError` if cancelled while waiting);
    - `func release()`;
    - `nonisolated func run<T: Sendable>(_ body: @Sendable () async throws -> T) async throws -> T`.
  - `struct OrderedResults<T>`: `init(count: Int)`, `mutating func set(_ index: Int, _ value: T)`, `var inOrder: [T]` (skips unset).
  - `struct ProgressThrottle`: `init(interval: TimeInterval = 0.1)`, `mutating func allow(now: TimeInterval, final: Bool) -> Bool`.

- [ ] **Step 1: Write the failing tests**

```swift
// append to example/ios/RunnerTests/RunnerTests.swift
actor ConcurrencyProbe {
  private(set) var current = 0
  private(set) var peak = 0
  func enter() { current += 1; peak = max(peak, current) }
  func leave() { current -= 1 }
}

final class ImportSchedulingTests: XCTestCase {
  func testLimiterNeverExceedsLimit() async throws {
    let limiter = AsyncLimiter(limit: 3)
    let probe = ConcurrencyProbe()
    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0..<20 {
        group.addTask {
          try await limiter.run {
            await probe.enter()
            try await Task.sleep(nanoseconds: 5_000_000)
            await probe.leave()
          }
        }
      }
      try await group.waitForAll()
    }
    let peak = await probe.peak
    XCTAssertEqual(peak, 3)
  }

  func testCancelledWaiterThrowsAndFreesNoPermit() async throws {
    let limiter = AsyncLimiter(limit: 1)
    try await limiter.acquire()
    let waiter = Task { try await limiter.acquire() }
    try await Task.sleep(nanoseconds: 10_000_000)
    waiter.cancel()
    do {
      try await waiter.value
      XCTFail("expected CancellationError")
    } catch is CancellationError {}
    await limiter.release()
    try await limiter.acquire() // the permit is free again
  }

  func testOrderedResultsRestoreSelectionOrder() {
    var results = OrderedResults<String>(count: 4)
    results.set(2, "c")
    results.set(0, "a")
    results.set(3, "d") // index 1 failed
    XCTAssertEqual(results.inOrder, ["a", "c", "d"])
  }

  func testThrottleAllowsTenPerSecondPlusFinal() {
    var throttle = ProgressThrottle(interval: 0.1)
    XCTAssertTrue(throttle.allow(now: 0, final: false))
    XCTAssertFalse(throttle.allow(now: 0.05, final: false))
    XCTAssertTrue(throttle.allow(now: 0.06, final: true))
    XCTAssertFalse(throttle.allow(now: 0.1, final: false))
    XCTAssertTrue(throttle.allow(now: 0.16, final: false))
  }
}
```

- [ ] **Step 2: Run and confirm the tests fail**

Run: `cd example && flutter build ios --simulator --debug --no-codesign && xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RunnerTests/ImportSchedulingTests`
Expected: FAIL to compile ("cannot find 'AsyncLimiter' in scope").

- [ ] **Step 3: Implement**

```swift
import Foundation

/// An async semaphore: at most `limit` bodies run at once. Waiters are
/// served in order and leave the queue when their task is cancelled.
actor AsyncLimiter {
  private let limit: Int
  private var running = 0
  private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []

  init(limit: Int) {
    precondition(limit > 0)
    self.limit = limit
  }

  func acquire() async throws {
    try Task.checkCancellation()
    if running < limit {
      running += 1
      return
    }
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        if Task.isCancelled {
          continuation.resume(throwing: CancellationError())
        } else {
          waiters.append((id, continuation))
        }
      }
    } onCancel: {
      Task { await self.dropWaiter(id) }
    }
  }

  /// Hands the permit to the next waiter, or frees it.
  func release() {
    if waiters.isEmpty {
      running -= 1
    } else {
      waiters.removeFirst().continuation.resume()
    }
  }

  private func dropWaiter(_ id: UUID) {
    guard let i = waiters.firstIndex(where: { $0.id == id }) else { return }
    waiters.remove(at: i).continuation.resume(throwing: CancellationError())
  }

  nonisolated func run<T: Sendable>(_ body: @Sendable () async throws -> T) async throws -> T {
    try await acquire()
    do {
      let value = try await body()
      await release()
      return value
    } catch {
      await release()
      throw error
    }
  }
}

/// Collects results that finish in any order and returns them in selection
/// order, skipping items that failed.
struct OrderedResults<T> {
  private var slots: [T?]

  init(count: Int) { slots = Array(repeating: nil, count: count) }

  mutating func set(_ index: Int, _ value: T) { slots[index] = value }

  var inOrder: [T] { slots.compactMap { $0 } }
}

/// At most one event per `interval`, except final events, which always pass.
struct ProgressThrottle {
  let interval: TimeInterval
  private var last = -TimeInterval.infinity

  init(interval: TimeInterval = 0.1) { self.interval = interval }

  mutating func allow(now: TimeInterval, final: Bool) -> Bool {
    guard final || now - last >= interval else { return false }
    last = now
    return true
  }
}
```

The throttle test expects `allow(now: 0.1, final: false)` to be false after the final at 0.06, so a final event resets `last`. The code does this.

- [ ] **Step 4: Run and confirm the tests pass**

Run: the same `xcodebuild test ... -only-testing:RunnerTests/ImportSchedulingTests` command.
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add ios/adaptive_liquid_glass/Sources/adaptive_liquid_glass/GlassImportScheduling.swift example/ios/RunnerTests/RunnerTests.swift
git commit -m "feat(ios): async limiter, ordered results and progress throttle"
```

---

### Task 10: iOS parallel import, progress, cancel, map reply

**Files:**
- Modify: `ios/adaptive_liquid_glass/Sources/adaptive_liquid_glass/GlassPhotosPicker.swift`:
  - init :37-46, `present` :56-87, `picker(_:didFinishPicking:)` :89-143, `send` :145, `copy` :151, `deliver` :162, `exportH264` :273-292;
  - `reencode` callers use the encode limiter.
- Modify: `ios/adaptive_liquid_glass/Sources/adaptive_liquid_glass/AdaptiveLiquidGlassPlugin.swift:75-100`

**Interfaces:**
- Consumes: `AsyncLimiter`, `OrderedResults` and `ProgressThrottle` (Task 9); the protocol from the spec §3.
- Produces:
  - `GlassPhotosPicker.present(arguments:result:importName:onEvent:onFinish:)`, where `onEvent: ((String, [String: Any]) -> Void)?`;
  - instance `func cancel()`;
  - `var importName: String?`;
  - the plugin handles `"cancelPhotoImport"`.

- [ ] **Step 1: Record the iOS baseline** if Task 5 left it as "n/a" (it must exist before this change).

- [ ] **Step 2: Implement the state and cancel**

Replace `onItemReady` with `onEvent` and add the following:

```swift
  let importName: String?
  private let onEvent: ((String, [String: Any]) -> Void)?
  private weak var pickerController: PHPickerViewController?
  private var importTask: Task<Void, Never>?
  private var throttle = ProgressThrottle()
  private var completed = 0
  private var total = 0

  /// Stops the import (main thread). While the picker shows, dismisses it
  /// and answers an empty, cancelled result.
  func cancel() {
    if !finished {
      finished = true
      pickerController?.dismiss(animated: true)
      send([], cancelled: true)
      return
    }
    importTask?.cancel()
  }

  /// Sends a throttled `progress` event (main thread).
  @MainActor private func progress(_ index: Int, _ fraction: Double?, final: Bool = false) {
    if final { completed += 1 }
    guard throttle.allow(now: ProcessInfo.processInfo.systemUptime, final: final) else { return }
    var args: [String: Any] = ["index": index, "total": total, "completed": completed]
    if let fraction = fraction { args["itemFraction"] = final ? 1.0 : fraction }
    else if final { args["itemFraction"] = 1.0 }
    onEvent?("progress", args)
  }

  private func send(_ items: [[String: Any]], cancelled: Bool = false) {
    result(["items": items, "dropped": 0, "cancelled": cancelled])
    onFinish()
  }
```

In `present`, set `session.pickerController = picker` and pass `importName`.

`GlassPhotosPicker` is not `@MainActor`, so mark the class `@MainActor` (it is only used from the main thread: the plugin's `handle` and the PHPicker delegate). Then make `copy`, `deliver`, `exportH264`, `reencode`, `imageSize`, `videoSize` and `isHEVC` `nonisolated static`. The delegate method `picker(_:didFinishPicking:)` must be `nonisolated` with `MainActor.assumeIsolated { ... }`, or the class can stay non-actor with every call to `progress` and `onEvent` wrapped in `await MainActor.run`. **Use the second option** (smaller diff): drop `@MainActor` from `progress` and call it through `await MainActor.run { self.progress(...) }`.

- [ ] **Step 3: Implement the parallel import**

Replace the body of `picker(_:didFinishPicking:)` after `finished = true`:

```swift
    if results.isEmpty {
      send([])
      return
    }
    total = results.count
    let options = options
    let limits = Limits()
    importTask = Task.detached(priority: .userInitiated) { [self] in
      var ordered = OrderedResults<[String: Any]>(count: results.count)
      var firstError: Error?
      await withTaskGroup(of: (Int, Result<[String: Any], Error>).self) { group in
        for (index, pick) in results.enumerated() {
          group.addTask {
            do {
              let item = try await Self.importItem(
                pick.itemProvider, index: index, options: options, limits: limits
              ) { fraction in
                await MainActor.run { self.progress(index, fraction) }
              }
              return (index, .success(item))
            } catch {
              return (index, .failure(error))
            }
          }
        }
        for await (index, outcome) in group {
          await MainActor.run { self.progress(index, nil, final: true) }
          switch outcome {
          case .success(let item):
            ordered.set(index, item)
            await MainActor.run { self.onEvent?("itemReady", item) }
          case .failure(let error):
            if firstError == nil, !(error is CancellationError) { firstError = error }
          }
        }
      }
      let cancelled = Task.isCancelled
      let loaded = ordered.inOrder
      await MainActor.run {
        if loaded.isEmpty, !cancelled, let error = firstError {
          self.result(FlutterError(
            code: "load_failed", message: error.localizedDescription, details: nil))
          self.onFinish()
        } else {
          self.send(loaded, cancelled: cancelled)
        }
      }
    }
```

`Task.isCancelled` inside the detached task reflects `importTask?.cancel()`, and cancellation propagates to the group children.

Add the per-item pipeline and limits:

```swift
  /// Concurrency caps: copies are I/O-bound; exports and decodes are the
  /// memory and thermal hogs.
  struct Limits {
    let loads = AsyncLimiter(limit: 3)
    let exports = AsyncLimiter(limit: 1)
    let encodes = AsyncLimiter(limit: 2)
  }

  /// Loads, copies and converts one item into its own session directory;
  /// removes that directory if it fails or is cancelled.
  private static func importItem(
    _ provider: NSItemProvider, index: Int, options: Options, limits: Limits,
    report: @escaping @Sendable (Double?) async -> Void
  ) async throws -> [String: Any] {
    let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
    let type = isVideo ? UTType.movie : UTType.image
    let concrete = provider.registeredTypeIdentifiers.compactMap { UTType($0) }
      .first { $0.conforms(to: type) } ?? type
    let session = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let converts = options.compatible || options.maxWidth != nil || options.maxHeight != nil
      || options.quality != nil
    let copyShare = converts ? 0.5 : 1.0
    do {
      let copy = try await limits.loads.run {
        try await load(provider, type: concrete, into: session) { f in
          await report(f * copyShare)
        }
      }
      try Task.checkCancellation()
      var item = await deliver(
        copy, type: concrete, isVideo: isVideo, options: options, limits: limits
      ) { f in await report(copyShare + f * (1 - copyShare)) }
      try Task.checkCancellation()
      item["index"] = index
      return item
    } catch {
      try? FileManager.default.removeItem(at: session)
      throw error
    }
  }

  /// `loadFileRepresentation`, copied inside its callback, with its
  /// `Progress` observed and cancelled with the task.
  private static func load(
    _ provider: NSItemProvider, type: UTType, into session: URL,
    report: @escaping @Sendable (Double) async -> Void
  ) async throws -> URL {
    final class Box: @unchecked Sendable {
      var progress: Progress?
      var observation: NSKeyValueObservation?
    }
    let box = Box()
    defer { box.observation?.invalidate() }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let progress = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
          // The provider deletes its URL on return: copy inside this callback.
          guard let url = url else {
            continuation.resume(throwing: error ?? NSError(
              domain: "adaptive_liquid_glass", code: 1,
              userInfo: [NSLocalizedDescriptionKey: "The selected item is unavailable."]))
            return
          }
          do {
            continuation.resume(returning: try copy(url, type: type, into: session))
          } catch {
            continuation.resume(throwing: error)
          }
        }
        box.progress = progress
        box.observation = progress.observe(\.fractionCompleted) { p, _ in
          let f = p.fractionCompleted
          Task { await report(f) }
        }
      }
    } onCancel: {
      box.progress?.cancel()
    }
  }
```

`copy(_:type:)` becomes `copy(_ url: URL, type: UTType, into session: URL)`. It creates `session` (`withIntermediateDirectories: true`) instead of `directory`, and writes `session/<uuid>.<ext>`.

`deliver(...)` gains `limits: Limits, report: @escaping @Sendable (Double) async -> Void`:
- video: `if let converted = try? await limits.exports.run({ await exportH264(asset, from: url, report: report) }) ?? nil`. The double optional comes from `run` throwing on cancel; treat a thrown cancel as `nil` here, then the caller's `Task.checkCancellation()` throws.
- image: `if let encoded = try? await limits.encodes.run({ reencode(url, type: type, options: options) }) ?? nil`, then `await report(1)`.

`AVURLAsset`/`URL` are fine; if `[String: Any]` is not `Sendable` under Swift 5.9 strict checking, the project uses minimal checking, so warnings are acceptable. Do not add `@preconcurrency` churn.

`exportH264(_:from:report:)`:

```swift
    let poll = Task {
      while !Task.isCancelled, session.status == .waiting || session.status == .exporting
        || session.status == .unknown {
        await report(Double(session.progress))
        try? await Task.sleep(nanoseconds: 100_000_000)
      }
    }
    await withTaskCancellationHandler {
      await withCheckedContinuation { done in
        session.exportAsynchronously { done.resume() }
      }
    } onCancel: {
      session.cancelExport()
    }
    poll.cancel()
```

Keep the existing status check and cleanup after this (a cancelled export has `.cancelled` status, so `dest` is removed and `nil` returned).

- [ ] **Step 4: Wire the plugin**

In `AdaptiveLiquidGlassPlugin.swift` `"pickPhotos"`:

```swift
      let onEvent: ((String, [String: Any]) -> Void)? = imports.map { channel in
        { method, args in channel.invokeMethod(method, arguments: args) }
      }
      photosPicker = GlassPhotosPicker.present(
        arguments: call.arguments, result: result, importName: importName, onEvent: onEvent) {
        [weak self] in self?.photosPicker = nil
      }
```

Add:

```swift
    case "cancelPhotoImport":
      let name = (call.arguments as? [String: Any])?["importChannel"] as? String
      if let picker = photosPicker, name != nil, picker.importName == name { picker.cancel() }
      result(nil)
```

Change the `clearPickedPhotos` `already_active` message to `"Wait for the photo import, or call controller.cancel(), before clearing picked files."`.

- [ ] **Step 5: Build, run the unit tests and the Dart suite**

Run: `cd example && flutter build ios --simulator --debug --no-codesign && xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:RunnerTests && cd .. && flutter test test/photos_picker/`
Expected: the build succeeds and all tests PASS.

- [ ] **Step 6: Manual check and bench on the iPhone 17 Pro simulator**

Run the example:
- 20 photos: the thumbnails arrive out of order but the final list is in order; record the time;
- 5 HEVC videos with `compatibleFormat`: the ring advances during export;
- Stop mid-way: finished items are kept, `cancelled: true`, and no partial session directories remain (`xcrun simctl get_app_container booted <bundle> data` then `tmp/adaptive_liquid_glass_picker`; every subdirectory holds a delivered file);
- cancel while the picker shows: it dismisses and returns empty.

Write the numbers into `## Bench → After`. The target is ≥ 2× on 20 photos (success criterion 4). If it is missed, record it and flag it in the final report rather than tuning the limits silently.

- [ ] **Step 7: Commit**

```bash
git add ios example/ios/RunnerTests docs/superpowers/plans/2026-11-04-photos-import-progress-cancel.md
git commit -m "feat(ios): parallel photo import with progress and cancel"
```

---

### Task 11: Docs and changelog

**Files:**
- Modify: `README.md` (Photos picker section, and the Limitations "Photos picker" entry near :1543)
- Modify: `TODO.md` ("Photos import" item)
- Modify: `CHANGELOG.md` (an entry under the next minor, `0.5.0`)

These three files have uncommitted user edits on `main`. Work on the feature branch, and only add to them; do not reformat.

- [ ] **Step 1: README Photos picker section.** Add a short "Progress and cancel" subsection with the spec §2 snippet (controller, `onProgress`, `index`, `cancelled`), one sentence on tap-to-cancel for the widget, and `showProgress`/`cancelLabel`.

- [ ] **Step 2: Shrink the Limitations entry** to the residuals from the spec §8:
- copy and conversion still take real time;
- an abandoned Android codec thread may hold a hardware codec until the process exits;
- the selection cap is platform-owned.

- [ ] **Step 3: TODO.md.** Mark progress, cancel, killable codec and parallel iOS done, and leave Android parallel copy and the selection cap open.

- [ ] **Step 4: CHANGELOG.** Add under `## 0.5.0` (create the heading if it is absent; do not touch the version in `pubspec.yaml`):

```markdown
- Photos: `GlassPhotoImportController` and `onProgress` give determinate progress and cancel for `pickGlassPhotos` and `GlassPhotosPicker`; tapping a busy picker cancels. `GlassPickedPhoto.index`, `GlassPickedPhotos.cancelled`.
- Photos (Android): a codec call that stops responding is abandoned after 30 s and the original is delivered with `conversionFailed`; later items skip conversion.
- Photos (iOS): items import in parallel (3 loads, 1 video export, 2 photo re-encodes); `onItemReady` may arrive out of selection order.
- Buttons: `GlassButton.loadingValue` and `onLoadingPressed`.
```

- [ ] **Step 5: Full verification**

Run: `flutter analyze && flutter test && cd example/android && ./gradlew :adaptive_liquid_glass:testDebugUnitTest`
Expected: no analyzer issues and all tests pass.

- [ ] **Step 6: Commit**

```bash
git add README.md TODO.md CHANGELOG.md
git commit -m "docs(photos): progress, cancel and the narrowed limitation"
```

---

## Bench

Simulator/emulator wall time from the first `ready #` to `import:`, median of 3 runs.

| Case | Platform | Before | After |
|---|---|---|---|
| 20 photos | iPhone 17 Pro sim | | |
| 5 × HEVC, `compatibleFormat` | iPhone 17 Pro sim | | |
| 20 photos | Android emulator | | |
| 5 × HEVC, `compatibleFormat` | Android emulator | | |

## Bench → Before

Not measured in the automated run: needs manual selection in the system picker. Run the example and read the `first item at` / `import:` log lines.
