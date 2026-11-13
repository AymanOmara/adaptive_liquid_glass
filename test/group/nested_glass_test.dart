import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/group/glass_group_scope.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MediaQuery(
  data: MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.implicitView!,
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  tearDown(() => GlassPlatform.instance.debugReset());

  // Glass inside another glass's content is layered on it, like a SwiftUI
  // `.glassEffect` button on a `.glassEffect` card: it must not join the
  // card's group, or the two shapes share one container (one
  // `GlassEffectContainer` on iOS 26) and the button melts into the card,
  // losing its rim.
  testWidgets('glass nested in glass content gets its own group', (t) async {
    GlassPlatform.instance.debugEnvironment = GlassEnvironment(
      platform: defaultTargetPlatform,
      iosMajorVersion: null,
      reduceTransparency: false,
      shaderSupported: true,
    );
    const inner = Key('inner');
    const outer = Key('outer');
    await t.pumpWidget(
      host(
        const Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: LiquidGlass(
              shape: GlassShape.rect(34),
              child: Center(
                key: outer,
                child: LiquidGlass(
                  shape: GlassShape.capsule(),
                  child: SizedBox(key: inner, width: 100, height: 44),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final outerScope = GlassGroupScope.maybeOf(t.element(find.byKey(outer)));
    final innerScope = GlassGroupScope.maybeOf(t.element(find.byKey(inner)));
    expect(outerScope, isNotNull);
    expect(innerScope, isNotNull);
    expect(identical(innerScope!.registry, outerScope!.registry), isFalse);
  });

  testWidgets('siblings in an explicit GlassGroup still share it', (t) async {
    GlassPlatform.instance.debugEnvironment = GlassEnvironment(
      platform: defaultTargetPlatform,
      iosMajorVersion: null,
      reduceTransparency: false,
      shaderSupported: true,
    );
    const a = Key('a');
    const b = Key('b');
    await t.pumpWidget(
      host(
        const GlassGroup(
          child: Row(
            children: [
              LiquidGlass(child: SizedBox(key: a, width: 44, height: 44)),
              LiquidGlass(child: SizedBox(key: b, width: 44, height: 44)),
            ],
          ),
        ),
      ),
    );
    expect(
      identical(
        GlassGroupScope.maybeOf(t.element(find.byKey(a)))!.registry,
        GlassGroupScope.maybeOf(t.element(find.byKey(b)))!.registry,
      ),
      isTrue,
    );
  });
}
