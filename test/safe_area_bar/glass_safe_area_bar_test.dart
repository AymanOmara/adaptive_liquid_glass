import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/safe_area_bar/glass_safe_area_bar.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

EdgeInsets? _seen;

void _size(WidgetTester t) {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _host(
  GlassSafeAreaEdge edge, {
  TextDirection direction = TextDirection.ltr,
  double alignment = 0,
  Widget? child,
}) => MediaQuery(
  data: const MediaQueryData(
    size: Size(400, 800),
    padding: EdgeInsets.only(top: 50, bottom: 30),
  ),
  child: Directionality(
    textDirection: direction,
    child: GlassSafeAreaBar(
      edge: edge,
      alignment: alignment,
      bar: const SizedBox(key: Key('bar'), width: 60, height: 44),
      child:
          child ??
          Builder(
            builder: (context) {
              _seen = MediaQuery.paddingOf(context);
              return const SizedBox.expand();
            },
          ),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('top bar sits at the safe top and insets the content', (t) async {
    shaderEnv();
    _size(t);
    await t.pumpWidget(_host(GlassSafeAreaEdge.top));
    await t.pump();
    expect(t.getRect(find.byKey(const Key('bar'))).top, 50);
    expect(_seen!.top, 94);
    expect(_seen!.bottom, 30);
  }, variant: ios);

  testWidgets('bottom bar sits above the safe bottom', (t) async {
    shaderEnv();
    _size(t);
    await t.pumpWidget(_host(GlassSafeAreaEdge.bottom));
    await t.pump();
    expect(t.getRect(find.byKey(const Key('bar'))).bottom, 770);
    expect(_seen!.bottom, 74);
  }, variant: ios);

  testWidgets('start follows the reading direction', (t) async {
    shaderEnv();
    _size(t);
    await t.pumpWidget(_host(GlassSafeAreaEdge.start));
    await t.pump();
    expect(t.getRect(find.byKey(const Key('bar'))).left, 0);
    expect(_seen!.left, 60);

    await t.pumpWidget(
      _host(GlassSafeAreaEdge.start, direction: TextDirection.rtl),
    );
    await t.pump();
    expect(t.getRect(find.byKey(const Key('bar'))).right, 400);
    expect(_seen!.right, 60);
    expect(_seen!.left, 0);
  }, variant: ios);

  testWidgets('alignment places the bar along its edge', (t) async {
    shaderEnv();
    _size(t);
    await t.pumpWidget(_host(GlassSafeAreaEdge.bottom, alignment: -1));
    await t.pump();
    expect(t.getRect(find.byKey(const Key('bar'))).left, 0);
    await t.pumpWidget(_host(GlassSafeAreaEdge.bottom, alignment: 1));
    await t.pump();
    expect(t.getRect(find.byKey(const Key('bar'))).right, 400);
  }, variant: ios);

  testWidgets('content scrolls under the bar', (t) async {
    shaderEnv();
    _size(t);
    await t.pumpWidget(
      _host(
        GlassSafeAreaEdge.top,
        child: ListView(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 50, child: Text('$i')),
          ],
        ),
      ),
    );
    await t.pump();
    // The list starts below the bar.
    expect(t.getTopLeft(find.text('0')).dy, greaterThanOrEqualTo(94));
    await t.drag(find.byType(ListView), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }, variant: ios);
}
