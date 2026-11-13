import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/list/list_metrics.dart';
import 'package:adaptive_liquid_glass/src/list/plain_list_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, ListTile;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The plain list's hairlines in [brightness].
Finder _separators([Brightness brightness = Brightness.light]) {
  final c = brightness == Brightness.light
      ? GlassColors.plainListSeparator.color
      : GlassColors.plainListSeparator.darkColor;
  return find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color.toARGB32() == c.toARGB32(),
  );
}

Widget _host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
}) => MediaQuery(
  data: MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.implicitView!,
  ).copyWith(platformBrightness: brightness, padding: EdgeInsets.zero),
  child: Directionality(textDirection: direction, child: child),
);

GlassPlainList _list({bool sticky = true, int rows = 3}) => GlassPlainList(
  stickyHeaders: sticky,
  sections: [
    GlassPlainListSection(
      header: const Text('Mailboxes'),
      children: [
        for (var i = 0; i < rows; i++)
          GlassListTile(key: ValueKey('r$i'), title: Text('Row $i')),
      ],
    ),
    const GlassPlainListSection(
      header: Text('More'),
      children: [
        GlassListTile(
          leading: Icon(CupertinoIcons.star),
          title: Text('Favourites'),
        ),
      ],
    ),
  ],
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('measured layout: rows, headers, a hairline under each row', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_host(_list()));
    // Every row has a hairline, the last of each section too.
    expect(_separators(), findsNWidgets(4));
    final width = t.getSize(find.byType(GlassPlainList)).width;
    final plain = t.getRect(_separators().first);
    expect(plain.left, PlainListMetrics.separatorStart);
    expect(plain.right, width - PlainListMetrics.separatorEnd);
    expect(plain.height, ListMetrics.separatorThickness);
    // After a leading icon it starts under the title.
    expect(t.getRect(_separators().last).left, ListMetrics.textStart);
    // The hairline overlays the row's bottom edge.
    final row = t.getRect(find.byKey(const ValueKey('r0')));
    expect(row.height, ListMetrics.minRowHeight);
    expect(plain.bottom, row.bottom);
    // The header's extent is 64.33 pt; the first row follows it.
    expect(
      row.top,
      closeTo(
        PlainListMetrics.headerTopPadding + PlainListMetrics.headerHeight,
        0.01,
      ),
    );
    final header = t.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Mailboxes'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(header.style.fontSize, ListMetrics.headerSize);
    expect(header.style.fontWeight, ListMetrics.headerWeight);
    expect(
      header.style.color!.toARGB32(),
      GlassColors.secondaryLabel.color.toARGB32(),
    );
  }, variant: ios);

  testWidgets('RTL mirrors the hairline insets', (t) async {
    shaderEnv();
    await t.pumpWidget(_host(_list(), direction: TextDirection.rtl));
    final width = t.getSize(find.byType(GlassPlainList)).width;
    expect(
      t.getRect(_separators().first).right,
      width - PlainListMetrics.separatorStart,
    );
    expect(t.getRect(_separators().last).right, width - ListMetrics.textStart);
    expect(
      t.getRect(find.text('Mailboxes')).right,
      width - ListMetrics.horizontalPadding,
    );
  }, variant: ios);

  testWidgets('dark mode: measured hairline and black page', (t) async {
    shaderEnv();
    await t.pumpWidget(_host(_list(), brightness: Brightness.dark));
    expect(_separators(Brightness.dark), findsNWidgets(4));
    final page = t.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(GlassPlainList),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(
      page.color.toARGB32(),
      GlassColors.plainListBackground.darkColor.toARGB32(),
    );
  }, variant: ios);

  testWidgets('headers stick while their section scrolls; opt out', (t) async {
    shaderEnv();
    await t.pumpWidget(_host(_list(rows: 30)));
    await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await t.pump();
    // Pinned at the top, over the rows scrolling under it.
    expect(
      t.getRect(find.text('Mailboxes')).center.dy,
      closeTo(
        PlainListMetrics.headerTopPadding + PlainListMetrics.headerHeight / 2,
        1,
      ),
    );
    await t.pumpWidget(_host(_list(rows: 30, sticky: false)));
    await t.pump();
    expect(find.text('Mailboxes'), findsNothing);
  }, variant: ios);

  testWidgets('swipe rows keep the hairline under the title', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(
        GlassPlainList(
          sections: [
            GlassPlainListSection(
              children: [
                GlassSwipeActions(
                  trailing: [
                    GlassSwipeAction(
                      icon: CupertinoIcons.trash,
                      label: 'Delete',
                      destructive: true,
                      onPressed: () {},
                    ),
                  ],
                  child: const GlassListTile(
                    leading: Icon(CupertinoIcons.tray),
                    title: Text('Inbox'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.byType(GlassSwipeActions), findsOneWidget);
    expect(t.getRect(_separators()).left, ListMetrics.textStart);
  }, variant: ios);

  testWidgets('Material: ListTiles, dividers between rows, subheaders', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      appHost(
        GlassPlainList(
          sections: [
            GlassPlainListSection(
              header: const Text('Mailboxes'),
              children: [
                GlassListTile(title: const Text('Inbox'), onTap: () => taps++),
                const GlassListTile(
                  leading: Icon(CupertinoIcons.star),
                  title: Text('Drafts'),
                ),
                const GlassListTile(title: Text('Sent')),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.byType(Divider), findsNWidgets(2));
    expect(
      t.widget<Divider>(find.byType(Divider).last).indent,
      ListMetrics.materialLeadingInset,
    );
    expect(
      t.getRect(find.text('Inbox')).center.dy,
      greaterThan(PlainListMetrics.materialHeaderHeight),
    );
    await t.tap(find.text('Inbox'));
    expect(taps, 1);
  }, variant: android);
}
