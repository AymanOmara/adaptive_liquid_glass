import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/controls/glass_thumb.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.enabled = true});

  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool value = false;

  @override
  Widget build(BuildContext context) => GlassToggle(
    value: value,
    onChanged: widget.enabled ? (v) => setState(() => value = v) : null,
  );
}

bool _value(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness)).value;

Finder get _lens =>
    find.byWidgetPredicate((w) => w is LiquidGlass && w.glass == Glass.clear);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('tapping flips it and moves the thumb', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final before = t.getCenter(find.byType(GlassThumb)).dx;
    await t.tap(find.byType(GlassToggle));
    await t.pumpAndSettle();
    expect(_value(t), isTrue);
    expect(t.getCenter(find.byType(GlassThumb)).dx, greaterThan(before + 20));
  }, variant: ios);

  testWidgets('the thumb is a glass lens only while held', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    expect(_lens, findsNothing);
    final g = await t.startGesture(t.getCenter(find.byType(GlassToggle)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_lens, findsOneWidget);
    await g.up();
    await t.pumpAndSettle();
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('dragging the thumb across turns it on', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final thumb = t.getCenter(find.byType(GlassThumb));
    await t.dragFrom(thumb, const Offset(40, 0));
    await t.pumpAndSettle();
    expect(_value(t), isTrue);
  }, variant: ios);

  testWidgets('right to left: on is to the left', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const _Harness(), direction: TextDirection.rtl),
    );
    final before = t.getCenter(find.byType(GlassThumb)).dx;
    await t.tap(find.byType(GlassToggle));
    await t.pumpAndSettle();
    expect(t.getCenter(find.byType(GlassThumb)).dx, lessThan(before - 20));
  }, variant: ios);

  testWidgets('a toggled switch for assistive tech; disabled ignores taps', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(const _Harness()));
    expect(
      t.getSemantics(find.byType(GlassToggle)),
      matchesSemantics(
        hasToggledState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    await t.pumpWidget(plainHost(const _Harness(enabled: false)));
    await t.tap(find.byType(GlassToggle));
    await t.pumpAndSettle();
    expect(_value(t), isFalse);
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a Material 3 switch', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(Switch), findsOneWidget);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(_value(t), isTrue);
  }, variant: android);

  testWidgets('on a glass card the lens keeps its own group', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const LiquidGlass(padding: EdgeInsets.all(16), child: _Harness()),
      ),
    );
    final g = await t.startGesture(t.getCenter(find.byType(GlassToggle)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    final groups = find.ancestor(of: _lens, matching: find.byType(GlassGroup));
    expect(groups, findsNWidgets(2));
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('a rejected tap springs the thumb back', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassToggle(value: false, onChanged: (_) {})));
    final start = t.getCenter(find.byType(GlassThumb)).dx;
    await t.tap(find.byType(GlassToggle));
    await t.pumpAndSettle();
    expect(t.getCenter(find.byType(GlassThumb)).dx, closeTo(start, 0.5));
  }, variant: ios);

  testWidgets('a rejected drag springs the thumb back', (t) async {
    shaderEnv();
    final calls = <bool>[];
    await t.pumpWidget(
      plainHost(GlassToggle(value: false, onChanged: calls.add)),
    );
    final start = t.getCenter(find.byType(GlassThumb)).dx;
    await t.drag(find.byType(GlassToggle), const Offset(60, 0));
    await t.pumpAndSettle();
    expect(t.getCenter(find.byType(GlassThumb)).dx, closeTo(start, 0.5));
    expect(calls, [true]);
  }, variant: ios);

  testWidgets('an external change mid-drag wins', (t) async {
    shaderEnv();
    final notifier = ValueNotifier<bool>(false);
    addTearDown(notifier.dispose);
    final calls = <bool>[];
    await t.pumpWidget(
      plainHost(
        ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (context, value, _) =>
              GlassToggle(value: value, onChanged: calls.add),
        ),
      ),
    );
    final start = t.getCenter(find.byType(GlassThumb)).dx;
    final g = await t.startGesture(t.getCenter(find.byType(GlassToggle)));
    await t.pump();
    for (var i = 0; i < 3; i++) {
      await g.moveBy(const Offset(10, 0));
      await t.pump();
    }
    notifier.value = true;
    await t.pump();
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(-10, 0));
      await t.pump();
    }
    await g.up();
    await t.pumpAndSettle();
    expect(t.getCenter(find.byType(GlassThumb)).dx, greaterThan(start + 15));
    expect(calls, isNot(contains(false)));
  }, variant: ios);

  testWidgets('an accepted drag lands on the new value', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final start = t.getCenter(find.byType(GlassThumb)).dx;
    await t.drag(find.byType(GlassToggle), const Offset(60, 0));
    await t.pumpAndSettle();
    expect(_value(t), isTrue);
    expect(t.getCenter(find.byType(GlassThumb)).dx, greaterThan(start + 15));
  }, variant: ios);
}
