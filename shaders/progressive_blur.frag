#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Adapted from liquid_glass_widgets (MIT, Sebastian Degenaar).
//
// One axis of a separable gaussian whose sigma follows a gradient: strongest
// at the region's top edge, easing to sharp at its bottom. Run twice
// (horizontal, then vertical) through ImageFilter.compose for a 2-D blur.
// The bound texture is the whole backdrop (screen), so the gradient is
// normalised over the region's own device-px rectangle passed from Dart.
// Float layout must match lib/src/navigation/progressive_blur_uniforms.dart.

uniform vec2 uSize;           // 0,1  engine: texture size, device px
uniform float uMaxSigma;      // 2    sigma at the top edge, device px
uniform float uFalloff;       // 3    gradient gamma
uniform float uAxis;          // 4    0 horizontal, 1 vertical
uniform vec2 uRegionOrigin;   // 5,6  region top-left, device px
uniform vec2 uRegionSize;     // 7,8  region size, device px
uniform sampler2D uTexture;

out vec4 fragColor;

// Taps per side; the stride widens to keep +-3 sigma covered and bilinear
// filtering smooths between taps.
const int kHalf = 24;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float g = clamp((frag.y - uRegionOrigin.y) / uRegionSize.y, 0.0, 1.0);
  float sigma = uMaxSigma * pow(1.0 - g, uFalloff);

  vec2 uv = frag / uSize;
  // Engines before Flutter 3.46 stored GLES render targets bottom-up;
  // impellerc defines the UNFLIPPED macro where that is no longer so.
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif

  if (sigma < 0.5) {
    fragColor = texture(uTexture, uv);
    return;
  }

  vec2 axis = uAxis < 0.5 ? vec2(1.0 / uSize.x, 0.0) : vec2(0.0, 1.0 / uSize.y);
  float stride = max(1.0, 3.0 * sigma / float(kHalf));

  // Gaussian weights by recurrence: w(i) = exp(-(i*stride)^2 / 2 sigma^2)
  // with two multiplies per tap instead of an exp().
  float inv2s2 = 1.0 / (2.0 * sigma * sigma);
  float g1 = exp(-stride * stride * inv2s2);
  float g2 = g1 * g1;

  vec4 acc = texture(uTexture, uv);
  float wsum = 1.0;
  float w = 1.0;
  for (int i = 1; i <= kHalf; i++) {
    w *= g1;
    g1 *= g2;
    vec2 off = axis * (float(i) * stride);
    vec2 sp = uv + off;
    vec2 sm = uv - off;
    // Drop taps outside the texture rather than smear its edge pixel.
    float ip = step(0.0, sp.x) * step(sp.x, 1.0) * step(0.0, sp.y) * step(sp.y, 1.0);
    float im = step(0.0, sm.x) * step(sm.x, 1.0) * step(0.0, sm.y) * step(sm.y, 1.0);
    acc += texture(uTexture, clamp(sp, 0.0, 1.0)) * (w * ip);
    acc += texture(uTexture, clamp(sm, 0.0, 1.0)) * (w * im);
    wsum += w * ip + w * im;
  }
  fragColor = acc / wsum;
}
