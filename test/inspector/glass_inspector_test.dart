import 'package:adaptive_liquid_glass/src/inspector/glass_inspector.dart';
import 'package:adaptive_liquid_glass/src/inspector/inspector_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

class _Host extends StatefulWidget {
  const _Host({this.shown = false, this.direction = TextDirection.ltr});
  final bool shown;
  final TextDirection direction;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late bool shown = widget.shown;
  final changes = <bool>[];

  void set(bool value) => setState(() => shown = value);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Directionality(
      textDirection: widget.direction,
      child: GlassInspector(
        isPresented: shown,
        onPresentedChanged: (v) {
          changes.add(v);
          set(v);
        },
        inspector: (_) => const Text('Inspector'),
        child: const ColoredBox(color: Colors.white, child: Text('Main')),
      ),
    ),
  );
}

void _size(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
}

_HostState _host(WidgetTester t) => t.state(find.byType(_Host));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('regular width: a trailing column slides in and out', (t) async {
    shaderEnv();
    _size(t, const Size(1024, 768));
    addTearDown(t.view.reset);
    await t.pumpWidget(const _Host());
    expect(t.getSize(find.byType(AnimatedContainer)).width, 0);

    _host(t).set(true);
    await t.pumpAndSettle();
    expect(
      t.getSize(find.byType(AnimatedContainer)).width,
      InspectorMetrics.columnWidth,
    );
    expect(t.getTopLeft(find.text('Inspector')).dx, 1024 - 320);
    expect(t.getSize(find.text('Main').first).width, lessThanOrEqualTo(704));
    expect(find.byType(BottomSheet), findsNothing);

    _host(t).set(false);
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(AnimatedContainer)).width, 0);
  }, variant: ios);

  testWidgets('right-to-left puts the column on the left', (t) async {
    shaderEnv();
    _size(t, const Size(1024, 768));
    addTearDown(t.view.reset);
    await t.pumpWidget(const _Host(shown: true, direction: TextDirection.rtl));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byType(AnimatedContainer)).dx, 0);
  }, variant: ios);

  testWidgets('compact width: a sheet; swiping it away reports false', (
    t,
  ) async {
    shaderEnv();
    _size(t, const Size(390, 844));
    addTearDown(t.view.reset);
    await t.pumpWidget(const _Host());
    expect(find.text('Inspector'), findsNothing);

    _host(t).set(true);
    await t.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);

    // Swipe the sheet down and away.
    await t.fling(find.text('Inspector'), const Offset(0, 600), 2000);
    await t.pumpAndSettle();
    expect(find.text('Inspector'), findsNothing);
    expect(_host(t).changes, [false]);
    expect(_host(t).shown, isFalse);
  }, variant: ios);

  testWidgets('compact width: isPresented false closes the sheet', (t) async {
    shaderEnv();
    _size(t, const Size(390, 844));
    addTearDown(t.view.reset);
    await t.pumpWidget(const _Host(shown: true));
    await t.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);

    _host(t).set(false);
    await t.pumpAndSettle();
    expect(find.text('Inspector'), findsNothing);
    expect(_host(t).changes, isEmpty);
  }, variant: ios);

  testWidgets('resizing moves an open inspector between sheet and column', (
    t,
  ) async {
    shaderEnv();
    _size(t, const Size(390, 844));
    addTearDown(t.view.reset);
    await t.pumpWidget(const _Host(shown: true));
    await t.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);

    _size(t, const Size(1024, 768));
    await t.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);
    expect(
      t.getSize(find.byType(AnimatedContainer)).width,
      InspectorMetrics.columnWidth,
    );
    expect(_host(t).changes, isEmpty);

    _size(t, const Size(390, 844));
    await t.pumpAndSettle();
    expect(find.text('Inspector'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  }, variant: ios);

  testWidgets('Material: the column is a Material surface', (t) async {
    _size(t, const Size(1024, 768));
    addTearDown(t.view.reset);
    await t.pumpWidget(const _Host(shown: true));
    await t.pumpAndSettle();
    final box = t.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Inspector'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final context = t.element(find.text('Inspector'));
    expect(
      (box.decoration as BoxDecoration).color,
      Theme.of(context).colorScheme.surfaceContainerLow,
    );
  }, variant: android);
}
