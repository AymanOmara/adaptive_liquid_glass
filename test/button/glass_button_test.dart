import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/button_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

LiquidGlass glassOf(WidgetTester t) =>
    t.widget<LiquidGlass>(find.byType(LiquidGlass));

TextStyle styleOf(WidgetTester t, String text) =>
    DefaultTextStyle.of(t.element(find.text(text))).style;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final size in GlassControlSize.values) {
    testWidgets('${size.name}: height and padding follow the metrics', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          GlassButton(
            onPressed: () {},
            size: size,
            child: const Text('Button'),
          ),
        ),
      );
      final m = glassButtonMetrics(size);
      final button = t.getSize(find.byType(GlassButton));
      final text = t.getSize(find.text('Button'));
      expect(button.height, moreOrLessEquals(m.height, epsilon: 0.01));
      expect(
        (button.width - text.width) / 2,
        moreOrLessEquals(m.padding, epsilon: 0.01),
      );
      expect(styleOf(t, 'Button').fontSize, m.fontSize);
    }, variant: ios);

    testWidgets('${size.name}: icon-only is a capsule 12 wider than tall', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          GlassButton.icon(
            onPressed: () {},
            size: size,
            icon: CupertinoIcons.add,
          ),
        ),
      );
      final m = glassButtonMetrics(size);
      expect(glassOf(t).shape, const GlassShape.capsule());
      expect(
        t.getSize(find.byType(GlassButton)),
        Size(m.iconOnlyHeight + m.iconOnlyExtraWidth, m.iconOnlyHeight),
      );
    }, variant: ios);
  }

  testWidgets('circle and roundedRect shapes', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Column(
          children: [
            GlassButton.icon(
              onPressed: () {},
              icon: CupertinoIcons.add,
              shape: GlassButtonShape.circle,
            ),
            GlassButton(
              onPressed: () {},
              shape: GlassButtonShape.roundedRect,
              child: const Text('A'),
            ),
          ],
        ),
      ),
    );
    final glasses = t
        .widgetList<LiquidGlass>(find.byType(LiquidGlass))
        .toList();
    expect(glasses[0].shape, const GlassShape.circle());
    final circle = t.getSize(find.byType(GlassButton).first);
    expect(circle.width, circle.height);
    expect(
      glasses[1].shape,
      GlassShape.rect(
        glassButtonMetrics(GlassControlSize.regular).cornerRadius,
      ),
    );
  }, variant: ios);

  testWidgets('prominent is tinted with the accent, label white', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.glassProminent,
          child: const Text('Go'),
        ),
      ),
    );
    expect(glassOf(t).glass!.tintColor, CupertinoColors.systemBlue.color);
    expect(styleOf(t, 'Go').color, const Color(0xFFFFFFFF));
  }, variant: ios);

  testWidgets('prominent uses tint when given', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.glassProminent,
          tint: const Color(0xFF00AA00),
          child: const Text('Go'),
        ),
      ),
    );
    expect(glassOf(t).glass!.tintColor, const Color(0xFF00AA00));
  }, variant: ios);

  testWidgets('destructive: red label on glass, red tint when prominent', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Column(
          children: [
            GlassButton(
              onPressed: () {},
              role: GlassButtonRole.destructive,
              child: const Text('Delete'),
            ),
            GlassButton(
              onPressed: () {},
              role: GlassButtonRole.destructive,
              style: GlassButtonStyle.glassProminent,
              child: const Text('Erase'),
            ),
          ],
        ),
      ),
    );
    expect(styleOf(t, 'Delete').color, GlassSystemColors.red.color);
    final glasses = t
        .widgetList<LiquidGlass>(find.byType(LiquidGlass))
        .toList();
    expect(glasses[1].glass!.tintColor, GlassSystemColors.red.color);
  }, variant: ios);

  testWidgets('cancel is semibold', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          role: GlassButtonRole.cancel,
          child: const Text('Cancel'),
        ),
      ),
    );
    expect(styleOf(t, 'Cancel').fontWeight, FontWeight.w600);
  }, variant: ios);

  testWidgets('tapping calls onPressed; glassId is forwarded', (t) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () => taps++,
          glassId: 'save',
          child: const Text('Save'),
        ),
      ),
    );
    await t.tap(find.text('Save'));
    expect(taps, 1);
    expect(glassOf(t).glassId, 'save');
    expect(glassOf(t).glass!.isInteractive, isTrue);
  }, variant: ios);

  testWidgets('GlassControlSizeScope sets the default size', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassControlSizeScope(
          size: GlassControlSize.large,
          child: GlassButton(onPressed: () {}, child: const Text('A')),
        ),
      ),
    );
    expect(
      t.getSize(find.byType(GlassButton)).height,
      glassButtonMetrics(GlassControlSize.large).height,
    );
  }, variant: ios);

  testWidgets('icon with a label: icon, gap, label', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton.icon(
          onPressed: () {},
          icon: CupertinoIcons.add,
          label: const Text('New'),
        ),
      ),
    );
    final icon = t.getRect(find.byIcon(CupertinoIcons.add));
    final label = t.getRect(find.text('New'));
    expect(
      label.left - icon.right,
      moreOrLessEquals(
        glassButtonMetrics(GlassControlSize.regular).iconGap,
        epsilon: 0.01,
      ),
    );
    expect(glassOf(t).shape, const GlassShape.capsule());
  }, variant: ios);

  testWidgets('icon-only button is announced by its semanticLabel', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(
        GlassButton.icon(
          onPressed: () {},
          icon: CupertinoIcons.share,
          semanticLabel: 'Share',
        ),
      ),
    );
    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    s.dispose();
  }, variant: ios);

  testWidgets('large text grows the button instead of clipping', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: 2,
          maxScaleFactor: 2,
          child: GlassButton(onPressed: () {}, child: const Text('Button')),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(
      t.getSize(find.byType(GlassButton)).height,
      greaterThan(glassButtonMetrics(GlassControlSize.regular).height),
    );
  }, variant: ios);

  testWidgets('glass label: opaque black over light, white over dark', (
    t,
  ) async {
    shaderEnv();
    Widget host(Brightness b) => plainHost(
      GlassForeground(
        backgroundBrightness: b,
        child: GlassButton.icon(
          onPressed: () {},
          icon: CupertinoIcons.add,
          label: const Text('Add'),
        ),
      ),
    );
    await t.pumpWidget(host(Brightness.light));
    // SwiftUI draws 0,0,0 (measured), not 85% black.
    expect(styleOf(t, 'Add').color, const Color(0xFF000000));
    expect(
      IconTheme.of(t.element(find.byIcon(CupertinoIcons.add))).color,
      const Color(0xFF000000),
    );
    await t.pumpWidget(host(Brightness.dark));
    expect(styleOf(t, 'Add').color, const Color(0xFFFFFFFF));
  }, variant: ios);

  testWidgets("the app's own label colour still wins", (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          child: const Text('Mine', style: TextStyle(color: Color(0xFF123456))),
        ),
      ),
    );
    final text = t.widget<RichText>(
      find.descendant(of: find.text('Mine'), matching: find.byType(RichText)),
    );
    expect(text.text.style!.color, const Color(0xFF123456));
  }, variant: ios);
}
