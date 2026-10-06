import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/list/list_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Card, Icons, ListTile;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The section's hairline separators, by colour.
final _separators = find.byWidgetPredicate(
  (w) =>
      w is ColoredBox &&
      w.color.toARGB32() == CupertinoColors.separator.color.toARGB32(),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('header, footer, separators; opaque unless glass', (t) async {
    shaderEnv();
    Widget section(Glass? glass) => GlassListSection(
      glass: glass,
      header: const Text('General'),
      footer: const Text('Footer'),
      children: const [
        GlassListTile(title: Text('About')),
        GlassListTile(title: Text('Storage')),
        GlassListTile(title: Text('Airplane Mode')),
      ],
    );
    await t.pumpWidget(plainHost(section(null)));
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Footer'), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
    expect(_separators, findsNWidgets(2));
    expect(t.getSize(_separators.first).height, ListMetrics.separatorThickness);
    await t.pumpWidget(plainHost(section(Glass.regular)));
    expect(find.byType(LiquidGlass), findsOneWidget);
  }, variant: ios);

  testWidgets('tap, long press, disabled; pressed highlight while held', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    var longPresses = 0;
    await t.pumpWidget(
      plainHost(
        GlassListSection(
          children: [
            GlassListTile(title: const Text('One'), onTap: () => taps++),
            GlassListTile(
              title: const Text('Two'),
              onLongPress: () => longPresses++,
            ),
            GlassListTile(
              title: const Text('Three'),
              onTap: () => taps++,
              enabled: false,
            ),
          ],
        ),
      ),
    );
    await t.tap(find.text('One'));
    await t.pump();
    expect(taps, 1);
    await t.longPress(find.text('Two'));
    await t.pump();
    expect(longPresses, 1);
    await t.tap(find.text('Three'));
    await t.pump();
    expect(taps, 1);

    final pressed = find.byWidgetPredicate(
      (w) =>
          w is ColoredBox &&
          w.color.toARGB32() == GlassColors.listRowPressed.color.toARGB32(),
    );
    final g = await t.startGesture(t.getCenter(find.text('Two')));
    // The highlight waits for the tap-down deadline, as a scroll may win.
    await t.pump(const Duration(milliseconds: 150));
    expect(pressed, findsOneWidget);
    await g.up();
    await t.pump();
    expect(pressed, findsNothing);
  }, variant: ios);

  testWidgets('the separator after a leading starts at textStart', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassListSection(
          children: [
            GlassListTile(
              leading: Icon(CupertinoIcons.settings),
              title: Text('General'),
            ),
            GlassListTile(title: Text('Storage')),
          ],
        ),
      ),
    );
    final separator = find.byWidgetPredicate(
      (w) => w is SizedBox && w.height == ListMetrics.separatorThickness,
    );
    expect(separator, findsOneWidget);
    final sectionStart = t.getTopLeft(find.byType(GlassListSection)).dx;
    expect(
      t.getTopLeft(separator).dx,
      closeTo(sectionStart + ListMetrics.margin + ListMetrics.textStart, 0.01),
    );
  }, variant: ios);

  testWidgets('right to left: the chevron is left of the title', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassListSection(
          children: [GlassListTile(title: Text('Wi-Fi'), chevron: true)],
        ),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      t.getCenter(find.byIcon(CupertinoIcons.chevron_forward)).dx,
      lessThan(t.getCenter(find.text('Wi-Fi')).dx),
    );
  }, variant: ios);

  testWidgets('a button labelled with its title; disabled is not enabled', (
    t,
  ) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(GlassListTile(title: const Text('Wi-Fi'), onTap: () {})),
    );
    expect(
      t.getSemantics(find.byType(GlassListTile)),
      isSemantics(isButton: true, isEnabled: true, label: 'Wi-Fi'),
    );
    await t.pumpWidget(
      plainHost(
        GlassListTile(
          title: const Text('Storage'),
          onTap: () {},
          enabled: false,
        ),
      ),
    );
    expect(
      t.getSemantics(find.byType(GlassListTile)),
      isSemantics(isButton: true, isEnabled: false, label: 'Storage'),
    );
    handle.dispose();
  }, variant: ios);

  testWidgets('Material: a Card of ListTiles; taps work', (t) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      appHost(
        GlassListSection(
          header: const Text('General'),
          children: [
            GlassListTile(
              leading: const Icon(CupertinoIcons.settings),
              title: const Text('About'),
              value: 'iOS 26.4',
              chevron: true,
              onTap: () => taps++,
            ),
            const GlassListTile(title: Text('Storage')),
          ],
        ),
      ),
    );
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await t.tap(find.text('About'));
    await t.pumpAndSettle();
    expect(taps, 1);
  }, variant: android);
}
