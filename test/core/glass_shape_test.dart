import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const box = Size(200, 60);

  test('capsule radius is half the shortest side', () {
    expect(const GlassShape.capsule().resolveRadius(box), 30);
    expect(const GlassShape.capsule().resolveRect(box), Offset.zero & box);
  });

  test('circle is a centred square', () {
    const shape = GlassShape.circle();
    expect(shape.resolveRect(box), const Rect.fromLTWH(70, 0, 60, 60));
    expect(shape.resolveRadius(box), 30);
    expect(shape.toBorder(box), isA<CircleBorder>());
  });

  test('rect radius is clamped to half the shortest side', () {
    expect(const GlassShape.rect(16).resolveRadius(box), 16);
    expect(const GlassShape.rect(100).resolveRadius(box), 30);
    expect(const GlassShape.rect(-4).resolveRadius(box), 0);
  });

  test('concentric uses the group value, else falls back to capsule', () {
    const shape = GlassShape.concentric(minimum: 6);
    expect(shape.resolveRadius(box, concentricRadius: 12), 12);
    expect(shape.resolveRadius(box), 30);
  });

  test('borders use the continuous corner curve', () {
    final border = const GlassShape.rect(16).toBorder(box);
    expect(border, isA<RoundedSuperellipseBorder>());
    expect((border as RoundedSuperellipseBorder).borderRadius,
        BorderRadius.circular(16));
  });

  test('concentricRadius subtracts the smallest inset', () {
    final r = concentricRadius(
      container: const Rect.fromLTWH(0, 0, 300, 100),
      containerRadius: 28,
      child: const Rect.fromLTWH(8, 12, 100, 76),
    );
    expect(r, 20); // smallest inset is 8 (left)
  });

  test('concentricRadius never goes below minimum', () {
    final r = concentricRadius(
      container: const Rect.fromLTWH(0, 0, 300, 100),
      containerRadius: 10,
      child: const Rect.fromLTWH(20, 20, 100, 60),
      minimum: 4,
    );
    expect(r, 4);
  });

  test('equality', () {
    expect(const GlassShape.rect(8), const GlassShape.rect(8));
    expect(const GlassShape.rect(8), isNot(const GlassShape.rect(9)));
    expect(const GlassShape.capsule(), const GlassShape.capsule());
  });
}
