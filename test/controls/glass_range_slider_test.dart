import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/controls/control_metrics.dart';
import 'package:adaptive_liquid_glass/src/controls/glass_thumb.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness({
    this.values = const RangeValues(0.2, 0.8),
    this.divisions,
    this.axis = Axis.horizontal,
  });

  final RangeValues values;

  final int? divisions;

  final Axis axis;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late RangeValues values = widget.values;
  final List<RangeValues> ends = [];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.axis == Axis.horizontal ? 300 : null,
    height: widget.axis == Axis.vertical ? 300 : null,
    child: GlassRangeSlider(
      values: values,
      divisions: widget.divisions,
      axis: widget.axis,
      onChanged: (v) => setState(() => values = v),
      onChangeEnd: ends.add,
    ),
  );
}

RangeValues _values(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness)).values;

Finder get _thumbs => find.byType(GlassThumb);

Finder get _lens =>
    find.byWidgetPredicate((w) => w is LiquidGlass && w.glass == Glass.clear);

Future<void> _dragFrom(WidgetTester t, Offset from, Offset by) async {
  final g = await t.startGesture(from);
  await t.pump();
  for (var i = 0; i < 10; i++) {
    await g.moveBy(by / 10);
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await t.pumpAndSettle();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('the thumbs sit at the values, filled between them', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final slider = t.getRect(find.byType(GlassRangeSlider));
    const travel = 300 - ControlMetrics.sliderThumbWidth;
    const half = ControlMetrics.sliderThumbWidth / 2;
    expect(_thumbs, findsNWidgets(2));
    expect(
      t.getCenter(_thumbs.at(0)).dx,
      moreOrLessEquals(slider.left + half + 0.2 * travel),
    );
    expect(
      t.getCenter(_thumbs.at(1)).dx,
      moreOrLessEquals(slider.left + half + 0.8 * travel),
    );
    final bars = find.descendant(
      of: find.byType(GlassRangeSlider),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is ShapeDecoration &&
            (w.decoration as ShapeDecoration).color?.toARGB32() ==
                GlassColors.sliderFill.color.toARGB32(),
      ),
    );
    final bar = t.getRect(bars);
    expect(bar.width, moreOrLessEquals(0.6 * travel));
    expect(bar.left, moreOrLessEquals(slider.left + half + 0.2 * travel));
  }, variant: ios);

  testWidgets('dragging a thumb moves only its end, with a lens', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final g = await t.startGesture(t.getCenter(_thumbs.at(0)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_lens, findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(15, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_values(t).start, greaterThan(0.35));
    expect(_values(t).end, 0.8);
    await g.up();
    await t.pumpAndSettle();
    expect(_lens, findsNothing);
    final ends = t.state<_HarnessState>(find.byType(_Harness)).ends;
    expect(ends.single, _values(t));

    await _dragFrom(t, t.getCenter(_thumbs.at(1)), const Offset(40, 0));
    expect(_values(t).end, greaterThan(0.9));
  }, variant: ios);

  testWidgets('the thumbs never cross', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    await _dragFrom(t, t.getCenter(_thumbs.at(0)), const Offset(250, 0));
    expect(_values(t), const RangeValues(0.8, 0.8));
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      plainHost(const _Harness(values: RangeValues(0.3, 0.6))),
    );
    await _dragFrom(t, t.getCenter(_thumbs.at(1)), const Offset(-250, 0));
    expect(_values(t).end, _values(t).start);
    expect(_values(t).start, 0.3);
  }, variant: ios);

  testWidgets('a tap moves the nearest thumb', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final slider = t.getRect(find.byType(GlassRangeSlider));
    const travel = 300 - ControlMetrics.sliderThumbWidth;
    const half = ControlMetrics.sliderThumbWidth / 2;
    await t.tapAt(Offset(slider.left + half + 0.65 * travel, slider.center.dy));
    await t.pumpAndSettle();
    expect(_values(t).start, 0.2);
    expect(_values(t).end, moreOrLessEquals(0.65, epsilon: 0.01));
    await t.tapAt(Offset(slider.left + half + 0.05 * travel, slider.center.dy));
    await t.pumpAndSettle();
    expect(_values(t).start, moreOrLessEquals(0.05, epsilon: 0.01));
  }, variant: ios);

  testWidgets('overlapping thumbs: the drag direction picks', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const _Harness(values: RangeValues(0.5, 0.5))),
    );
    await _dragFrom(t, t.getCenter(_thumbs.at(0)), const Offset(50, 0));
    expect(_values(t).start, 0.5);
    expect(_values(t).end, greaterThan(0.6));
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      plainHost(const _Harness(values: RangeValues(0.5, 0.5))),
    );
    await _dragFrom(t, t.getCenter(_thumbs.at(1)), const Offset(-50, 0));
    expect(_values(t).end, 0.5);
    expect(_values(t).start, lessThan(0.4));
  }, variant: ios);

  testWidgets('right to left: dragging left raises the end', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const _Harness(), direction: TextDirection.rtl),
    );
    expect(
      t.getCenter(_thumbs.at(1)).dx,
      lessThan(t.getCenter(_thumbs.at(0)).dx),
    );
    await _dragFrom(t, t.getCenter(_thumbs.at(1)), const Offset(-40, 0));
    expect(_values(t).end, greaterThan(0.9));
  }, variant: ios);

  testWidgets('divisions snap both thumbs', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(divisions: 10)));
    await _dragFrom(t, t.getCenter(_thumbs.at(0)), const Offset(33, 0));
    await _dragFrom(t, t.getCenter(_thumbs.at(1)), const Offset(-47, 0));
    final v = _values(t);
    expect(v.start * 10, moreOrLessEquals((v.start * 10).roundToDouble()));
    expect(v.end * 10, moreOrLessEquals((v.end * 10).roundToDouble()));
    expect(v.start, greaterThan(0.2));
    expect(v.end, lessThan(0.8));
  }, variant: ios);

  testWidgets('vertical: min at the bottom, dragging up raises', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(axis: Axis.vertical)));
    final slider = t.getRect(find.byType(GlassRangeSlider));
    expect(slider.width, ControlMetrics.sliderHeight);
    expect(
      t.getCenter(_thumbs.at(0)).dy,
      greaterThan(t.getCenter(_thumbs.at(1)).dy),
    );
    await _dragFrom(t, t.getCenter(_thumbs.at(1)), const Offset(0, -40));
    expect(_values(t).end, greaterThan(0.9));
    await _dragFrom(t, t.getCenter(_thumbs.at(0)), const Offset(0, 40));
    expect(_values(t).start, lessThan(0.1));
    await _dragFrom(t, t.getCenter(_thumbs.at(0)), const Offset(0, -400));
    expect(_values(t).start, _values(t).end);
  }, variant: ios);

  testWidgets('each thumb is its own slider for assistive tech', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(const _Harness()));
    final low = t.getSemantics(_thumbs.at(0));
    final high = t.getSemantics(_thumbs.at(1));
    expect(low.id, isNot(high.id));
    expect(low.value, '20%');
    expect(low.increasedValue, '30%');
    expect(high.value, '80%');
    expect(high.decreasedValue, '70%');
    t.semantics.performAction(
      find.semantics.byValue('20%'),
      SemanticsAction.increase,
    );
    await t.pump();
    expect(_values(t).start, moreOrLessEquals(0.3));
    t.semantics.performAction(
      find.semantics.byValue('80%'),
      SemanticsAction.increase,
    );
    await t.pump();
    expect(_values(t).end, moreOrLessEquals(0.9));
    s.dispose();
  }, variant: ios);

  testWidgets('assistive tech cannot push a thumb past the other', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(const _Harness(values: RangeValues(0.5, 0.5))),
    );
    expect(t.getSemantics(_thumbs.at(0)).increasedValue, '50%');
    expect(t.getSemantics(_thumbs.at(1)).decreasedValue, '50%');
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a Material 3 range slider', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(RangeSlider), findsOneWidget);
    await t.pumpWidget(appHost(const _Harness(axis: Axis.vertical)));
    expect(
      find.ancestor(
        of: find.byType(RangeSlider),
        matching: find.byType(RotatedBox),
      ),
      findsOneWidget,
    );
    final rect = t.getRect(find.byType(GlassRangeSlider));
    expect(rect.height, greaterThan(rect.width));
  }, variant: android);
}
