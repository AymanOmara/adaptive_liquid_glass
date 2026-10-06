import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/text_field/text_field_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a glass field with a placeholder', (t) async {
    shaderEnv();
    final changes = <String>[];
    await t.pumpWidget(
      _app(GlassTextField(placeholder: 'Email', onChanged: changes.add)),
    );
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    await t.enterText(find.byType(CupertinoTextField), 'glass');
    await t.pump();
    expect(changes.last, 'glass');
  }, variant: ios);

  testWidgets('the clear button clears and reports empty', (t) async {
    shaderEnv();
    final changes = <String>[];
    await t.pumpWidget(
      _app(GlassTextField(clearButton: true, onChanged: changes.add)),
    );
    expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
    await t.enterText(find.byType(CupertinoTextField), 'glass');
    await t.pump();
    expect(changes.last, 'glass');
    await t.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await t.pump();
    expect(changes.last, '');
    expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
  }, variant: ios);

  testWidgets('no clear button without clearButton', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(const GlassTextField()));
    await t.enterText(find.byType(CupertinoTextField), 'glass');
    await t.pump();
    expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
  }, variant: ios);

  testWidgets('errorText is shown; null hides it', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(const GlassTextField(errorText: 'Required')));
    expect(find.text('Required'), findsOneWidget);
    await t.pumpWidget(_app(const GlassTextField()));
    expect(find.text('Required'), findsNothing);
  }, variant: ios);

  testWidgets('single-line capsule, multi-line rect, fixed height', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(const GlassTextField()));
    expect(
      t.widget<LiquidGlass>(find.byType(LiquidGlass)).shape,
      const GlassShape.capsule(),
    );
    expect(
      t.getSize(find.byType(GlassTextField)).height,
      TextFieldMetrics.height,
    );
    await t.pumpWidget(_app(const GlassTextField(maxLines: 3)));
    expect(
      t.widget<LiquidGlass>(find.byType(LiquidGlass)).shape,
      const GlassShape.rect(TextFieldMetrics.multiLineRadius),
    );
    expect(
      t.getSize(find.byType(GlassTextField)).height,
      greaterThanOrEqualTo(TextFieldMetrics.height),
    );
  }, variant: ios);

  testWidgets('password: the eye button reveals the text', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(_app(const GlassTextField.password()));
    expect(
      t.widget<CupertinoTextField>(find.byType(CupertinoTextField)).obscureText,
      isTrue,
    );
    await t.tap(find.bySemanticsLabel('Show password'));
    await t.pump();
    expect(
      t.widget<CupertinoTextField>(find.byType(CupertinoTextField)).obscureText,
      isFalse,
    );
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    handle.dispose();
  }, variant: ios);

  testWidgets('disabled: the field is off and faded', (t) async {
    shaderEnv();
    final controller = TextEditingController(text: 'typed');
    addTearDown(controller.dispose);
    await t.pumpWidget(
      _app(
        GlassTextField(
          controller: controller,
          clearButton: true,
          enabled: false,
        ),
      ),
    );
    expect(
      t.widget<CupertinoTextField>(find.byType(CupertinoTextField)).enabled,
      isFalse,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == TextFieldMetrics.disabledOpacity,
      ),
      findsOneWidget,
    );
    expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
  }, variant: ios);

  testWidgets('semanticLabel labels the field', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(_app(const GlassTextField(semanticLabel: 'Email')));
    expect(find.bySemanticsLabel('Email'), findsOneWidget);
    expect(
      t
          .getSemantics(find.bySemanticsLabel('Email'))
          .flagsCollection
          .isTextField,
      isTrue,
    );
    handle.dispose();
  }, variant: ios);

  testWidgets('RTL: the prefix sits at the start', (t) async {
    shaderEnv();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                width: 300,
                child: GlassTextField(prefix: Icon(CupertinoIcons.person)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      t.getCenter(find.byIcon(CupertinoIcons.person)).dx,
      greaterThan(t.getCenter(find.byType(CupertinoTextField)).dx),
    );
  }, variant: ios);

  testWidgets('Material: a filled TextField with the error', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(const GlassTextField(errorText: 'Required')));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  }, variant: android);

  testWidgets('Material: the password eye toggles', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(const GlassTextField.password()));
    expect(t.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await t.tap(find.byIcon(Icons.visibility));
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  }, variant: android);
}
