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
uniform vec4 uInfo[16];    // radius px, variant(0 regular, 1 clear), cornerExponent (0 = global), -
uniform vec4 uTints[16];   // rgb, strength
uniform vec4 uVar[8];      // per variant (regular A-D, then clear A-D):
                           //   A(lens decay px, band px, lens strength, disp) B(rimW, rimI, fillOpacity, dim)
                           //   C(shadowR, shadowO, tintS, lens size ref px) D(fillR, fillG, fillB, saturation)
// uTexture is the backdrop already blurred by ImageFilter.blur (composed
// before this shader). FlutterFragCoord is screen-global; uSize is the
// blurred input's size, which may exceed the screen on the right/bottom, so
// sampling at px / uSize still returns the pixel under px.
uniform sampler2D uTexture;

out vec4 fragColor;

vec4 tex(vec2 px) {
  vec2 uv = clamp(px / uSize, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv);
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
  float n = uInfo[i].z > 0.0 ? uInfo[i].z : uGlobal2.y;
  return sdSuperellipseBox(p - (rc.xy + hs), hs, uInfo[i].x, n);
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
  // Output is premultiplied colour composited srcOver onto the sharp
  // backdrop: transparent outside the shape except for the shadow.
  vec2 px = FlutterFragCoord().xy;
  int count = int(uGlobal.x);
  if (count == 0) { fragColor = vec4(0.0); return; }

  // Per-shape attributes blended by proximity (for merged regions).
  // Weights are shifted by the nearest distance (online softmax) so the
  // nearest shape always weighs 1: raw exp(-dist/k) underflows to 0 beyond
  // ~87 px and wsum = 0 turned every attribute into NaN (black output).
  float wsum = 0.0;
  float clearMix = 0.0;
  float halfMin = 0.0;  // half the shorter side, for the lens size factor
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
      halfMin *= s;
      tint *= s;
      dmin = e;
    }
    float w = exp(-(e - dmin) / wk);
    wsum += w;
    clearMix += w * uInfo[i].y;
    halfMin += w * 0.5 * min(uRects[i].z, uRects[i].w);
    tint += w * uTints[i];
  }
  clearMix /= wsum;
  halfMin /= wsum;
  tint /= wsum;

  vec4 A = mix(uVar[0], uVar[4], clearMix);
  vec4 B = mix(uVar[1], uVar[5], clearMix);
  vec4 C = mix(uVar[2], uVar[6], clearMix);
  vec4 D = mix(uVar[3], uVar[7], clearMix);
  float hc = uGlobal2.z;

  float inside = 1.0 - smoothstep(-0.75, 0.75, d);

  // Shadow outside the shape; full strength at the edge (max(d, 0)). It is
  // black at alpha `sh` over the untouched backdrop, and is also kept under
  // the anti-aliased edge (|d| < 0.75) so no bright ring appears there.
  float sr = max(C.x * 0.5, 1.0);
  float dOut = max(d, 0.0);
  float sh = C.y * exp(-(dOut * dOut) / (2.0 * sr * sr));
  vec4 shadow = vec4(0.0, 0.0, 0.0, sh) * (1.0 - inside);
  if (inside <= 0.0) {
    fragColor = shadow;
    return;
  }

  // Opaque (Reduce Transparency).
  if (uGlobal.w > 0.5) {
    vec3 solid = mix(uOpaque.rgb, tint.rgb, tint.a);
    fragColor = vec4(solid * inside, inside) + shadow;
    return;
  }

  float e = 1.0;
  vec2 nrm = vec2(field(px + vec2(e, 0.0)) - field(px - vec2(e, 0.0)),
                  field(px + vec2(0.0, e)) - field(px - vec2(0.0, e)));
  nrm = normalize(nrm + vec2(1e-6));

  // Lens v3, measured from SwiftUI (Task 15c, tool/fidelity/measure_lens.py):
  // the displacement along the normal falls off exponentially with depth
  // (length `decay`) and is cut to 0 at `band`. At the edge it is
  // strength x band (about -47 pt: the outer pixels sample deep inside, so
  // the band shows a mirrored, compressed copy of the interior). Shapes with
  // a half shorter side below the size ref get a uniformly scaled-down lens.
  float depth = -d;
  float band = max(A.y, 1.0);
  float decay = max(A.x, 1e-3);
  float sc = C.w > 0.0 ? min(1.0, halfMin / C.w) : 1.0;
  float cut = exp(-band / decay);
  float v = max(exp(-max(depth, 0.0) / max(decay * sc, 1e-3)) - cut, 0.0) / (1.0 - cut);
  float lensAmt = A.z * (1.0 - 0.5 * hc) * band * sc * v;
  vec2 sp = px + nrm * lensAmt;

  vec3 col = tex(sp).rgb;
  vec2 disp = nrm * lensAmt * A.w;
  col.r = mix(col.r, tex(sp + disp).r, v);
  col.b = mix(col.b, tex(sp - disp).b, v);

  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(luma), col, D.w);
  col = mix(col, D.rgb, B.z);
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

  fragColor = vec4(clamp(col, 0.0, 1.0) * inside, inside) + shadow;
}
