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
}) =>
    GlassEnvironment(
        platform: platform,
        iosMajorVersion: platform == TargetPlatform.iOS ? ios : null,
        reduceTransparency: rt,
        shaderSupported: shader);

EffectiveGlassMode r(GlassRenderMode m, GlassEnvironment e,
        {bool native = false}) =>
    resolveGlassMode(requested: m, nativeEnabled: native, environment: e);

void main() {
  const auto = GlassRenderMode.auto;

  test('auto on Android is material', () {
    expect(r(auto, env(platform: TargetPlatform.android)),
        EffectiveGlassMode.material);
  });

  test('auto on iOS is shader unless native is enabled and available', () {
    expect(r(auto, env()), EffectiveGlassMode.shader);
    expect(r(auto, env(), native: true), EffectiveGlassMode.native);
    expect(r(auto, env(ios: 18), native: true), EffectiveGlassMode.shader);
    expect(r(auto, env(ios: null), native: true), EffectiveGlassMode.shader);
  });

  test('no shader support degrades', () {
    expect(r(auto, env(shader: false)), EffectiveGlassMode.degraded);
    expect(r(GlassRenderMode.shader, env(shader: false)),
        EffectiveGlassMode.degraded);
  });

  test('explicit modes win', () {
    expect(r(GlassRenderMode.material, env()), EffectiveGlassMode.material);
    expect(r(GlassRenderMode.shader, env(platform: TargetPlatform.android)),
        EffectiveGlassMode.shader);
    expect(r(GlassRenderMode.native, env()), EffectiveGlassMode.native);
  });

  test('explicit native below iOS 26 or off iOS falls to shader', () {
    expect(r(GlassRenderMode.native, env(ios: 18)), EffectiveGlassMode.shader);
    expect(r(GlassRenderMode.native, env(platform: TargetPlatform.android)),
        EffectiveGlassMode.shader);
  });

  test('Reduce Transparency turns shader and degraded into opaque', () {
    expect(r(auto, env(rt: true)), EffectiveGlassMode.opaque);
    expect(r(auto, env(rt: true, shader: false)), EffectiveGlassMode.opaque);
    expect(r(GlassRenderMode.shader, env(rt: true)), EffectiveGlassMode.opaque);
  });

  test('Reduce Transparency leaves native and material alone', () {
    expect(r(auto, env(rt: true), native: true), EffectiveGlassMode.native);
    expect(r(GlassRenderMode.material, env(rt: true)),
        EffectiveGlassMode.material);
  });
}
