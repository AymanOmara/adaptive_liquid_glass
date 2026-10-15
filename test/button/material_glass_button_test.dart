import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/material_glass_button.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('glass → tonal, prominent → filled, cancel → text button', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        Column(
          children: [
            GlassButton(onPressed: () {}, child: const Text('A')),
            GlassButton(
              onPressed: () {},
              style: GlassButtonStyle.glassProminent,
              child: const Text('B'),
            ),
            GlassButton(
              onPressed: () {},
              role: GlassButtonRole.cancel,
              child: const Text('C'),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.widgetWithText(FilledButton, 'A'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'B'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'C'), findsOneWidget);
  }, variant: android);

  testWidgets('icon-only → IconButton sized by control size', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        GlassButton.icon(
          onPressed: () {},
          icon: CupertinoIcons.add,
          size: GlassControlSize.large,
        ),
      ),
    );
    expect(find.byType(IconButton), findsOneWidget);
    expect(
      t.getSize(find.byType(IconButton)).height,
      materialButtonHeights[GlassControlSize.large],
    );
  }, variant: android);

  testWidgets('label buttons take the size height', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        GlassButton(
          onPressed: () {},
          size: GlassControlSize.extraLarge,
          child: const Text('A'),
        ),
      ),
    );
    expect(
      t.getSize(find.byType(FilledButton)).height,
      materialButtonHeights[GlassControlSize.extraLarge],
    );
  }, variant: android);

  testWidgets('destructive prominent uses the error colour', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        GlassButton(
          onPressed: () {},
          role: GlassButtonRole.destructive,
          style: GlassButtonStyle.glassProminent,
          child: const Text('Delete'),
        ),
      ),
    );
    final scheme = Theme.of(t.element(find.text('Delete'))).colorScheme;
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.backgroundColor!.resolve({}), scheme.error);
  }, variant: android);

  testWidgets('prominent tint becomes the fill', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.glassProminent,
          tint: const Color(0xFF00AA00),
          child: const Text('Go'),
        ),
      ),
    );
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF00AA00));
  }, variant: android);

  testWidgets('loading: progress indicator, taps ignored, same size', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    Widget b(bool loading) => appHost(
      GlassButton(
        onPressed: () => taps++,
        loading: loading,
        child: const Text('Save'),
      ),
    );
    await t.pumpWidget(b(false));
    final size = t.getSize(find.byType(FilledButton));
    await t.pumpWidget(b(true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(t.getSize(find.byType(FilledButton)), size);
  }, variant: android);

  testWidgets('disabled: onPressed null', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const GlassButton(onPressed: null, child: Text('A'))),
    );
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  }, variant: android);

  testWidgets('a tinted prominent button labels for contrast (W20)', (t) async {
    shaderEnv();
    Color? labelOf(String text) =>
        DefaultTextStyle.of(t.element(find.text(text))).style.color;
    await t.pumpWidget(
      appHost(
        Column(
          children: [
            GlassButton(
              onPressed: () {},
              style: GlassButtonStyle.glassProminent,
              tint: Colors.yellow,
              child: const Text('Light'),
            ),
            GlassButton(
              onPressed: () {},
              style: GlassButtonStyle.borderedProminent,
              tint: Colors.indigo.shade900,
              child: const Text('Dark'),
            ),
          ],
        ),
      ),
    );
    expect(labelOf('Light'), Colors.black);
    expect(labelOf('Dark'), Colors.white);
  }, variant: android);

  testWidgets('foregroundColor colours the label; disabled keeps dimmed', (
    t,
  ) async {
    shaderEnv();
    const fg = Color(0xFF123456);
    Color? labelOf(String text) =>
        DefaultTextStyle.of(t.element(find.text(text))).style.color;
    await t.pumpWidget(
      appHost(
        Column(
          children: [
            GlassButton(
              onPressed: () {},
              style: GlassButtonStyle.glassProminent,
              tint: Colors.yellow,
              foregroundColor: fg,
              child: const Text('Go'),
            ),
            GlassButton.icon(
              onPressed: () {},
              icon: CupertinoIcons.add,
              foregroundColor: fg,
            ),
            const GlassButton(
              onPressed: null,
              foregroundColor: fg,
              child: Text('Off'),
            ),
          ],
        ),
      ),
    );
    expect(labelOf('Go'), fg);
    expect(IconTheme.of(t.element(find.byIcon(CupertinoIcons.add))).color, fg);
    expect(labelOf('Off'), isNot(fg));
  }, variant: android);

  testWidgets('cornerRadius rounds a roundedRect', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        GlassButton(
          onPressed: () {},
          shape: GlassButtonShape.roundedRect,
          cornerRadius: 4,
          child: const Text('A'),
        ),
      ),
    );
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(
      button.style!.shape!.resolve({}),
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }, variant: android);
}
