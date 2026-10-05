import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:adaptive_liquid_glass/src/navigation/scroll_edge.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget page({
  Widget? title = const Text('Inbox'),
  List<Widget> actions = const [],
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (c, child) => Directionality(textDirection: dir, child: child!),
  home: Scaffold(
    extendBodyBehindAppBar: true,
    appBar: GlassNavigationBar(title: title, actions: actions),
    body: ListView(
      children: [
        for (var i = 0; i < 50; i++)
          SizedBox(height: 44, child: Text('Row $i')),
      ],
    ),
  ),
);

List<Widget> twoActions() => [
  GlassButton.icon(
    onPressed: () {},
    icon: CupertinoIcons.pencil,
    semanticLabel: 'Edit',
  ),
  GlassButton.icon(
    onPressed: () {},
    icon: CupertinoIcons.ellipsis,
    semanticLabel: 'More',
  ),
];

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('preferred height is the measured bar', (t) async {
    expect(
      const GlassNavigationBar().preferredSize.height,
      NavBarMetrics.barHeight,
    );
  });

  testWidgets('title is a centred header, 17 semibold', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(page());
    final title = find.text('Inbox');
    expect(t.getCenter(title).dx, moreOrLessEquals(400, epsilon: 1));
    final style = DefaultTextStyle.of(t.element(title)).style;
    expect(style.fontSize, NavBarMetrics.titleFontSize);
    expect(style.fontWeight, FontWeight.w600);
    expect(
      t.getSemantics(title),
      matchesSemantics(label: 'Inbox', isHeader: true),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('actions: 44-pt cells merged into one union at the end', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(page(actions: twoActions()));
    final members = t
        .widgetList<GlassMember>(find.byType(GlassMember))
        .toList();
    expect(members, hasLength(2));
    expect(members.map((m) => m.unionId).toSet(), hasLength(1));
    expect(members.first.unionId, isNotNull);
    final buttons = find.byType(GlassButton);
    final last = t.getRect(buttons.last);
    expect(last.height, NavBarMetrics.item.iconOnlyHeight);
    expect(
      last.width,
      NavBarMetrics.item.iconOnlyHeight + NavBarMetrics.item.iconOnlyExtraWidth,
    );
    expect(800 - last.right, moreOrLessEquals(NavBarMetrics.edgeInset));
  }, variant: ios);

  testWidgets('RTL: actions at the left edge', (t) async {
    shaderEnv();
    await t.pumpWidget(page(actions: twoActions(), dir: TextDirection.rtl));
    expect(
      t.getRect(find.byType(GlassButton).last).left,
      moreOrLessEquals(NavBarMetrics.edgeInset),
    );
  }, variant: ios);

  testWidgets('a long title truncates instead of overflowing', (t) async {
    shaderEnv();
    for (final dir in TextDirection.values) {
      await t.pumpWidget(
        page(
          title: const Text(
            'A very long title that cannot possibly fit in the bar at all, '
            'not even close, on any phone that exists today',
          ),
          actions: twoActions(),
          dir: dir,
        ),
      );
      expect(t.takeException(), isNull);
    }
  }, variant: ios);

  testWidgets('scroll edge shows only once content is under the bar', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(page());
    GlassScrollEdge edge() =>
        t.widget<GlassScrollEdge>(find.byType(GlassScrollEdge));
    expect(edge().visible, isFalse);
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(edge().visible, isTrue);
  }, variant: ios);

  testWidgets('no back button on the root route', (t) async {
    shaderEnv();
    await t.pumpWidget(page());
    expect(find.byType(GlassBackButton), findsNothing);
  }, variant: ios);

  testWidgets('a pushed route gets a 44-pt back button that pops', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  appBar: GlassNavigationBar(title: Text('Detail')),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsOneWidget);
    expect(t.getSize(find.byType(GlassBackButton)), const Size(44, 44));
    expect(
      t.getRect(find.byType(GlassBackButton)).left,
      moreOrLessEquals(NavBarMetrics.edgeInset),
    );
    await t.tap(find.byType(GlassBackButton));
    await t.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  }, variant: ios);
}
