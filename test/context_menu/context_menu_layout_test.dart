import 'package:adaptive_liquid_glass/src/context_menu/context_menu_metrics.dart';
import 'package:adaptive_liquid_glass/src/context_menu/glass_context_menu_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _screen = Size(402, 874);
const _safe = EdgeInsets.only(top: 62, bottom: 34);
const _menuKey = Key('menu');

/// Lays a [menuSize] menu out for [preview] on the reference screen and
/// returns where it landed.
Future<Rect> _place(WidgetTester t, Rect preview, Size menuSize) async {
  t.view.physicalSize = _screen;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    CustomSingleChildLayout(
      delegate: GlassContextMenuLayout(preview: preview, padding: _safe),
      child: SizedBox.fromSize(key: _menuKey, size: menuSize),
    ),
  );
  return t.getRect(find.byKey(_menuKey));
}

void main() {
  group('lifted', () {
    test('a card wider than the margins keeps at least its own size', () {
      // 390 wide on a 402 screen: the 16-pt margins leave 370.
      const card = Rect.fromLTWH(6, 300, 390, 100);
      final lifted = ContextMenuMetrics.lifted(card, _screen, _safe);
      expect(lifted.width, greaterThanOrEqualTo(card.width));
      expect(lifted.height, greaterThanOrEqualTo(card.height));
      expect(lifted.center.dx, moreOrLessEquals(_screen.width / 2));
    });

    test('a 360-pt card still lifts only to the margins (1.024)', () {
      const card = Rect.fromLTWH(21, 300, 360, 80);
      final lifted = ContextMenuMetrics.lifted(card, _screen, _safe);
      expect(lifted.width, moreOrLessEquals(_screen.width - 32));
    });
  });

  group('menu placement', () {
    const menu = Size(250, 200);

    testWidgets('below the lifted item when it fits', (t) async {
      const preview = Rect.fromLTWH(88, 200, 226, 136);
      final r = await _place(t, preview, menu);
      expect(r.top, preview.bottom + ContextMenuMetrics.gap);
    });

    testWidgets('above it when only that fits', (t) async {
      const preview = Rect.fromLTWH(88, 600, 226, 136);
      final r = await _place(t, preview, menu);
      expect(r.bottom, preview.top - ContextMenuMetrics.gap);
    });

    testWidgets(
      'neither fits: pinned safeMargin above the safe bottom, as the item',
      (t) async {
        // A tall preview leaves no room above or below it.
        const preview = Rect.fromLTWH(88, 82, 226, 700);
        final r = await _place(t, preview, menu);
        expect(
          r.bottom,
          _screen.height - _safe.bottom - ContextMenuMetrics.safeMargin,
        );
      },
    );
  });
}
