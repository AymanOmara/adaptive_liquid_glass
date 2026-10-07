import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/list/list_chevron.dart';
import 'package:adaptive_liquid_glass/src/picker/picker_page.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness({required this.style, this.enabled = true, this.onChanged});

  final GlassPickerStyle style;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String value = 'w';

  @override
  Widget build(BuildContext context) => GlassListSection(
    children: [
      GlassPicker<String>(
        style: widget.style,
        label: const Text('Period'),
        items: const [
          GlassPickerItem(value: 'd', label: 'Day'),
          GlassPickerItem(value: 'w', label: 'Week'),
          GlassPickerItem(value: 'm', label: 'Month'),
        ],
        selected: value,
        onChanged: widget.enabled
            ? (v) {
                widget.onChanged?.call(v);
                setState(() => value = v);
              }
            : null,
      ),
    ],
  );
}

/// The iOS checkmark's horizontal centre.
double _checkDx(WidgetTester t) =>
    t.getCenter(find.byIcon(CupertinoIcons.checkmark_alt)).dx;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('inline', () {
    testWidgets('rows with a blue checkmark on the choice; a tap picks', (
      t,
    ) async {
      shaderEnv();
      final picked = <String>[];
      await t.pumpWidget(
        appHost(
          _Harness(style: GlassPickerStyle.inline, onChanged: picked.add),
        ),
      );
      expect(find.byType(GlassListTile), findsNWidgets(3));
      final check = t.widget<Icon>(find.byIcon(CupertinoIcons.checkmark_alt));
      expect(check.color!.toARGB32(), GlassSystemColors.blue.color.toARGB32());
      // The checkmark sits on the Week row, at its end.
      expect(
        t.getCenter(find.byIcon(CupertinoIcons.checkmark_alt)).dy,
        moreOrLessEquals(t.getCenter(find.text('Week')).dy, epsilon: 1),
      );
      expect(_checkDx(t), greaterThan(t.getCenter(find.text('Week')).dx));
      await t.tap(find.text('Month'));
      await t.pumpAndSettle();
      expect(picked, ['m']);
      expect(
        t.getCenter(find.byIcon(CupertinoIcons.checkmark_alt)).dy,
        moreOrLessEquals(t.getCenter(find.text('Month')).dy, epsilon: 1),
      );
    }, variant: ios);

    testWidgets('Material: ListTiles with a check on the choice', (t) async {
      shaderEnv();
      final picked = <String>[];
      await t.pumpWidget(
        appHost(
          _Harness(style: GlassPickerStyle.inline, onChanged: picked.add),
        ),
      );
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        t.widget<ListTile>(find.widgetWithText(ListTile, 'Week')).selected,
        isTrue,
      );
      await t.tap(find.text('Day'));
      await t.pumpAndSettle();
      expect(picked, ['d']);
      expect(
        t.widget<ListTile>(find.widgetWithText(ListTile, 'Day')).selected,
        isTrue,
      );
    }, variant: android);

    testWidgets('semantics: selectable buttons, the choice selected', (
      t,
    ) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        appHost(const _Harness(style: GlassPickerStyle.inline)),
      );
      expect(
        t.getSemantics(find.text('Week')),
        isSemantics(
          isButton: true,
          isEnabled: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          label: 'Week',
        ),
      );
      expect(
        t.getSemantics(find.text('Day')),
        isSemantics(isButton: true, isSelected: false, label: 'Day'),
      );
      handle.dispose();
    }, variant: ios);

    testWidgets('RTL: the checkmark is at the row\'s end, on the left', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          const _Harness(style: GlassPickerStyle.inline),
          direction: TextDirection.rtl,
        ),
      );
      expect(_checkDx(t), lessThan(t.getCenter(find.text('Week')).dx));
    }, variant: ios);

    testWidgets('disabled: taps do nothing; rows read as disabled', (t) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      final picked = <String>[];
      await t.pumpWidget(
        appHost(
          _Harness(
            style: GlassPickerStyle.inline,
            enabled: false,
            onChanged: picked.add,
          ),
        ),
      );
      await t.tap(find.text('Month'));
      await t.pumpAndSettle();
      expect(picked, isEmpty);
      expect(
        t.getSemantics(find.text('Month')),
        isSemantics(isButton: true, isEnabled: false),
      );
      handle.dispose();
    }, variant: ios);
  });

  group('navigationLink', () {
    testWidgets('a row with label, value and chevron; pushes and pops', (
      t,
    ) async {
      shaderEnv();
      final picked = <String>[];
      await t.pumpWidget(
        appHost(
          _Harness(
            style: GlassPickerStyle.navigationLink,
            onChanged: picked.add,
          ),
        ),
      );
      expect(find.byType(GlassListTile), findsOneWidget);
      expect(find.text('Period'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.byType(ListChevron), findsOneWidget);
      expect(
        t.getCenter(find.byType(ListChevron)).dx,
        greaterThan(t.getCenter(find.text('Week')).dx),
      );
      await t.tap(find.text('Period'));
      await t.pumpAndSettle();
      expect(find.byType(PickerPage<String>), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
      await t.tap(find.text('Month'));
      await t.pumpAndSettle();
      expect(find.byType(PickerPage<String>), findsNothing);
      expect(picked, ['m']);
      expect(find.text('Month'), findsOneWidget);
    }, variant: ios);

    testWidgets('Material: a ListTile pushing a Material page', (t) async {
      shaderEnv();
      final picked = <String>[];
      await t.pumpWidget(
        appHost(
          _Harness(
            style: GlassPickerStyle.navigationLink,
            onChanged: picked.add,
          ),
        ),
      );
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await t.tap(find.text('Period'));
      await t.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
      await t.tap(find.text('Day'));
      await t.pumpAndSettle();
      expect(find.byType(PickerPage<String>), findsNothing);
      expect(picked, ['d']);
    }, variant: android);

    testWidgets('semantics: a button reading label and value', (t) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        appHost(const _Harness(style: GlassPickerStyle.navigationLink)),
      );
      expect(
        t.getSemantics(find.text('Period')),
        isSemantics(isButton: true, isEnabled: true, label: 'Period\nWeek'),
      );
      handle.dispose();
    }, variant: ios);

    testWidgets('RTL: the chevron is on the left of the value', (t) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          const _Harness(style: GlassPickerStyle.navigationLink),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        t.getCenter(find.byType(ListChevron)).dx,
        lessThan(t.getCenter(find.text('Week')).dx),
      );
      expect(
        t.getCenter(find.text('Week')).dx,
        lessThan(t.getCenter(find.text('Period')).dx),
      );
    }, variant: ios);

    testWidgets('disabled: nothing pushes', (t) async {
      shaderEnv();
      await t.pumpWidget(
        appHost(
          const _Harness(
            style: GlassPickerStyle.navigationLink,
            enabled: false,
          ),
        ),
      );
      await t.tap(find.text('Period'));
      await t.pumpAndSettle();
      expect(find.byType(PickerPage<String>), findsNothing);
    }, variant: ios);

    testWidgets('Reduce Motion: the page appears without a transition', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(
            body: _Harness(style: GlassPickerStyle.navigationLink),
          ),
        ),
      );
      await t.tap(find.text('Period'));
      await t.pump();
      await t.pump();
      expect(find.byType(PickerPage<String>), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    }, variant: ios);
  });
}
