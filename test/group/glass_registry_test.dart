import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_entry.dart';
import 'package:adaptive_liquid_glass/src/group/glass_press_geometry.dart';
import 'package:adaptive_liquid_glass/src/group/glass_registry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

GlassEntry entry() =>
    GlassEntry(shape: const GlassShape.capsule(), glass: Glass.regular);

void main() {
  test('register / unregister notify listeners', () {
    final r = GlassRegistry();
    var n = 0;
    r.addListener(() => n++);
    final e = entry();
    expect(r.register(e), isTrue);
    expect(r.entries, [e]);
    r.unregister(e);
    expect(r.entries, isEmpty);
    r.unregister(e); // second removal is a no-op
    expect(n, 2);
  });

  test('the 17th member is refused with a non-fatal error', () {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final r = GlassRegistry();
    for (var i = 0; i < GlassRegistry.maxShapes; i++) {
      expect(r.register(entry()), isTrue);
    }
    expect(r.register(entry()), isFalse);
    expect(r.entries.length, 16);
    expect(errors, hasLength(1));
    expect(errors.single.exceptionAsString(), contains('16'));
  });

  test('the shape-limit error is reported once per group', () {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final r = GlassRegistry();
    for (var i = 0; i < GlassRegistry.maxShapes; i++) {
      r.register(entry());
    }
    // Five extra members, each registering twice (a rebuild).
    for (var i = 0; i < 10; i++) {
      expect(r.register(entry()), isFalse);
    }
    expect(errors, hasLength(1));
    final message = errors.single.exceptionAsString();
    expect(message, contains('GlassBatch'));
    expect(message, contains('batchImplicitGroups'));

    // Another group reports its own overflow.
    final other = GlassRegistry();
    for (var i = 0; i <= GlassRegistry.maxShapes; i++) {
      other.register(entry());
    }
    expect(errors, hasLength(2));
  });

  test('press geometry scales about the centre and translates', () {
    const g = GlassPressGeometry(
      scaleX: 1.5,
      scaleY: 1,
      translation: Offset(10, 0),
      glow: 1,
    );
    final out = g.apply(const Rect.fromLTWH(0, 0, 100, 40));
    expect(out, const Rect.fromLTWH(-15, 0, 150, 40));
    expect(g.radiusScale, 1);
    expect(
      GlassPressGeometry.identity.apply(const Rect.fromLTWH(1, 2, 3, 4)),
      const Rect.fromLTWH(1, 2, 3, 4),
    );
  });

  test('entries without a laid-out box are not laid out', () {
    expect(entry().isLaidOut, isFalse);
  });
}
