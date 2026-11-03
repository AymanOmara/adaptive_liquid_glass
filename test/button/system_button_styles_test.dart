import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/system_button_metrics.dart';
import 'package:adaptive_liquid_glass/src/button/system_style_button.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPressTimeout, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _systemStyles = [
  GlassButtonStyle.bordered,
  GlassButtonStyle.borderedProminent,
  GlassButtonStyle.borderless,
  GlassButtonStyle.plain,
];

TextStyle styleOf(WidgetTester t, String text) =>
    DefaultTextStyle.of(t.element(find.text(text))).style;

/// The fill of the button's background, or null without one.
Color? fillOf(WidgetTester t) {
  final boxes = find.descendant(
    of: find.byType(SystemStyleButton),
    matching: find.byType(DecoratedBox),
  );
  if (boxes.evaluate().isEmpty) return null;
  final d = t.widget<DecoratedBox>(boxes.first).decoration as ShapeDecoration;
  return d.color;
}

// CupertinoTheme's default primary colour, as the glass styles use.
Color get _accent => CupertinoColors.systemBlue.color;
Color get _red => GlassSystemColors.red.color;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final style in _systemStyles) {
    testWidgets('${style.name}: no glass, taps fire', (t) async {
      shaderEnv();
      var taps = 0;
      await t.pumpWidget(
        plainHost(
          GlassButton(
            onPressed: () => taps++,
            style: style,
            child: const Text('Go'),
          ),
        ),
      );
      expect(find.byType(LiquidGlass), findsNothing);
      expect(find.byType(SystemStyleButton), findsOneWidget);
      await t.tap(find.text('Go'));
      expect(taps, 1);
    }, variant: ios);

    testWidgets('${style.name}: disabled is grey and a disabled button', (
      t,
    ) async {
      shaderEnv();
      final s = t.ensureSemantics();
      await t.pumpWidget(
        plainHost(
          GlassButton(onPressed: null, style: style, child: const Text('Go')),
        ),
      );
      expect(styleOf(t, 'Go').color, GlassColors.buttonDisabledLabel.color);
      final bordered =
          style == GlassButtonStyle.bordered ||
          style == GlassButtonStyle.borderedProminent;
      expect(
        fillOf(t),
        bordered ? GlassColors.borderedButtonFill.color : isNull,
      );
      expect(
        t.getSemantics(find.byType(GlassButton)),
        matchesSemantics(label: 'Go', isButton: true, hasEnabledState: true),
      );
      s.dispose();
    }, variant: ios);

    testWidgets('${style.name}: icon with label and icon-only render', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          Column(
            children: [
              GlassButton.icon(
                onPressed: () {},
                style: style,
                icon: CupertinoIcons.add,
                label: const Text('Add'),
              ),
              GlassButton.icon(
                onPressed: () {},
                style: style,
                icon: CupertinoIcons.trash,
                semanticLabel: 'Delete',
              ),
            ],
          ),
        ),
      );
      expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    }, variant: ios);
  }

  testWidgets('bordered: grey fill, accent label; tint colours the fill', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.bordered,
          child: const Text('Go'),
        ),
      ),
    );
    expect(styleOf(t, 'Go').color, _accent);
    expect(fillOf(t), GlassColors.borderedButtonFill.color);

    const green = Color(0xFF00AA00);
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.bordered,
          tint: green,
          child: const Text('Go'),
        ),
      ),
    );
    expect(styleOf(t, 'Go').color, green);
    expect(
      fillOf(t),
      green.withValues(alpha: SystemButtonMetrics.tintedFillOpacityLight),
    );
  }, variant: ios);

  testWidgets('bordered: height and padding follow the system metrics', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.bordered,
          child: const Text('Button'),
        ),
      ),
    );
    final m = SystemButtonMetrics.forSize(
      GlassControlSize.regular,
      style: GlassButtonStyle.bordered,
    );
    final button = t.getSize(find.byType(GlassButton));
    final text = t.getSize(find.text('Button'));
    expect(button.height, moreOrLessEquals(m.height, epsilon: 0.01));
    expect(
      (button.width - text.width) / 2,
      moreOrLessEquals(m.padding, epsilon: 0.01),
    );
  }, variant: ios);

  testWidgets('borderedProminent: solid accent fill, white label', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.borderedProminent,
          child: const Text('Go'),
        ),
      ),
    );
    expect(fillOf(t), _accent);
    expect(styleOf(t, 'Go').color, GlassColors.white);
  }, variant: ios);

  testWidgets('borderless: accent label, no background, hugs the label', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.borderless,
          child: const Text('Go'),
        ),
      ),
    );
    expect(styleOf(t, 'Go').color, _accent);
    expect(fillOf(t), isNull);
    expect(t.getSize(find.byType(GlassButton)), t.getSize(find.text('Go')));
  }, variant: ios);

  testWidgets('plain: primary label colour, no background', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.plain,
          child: const Text('Go'),
        ),
      ),
    );
    expect(styleOf(t, 'Go').color, GlassColors.plainButtonLabel.color);
    expect(fillOf(t), isNull);
  }, variant: ios);

  testWidgets('destructive tints every system style red', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Column(
          children: [
            for (final style in _systemStyles)
              GlassButton(
                onPressed: () {},
                style: style,
                role: GlassButtonRole.destructive,
                child: Text(style.name),
              ),
          ],
        ),
      ),
    );
    expect(styleOf(t, 'bordered').color, _red);
    expect(styleOf(t, 'borderless').color, _red);
    expect(styleOf(t, 'plain').color, _red);
    expect(styleOf(t, 'borderedProminent').color, GlassColors.white);
    final fills = t
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SystemStyleButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => (d.decoration as ShapeDecoration).color)
        .toList();
    expect(fills, [GlassColors.borderedButtonFill.color, _red]);
  }, variant: ios);

  testWidgets('borderless press fades only the label and release restores it', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.borderless,
          child: const Text('Go'),
        ),
      ),
    );
    double opacity() => t
        .widget<Opacity>(
          find.descendant(
            of: find.byType(SystemStyleButton),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(opacity(), 1);
    final g = await t.startGesture(t.getCenter(find.text('Go')));
    // Highlight in the first frame, without waiting for tap recognition.
    await t.pump();
    expect(opacity(), closeTo(0.2, 1e-12));
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(opacity(), greaterThan(0.2));
    expect(opacity(), lessThan(1));
    await t.pumpAndSettle();
    expect(opacity(), 1);
  }, variant: ios);

  testWidgets('cancel restores the fill and disabling clears a held press', (
    t,
  ) async {
    shaderEnv();
    Widget button(bool enabled) => plainHost(
      GlassButton(
        onPressed: enabled ? () {} : null,
        style: GlassButtonStyle.bordered,
        tint: const Color(0xFF0080FF),
        child: const Text('Go'),
      ),
    );
    await t.pumpWidget(button(true));
    final idle = fillOf(t);
    final g = await t.startGesture(t.getCenter(find.text('Go')));
    await t.pump(kPressTimeout);
    await t.pump();
    expect(fillOf(t), const Color(0xFF0080FF).withValues(alpha: 0.12));
    await g.cancel();
    await t.pumpAndSettle();
    expect(fillOf(t), idle);
    final held = await t.startGesture(t.getCenter(find.text('Go')));
    await t.pump(kPressTimeout);
    await t.pump();
    await t.pumpWidget(button(false));
    await held.up();
    await t.pumpAndSettle();
    expect(fillOf(t), GlassColors.borderedButtonFill.color);
    await t.pumpWidget(button(true));
    await t.pumpAndSettle();
    expect(fillOf(t), idle);
  }, variant: ios);

  testWidgets('secondary mouse buttons do not highlight or activate', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () => taps++,
          style: GlassButtonStyle.bordered,
          tint: const Color(0xFF0080FF),
          child: const Text('Go'),
        ),
      ),
    );
    final idle = fillOf(t);
    final g = await t.startGesture(
      t.getCenter(find.text('Go')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await t.pump();
    expect(fillOf(t), idle);
    await g.up();
    await t.pumpAndSettle();
    expect(taps, 0);
  }, variant: ios);

  testWidgets('another pointer ending does not release the primary press', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () {},
          style: GlassButtonStyle.bordered,
          tint: const Color(0xFF0080FF),
          child: const Text('Go'),
        ),
      ),
    );
    final idle = fillOf(t);
    final point = t.getCenter(find.text('Go'));
    final first = await t.startGesture(point, pointer: 1);
    final second = await t.startGesture(point, pointer: 2);
    await second.up();
    await t.pump();
    expect(fillOf(t), const Color(0xFF0080FF).withValues(alpha: 0.12));
    await first.cancel();
    await t.pumpAndSettle();
    expect(fillOf(t), idle);
  }, variant: ios);

  testWidgets('scrolling cancels a pointer highlight without activation', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      plainHost(
        ListView(
          controller: controller,
          padding: const EdgeInsets.only(top: 100),
          children: [
            GlassButton(
              onPressed: () => taps++,
              style: GlassButtonStyle.bordered,
              tint: const Color(0xFF0080FF),
              child: const Text('Go'),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final idle = fillOf(t);
    final g = await t.startGesture(t.getCenter(find.text('Go')));
    await t.pump();
    expect(fillOf(t), isNot(idle));
    await g.moveBy(const Offset(0, -100));
    await t.pump();
    await g.moveBy(const Offset(0, -20));
    await g.up();
    await t.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(fillOf(t), idle);
    expect(taps, 0);
  }, variant: ios);

  testWidgets('loading: indicator, taps ignored', (t) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      plainHost(
        GlassButton(
          onPressed: () => taps++,
          style: GlassButtonStyle.borderedProminent,
          loading: true,
          child: const Text('Save'),
        ),
      ),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    await t.tap(find.byType(GlassButton), warnIfMissed: false);
    expect(taps, 0);
  }, variant: ios);

  testWidgets('Material: bordered → tonal, borderedProminent → filled, '
      'borderless and plain → text buttons', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        Column(
          children: [
            for (final style in _systemStyles)
              GlassButton(
                onPressed: () {},
                style: style,
                child: Text(style.name),
              ),
            GlassButton.icon(
              onPressed: () {},
              style: GlassButtonStyle.borderless,
              icon: CupertinoIcons.add,
            ),
          ],
        ),
      ),
    );
    expect(find.byType(SystemStyleButton), findsNothing);
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.widgetWithText(FilledButton, 'bordered'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'borderedProminent'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'borderless'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'plain'), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    final scheme = Theme.of(t.element(find.text('plain'))).colorScheme;
    expect(styleOf(t, 'plain').color, scheme.onSurface);
  }, variant: android);

  testWidgets('Material: destructive is red for every system style', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        Column(
          children: [
            for (final style in _systemStyles)
              GlassButton(
                onPressed: () {},
                style: style,
                role: GlassButtonRole.destructive,
                child: Text(style.name),
              ),
          ],
        ),
      ),
    );
    final scheme = Theme.of(t.element(find.text('plain'))).colorScheme;
    expect(styleOf(t, 'bordered').color, scheme.onErrorContainer);
    expect(styleOf(t, 'borderedProminent').color, scheme.onError);
    expect(styleOf(t, 'borderless').color, scheme.error);
    expect(styleOf(t, 'plain').color, scheme.error);
  }, variant: android);

  testWidgets('Material: disabled system styles are disabled buttons', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        Column(
          children: [
            for (final style in _systemStyles)
              GlassButton(
                onPressed: null,
                style: style,
                child: Text(style.name),
              ),
          ],
        ),
      ),
    );
    for (final b in t.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    )) {
      expect(b.enabled, isFalse);
    }
  }, variant: android);
}
