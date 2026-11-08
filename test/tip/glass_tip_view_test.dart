import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tip/tip_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

GlassTip _tip({List<GlassTipAction> actions = const []}) => GlassTip(
  title: const Text('Save as a Favorite'),
  message: const Text('Your favorite places appear first.'),
  image: const Icon(CupertinoIcons.star),
  actions: actions,
);

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    plainHost(SizedBox(width: 370, child: child), direction: direction);

Finder _close([String label = 'Close']) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('lays out image, title, message and close like TipKit', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_host(GlassTipView(tip: _tip())));
    final card = t.getRect(find.byType(GlassTipView));
    final image = t.getRect(find.byIcon(CupertinoIcons.star));
    final title = t.getRect(find.text('Save as a Favorite'));
    final close = t.getRect(_close());
    expect(image.left - card.left, closeTo(TipMetrics.startInset, 1));
    expect(title.left - card.left, closeTo(73, 1));
    expect(title.top - card.top, closeTo(TipMetrics.topInset, 1));
    expect(card.right - close.right, closeTo(TipMetrics.closeInset, 0.5));
    expect(close.width, TipMetrics.closeSize);
    expect(
      t.getRect(find.text('Your favorite places appear first.')).top,
      greaterThan(title.bottom),
    );
  }, variant: ios);

  testWidgets('mirrors under RTL', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(GlassTipView(tip: _tip()), direction: TextDirection.rtl),
    );
    final card = t.getRect(find.byType(GlassTipView));
    final image = t.getRect(find.byIcon(CupertinoIcons.star));
    final close = t.getRect(_close());
    expect(card.right - image.right, closeTo(TipMetrics.startInset, 1));
    expect(close.left - card.left, closeTo(TipMetrics.closeInset, 0.5));
  }, variant: ios);

  testWidgets('close dismisses with closed and then builds nothing', (t) async {
    shaderEnv();
    final reasons = <GlassTipDismissReason>[];
    final controller = GlassTipController(onDismissed: reasons.add);
    await t.pumpWidget(
      _host(GlassTipView(tip: _tip(), controller: controller)),
    );
    await t.tap(_close());
    await t.pumpAndSettle();
    expect(controller.isDismissed, isTrue);
    expect(reasons, [GlassTipDismissReason.closed]);
    expect(find.text('Save as a Favorite'), findsNothing);
  }, variant: ios);

  testWidgets('collapses at once under Reduce Motion', (t) async {
    shaderEnv();
    final controller = GlassTipController();
    await t.pumpWidget(
      _host(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GlassTipView(tip: _tip(), controller: controller),
        ),
      ),
    );
    controller.dismiss();
    await t.pump();
    expect(find.text('Save as a Favorite'), findsNothing);
  }, variant: ios);

  testWidgets('a hydrated dismissed controller builds nothing; reset shows', (
    t,
  ) async {
    shaderEnv();
    final controller = GlassTipController(dismissed: true);
    await t.pumpWidget(
      _host(GlassTipView(tip: _tip(), controller: controller)),
    );
    expect(find.text('Save as a Favorite'), findsNothing);
    controller.reset();
    await t.pumpAndSettle();
    expect(find.text('Save as a Favorite'), findsOneWidget);
  }, variant: ios);

  testWidgets('actions fire; the first is the trailing prominent one', (
    t,
  ) async {
    shaderEnv();
    final taps = <String>[];
    await t.pumpWidget(
      _host(
        GlassTipView(
          tip: _tip(
            actions: [
              GlassTipAction(
                label: 'Learn More',
                onPressed: () => taps.add('l'),
              ),
              GlassTipAction(label: 'Not Now', onPressed: () => taps.add('n')),
            ],
          ),
        ),
      ),
    );
    final learn = t.getRect(find.text('Learn More'));
    final later = t.getRect(find.text('Not Now'));
    expect(learn.left, greaterThan(later.right));
    await t.tap(find.text('Learn More'));
    await t.tap(find.text('Not Now'));
    expect(taps, ['l', 'n']);
    expect(find.text('Learn More'), findsOneWidget, reason: 'tip stays up');
  }, variant: ios);

  testWidgets('a custom close label names the button', (t) async {
    shaderEnv();
    await t.pumpWidget(_host(GlassTipView(tip: _tip(), closeLabel: 'إغلاق')));
    expect(_close('إغلاق'), findsOneWidget);
  }, variant: ios);

  testWidgets('Android draws a Material card with an IconButton close', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(appHost(GlassTipView(tip: _tip())));
    expect(
      find.ancestor(
        of: find.text('Save as a Favorite'),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
    expect(find.byType(IconButton), findsOneWidget);
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(find.text('Save as a Favorite'), findsNothing);
  }, variant: android);
}
