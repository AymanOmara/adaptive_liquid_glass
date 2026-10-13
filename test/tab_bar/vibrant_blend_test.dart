import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/vibrancy_kind.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/vibrant_blend.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Widget _bar(GlassRenderMode mode) => GlassTabBar(
  items: const [
    GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
    GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
  ],
  selectedIndex: 0,
  onSelected: (_) {},
  mode: mode,
);

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.iOS,
      iosMajorVersion: 26,
      reduceTransparency: false,
      shaderSupported: true,
    );
  });
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('shader glass: labels are vibrant, the tint as tinted', (
    t,
  ) async {
    await t.pumpWidget(plainHost(_bar(GlassRenderMode.shader)));
    final blends = t
        .renderObjectList<RenderVibrantBlend>(find.byType(VibrantBlend))
        .toList();
    expect(blends.where((b) => b.enabled), hasLength(2));
    expect(
      blends.where((b) => b.enabled && b.kind == VibrancyKind.tint),
      hasLength(1),
    );
    expect(blends.any((b) => b.enabled && b.child!.needsCompositing), isFalse);
  }, variant: _ios);

  testWidgets('native glass: no blend', (t) async {
    await t.pumpWidget(plainHost(_bar(GlassRenderMode.native)));
    expect(
      t
          .renderObjectList<RenderVibrantBlend>(find.byType(VibrantBlend))
          .where((b) => b.enabled),
      isEmpty,
    );
  }, variant: _ios);
}
