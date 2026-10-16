import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/context_menu/glass_context_menu_route.dart';
import 'package:adaptive_liquid_glass/src/menu/glass_menu_panel.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _card = Rect.fromLTWH(101, 302, 200, 120);
const _preview = Key('preview');

/// UIKit's context menu over a 200 x 120 card, 60 fps frame dumps
/// (`-controls contextmenuuikitmotion`): frames after the lift began, and
/// how far the card's growth (200 -> 226 wide) and the menu's height had
/// got.
final _openCard = <double, double>{
  5.5: 0.897,
  7.5: 0.923,
  8.5: 0.974,
  10.5: 1.0,
};
final _openMenu = <double, double>{
  2.5: 0.361,
  3.5: 0.534,
  4.5: 0.673,
  5.5: 0.865,
  9.5: 0.994,
  12.5: 1.021,
  16.5: 1.011,
  23.5: 1.0,
};

/// Closing, frames after the close began: how far the card had settled
/// back (226 -> 200).
final _closeCard = <double, double>{
  1.3: 0.085,
  4.3: 0.51,
  7.3: 0.83,
  9.3: 0.96,
};

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  Future<NavigatorState> host(WidgetTester t) async {
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      CupertinoApp(navigatorKey: key, home: const SizedBox.expand()),
    );
    return key.currentState!;
  }

  GlassContextMenuRoute route() => GlassContextMenuRoute(
    preview: const SizedBox(key: _preview, width: 200, height: 120),
    previewRect: _card,
    items: [
      GlassMenuItem(label: 'Copy', onSelected: () {}),
      GlassMenuItem(label: 'Share', onSelected: () {}),
      GlassMenuItem(label: 'Delete', destructive: true, onSelected: () {}),
    ],
  );

  double cardGrowth(WidgetTester t) =>
      (t.getRect(find.byKey(_preview)).width - 200) / 26;

  testWidgets('opening follows UIKit: the lift and the menu spring', (t) async {
    shaderEnv();
    final nav = await host(t);
    nav.push(route());
    await t.pump();
    const lead = 22; // ms, ContextMenuMetrics.openLead
    var elapsed = 0;
    Future<void> at(double frames) async {
      final ms = lead + (frames * 1000 / 60).round();
      await t.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
    }

    final frames = {..._openCard.keys, ..._openMenu.keys}.toList()..sort();
    final menuAt = <double, double>{};
    for (final f in frames) {
      await at(f);
      if (_openCard.containsKey(f)) {
        expect(cardGrowth(t), closeTo(_openCard[f]!, 0.05), reason: 'card $f');
      }
      if (_openMenu.containsKey(f)) {
        menuAt[f] = t.getRect(find.byType(GlassMenuPanel)).height;
      }
    }
    await t.pumpAndSettle();
    final menuFull = t.getRect(find.byType(GlassMenuPanel)).height;
    for (final MapEntry(key: f, value: h) in menuAt.entries) {
      // 0.06: frame 5.5 is a repeated dump frame, its time uncertain.
      expect(h / menuFull, closeTo(_openMenu[f]!, 0.06), reason: 'menu $f');
    }
    // The menu grows from its top, by the card.
    expect(cardGrowth(t), closeTo(1, 0.01));
  }, variant: ios);

  testWidgets('closing follows UIKit: the card settles back, the menu goes', (
    t,
  ) async {
    shaderEnv();
    final nav = await host(t);
    nav.push(route());
    await t.pumpAndSettle();
    nav.pop();
    await t.pump();
    var elapsed = 0;
    for (final MapEntry(key: f, value: p) in _closeCard.entries) {
      final ms = (f * 1000 / 60).round();
      await t.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      expect(1 - cardGrowth(t), closeTo(p, 0.06), reason: 'card $f');
      if (ms > 50) {
        // UIKit's menu is gone within three frames.
        final o = t.widget<Opacity>(
          find
              .ancestor(
                of: find.byType(GlassMenuPanel),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(o.opacity, 0);
      }
    }
  }, variant: ios);
}
