#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Float layout must match lib/src/shader/glass_uniforms.dart.
uniform vec2 uSize;        // engine: texture size
uniform vec4 uGlobal;      // count, dpr, lightAngle, opaque
uniform vec4 uGlobal2;     // smoothing px, cornerExponent, highContrast, -
uniform vec4 uOpaque;      // rgb
uniform vec4 uTouch;       // x, y, glow, glowRadius px
uniform vec4 uRects[16];   // x, y, w, h px
uniform vec4 uInfo[16];    // radius px, variant(0 regular, 1 clear), -, -
uniform vec4 uTints[16];   // rgb, strength
uniform vec4 uVar[6];      // per variant: A(blur, band, lens, disp) B(rimW, rimI, lift, dim) C(shadowR, shadowO, tintS, -)
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 tex(vec2 px) {
  vec2 uv = clamp(px / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv);
}

vec4 blurred(vec2 px, float sigma) {
  if (sigma < 0.5) return tex(px);
  vec4 acc = vec4(0.0);
  float wsum = 0.0;
  for (int i = 0; i < 24; i++) {
    float fi = float(i) + 0.5;
    float rr = sqrt(fi / 24.0) * sigma * 2.5;
    float a = fi * 2.39996323;
    float w = exp(-(rr * rr) / (2.0 * sigma * sigma));
    acc += tex(px + vec2(cos(a), sin(a)) * rr) * w;
    wsum += w;
  }
  return acc / wsum;
}

float sdSuperellipseBox(vec2 p, vec2 halfSize, float r, float n) {
  r = min(r, min(halfSize.x, halfSize.y));
  vec2 q = abs(p) - halfSize + r;
  vec2 m = max(q, 0.0);
  float corner = pow(pow(m.x, n) + pow(m.y, n), 1.0 / n);
  return corner + min(max(q.x, q.y), 0.0) - r;
}

float shapeDist(int i, vec2 p) {
  vec4 rc = uRects[i];
  vec2 hs = rc.zw * 0.5;
  return sdSuperellipseBox(p - (rc.xy + hs), hs, uInfo[i].x, uGlobal2.y);
}

float smin(float a, float b, float k) {
  if (k <= 0.0) return min(a, b);
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

float field(vec2 p) {
  float d = 1e6;
  for (int i = 0; i < 16; i++) {
    if (i >= int(uGlobal.x)) break;
    d = smin(d, shapeDist(i, p), uGlobal2.x);
  }
  return d;
}

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec4 base = tex(px);
  int count = int(uGlobal.x);
  if (count == 0) { fragColor = base; return; }

  // Per-shape attributes blended by proximity (for merged regions).
  // Weights are shifted by the nearest distance (online softmax) so the
  // nearest shape always weighs 1: raw exp(-dist/k) underflows to 0 beyond
  // ~87 px and wsum = 0 turned every attribute into NaN (black output).
  float wsum = 0.0;
  float clearMix = 0.0;
  vec4 tint = vec4(0.0);
  float d = 1e6;
  float wk = uGlobal2.x * 0.5 + 1.0;
  float dmin = 1e6;
  for (int i = 0; i < 16; i++) {
    if (i >= count) break;
    float di = shapeDist(i, px);
    d = smin(d, di, uGlobal2.x);
    float e = max(di, 0.0);
    if (e < dmin) {
      float s = exp(-(dmin - e) / wk);
      wsum *= s;
      clearMix *= s;
      tint *= s;
      dmin = e;
    }
    float w = exp(-(e - dmin) / wk);
    wsum += w;
    clearMix += w * uInfo[i].y;
    tint += w * uTints[i];
  }
  clearMix /= wsum;
  tint /= wsum;

  vec4 A = mix(uVar[0], uVar[3], clearMix);
  vec4 B = mix(uVar[1], uVar[4], clearMix);
  vec4 C = mix(uVar[2], uVar[5], clearMix);
  float hc = uGlobal2.z;

  float inside = 1.0 - smoothstep(-0.75, 0.75, d);

  // Shadow outside the shape.
  if (inside <= 0.0) {
    float sr = max(C.x * 0.5, 1.0);
    float sh = C.y * exp(-(d * d) / (2.0 * sr * sr));
    fragColor = vec4(base.rgb * (1.0 - sh), base.a);
    return;
  }

  // Opaque (Reduce Transparency).
  if (uGlobal.w > 0.5) {
    vec3 solid = mix(uOpaque.rgb, tint.rgb, tint.a);
    fragColor = vec4(mix(base.rgb, solid, inside), 1.0);
    return;
  }

  float e = 1.0;
  vec2 nrm = vec2(field(px + vec2(e, 0.0)) - field(px - vec2(e, 0.0)),
                  field(px + vec2(0.0, e)) - field(px - vec2(0.0, e)));
  nrm = normalize(nrm + vec2(1e-6));

  float depth = -d;
  float band = max(A.y, 1.0);
  float t = clamp(1.0 - depth / band, 0.0, 1.0);
  float lensAmt = A.z * (1.0 - 0.5 * hc) * t * t * band;
  vec2 sp = px + nrm * lensAmt;

  vec4 g = blurred(sp, A.x);
  vec3 col = g.rgb;
  vec2 disp = nrm * lensAmt * A.w;
  col.r = mix(col.r, blurred(sp + disp, A.x * 0.5).r, t);
  col.b = mix(col.b, blurred(sp - disp, A.x * 0.5).b, t);

  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col += B.z * (1.0 - luma);
  col *= (1.0 - B.w);
  col = mix(col, tint.rgb, tint.a);

  vec2 L = vec2(cos(uGlobal.z), sin(uGlobal.z));
  float rimW = max(B.x * (1.0 + hc), 0.5);
  float rim = 1.0 - smoothstep(0.0, rimW, depth);
  float spec = rim * (max(dot(nrm, L), 0.0) + 0.35 * max(dot(nrm, -L), 0.0));
  col += B.y * (1.0 + hc) * spec;

  if (uTouch.z > 0.0) {
    vec2 dt = px - uTouch.xy;
    float gr = max(uTouch.w, 1.0);
    col += 0.25 * uTouch.z * exp(-dot(dt, dt) / (2.0 * gr * gr));
  }

  fragColor = vec4(mix(base.rgb, clamp(col, 0.0, 1.0), inside), 1.0);
}
