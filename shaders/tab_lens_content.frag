#version 460 core
// The tab lens's own content: the tinted tab row, refracted towards the
// lens's round ends and drawn over the glass, clipped to the lens. iOS composites the tinted
// tabs over the lens's brightened backdrop this way, so the tabs keep their
// colour while the backdrop lightens.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // set by the engine: the input texture, physical px
uniform vec2 uBox;      // the input box, logical px
uniform vec4 uLens;     // lens centre x, y, half width, half height (logical)
uniform vec4 uProfile;  // lens decay, band (logical px), strength, dispersion
uniform vec4 uEdge;     // edge (logical px, < 0 anisotropic), edge decay,
                        // anisotropic (1: the lens bends only at the ends),
                        // blur radius at the rim (logical px)
uniform sampler2D uTexture;

out vec4 fragColor;

float field(vec2 p) {
  vec2 h = uLens.zw;
  float r = min(h.x, h.y);
  vec2 q = abs(p - uLens.xy) - (h - vec2(r));
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

vec4 tex(vec2 p) {
  vec2 uv = p / uBox;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, clamp(uv, vec2(0.0), vec2(1.0)));
}

void main() {
  vec2 px = FlutterFragCoord().xy * uBox / uSize;  // logical px
  float d = field(px);
  float inside = 1.0 - smoothstep(-0.4, 0.4, d);
  if (inside <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  vec2 grad = vec2(field(px + vec2(0.5, 0.0)) - field(px - vec2(0.5, 0.0)),
                   field(px + vec2(0.0, 0.5)) - field(px - vec2(0.0, 0.5)));
  vec2 nrm = grad / max(length(grad), 1e-6);

  float depth = max(-d, 0.0);
  float band = max(uProfile.y, 1.0);
  float decay = max(uProfile.x, 1e-3);
  float cut = exp(-band / decay);
  float ex = exp(-depth / decay);
  float v = max(ex - cut, 0.0) / max(1.0 - cut, 1e-6);
  float lensAmt = uProfile.z * band * v;
  float le = uEdge.x * exp(-depth / max(uEdge.y, 1e-3));
  bool aniso = uEdge.x < 0.0 || uEdge.z > 0.5;
  // The ends bend, the long sides do not; the weight eases in over the
  // first 45 degrees off the long sides.
  float wx = aniso ? smoothstep(0.0, 0.7, abs(nrm.x)) : 1.0;
  lensAmt *= wx;
  if (aniso) le *= 1.0 - wx;
  lensAmt -= le;
  vec2 sp = px + nrm * lensAmt;

  // Each tap splits colour like a prism (red out, blue in, or with a
  // negative k red against green and blue), and the taps spread with the
  // lens profile, so the bent rim is soft as on iOS.
  float k = uProfile.w;
  vec2 disp = nrm * lensAmt * abs(k);
  float rb = uEdge.w * v * wx;
  vec2 tng = vec2(-nrm.y, nrm.x);
  vec4 c = vec4(0.0);
  float wsum = 0.0;
  for (int i = 0; i < 7; i++) {
    vec2 o = vec2(0.0);
    float w = 1.0;
    if (i > 0) {
      float a = float(i - 1) * 1.0471976;
      o = (nrm * cos(a) + tng * sin(a)) * rb;
      w = 0.75;
    }
    vec4 m = tex(sp + o);
    if (k != 0.0) {
      vec4 a1 = tex(sp + o + disp);
      vec4 b1 = tex(sp + o - disp);
      m.r = mix(m.r, a1.r, v);
      m.b = mix(m.b, b1.b, v);
      if (k < 0.0) m.g = mix(m.g, b1.g, v);
      m.a = max(m.a, mix(m.a, max(a1.a, b1.a), v));
    }
    c += m * w;
    wsum += w;
    if (rb < 0.25) break;
  }
  c /= wsum;
  fragColor = c * inside;
}
