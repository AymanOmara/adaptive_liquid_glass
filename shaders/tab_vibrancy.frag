#version 460 core
// iOS's vibrant tab labels: each glyph pixel keeps the hue of the glass
// behind it and takes the glyph's lightness, which follows the glass's
// lightness a little. A backdrop filter: the input is the glass under the
// glyphs, uGlyphs the glyphs rasterised.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // set by the engine: the backdrop, physical px
uniform vec4 uBox;      // the glyph image's origin and size, physical px
uniform vec4 uTone;     // kind (w): 0 label (x lightness gain, y reference
                        // lightness, z chroma gain), 1 tint (x gain, y
                        // reference), 2 pill (x scale, y gamma, z lift)
uniform sampler2D uTexture;
uniform sampler2D uGlyphs;

out vec4 fragColor;

float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

vec2 flip(vec2 uv) {
  // Engines before Flutter 3.46 stored GLES render targets bottom-up.
#if defined(IMPELLER_TARGET_OPENGLES) && !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
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
    // An image, not a render target: never stored bottom-up.
    g = texture(uGlyphs, guv);
  }
  if (g.a <= 0.0) {
    fragColor = c;
    return;
  }
  vec3 gc = g.rgb / g.a;
  vec3 bc = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  if (uTone.w > 1.5) {
    vec3 p = clamp(uTone.x * pow(bc, vec3(uTone.y)) + vec3(uTone.z), 0.0, 1.0);
    fragColor = mix(c, vec4(p, 1.0), g.a);
    return;
  }
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
