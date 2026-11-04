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
