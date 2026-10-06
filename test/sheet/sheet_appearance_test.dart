import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// An app that follows the system appearance, and a button that opens
/// what [open] shows.
Widget _app(void Function(BuildContext) open) => MaterialApp(
  theme: ThemeData(brightness: Brightness.light),
  darkTheme: ThemeData(brightness: Brightness.dark),
  home: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => open(context),
        child: const Text('Open'),
      ),
    ),
  ),
);

Brightness _glassBrightness(WidgetTester t) =>
    t.widget<GlassBackdrop>(find.byType(GlassBackdrop).last).config.brightness;

Color? _textColour(WidgetTester t, String text) =>
    DefaultTextStyle.of(t.element(find.text(text))).style.color;

Future<void> _goDark(WidgetTester t) async {
  t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  await t.pumpAndSettle();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() {
    GlassPlatform.instance.debugReset();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  testWidgets('an open sheet follows a switch to dark', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassSheet<void>(
          context: context,
          builder: (context) => const Text('Body'),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), Brightness.light);
    final light = _textColour(t, 'Body');
    await _goDark(t);
    expect(_glassBrightness(t), Brightness.dark);
    expect(_textColour(t, 'Body'), isNot(light));
    expect(
      _textColour(t, 'Body')!.toARGB32(),
      CupertinoColors.label.darkColor.toARGB32(),
    );
  }, variant: ios);

  testWidgets('an open large sheet: its opaque surface turns dark', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassSheet<void>(
          context: context,
          detents: const [GlassSheetDetent.large],
          builder: (context) => const SizedBox.expand(),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    Color surface() {
      final box = t.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(GlassSheet),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is ShapeDecoration &&
                    (w.decoration as ShapeDecoration).shape
                        is RoundedSuperellipseBorder,
              ),
            )
            .first,
      );
      return (box.decoration as ShapeDecoration).color!;
    }

    expect(
      surface().toARGB32(),
      CupertinoColors.systemBackground.color.toARGB32(),
    );
    await _goDark(t);
    // Elevated: a sheet's dark surface is #1C1C1E, not black.
    expect(
      surface().toARGB32(),
      CupertinoColors.systemBackground.darkElevatedColor.toARGB32(),
    );
  }, variant: ios);

  testWidgets('an open alert follows a switch to dark', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), Brightness.light);
    await _goDark(t);
    expect(_glassBrightness(t), Brightness.dark);
  }, variant: ios);

  testWidgets('an open popover follows a switch to dark', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassPopover<void>(
          context: context,
          builder: (context) => const Text('Pop'),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final light = _textColour(t, 'Pop');
    expect(_glassBrightness(t), Brightness.light);
    await _goDark(t);
    expect(_glassBrightness(t), Brightness.dark);
    expect(_textColour(t, 'Pop'), isNot(light));
  }, variant: ios);

  testWidgets('Material: an open bottom sheet follows a switch to dark', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassSheet<void>(
          context: context,
          builder: (context) => const Text('Body'),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    Color background() => Theme.of(t.element(sheet)).colorScheme.surface;
    final light = background();
    await _goDark(t);
    expect(background(), isNot(light));
  }, variant: android);
}
