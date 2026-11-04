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

  /// The most recent progress snapshot.
  GlassPhotoImportProgress get current => _current;

  /// Folds one native `progress` event into a new snapshot.
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
    final raw = total <= 0
        ? 0.0
        : ((completed + inFlight) / total).clamp(0.0, 1.0);
    return _current = GlassPhotoImportProgress(
      total: total,
      completed: completed,
      currentIndex: index ?? _current.currentIndex,
      // The item's best value so far, so it never goes backwards either.
      itemFraction: index == null
          ? _current.itemFraction
          : (_finished.contains(index) ? 1.0 : _inFlight[index]),
      fraction: math.max(raw, _current.fraction),
      phase: GlassPhotoImportPhase.importing,
    );
  }

  /// Marks the import finished and returns the final snapshot.
  ///
  /// A finished import reports every item completed and fraction 1; a
  /// [cancelled] (or interrupted) one keeps the [GlassPhotoImportProgress.completed]
  /// count and fraction it reached.
  GlassPhotoImportProgress done({bool cancelled = false}) =>
      _current = GlassPhotoImportProgress(
        total: _current.total,
        completed: cancelled ? _current.completed : _current.total,
        currentIndex: _current.currentIndex,
        itemFraction: _current.itemFraction,
        fraction: cancelled ? _current.fraction : 1,
        phase: GlassPhotoImportPhase.done,
      );
}
