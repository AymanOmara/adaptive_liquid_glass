import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

const _red = Color(0xFFFF0000);

/// Pumps [glass] around a probe and returns the probe's context.
Future<BuildContext> _probe(
  WidgetTester t,
  Widget Function(Widget probe) glass, {
  Widget Function(Widget) host = plainHost,
}) async {
  late BuildContext probe;
  await t.pumpWidget(
    host(
      glass(
        Builder(
          builder: (c) {
            probe = c;
            return const Text('label');
          },
        ),
      ),
    ),
  );
  return probe;
}

Color? _textColor(BuildContext c) => DefaultTextStyle.of(c).style.color;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() {
    GlassPlatform.instance.debugReset();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  testWidgets('text and icons on glass use the vibrant label colour', (
    t,
  ) async {
    shaderEnv();
    final c = await _probe(t, (p) => LiquidGlass(child: p));
    final label = GlassForeground.labelColorOf(c);
    expect(label, const Color(0xD9000000));
    expect(_textColor(c), label);
    expect(IconTheme.of(c).color, label);
  }, variant: ios);

  testWidgets('the label colour follows a dark backdrop', (t) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    shaderEnv();
    final c = await _probe(t, (p) => LiquidGlass(child: p));
    expect(_textColor(c), const Color(0xFFFFFFFF));
    expect(IconTheme.of(c).color, const Color(0xFFFFFFFF));
  }, variant: ios);

  testWidgets('explicit colours still win', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const LiquidGlass(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('red', style: TextStyle(color: _red)),
              Icon(IconData(0xe000), color: _red),
            ],
          ),
        ),
      ),
    );
    final text = t.widget<RichText>(find.byType(RichText).first);
    expect(text.text.style?.color, _red);
    expect(t.widget<Icon>(find.byType(Icon)).color, _red);
  }, variant: ios);

  testWidgets('other text style fields are merged, not replaced', (t) async {
    shaderEnv();
    final c = await _probe(
      t,
      (p) => DefaultTextStyle(
        style: const TextStyle(fontSize: 31, color: _red),
        child: LiquidGlass(child: p),
      ),
    );
    expect(DefaultTextStyle.of(c).style.fontSize, 31);
    expect(_textColor(c), const Color(0xD9000000));
  }, variant: ios);

  testWidgets('adaptiveForeground: false leaves the ambient colours', (
    t,
  ) async {
    shaderEnv();
    final c = await _probe(
      t,
      (p) => DefaultTextStyle(
        style: const TextStyle(color: _red),
        child: LiquidGlass(adaptiveForeground: false, child: p),
      ),
    );
    expect(_textColor(c), _red);
  }, variant: ios);

  testWidgets('Material path uses the on-surface colour', (t) async {
    shaderEnv();
    final c = await _probe(
      t,
      (p) => LiquidGlass(child: p),
      host: appHost,
    );
    final scheme = Theme.of(c).colorScheme;
    expect(_textColor(c), scheme.onSurface);
    expect(IconTheme.of(c).color, scheme.onSurface);
  }, variant: android);

  testWidgets('Material tinted glass uses its on-container colour', (
    t,
  ) async {
    shaderEnv();
    final c = await _probe(
      t,
      (p) => LiquidGlass(glass: Glass.regular.tint(Colors.orange), child: p),
      host: appHost,
    );
    final seeded = ColorScheme.fromSeed(
      seedColor: Colors.orange,
      brightness: Theme.of(c).brightness,
    );
    expect(_textColor(c), seeded.onPrimaryContainer);
  }, variant: android);

  testWidgets('identity glass leaves the content alone', (t) async {
    shaderEnv();
    final c = await _probe(
      t,
      (p) => DefaultTextStyle(
        style: const TextStyle(color: _red),
        child: LiquidGlass(glass: Glass.identity, child: p),
      ),
    );
    expect(_textColor(c), _red);
  }, variant: ios);
}
