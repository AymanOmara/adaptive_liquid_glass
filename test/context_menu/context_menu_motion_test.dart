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

/// The press before the lift, idb long presses on the same card timed
/// from its touchesBegan: seconds after touch-down and the card's scale
/// (200 wide).
final _press = <double, double>{
  0.2: 1.0,
  0.33: 1.01,
  0.43: 1.0233,
  0.53: 1.04,
  0.66: 1.0567,
  0.75: 1.0633,
};

const _card2 = Key('card');

Widget _menuApp() => CupertinoApp(
  home: Center(
    child: GlassContextMenu(
      items: [GlassMenuItem(label: 'Copy', onSelected: () {})],
      child: const SizedBox(
        key: _card2,
        width: 200,
        height: 120,
        child: ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    ),
  ),
);

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

  group('the press before the lift follows UIKit', () {
    Future<TestGesture> press(WidgetTester t) async {
      shaderEnv();
      await host(t);
      await t.pumpWidget(_menuApp());
      final g = await t.startGesture(t.getCenter(find.byKey(_card2)));
      // The frame the press starts on: its time 0.
      await t.pump();
      return g;
    }

    double scale(WidgetTester t) =>
        t.getRect(find.byKey(_card2).first).width / 200;

    testWidgets('the item eases up under the finger, then lifts on', (t) async {
      final g = await press(t);
      var elapsed = 0;
      for (final MapEntry(key: s, value: v) in _press.entries) {
        final ms = (s * 1000).round();
        await t.pump(Duration(milliseconds: ms - elapsed));
        elapsed = ms;
        expect(scale(t), closeTo(v, 0.004), reason: '$s s');
      }
      expect(find.byType(GlassMenuPanel), findsNothing);
      await t.pump(Duration(milliseconds: 800 - elapsed + 16));
      await t.pump(const Duration(milliseconds: 16));
      expect(find.byType(GlassMenuPanel), findsOneWidget);
      // The lift carries on from the pressed size (UIKit's first lifted
      // frame is already 1.117).
      final lifted = t.getRect(find.byKey(_card2).last).width / 200;
      expect(lifted, greaterThan(1.06));
      await g.up();
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byKey(_card2).last).width / 200,
        closeTo(1.13, 0.01),
      );
    }, variant: ios);

    testWidgets('released at 0.3 s it settles back without the menu', (
      t,
    ) async {
      final g = await press(t);
      await t.pump(const Duration(milliseconds: 300));
      expect(scale(t), greaterThan(1.003));
      await g.up();
      await t.pumpAndSettle();
      expect(scale(t), 1);
      expect(find.byType(GlassMenuPanel), findsNothing);
    }, variant: ios);

    testWidgets('released at 0.6 s the menu still opens', (t) async {
      final g = await press(t);
      await t.pump(const Duration(milliseconds: 600));
      await g.up();
      await t.pumpAndSettle();
      expect(find.byType(GlassMenuPanel), findsOneWidget);
    }, variant: ios);
  });
}
