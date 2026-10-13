import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/controls/control_metrics.dart';
import 'package:adaptive_liquid_glass/src/controls/glass_thumb.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.divisions, this.axis = Axis.horizontal});

  final int? divisions;

  final Axis axis;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  double value = 0.5;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.axis == Axis.horizontal ? 300 : null,
    height: widget.axis == Axis.vertical ? 300 : null,
    child: GlassSlider(
      value: value,
      divisions: widget.divisions,
      axis: widget.axis,
      onChanged: (v) => setState(() => value = v),
    ),
  );
}

double _value(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness)).value;

Finder get _lens =>
    find.byWidgetPredicate((w) => w is LiquidGlass && w.glass == Glass.clear);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('the thumb sits at the value', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final slider = t.getRect(find.byType(GlassSlider));
    expect(
      t.getCenter(find.byType(GlassThumb)).dx,
      moreOrLessEquals(slider.center.dx),
    );
  }, variant: ios);

  testWidgets('dragging moves the value and shows the lens', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final g = await t.startGesture(t.getCenter(find.byType(GlassThumb)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_lens, findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(20, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_value(t), greaterThan(0.9));
    await g.up();
    await t.pumpAndSettle();
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('right to left: dragging left raises the value', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const _Harness(), direction: TextDirection.rtl),
    );
    await t.drag(find.byType(GlassThumb), const Offset(-80, 0));
    await t.pumpAndSettle();
    expect(_value(t), greaterThan(0.6));
  }, variant: ios);

  testWidgets('divisions snap the value', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(divisions: 4)));
    await t.drag(find.byType(GlassThumb), const Offset(50, 0));
    await t.pumpAndSettle();
    expect(_value(t) * 4, moreOrLessEquals((_value(t) * 4).roundToDouble()));
  }, variant: ios);

  testWidgets('assistive tech can raise and lower it', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(const _Harness()));
    final node = t.getSemantics(find.byType(GlassSlider));
    expect(node.value, '50%');
    expect(node.increasedValue, '60%');
    t.semantics.performAction(
      find.semantics.byValue('50%'),
      SemanticsAction.increase,
    );
    await t.pump();
    expect(_value(t), moreOrLessEquals(0.6));
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a Material 3 slider', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(Slider), findsOneWidget);
  }, variant: android);

  testWidgets('vertical: the thumb sits at the value, min at the bottom', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(axis: Axis.vertical)));
    final slider = t.getRect(find.byType(GlassSlider));
    expect(slider.width, ControlMetrics.sliderHeight);
    expect(slider.height, 300);
    final thumb = t.getRect(find.byType(GlassThumb));
    expect(thumb.center.dy, moreOrLessEquals(slider.center.dy));
    expect(thumb.height, ControlMetrics.sliderThumbWidth);
    expect(thumb.width, ControlMetrics.sliderThumbHeight);
  }, variant: ios);

  testWidgets('vertical: dragging up raises the value, down lowers it', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(axis: Axis.vertical)));
    final g = await t.startGesture(t.getCenter(find.byType(GlassThumb)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_lens, findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, -20));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_value(t), greaterThan(0.9));
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(0, 20));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_value(t), 0);
    await g.up();
    await t.pumpAndSettle();
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('vertical: a tap near the bottom jumps low', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(axis: Axis.vertical)));
    final slider = t.getRect(find.byType(GlassSlider));
    await t.tapAt(slider.bottomCenter - const Offset(0, 40));
    await t.pumpAndSettle();
    expect(_value(t), lessThan(0.15));
  }, variant: ios);

  testWidgets('vertical: divisions snap and increase moves up', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(const _Harness(axis: Axis.vertical, divisions: 4)),
    );
    await t.drag(find.byType(GlassThumb), const Offset(0, -60));
    await t.pumpAndSettle();
    expect(_value(t), 0.75);
    t.semantics.performAction(
      find.semantics.byValue('75%'),
      SemanticsAction.increase,
    );
    await t.pumpAndSettle();
    expect(_value(t), 1);
    final thumb = t.getCenter(find.byType(GlassThumb));
    expect(thumb.dy, lessThan(t.getCenter(find.byType(GlassSlider)).dy));
    s.dispose();
  }, variant: ios);

  testWidgets('Material vertical: a turned Material 3 slider', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness(axis: Axis.vertical)));
    expect(find.byType(Slider), findsOneWidget);
    expect(
      find.ancestor(of: find.byType(Slider), matching: find.byType(RotatedBox)),
      findsOneWidget,
    );
    final rect = t.getRect(find.byType(GlassSlider));
    expect(rect.height, greaterThan(rect.width));
  }, variant: android);
}
