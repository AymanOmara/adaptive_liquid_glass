import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/text_field/text_field_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(Widget child, {bool resize = true}) => MaterialApp(
  home: Scaffold(
    resizeToAvoidBottomInset: resize,
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [child]),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a glass rounded rect that edits multi-line text', (t) async {
    shaderEnv();
    final changes = <String>[];
    await t.pumpWidget(
      _app(GlassTextEditor(placeholder: 'Notes', onChanged: changes.add)),
    );
    expect(
      t.widget<LiquidGlass>(find.byType(LiquidGlass)).shape,
      const GlassShape.rect(TextFieldMetrics.multiLineRadius),
    );
    expect(find.text('Notes'), findsOneWidget);
    await t.enterText(find.byType(CupertinoTextField), 'one\ntwo');
    await t.pump();
    expect(changes.last, 'one\ntwo');
    expect(find.byType(RawScrollbar), findsOneWidget);
  }, variant: ios);

  testWidgets('default height when unbounded; height overrides', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(const GlassTextEditor()));
    expect(
      t.getSize(find.byType(GlassTextEditor)).height,
      TextFieldMetrics.editorHeight,
    );
    await t.pumpWidget(_app(const GlassTextEditor(height: 120)));
    expect(t.getSize(find.byType(GlassTextEditor)).height, 120);
  }, variant: ios);

  testWidgets('fills a bounded parent', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(const SizedBox(height: 300, child: GlassTextEditor())),
    );
    expect(t.getSize(find.byType(GlassTextEditor)).height, 300);
  }, variant: ios);

  testWidgets('long text scrolls inside the editor', (t) async {
    shaderEnv();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final text = TextEditingController(
      text: List.generate(60, (i) => 'line $i').join('\n'),
    );
    addTearDown(text.dispose);
    await t.pumpWidget(
      _app(GlassTextEditor(controller: text, scrollController: scroll)),
    );
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(
      t.getSize(find.byType(GlassTextEditor)).height,
      TextFieldMetrics.editorHeight,
    );
  }, variant: ios);

  testWidgets('hidden scroll indicators draw no bar', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        const GlassTextEditor(
          scrollIndicators: GlassScrollIndicatorVisibility.hidden,
        ),
      ),
    );
    expect(find.byType(RawScrollbar), findsNothing);
  }, variant: ios);

  testWidgets('disabled dims and blocks editing', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(const GlassTextEditor(enabled: false)));
    expect(
      t
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byType(LiquidGlass),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      TextFieldMetrics.disabledOpacity,
    );
    expect(
      t.widget<CupertinoTextField>(find.byType(CupertinoTextField)).enabled,
      isFalse,
    );
  }, variant: ios);

  testWidgets('the keyboard covering the editor pads its bottom', (t) async {
    shaderEnv();
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // As a sheet or scroll view that does not shrink for the keyboard.
    await t.pumpWidget(_app(const GlassTextEditor(), resize: false));
    // Editor spans y 20..220; a 650 keyboard covers from y 150.
    t.view.viewInsets = const FakeViewPadding(bottom: 650);
    await t.pump();
    await t.pump();
    final pad = t.widget<Padding>(
      find
          .ancestor(
            of: find.byType(GlassScrollIndicators),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect((pad.padding as EdgeInsets).bottom, closeTo(70, 0.5));
    t.view.viewInsets = FakeViewPadding.zero;
    await t.pump();
    await t.pump();
    final cleared = t.widget<Padding>(
      find
          .ancestor(
            of: find.byType(GlassScrollIndicators),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect((cleared.padding as EdgeInsets).bottom, 0);
  }, variant: ios);

  testWidgets('Material path: a filled TextField, no glass', (t) async {
    await t.pumpWidget(
      _app(
        const GlassTextEditor(
          placeholder: 'Notes',
          mode: GlassRenderMode.material,
        ),
      ),
    );
    expect(find.byType(LiquidGlass), findsNothing);
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.expands, isTrue);
    expect(field.decoration!.filled, isTrue);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
  }, variant: android);
}
