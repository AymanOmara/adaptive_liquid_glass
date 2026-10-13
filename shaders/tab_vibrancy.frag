#version 460 core
// iOS's vibrant tab labels: each glyph pixel keeps the hue of the glass
// behind it and takes the glyph's lightness, which follows the glass's
// lightness a little. A backdrop filter: the input is the glass under the
// glyphs, uGlyphs the glyphs rasterised.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // set by the engine: the backdrop, physical px
uniform vec4 uBox;      // the glyph image's origin and size, physical px
uniform vec4 uTone;     // lightness gain, reference lightness, chroma gain,
                        // tinted (1: each channel moves by gain instead)
uniform sampler2D uTexture;
uniform sampler2D uGlyphs;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

vec2 flip(vec2 uv) {
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec4 c = texture(uTexture, flip(px / uSize));
  vec2 guv = (px - uBox.xy) / uBox.zw;
  vec4 g = vec4(0.0);
  if (all(greaterThanEqual(guv, vec2(0.0))) && all(lessThanEqual(guv, vec2(1.0)))) {
    g = texture(uGlyphs, flip(guv));
  }
  if (g.a <= 0.0) {
    fragColor = c;
    return;
  }
  vec3 gc = g.rgb / g.a;
  vec3 bc = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  if (uTone.w > 0.5) {
    vec3 t = clamp(gc + uTone.x * (bc - vec3(uTone.y)), 0.0, 1.0);
    fragColor = mix(c, vec4(t, 1.0), g.a);
    return;
  }
  float lb = lum(bc);
  float l = lum(gc) + uTone.x * (lb - uTone.y);
  vec3 v = clamp(vec3(l) + uTone.z * (bc - vec3(lb)), 0.0, 1.0);
  fragColor = mix(c, vec4(v, 1.0), g.a);
}
