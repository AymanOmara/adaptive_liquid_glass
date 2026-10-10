import 'package:adaptive_liquid_glass/src/core/effective_glass_mode.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/core/glass_render_mode.dart';
import 'package:adaptive_liquid_glass/src/core/render_mode_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

GlassEnvironment env({
  TargetPlatform platform = TargetPlatform.iOS,
  int? ios = 26,
  bool rt = false,
  bool shader = true,
}) => GlassEnvironment(
  platform: platform,
  iosMajorVersion: platform == TargetPlatform.iOS ? ios : null,
  reduceTransparency: rt,
  shaderSupported: shader,
);

EffectiveGlassMode r(GlassRenderMode m, GlassEnvironment e) =>
    resolveGlassMode(requested: m, environment: e);

void main() {
  const auto = GlassRenderMode.auto;

  test('auto on Android is material', () {
    expect(
      r(auto, env(platform: TargetPlatform.android)),
      EffectiveGlassMode.material,
    );
  });

  test('auto on iOS 26+ is native, with no flag', () {
    expect(r(auto, env()), EffectiveGlassMode.native);
    expect(r(auto, env(ios: 27)), EffectiveGlassMode.native);
    expect(r(auto, env(shader: false)), EffectiveGlassMode.native);
  });

  test('auto below iOS 26 (or unknown) is shader', () {
    expect(r(auto, env(ios: 18)), EffectiveGlassMode.shader);
    expect(r(auto, env(ios: 25)), EffectiveGlassMode.shader);
    expect(r(auto, env(ios: null)), EffectiveGlassMode.shader);
  });

  test('no shader support degrades', () {
    expect(r(auto, env(ios: 18, shader: false)), EffectiveGlassMode.degraded);
    expect(
      r(GlassRenderMode.shader, env(shader: false)),
      EffectiveGlassMode.degraded,
    );
  });

  test('explicit shader opts out of native on iOS 26+', () {
    expect(r(GlassRenderMode.shader, env()), EffectiveGlassMode.shader);
  });

  test('explicit modes win', () {
    expect(r(GlassRenderMode.material, env()), EffectiveGlassMode.material);
    expect(
      r(GlassRenderMode.shader, env(platform: TargetPlatform.android)),
      EffectiveGlassMode.shader,
    );
    expect(r(GlassRenderMode.native, env()), EffectiveGlassMode.native);
  });

  test('explicit native below iOS 26 or off iOS falls to shader', () {
    expect(r(GlassRenderMode.native, env(ios: 18)), EffectiveGlassMode.shader);
    expect(
      r(GlassRenderMode.native, env(platform: TargetPlatform.android)),
      EffectiveGlassMode.shader,
    );
  });

  test('Reduce Transparency turns shader and degraded into opaque', () {
    expect(r(auto, env(ios: 18, rt: true)), EffectiveGlassMode.opaque);
    expect(
      r(auto, env(ios: 18, rt: true, shader: false)),
      EffectiveGlassMode.opaque,
    );
    expect(r(GlassRenderMode.shader, env(rt: true)), EffectiveGlassMode.opaque);
  });

  test('Reduce Transparency leaves native and material alone', () {
    // SwiftUI's glass handles Reduce Transparency itself.
    expect(r(auto, env(rt: true)), EffectiveGlassMode.native);
    expect(r(GlassRenderMode.native, env(rt: true)), EffectiveGlassMode.native);
    expect(
      r(GlassRenderMode.material, env(rt: true)),
      EffectiveGlassMode.material,
    );
  });

  test('a forced Reduce Transparency makes native glass opaque too', () {
    final forced = env(rt: true).copyWith(reduceTransparencyForced: true);
    expect(r(auto, forced), EffectiveGlassMode.opaque);
    expect(r(GlassRenderMode.native, forced), EffectiveGlassMode.opaque);
    expect(r(GlassRenderMode.material, forced), EffectiveGlassMode.material);
  });
}
