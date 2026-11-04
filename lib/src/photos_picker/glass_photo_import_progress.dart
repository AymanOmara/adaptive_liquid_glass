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
  /// Creates a progress snapshot.
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

  /// Where the import is.
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
  int get hashCode => Object.hash(
    total,
    completed,
    currentIndex,
    itemFraction,
    fraction,
    phase,
  );

  @override
  String toString() =>
      'GlassPhotoImportProgress($phase, $completed/$total, '
      'item $currentIndex: $itemFraction, fraction: $fraction)';
}
