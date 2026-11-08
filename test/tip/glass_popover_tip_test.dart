import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tip/tip_body.dart';
import 'package:adaptive_liquid_glass/src/tip/tip_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _title = 'Save as a Favorite';

GlassTip _tip() => const GlassTip(
  title: Text(_title),
  message: Text('Your favorite places appear first.'),
  image: Icon(CupertinoIcons.star),
);

const _anchorKey = ValueKey('anchor');

Widget _host(
  GlassTipController controller, {
  Alignment alignment = Alignment.center,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  home: Directionality(
    textDirection: direction,
    child: Scaffold(
      body: Align(
        alignment: alignment,
        child: GlassPopoverTip(
          tip: _tip(),
          controller: controller,
          child: const SizedBox(key: _anchorKey, width: 44, height: 44),
        ),
      ),
    ),
  ),
);

Finder _close() => find.descendant(
  of: find.byType(TipBody),
  matching: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Close',
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('opens above its anchor, centred, 319 wide', (t) async {
    shaderEnv();
    await t.pumpWidget(_host(GlassTipController()));
    await t.pumpAndSettle();
    final anchor = t.getRect(find.byKey(_anchorKey));
    final title = t.getRect(find.text(_title));
    expect(title.bottom, lessThan(anchor.top));
    final left = anchor.center.dx - TipMetrics.popoverMaxWidth / 2;
    expect(title.left - left, closeTo(73, 1));
    final close = t.getRect(_close());
    expect(
      left + TipMetrics.popoverMaxWidth - close.right,
      closeTo(TipMetrics.closeInset, 0.5),
    );
  }, variant: ios);

  testWidgets('opens below an anchor near the top', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(GlassTipController(), alignment: Alignment.topCenter),
    );
    await t.pumpAndSettle();
    final anchor = t.getRect(find.byKey(_anchorKey));
    expect(t.getRect(find.text(_title)).top, greaterThan(anchor.bottom));
  }, variant: ios);

  testWidgets('mirrors the close button under RTL', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(GlassTipController(), direction: TextDirection.rtl),
    );
    await t.pumpAndSettle();
    final anchor = t.getRect(find.byKey(_anchorKey));
    final left = anchor.center.dx - TipMetrics.popoverMaxWidth / 2;
    expect(
      t.getRect(_close()).left - left,
      closeTo(TipMetrics.closeInset, 0.5),
    );
  }, variant: ios);

  testWidgets('close dismisses with closed and closes the popover', (t) async {
    shaderEnv();
    final reasons = <GlassTipDismissReason>[];
    final controller = GlassTipController(onDismissed: reasons.add);
    await t.pumpWidget(_host(controller));
    await t.pumpAndSettle();
    await t.tap(_close());
    await t.pumpAndSettle();
    expect(reasons, [GlassTipDismissReason.closed]);
    expect(find.text(_title), findsNothing);
  }, variant: ios);

  testWidgets('a tap outside dismisses it', (t) async {
    shaderEnv();
    final controller = GlassTipController();
    await t.pumpWidget(_host(controller));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 590));
    await t.pumpAndSettle();
    expect(controller.isDismissed, isTrue);
    expect(find.text(_title), findsNothing);
  }, variant: ios);

  testWidgets('a hydrated dismissed controller never opens; reset opens', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassTipController(dismissed: true);
    await t.pumpWidget(_host(controller));
    await t.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    controller.reset();
    await t.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
  }, variant: ios);

  testWidgets('dismissing the controller elsewhere closes it', (t) async {
    shaderEnv();
    final controller = GlassTipController();
    await t.pumpWidget(_host(controller));
    await t.pumpAndSettle();
    controller.dismiss(GlassTipDismissReason.actionPerformed);
    await t.pumpAndSettle();
    expect(find.text(_title), findsNothing);
  }, variant: ios);

  testWidgets('removing the anchor closes it without dismissing', (t) async {
    shaderEnv();
    final controller = GlassTipController();
    await t.pumpWidget(_host(controller));
    await t.pumpAndSettle();
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(controller.isDismissed, isFalse);
  }, variant: ios);

  testWidgets('Android shows a Material bubble with an IconButton close', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassTipController();
    await t.pumpWidget(_host(controller));
    await t.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(controller.isDismissed, isTrue);
    expect(find.text(_title), findsNothing);
  }, variant: android);
}
