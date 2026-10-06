import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/list/list_chevron.dart';
import 'package:adaptive_liquid_glass/src/list/list_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Card, ColorScheme, Colors, Icons, ListTile, MaterialApp, ThemeData;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The section's hairline separators, by colour.
final _separators = find.byWidgetPredicate(
  (w) =>
      w is ColoredBox &&
      w.color.toARGB32() == GlassColors.listSeparator.color.toARGB32(),
);

/// The style the [Icon] under test renders with.
TextStyle _iconStyle(WidgetTester t) => t
    .widget<RichText>(
      find.descendant(of: find.byType(Icon), matching: find.byType(RichText)),
    )
    .text
    .style!;

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

  testWidgets('rows are at least minRowHeight; separators overlay', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassListSection(
          children: [
            GlassListTile(title: Text('About')),
            GlassListTile(title: Text('Storage')),
            GlassListTile(title: Text('Airplane Mode')),
          ],
        ),
      ),
    );
    final rows = find.byType(GlassListTile);
    expect(
      t.getSize(rows.first).height,
      greaterThanOrEqualTo(ListMetrics.minRowHeight),
    );
    // Two separators overlay the rows yet add no height.
    expect(_separators, findsNWidgets(2));
    expect(
      t.getBottomLeft(rows.last).dy - t.getTopLeft(rows.first).dy,
      closeTo(3 * ListMetrics.minRowHeight, 0.01),
    );
    // Under a row without a leading the separator starts at the row's
    // own inset.
    final sectionStart = t.getTopLeft(find.byType(GlassListSection)).dx;
    expect(
      t.getTopLeft(_separators.first).dx,
      closeTo(
        sectionStart + ListMetrics.margin + ListMetrics.horizontalPadding,
        0.01,
      ),
    );
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

  testWidgets('the leading icon takes the theme accent; explicit wins', (
    t,
  ) async {
    shaderEnv();
    Widget section({Color? iconColor, bool enabled = true}) => GlassListSection(
      children: [
        GlassListTile(
          leading: Icon(CupertinoIcons.wifi, color: iconColor),
          title: const Text('Wi-Fi'),
          enabled: enabled,
        ),
      ],
    );
    await t.pumpWidget(plainHost(section()));
    // The default is iOS 26's measured accent at the measured size.
    expect(
      _iconStyle(t).color!.toARGB32(),
      GlassColors.listIcon.color.toARGB32(),
    );
    expect(_iconStyle(t).fontSize, ListMetrics.iconSize);
    await t.pumpWidget(
      plainHost(
        CupertinoTheme(
          data: const CupertinoThemeData(
            primaryColor: CupertinoColors.systemRed,
          ),
          child: section(),
        ),
      ),
    );
    expect(
      _iconStyle(t).color!.toARGB32(),
      CupertinoColors.systemRed.color.toARGB32(),
    );
    const explicit = Color(0xFF123456);
    await t.pumpWidget(plainHost(section(iconColor: explicit)));
    expect(_iconStyle(t).color!.toARGB32(), explicit.toARGB32());
    await t.pumpWidget(plainHost(section(enabled: false)));
    expect(
      _iconStyle(t).color!.toARGB32(),
      CupertinoColors.tertiaryLabel.color.toARGB32(),
    );
  }, variant: ios);

  testWidgets('under a MaterialApp only cupertinoOverrideTheme tints', (
    t,
  ) async {
    shaderEnv();
    Widget app({CupertinoThemeData? override}) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        cupertinoOverrideTheme: override,
      ),
      home: const GlassListSection(
        children: [
          GlassListTile(
            leading: Icon(CupertinoIcons.wifi),
            title: Text('Wi-Fi'),
          ),
        ],
      ),
    );
    // The Material colour scheme's primary is not an iOS accent choice.
    await t.pumpWidget(app());
    expect(
      _iconStyle(t).color!.toARGB32(),
      GlassColors.listIcon.color.toARGB32(),
    );
    await t.pumpWidget(
      app(
        override: const CupertinoThemeData(
          primaryColor: CupertinoColors.systemRed,
        ),
      ),
    );
    // MaterialApp animates theme changes.
    await t.pumpAndSettle();
    expect(
      _iconStyle(t).color!.toARGB32(),
      CupertinoColors.systemRed.color.toARGB32(),
    );
  }, variant: ios);

  testWidgets('the toggle ends controlEnd and the chevron chevronEnd', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassListSection(
          children: [
            GlassListTile(
              title: const Text('Airplane Mode'),
              trailing: GlassToggle(value: true, onChanged: (_) {}),
            ),
            const GlassListTile(title: Text('About'), chevron: true),
          ],
        ),
      ),
    );
    final platterEnd =
        t.getTopRight(find.byType(GlassListSection)).dx - ListMetrics.margin;
    expect(
      t.getTopRight(find.byType(GlassToggle)).dx,
      closeTo(platterEnd - ListMetrics.controlEnd, 0.01),
    );
    expect(
      t.getTopRight(find.byType(ListChevron)).dx,
      closeTo(platterEnd - ListMetrics.chevronEnd, 0.01),
    );
  }, variant: ios);

  testWidgets('the header is 17 semibold; the footer 13', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassListSection(
          header: Text('General'),
          footer: Text('Footer text'),
          children: [GlassListTile(title: Text('About'))],
        ),
      ),
    );
    final header = t
        .widget<RichText>(
          find.descendant(
            of: find.text('General'),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style!;
    expect(header.fontSize, ListMetrics.headerSize);
    expect(header.fontWeight, ListMetrics.headerWeight);
    final footer = t
        .widget<RichText>(
          find.descendant(
            of: find.text('Footer text'),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style!;
    expect(footer.fontSize, ListMetrics.footerSize);
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
    expect(_separators, findsOneWidget);
    final sectionStart = t.getTopLeft(find.byType(GlassListSection)).dx;
    final sectionEnd = t.getTopRight(find.byType(GlassListSection)).dx;
    expect(
      t.getTopLeft(_separators.first).dx,
      closeTo(sectionStart + ListMetrics.margin + ListMetrics.textStart, 0.01),
    );
    expect(
      t.getTopRight(_separators.first).dx,
      closeTo(sectionEnd - ListMetrics.margin - ListMetrics.separatorEnd, 0.01),
    );
  }, variant: ios);

  testWidgets('right to left: the chevron is left, the leading right', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassListSection(
          children: [
            GlassListTile(
              leading: Icon(CupertinoIcons.wifi),
              title: Text('Wi-Fi'),
              chevron: true,
            ),
          ],
        ),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      t.getCenter(find.byType(ListChevron)).dx,
      lessThan(t.getCenter(find.text('Wi-Fi')).dx),
    );
    expect(
      t.getCenter(find.byType(Icon)).dx,
      greaterThan(t.getCenter(find.text('Wi-Fi')).dx),
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
