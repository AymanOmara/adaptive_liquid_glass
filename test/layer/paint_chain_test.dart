import 'package:adaptive_liquid_glass/src/layer/paint_chain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _probe = Key('probe');

Future<PaintChain> chainOf(WidgetTester tester, Widget tree) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: tree),
    ),
  );
  final box = tester.renderObject(find.byKey(_probe, skipOffstage: false));
  return describePaintChain(box, {
    tester.renderObject(find.byType(Align).first),
  });
}

const Widget probe = SizedBox(key: _probe, width: 20, height: 20);

void main() {
  testWidgets('plain: painted, opaque, unclipped', (tester) async {
    final c = await chainOf(tester, probe);
    expect(c.painted, isTrue);
    expect(c.opacity, 1);
    expect(c.clip, isNull);
  });

  testWidgets('opacity and fades multiply', (tester) async {
    final c = await chainOf(
      tester,
      const Opacity(
        opacity: 0.5,
        child: FadeTransition(
          opacity: AlwaysStoppedAnimation(0.5),
          child: probe,
        ),
      ),
    );
    expect(c.opacity, 0.25);
    expect(c.painted, isTrue);
  });

  testWidgets('zero opacity and offstage do not paint', (tester) async {
    expect(
      (await chainOf(tester, const Opacity(opacity: 0, child: probe))).painted,
      isFalse,
    );
    expect(
      (await chainOf(tester, const Offstage(child: probe))).painted,
      isFalse,
    );
  });

  testWidgets('a hidden IndexedStack child does not paint', (tester) async {
    final hidden = await chainOf(
      tester,
      const IndexedStack(index: 1, children: [probe, SizedBox()]),
    );
    expect(hidden.painted, isFalse);
    final shown = await chainOf(
      tester,
      const IndexedStack(index: 0, children: [probe, SizedBox()]),
    );
    expect(shown.painted, isTrue);
  });

  testWidgets('clips intersect in global coordinates', (tester) async {
    final c = await chainOf(
      tester,
      Padding(
        padding: const EdgeInsets.only(left: 10, top: 5),
        child: ClipRect(
          child: SizedBox(
            width: 100,
            height: 40,
            child: ClipRect(
              clipper: _Half(),
              child: const Align(alignment: Alignment.topLeft, child: probe),
            ),
          ),
        ),
      ),
    );
    expect(c.clip, const Rect.fromLTWH(10, 5, 50, 40));
  });

  testWidgets('a scroll view clips to its viewport', (tester) async {
    final c = await chainOf(
      tester,
      SizedBox(
        width: 100,
        height: 60,
        child: ListView(
          children: [
            const SizedBox(height: 50),
            const Align(alignment: Alignment.topLeft, child: probe),
          ],
        ),
      ),
    );
    expect(c.clip, const Rect.fromLTWH(0, 0, 100, 60));
  });

  testWidgets('rectangular clips leave no clip path', (tester) async {
    final c = await chainOf(
      tester,
      const ClipRect(child: ClipRRect(child: probe)),
    );
    expect(c.clip, isNotNull);
    expect(c.clipPath, isNull);
  });

  testWidgets('a rounded clip keeps its shape in global px', (tester) async {
    final c = await chainOf(
      tester,
      const Padding(
        padding: EdgeInsets.only(left: 10, top: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: probe,
        ),
      ),
    );
    expect(c.clip, const Rect.fromLTWH(10, 5, 20, 20));
    final p = c.clipPath!;
    expect(p.contains(const Offset(20, 15)), isTrue);
    expect(p.contains(const Offset(10.5, 5.5)), isFalse); // corner
    expect(p.contains(const Offset(29.5, 24.5)), isFalse);
  });

  testWidgets('ovals, physical models and paths intersect', (tester) async {
    final c = await chainOf(
      tester,
      const PhysicalModel(
        color: Color(0xFF000000),
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.all(Radius.circular(4)),
        child: ClipOval(child: probe),
      ),
    );
    final p = c.clipPath!;
    expect(p.contains(const Offset(10, 10)), isTrue);
    expect(p.contains(const Offset(2, 2)), isFalse); // outside the oval
    expect(p.contains(const Offset(10, 1)), isTrue);
  });

  testWidgets('Clip.none and a plain ClipPath clip nothing extra', (
    tester,
  ) async {
    final c = await chainOf(
      tester,
      const ClipRRect(
        clipBehavior: Clip.none,
        borderRadius: BorderRadius.all(Radius.circular(8)),
        child: ClipPath(child: probe),
      ),
    );
    expect(c.clipPath, isNull);
  });

  testWidgets('order follows child order', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            SizedBox(key: Key('a')),
            Column(
              children: [
                SizedBox(),
                SizedBox(key: Key('b')),
              ],
            ),
          ],
        ),
      ),
    );
    final stop = {tester.renderObject(find.byType(Stack))};
    final a = describePaintChain(
      tester.renderObject(find.byKey(const Key('a'))),
      stop,
    );
    final b = describePaintChain(
      tester.renderObject(find.byKey(const Key('b'))),
      stop,
    );
    expect(a.order, [0]);
    expect(b.order, [1, 1]);
  });
}

class _Half extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  Rect getApproximateClipRect(Size size) => getClip(size);

  @override
  bool shouldReclip(_Half oldClipper) => false;
}
