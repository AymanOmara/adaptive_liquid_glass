import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/context_menu/context_menu_metrics.dart';
import 'package:adaptive_liquid_glass/src/menu/glass_menu_panel.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(List<String> log) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: GlassContextMenu(
        items: [
          GlassMenuItem(
            label: 'Copy',
            icon: CupertinoIcons.doc_on_doc,
            onSelected: () => log.add('copy'),
          ),
          GlassMenuItem(
            label: 'Delete',
            icon: CupertinoIcons.trash,
            destructive: true,
            onSelected: () => log.add('delete'),
          ),
        ],
        child: const SizedBox(
          width: 200,
          height: 120,
          child: ColoredBox(color: Colors.white, child: Text('Card')),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a long-press opens the menu below the item; it picks', (
    t,
  ) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(_app(log));
    final card = t.getRect(find.text('Card').first);
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    final panel = t.getRect(find.byType(GlassMenuPanel));
    expect(panel.top, greaterThan(card.top + 100));
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(find.byType(GlassMenuPanel), findsNothing);
    expect(log, ['delete']);
  }, variant: ios);

  testWidgets('the menu is UIKit\'s 250 wide; the lifted item casts '
      'its shadow', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    expect(
      t.getSize(find.byType(GlassMenuPanel)).width,
      ContextMenuMetrics.menuWidth,
    );
    // Black under the item's bounds, at full strength once lifted, its
    // blur in screen points whatever the item's lift.
    final shadows = t
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((b) => b.decoration)
        .whereType<BoxDecoration>()
        .expand((d) => d.boxShadow ?? const <BoxShadow>[])
        .where(
          (s) =>
              (s.color.a - ContextMenuMetrics.previewShadowColor.a).abs() <
              0.01,
        );
    expect(shadows, hasLength(1));
    expect(shadows.single.offset, Offset.zero);
    expect(
      ContextMenuMetrics.previewShadow(scale: 1.13).blurSigma * 1.13,
      moreOrLessEquals(ContextMenuMetrics.previewShadowSigma, epsilon: 1e-6),
    );
  }, variant: ios);

  testWidgets('the page behind is dimmed, not blurred, as UIKit', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    final before = t.widgetList(find.byType(BackdropFilter)).length;
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    // Only the menu's own glass may add a backdrop; no full-page blur.
    final pageBlurs = t
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .skip(before)
        .where(
          (b) =>
              t.getSize(find.byWidget(b)) ==
              t.view.physicalSize / t.view.devicePixelRatio,
        );
    expect(pageBlurs, isEmpty);
  }, variant: ios);

  testWidgets('a tap outside closes it without choosing', (t) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(_app(log));
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.byType(GlassMenuPanel), findsNothing);
    expect(log, isEmpty);
  }, variant: ios);

  testWidgets('Material: a popup menu', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    expect(find.byType(PopupMenuItem<GlassMenuItem>), findsNWidgets(2));
  }, variant: android);
}
