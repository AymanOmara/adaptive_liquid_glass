import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const r = Rect.fromLTWH(200, 300, 100, 50);
  test('global space scales by dpr', () {
    expect(
        toTextureSpace(r,
            filterOriginGlobal: const Offset(190, 290),
            devicePixelRatio: 3,
            space: GlassTextureSpace.global),
        const Rect.fromLTWH(600, 900, 300, 150));
  });
  test('local space is relative to the filter origin', () {
    expect(
        toTextureSpace(r,
            filterOriginGlobal: const Offset(190, 290),
            devicePixelRatio: 3,
            space: GlassTextureSpace.local),
        const Rect.fromLTWH(30, 30, 300, 150));
    expect(
        pointToTextureSpace(const Offset(191, 292),
            filterOriginGlobal: const Offset(190, 290),
            devicePixelRatio: 2,
            space: GlassTextureSpace.local),
        const Offset(2, 4));
  });
}
