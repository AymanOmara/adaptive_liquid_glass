import 'package:adaptive_liquid_glass/src/native/native_glass_layer.dart';
import 'package:adaptive_liquid_glass/src/native/shader_glass_keep_out.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const group = Rect.fromLTWH(300, 700, 56, 56);
  const full = EdgeInsets.all(kNativeOverhang);

  test('full overhang with nothing to keep out of', () {
    expect(nativeOverhangFor(group, const []), full);
  });

  test('a far rect does not trim', () {
    expect(
      nativeOverhangFor(group, const [Rect.fromLTWH(0, 0, 50, 50)]),
      full,
    );
  });

  test('a bar below trims only the bottom to the gap', () {
    final o = nativeOverhangFor(group, const [
      Rect.fromLTWH(0, 766, 402, 62),
    ]);
    expect(o, const EdgeInsets.fromLTRB(24, 24, 24, 10));
  });

  test('a bar right below trims the bottom to zero', () {
    final o = nativeOverhangFor(group, const [
      Rect.fromLTWH(0, 756, 402, 62),
    ]);
    expect(o.bottom, 0);
    expect(o.top, kNativeOverhang);
  });

  test('a diagonal rect trims the side that keeps more overhang', () {
    // 20 to the right, 5 below: trimming right keeps 20.
    final o = nativeOverhangFor(group, const [
      Rect.fromLTWH(376, 761, 40, 40),
    ]);
    expect(o, const EdgeInsets.fromLTRB(24, 24, 20, 24));
  });

  test('an overlapping rect is left alone', () {
    expect(
      nativeOverhangFor(group, const [Rect.fromLTWH(310, 710, 10, 10)]),
      full,
    );
  });

  testWidgets('registry notifies after the frame and clears', (t) async {
    final k = ShaderGlassKeepOut.instance;
    var n = 0;
    void l() => n++;
    k.addListener(l);
    final owner = Object();
    k.report(owner, const Rect.fromLTWH(0, 0, 10, 10));
    expect(n, 0);
    await t.pump();
    expect(n, 1);
    expect(k.rects, contains(const Rect.fromLTWH(0, 0, 10, 10)));
    k.report(owner, null);
    await t.pump();
    expect(n, 2);
    expect(k.rects, isEmpty);
    k.removeListener(l);
  });
}
