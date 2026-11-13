import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/list/group_box_metrics.dart';
import 'package:adaptive_liquid_glass/src/list/list_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Card;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The fill of each group box's platter, outermost first.
List<int> _fills(WidgetTester t) => t
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(GlassGroupBox).first,
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((d) => ((d.decoration as ShapeDecoration).color!).toARGB32())
    .toList();

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('label gap; padding; 8-pt corners', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const SizedBox(
          width: 370,
          child: GlassGroupBox(
            label: Text('Storage'),
            labelIcon: Icon(CupertinoIcons.folder),
            child: Text('Body'),
          ),
        ),
      ),
    );
    final box = t.getRect(find.byType(GlassGroupBox));
    // The label row is as tall as its 20-pt icon.
    final label = t.getRect(find.byType(Row));
    final body = t.getRect(find.text('Body'));
    expect(body.top - label.bottom, closeTo(GroupBoxMetrics.labelGap, 0.1));
    expect(body.left - box.left, GroupBoxMetrics.padding);
    expect(box.bottom - body.bottom, GroupBoxMetrics.padding);
    expect(find.byType(Icon), findsOneWidget);
    final shape =
        t.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration
            as ShapeDecoration;
    expect(
      (shape.shape as RoundedSuperellipseBorder).borderRadius,
      BorderRadius.circular(GroupBoxMetrics.cornerRadius),
    );
  }, variant: ios);

  testWidgets('nested: 13-pt gap over an inner box; fills alternate', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const SizedBox(
          width: 370,
          child: GlassGroupBox(
            label: Text('Nested'),
            child: GlassGroupBox(child: GlassGroupBox(child: Text('Inner'))),
          ),
        ),
      ),
    );
    final label = t.getRect(find.text('Nested'));
    final inner = t.getRect(find.byType(GlassGroupBox).at(1));
    expect(
      inner.top - label.bottom,
      closeTo(GroupBoxMetrics.nestedLabelGap, 0.1),
    );
    final outer = GlassColors.groupBoxBackground.color.toARGB32();
    final nested = GlassColors.groupBoxNestedBackground.color.toARGB32();
    expect(_fills(t), [outer, nested, outer]);
  }, variant: ios);

  testWidgets('Material: a filled Card', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const GlassGroupBox(label: Text('Storage'), child: Text('Body'))),
    );
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(RoundedSuperellipseBorder), findsNothing);
    expect(find.text('Storage'), findsOneWidget);
  }, variant: android);

  testWidgets('a swipeable row with a leading insets its hairline as a '
      'plain one', (t) async {
    shaderEnv();
    Future<double> inset(Widget first) async {
      await t.pumpWidget(
        plainHost(
          GlassListSection(
            children: [
              first,
              const GlassListTile(title: Text('Two')),
            ],
          ),
        ),
      );
      return t
          .getTopLeft(
            find.byWidgetPredicate(
              (w) =>
                  w is ColoredBox &&
                  w.color.toARGB32() ==
                      GlassColors.listSeparator.color.toARGB32(),
            ),
          )
          .dx;
    }

    const tile = GlassListTile(
      leading: Icon(CupertinoIcons.star),
      title: Text('One'),
    );
    final plain = await inset(tile);
    final swipeable = await inset(
      GlassSwipeActions(
        trailing: [
          GlassSwipeAction(
            icon: CupertinoIcons.trash,
            label: 'Delete',
            onPressed: () {},
          ),
        ],
        child: tile,
      ),
    );
    final bare = await inset(const GlassListTile(title: Text('One')));
    expect(swipeable, plain);
    expect(plain, greaterThan(bare + ListMetrics.horizontalPadding));
  }, variant: ios);
}
