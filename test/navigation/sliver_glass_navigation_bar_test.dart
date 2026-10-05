import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:adaptive_liquid_glass/src/navigation/scroll_edge.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget page(
  ScrollController controller, {
  TextDirection dir = TextDirection.ltr,
  double textScale = 1,
}) => MaterialApp(
  builder: (c, child) => MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Directionality(textDirection: dir, child: child!),
  ),
  home: Scaffold(
    body: CustomScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverGlassNavigationBar(largeTitle: Text('Inbox')),
        SliverList.builder(
          itemCount: 60,
          itemBuilder: (_, i) => SizedBox(height: 44, child: Text('Row $i')),
        ),
      ],
    ),
  ),
);

/// The large title (34 pt) and inline title (17 pt) texts.
Finder titleOfSize(double size) => find.byWidgetPredicate(
  (w) => w is DefaultTextStyle && w.style.fontSize == size,
);
Finder get large => find.descendant(
  of: titleOfSize(NavBarMetrics.largeTitleFontSize),
  matching: find.text('Inbox'),
);
double inlineOpacity(WidgetTester t) => t
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: titleOfSize(NavBarMetrics.titleFontSize),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('at rest: large title at the start, inline hidden', (t) async {
    shaderEnv();
    await t.pumpWidget(page(ScrollController()));
    expect(
      t.getRect(large).left,
      moreOrLessEquals(NavBarMetrics.largeTitleInset, epsilon: 0.5),
    );
    expect(
      t
          .widget<Baseline>(
            find.ancestor(of: large, matching: find.byType(Baseline)),
          )
          .baseline,
      NavBarMetrics.largeTitleBaselineBelowBar,
    );
    expect(inlineOpacity(t), 0);
    expect(
      t.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible,
      isFalse,
    );
  }, variant: ios);

  testWidgets('scrolling moves the large title up with the content', (t) async {
    shaderEnv();
    final c = ScrollController();
    await t.pumpWidget(page(c));
    final rest = t.getRect(large).top;
    final row = t.getRect(find.text('Row 0')).top;
    c.jumpTo(20);
    await t.pump();
    expect(t.getRect(large).top, moreOrLessEquals(rest - 20, epsilon: 0.01));
    expect(
      t.getRect(find.text('Row 0')).top,
      moreOrLessEquals(row - 20, epsilon: 0.01),
    );
    expect(
      t.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible,
      isTrue,
    );
  }, variant: ios);

  testWidgets('inline title appears past the threshold, fading in', (t) async {
    shaderEnv();
    final c = ScrollController();
    await t.pumpWidget(page(c));
    c.jumpTo(NavBarMetrics.inlineThreshold - 1);
    await t.pump();
    expect(inlineOpacity(t), 0);
    c.jumpTo(NavBarMetrics.inlineThreshold + 1);
    await t.pump();
    expect(inlineOpacity(t), 1);
    final fade = t.widget<AnimatedOpacity>(
      find.ancestor(
        of: titleOfSize(NavBarMetrics.titleFontSize),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(fade.duration, NavBarMetrics.inlineFade);
  }, variant: ios);

  testWidgets('pulling down stretches the large title', (t) async {
    shaderEnv();
    await t.pumpWidget(page(ScrollController()));
    final g = await t.startGesture(t.getCenter(find.text('Row 5')));
    await g.moveBy(const Offset(0, 120));
    await t.pump();
    final transform = t.widget<Transform>(
      find.ancestor(of: large, matching: find.byType(Transform)).first,
    );
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1));
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('RTL: large title at the right', (t) async {
    shaderEnv();
    await t.pumpWidget(page(ScrollController(), dir: TextDirection.rtl));
    expect(
      800 - t.getRect(large).right,
      moreOrLessEquals(NavBarMetrics.largeTitleInset, epsilon: 0.5),
    );
  }, variant: ios);

  testWidgets('large text: no overflow', (t) async {
    shaderEnv();
    await t.pumpWidget(page(ScrollController(), textScale: 2));
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('Material: SliverAppBar.large', (t) async {
    shaderEnv();
    await t.pumpWidget(page(ScrollController()));
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
  }, variant: android);

  testWidgets('the large title never shows above the bar', (t) async {
    shaderEnv();
    final c = ScrollController();
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          padding: EdgeInsets.only(top: 62),
        ),
        child: page(c),
      ),
    );
    c.jumpTo(100);
    await t.pump();
    final clip = t.widget<ClipRect>(
      find.ancestor(of: large, matching: find.byType(ClipRect)).first,
    );
    expect(clip.clipper!.getClip(const Size(800, 200)).top, 62);
  }, variant: ios);

  testWidgets('content under the bar blurs once the title collapses', (
    t,
  ) async {
    shaderEnv();
    final c = ScrollController();
    await t.pumpWidget(page(c));
    Finder blur() => find.descendant(
      of: find.byType(GlassScrollEdge),
      matching: find.byType(BackdropFilter),
    );
    c.jumpTo(30);
    await t.pump();
    expect(blur(), findsNothing);
    c.jumpTo(NavBarMetrics.inlineThreshold + 10);
    await t.pump();
    expect(blur(), findsOneWidget);
  }, variant: ios);

  testWidgets('the inline title comes in blurred, then sharpens', (t) async {
    shaderEnv();
    final c = ScrollController();
    await t.pumpWidget(page(c));
    c.jumpTo(NavBarMetrics.inlineThreshold + 10);
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    ImageFiltered blur() => t.widget<ImageFiltered>(
      find.ancestor(
        of: titleOfSize(NavBarMetrics.titleFontSize),
        matching: find.byType(ImageFiltered),
      ),
    );
    expect(blur().enabled, isTrue);
    await t.pump(NavBarMetrics.inlineFade);
    expect(blur().enabled, isFalse);
  }, variant: ios);
}
