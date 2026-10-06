import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/progress/progress_metrics.dart';
import 'package:adaptive_liquid_glass/src/progress/progress_ring_painter.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Harness extends StatefulWidget {
  const _Harness({this.value, this.circular = false, this.semanticLabel});

  final double? value;

  final bool circular;

  final String? semanticLabel;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  double? value = 0.5;

  @override
  void initState() {
    super.initState();
    value = widget.value;
  }

  void set(double? v) => setState(() => value = v);

  @override
  Widget build(BuildContext context) => widget.circular
      ? GlassProgressIndicator.circular(
          value: value,
          semanticLabel: widget.semanticLabel,
        )
      : GlassProgressIndicator(
          value: value,
          semanticLabel: widget.semanticLabel,
        );
}

Widget _bar(double? value) =>
    SizedBox(width: 200, child: _Harness(value: value));

Finder get _fill => find.descendant(
  of: find.byType(FractionallySizedBox),
  matching: find.byType(DecoratedBox),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a determinate bar: a glass track 6 tall, fill half of it', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_bar(0.5)));
    await t.pumpAndSettle();
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(t.getSize(find.byType(LiquidGlass)), const Size(200, 6));
    expect(t.getSize(_fill).width, moreOrLessEquals((200 - 2) * 0.5));
    expect(t.getSize(_fill).height, moreOrLessEquals(6 - 2));
  }, variant: ios);

  testWidgets('a new value eases in; Reduce Motion jumps', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_bar(0.5)));
    await t.pumpAndSettle();
    final state = t.state<_HarnessState>(find.byType(_Harness));
    state.set(1);
    await t.pump();
    await t.pump(const Duration(milliseconds: 125));
    // Halfway between (200 - 2) * 0.5 and (200 - 2).
    final mid = t.getSize(_fill).width;
    expect(mid, greaterThan(110));
    expect(mid, lessThan(186));
    await t.pumpAndSettle();
    expect(t.getSize(_fill).width, moreOrLessEquals(200 - 2));
  }, variant: ios);

  testWidgets('Reduce Motion: the fill jumps to the new value', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _bar(0.5),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    t.state<_HarnessState>(find.byType(_Harness)).set(1);
    await t.pump();
    await t.pump();
    expect(t.getSize(_fill).width, moreOrLessEquals(200 - 2));
  }, variant: ios);

  testWidgets('an indeterminate bar slides its segment', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_bar(null)));
    await t.pump();
    final before = t.getTopLeft(_fill).dx;
    await t.pump(const Duration(milliseconds: 100));
    final after = t.getTopLeft(_fill).dx;
    expect(after, greaterThan(before));
  }, variant: ios);

  testWidgets('Reduce Motion: the indeterminate segment stays put', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _bar(null),
          ),
        ),
      ),
    );
    await t.pump();
    final before = t.getTopLeft(_fill).dx;
    await t.pump(const Duration(milliseconds: 100));
    final after = t.getTopLeft(_fill).dx;
    expect(after, moreOrLessEquals(before));
  }, variant: ios);

  testWidgets('right to left: the fill grows from the right edge', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_bar(0.5), direction: TextDirection.rtl));
    await t.pumpAndSettle();
    final trackRight = t.getTopRight(find.byType(LiquidGlass)).dx;
    expect(
      t.getTopRight(_fill).dx,
      moreOrLessEquals(trackRight - 1, epsilon: 0.1),
    );
  }, variant: ios);

  testWidgets('a determinate ring: a 20 x 20 painted arc', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(value: 0.5, circular: true)));
    await t.pumpAndSettle();
    final paint = find.descendant(
      of: find.byType(GlassProgressIndicator),
      matching: find.byType(CustomPaint),
    );
    expect(t.getSize(paint), const Size(20, 20));
    final painter = t.widget<CustomPaint>(paint).painter;
    expect(painter, isA<ProgressRingPainter>());
    expect((painter as ProgressRingPainter).value, moreOrLessEquals(0.5));
  }, variant: ios);

  testWidgets("an indeterminate ring: iOS's activity spinner", (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness(circular: true)));
    await t.pump();
    final spinner = t.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(spinner.radius, moreOrLessEquals(ProgressMetrics.circularSize / 2));
  }, variant: ios);

  testWidgets('the label and the percentage for assistive tech', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(const _Harness(value: 0.5, semanticLabel: 'Downloading')),
    );
    await t.pumpAndSettle();
    expect(
      t.getSemantics(find.byType(GlassProgressIndicator)),
      matchesSemantics(label: 'Downloading', value: '50%'),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('Material: progress indicators', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness(value: 0.5)));
    await t.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await t.pumpWidget(appHost(const _Harness(value: 0.5, circular: true)));
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }, variant: android);
}
