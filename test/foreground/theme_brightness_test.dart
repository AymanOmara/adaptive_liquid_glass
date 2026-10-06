import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// An app whose theme is fixed to [theme] (no darkTheme, so the platform
/// brightness cannot change it), with a button that opens what [open]
/// shows.
Widget _app({
  required Brightness theme,
  required void Function(BuildContext) open,
}) => MaterialApp(
  theme: ThemeData(brightness: theme),
  home: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => open(context),
        child: const Text('Open'),
      ),
    ),
  ),
);

/// The same app with [child] directly in the home (the no-overlay cases).
Widget _host({required Brightness theme, required Widget child}) => MaterialApp(
  theme: ThemeData(brightness: theme),
  home: Center(child: child),
);

/// The local-override host: the app theme matches the platform, a local
/// [CupertinoTheme] above the opener disagrees with it. Overlays capture
/// that local theme, so what opens draws with it, not the app theme.
Widget _localApp({
  required Brightness platform,
  required Brightness theme,
  required void Function(BuildContext) open,
}) => MaterialApp(
  theme: ThemeData(brightness: platform),
  home: CupertinoTheme(
    data: CupertinoThemeData(brightness: theme),
    child: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => open(context),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Brightness _glassBrightness(WidgetTester t) =>
    t.widget<GlassBackdrop>(find.byType(GlassBackdrop).last).config.brightness;

Color? _spanColour(InlineSpan span) {
  final colour = span.style?.color;
  if (colour != null) return colour;
  Color? found;
  span.visitChildren((child) {
    found ??= _spanColour(child);
    return found == null;
  });
  return found;
}

/// The rendered colour of the [text]'s RichText: the first colour in its
/// InlineSpan tree.
Color _textColour(WidgetTester t, String text) => _spanColour(
  t
      .widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == text,
        ),
      )
      .text,
)!;

Color _label(Brightness theme) => theme == Brightness.light
    ? CupertinoColors.label.color
    : CupertinoColors.label.darkColor;

Color _secondaryLabel(Brightness theme) => theme == Brightness.light
    ? CupertinoColors.secondaryLabel.color
    : CupertinoColors.secondaryLabel.darkColor;

/// The vibrant label the glass gives its content (GlassForeground's
/// fallback, the theme brightness: sampling needs a GlassBackdropSource,
/// which these hosts do not have).
Color _glassLabel(Brightness theme) => theme == Brightness.light
    ? GlassColors.labelOnLight
    : GlassColors.labelOnDark;

/// Registers [run] once per mismatched (platform, theme) pair.
void _bothDirections(
  String what,
  Future<void> Function(WidgetTester t, Brightness platform, Brightness theme)
  run,
) {
  for (final (platform, theme) in [
    (Brightness.dark, Brightness.light),
    (Brightness.light, Brightness.dark),
  ]) {
    final platformName = platform == Brightness.dark ? 'dark' : 'light';
    final themeName = theme == Brightness.dark ? 'dark' : 'light';
    testWidgets(
      '$what: platform $platformName, theme $themeName -> '
      '${themeName == 'dark' ? 'dark glass, light text' : 'light glass, dark text'}',
      (t) async {
        shaderEnv();
        t.platformDispatcher.platformBrightnessTestValue = platform;
        await run(t, platform, theme);
      },
      variant: ios,
    );
  }
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() {
    GlassPlatform.instance.debugReset();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  _bothDirections('alert', (t, platform, theme) async {
    await t.pumpWidget(
      _app(
        theme: theme,
        open: (context) => showGlassAlert(
          context: context,
          title: 'Title',
          message: 'Message',
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    expect(_textColour(t, 'Title').toARGB32(), _label(theme).toARGB32());
  });

  _bothDirections('action sheet', (t, platform, theme) async {
    await t.pumpWidget(
      _app(
        theme: theme,
        open: (context) => showGlassActionSheet(
          context: context,
          title: 'Title',
          message: 'Message',
          actions: const [GlassDialogAction(label: 'Share')],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    // The action sheet's title is the secondary label colour.
    expect(
      _textColour(t, 'Title').toARGB32(),
      _secondaryLabel(theme).toARGB32(),
    );
  });

  _bothDirections('sheet', (t, platform, theme) async {
    await t.pumpWidget(
      _app(
        theme: theme,
        open: (context) => showGlassSheet<void>(
          context: context,
          builder: (_) => const Text('Body'),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    expect(_textColour(t, 'Body').toARGB32(), _label(theme).toARGB32());
  });

  _bothDirections('popover', (t, platform, theme) async {
    await t.pumpWidget(
      _app(
        theme: theme,
        open: (context) => showGlassPopover<void>(
          context: context,
          builder: (_) =>
              const Padding(padding: EdgeInsets.all(16), child: Text('Body')),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    // The popover's page text is the plain label colour (its glass is not
    // adaptively foregrounded).
    expect(_textColour(t, 'Body').toARGB32(), _label(theme).toARGB32());
  });

  _bothDirections('menu', (t, platform, theme) async {
    await t.pumpWidget(
      _host(
        theme: theme,
        child: GlassMenuButton(
          icon: CupertinoIcons.ellipsis,
          semanticLabel: 'More',
          items: [GlassMenuItem(label: 'Copy', onSelected: () {})],
        ),
      ),
    );
    await t.tap(find.byType(GlassMenuButton));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    expect(_textColour(t, 'Copy').toARGB32(), _label(theme).toARGB32());
  });

  _bothDirections('toast', (t, platform, theme) async {
    GlassToastHandle? handle;
    await t.pumpWidget(
      _app(
        theme: theme,
        open: (context) => handle = showGlassToast(context, message: 'Saved'),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    // The toast's message is the vibrant label colour (no sampled
    // backdrop here, so the theme's brightness picks it).
    expect(_textColour(t, 'Saved').toARGB32(), _glassLabel(theme).toARGB32());
    handle!.dismiss();
    await t.pumpAndSettle();
  });

  _bothDirections('text field', (t, platform, theme) async {
    await t.pumpWidget(
      _host(
        theme: theme,
        child: GlassTextField(controller: TextEditingController(text: 'Hello')),
      ),
    );
    await t.pump();
    expect(_glassBrightness(t), theme);
    expect(
      t.widget<EditableText>(find.byType(EditableText)).style.color!.toARGB32(),
      _label(theme).toARGB32(),
    );
  });

  // The app theme matches the platform; the local CupertinoTheme around
  // the opener disagrees. The overlays capture it, so what opens draws
  // with the local brightness.
  _bothDirections('local override alert', (t, platform, theme) async {
    await t.pumpWidget(
      _localApp(
        platform: platform,
        theme: theme,
        open: (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    expect(_textColour(t, 'Title').toARGB32(), _label(theme).toARGB32());
  });

  _bothDirections('local override sheet', (t, platform, theme) async {
    await t.pumpWidget(
      _localApp(
        platform: platform,
        theme: theme,
        open: (context) => showGlassSheet<void>(
          context: context,
          builder: (_) => const Text('Body'),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), theme);
    expect(_textColour(t, 'Body').toARGB32(), _label(theme).toARGB32());
  });

  testWidgets('alert: platform dark, theme dark -> dark glass, light text', (
    t,
  ) async {
    shaderEnv();
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await t.pumpWidget(
      _app(
        theme: Brightness.dark,
        open: (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(_glassBrightness(t), Brightness.dark);
    expect(
      _textColour(t, 'Title').toARGB32(),
      CupertinoColors.label.darkColor.toARGB32(),
    );
  }, variant: ios);
}
