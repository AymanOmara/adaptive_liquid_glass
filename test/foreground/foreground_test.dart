import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  Widget host(WidgetTester t, Widget child) => MediaQuery(
    data: MediaQueryData.fromView(t.view),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  Future<Brightness> run(WidgetTester t, Color background) async {
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: true,
    );
    late BuildContext inner;
    await t.pumpWidget(
      host(
        t,
        Stack(
          children: [
            Positioned.fill(
              child: GlassBackdropSource(child: ColoredBox(color: background)),
            ),
            Positioned(
              left: 50,
              top: 50,
              width: 100,
              height: 40,
              child: LiquidGlass(
                child: Builder(
                  builder: (c) {
                    inner = c;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // Fake-async pumps fire the periodic sampler; the readback itself needs
    // real async time.
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 300));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
    }
    await t.pump();
    final b = GlassForeground.backgroundBrightnessOf(inner);
    await t.pumpWidget(const SizedBox()); // cancels timers
    return b;
  }

  testWidgets('white content → light background, dark label', (t) async {
    expect(await run(t, const Color(0xFFFFFFFF)), Brightness.light);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('black content → dark background', (t) async {
    expect(await run(t, const Color(0xFF000000)), Brightness.dark);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('no source → platform brightness', (t) async {
    late BuildContext inner;
    await t.pumpWidget(
      host(
        t,
        Builder(
          builder: (c) {
            inner = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      GlassForeground.backgroundBrightnessOf(inner),
      MediaQuery.platformBrightnessOf(inner),
    );
    expect(GlassForeground.labelColorOf(inner), isA<Color>());
  });
}
