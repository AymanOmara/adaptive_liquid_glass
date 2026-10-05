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
      iosMajorVersion: 18,
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

  const iosEnv = GlassEnvironment(
    platform: TargetPlatform.iOS,
    iosMajorVersion: 18,
    reduceTransparency: false,
    shaderSupported: true,
  );

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 300));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
    }
    await t.pump();
  }

  Widget glass(void Function(BuildContext) grab) => Positioned(
    left: 50,
    top: 50,
    width: 100,
    height: 40,
    child: LiquidGlass(
      child: Builder(
        builder: (c) {
          grab(c);
          return const SizedBox.expand();
        },
      ),
    ),
  );

  const black = ColoredBox(color: Color(0xFF000000));

  testWidgets('source inside the group subtree does not throw', (t) async {
    GlassPlatform.instance.debugEnvironment = iosEnv;
    late BuildContext inner;
    await t.pumpWidget(
      host(
        t,
        GlassGroup(
          child: Stack(
            children: [
              const Positioned.fill(child: GlassBackdropSource(child: black)),
              glass((c) => inner = c),
            ],
          ),
        ),
      ),
    );
    await settle(t);
    expect(t.takeException(), isNull);
    expect(GlassForeground.backgroundBrightnessOf(inner), Brightness.dark);
    await t.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('source mounted after first frame is picked up', (t) async {
    GlassPlatform.instance.debugEnvironment = iosEnv;
    late BuildContext inner;
    Widget tree({required bool withSource}) => host(
      t,
      Stack(
        children: [
          if (withSource)
            const Positioned.fill(child: GlassBackdropSource(child: black)),
          glass((c) => inner = c),
        ],
      ),
    );
    await t.pumpWidget(tree(withSource: false));
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpWidget(tree(withSource: true));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(GlassForeground.backgroundBrightnessOf(inner), Brightness.dark);
    await t.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('removing the source clears the sampled brightness', (t) async {
    GlassPlatform.instance.debugEnvironment = iosEnv;
    late BuildContext inner;
    Widget tree({required bool withSource}) => host(
      t,
      Stack(
        children: [
          if (withSource)
            const Positioned.fill(child: GlassBackdropSource(child: black)),
          glass((c) => inner = c),
        ],
      ),
    );
    await t.pumpWidget(tree(withSource: true));
    await settle(t);
    expect(GlassForeground.backgroundBrightnessOf(inner), Brightness.dark);
    await t.pumpWidget(tree(withSource: false));
    await t.pump();
    expect(
      GlassForeground.backgroundBrightnessOf(inner),
      MediaQuery.platformBrightnessOf(inner),
    );
    expect(MediaQuery.platformBrightnessOf(inner), Brightness.light);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('prefers a source covering the glass region', (t) async {
    GlassPlatform.instance.debugEnvironment = iosEnv;
    late BuildContext inner;
    await t.pumpWidget(
      host(
        t,
        Stack(
          children: [
            const Positioned(
              left: 300,
              top: 300,
              width: 50,
              height: 50,
              child: GlassBackdropSource(
                child: ColoredBox(color: Color(0xFFFFFFFF)),
              ),
            ),
            const Positioned.fill(child: GlassBackdropSource(child: black)),
            glass((c) => inner = c),
          ],
        ),
      ),
    );
    await settle(t);
    expect(GlassForeground.backgroundBrightnessOf(inner), Brightness.dark);
    await t.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('no source → no periodic timer', (t) async {
    GlassPlatform.instance.debugEnvironment = iosEnv;
    await t.pumpWidget(host(t, Stack(children: [glass((_) {})])));
    await t.pump(const Duration(seconds: 1));
    expect(t.binding.transientCallbackCount, 0);
    // flutter_test fails the test if a periodic timer is still pending when
    // the widget tree is left mounted.
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
