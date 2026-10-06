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
uniform vec4 uInfo[16];    // radius px, variant(0 regular, 1 clear), cornerExponent (0 = global), fill scale
uniform vec4 uTints[16];   // rgb, strength
uniform vec4 uVar[24];     // per variant (regular A-L, then clear A-L):
                           //   A(lens decay px, band px, lens strength, disp) B(rimW, rimI, fillOpacity, dim)
                           //   C(shadowR, shadowO, tintS, lens size ref px) D(fillR, fillG, fillB, saturation)
                           //   E(frost wide sigma px, wide mix edge, wide mix centre, wide size ref px)
                           //   F(wide size drop, glow strength, post-lens blur share, normal radius scale)
                           //   G, H, I.x: tone LUT, 9 grey output knots at inputs i/8 (Task 17d)
                           //   I.yzw(lens edge px, lens edge decay px, tone lift)
                           //   J(rim mix, rim mix width px, rim mix cut px, rim mix luma floor)
                           //   K(tone lift knee, tone lift size ref px, post-lens sigma px, blur size ref px)
                           //   L(rim back strength, lens vertical-only weight, -, -)
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

// Index-free: the uniform arrays are indexed only inside the
// constant-bounded loops, whose induction variable SkSL accepts as a
// constant index expression (a function parameter is not one). `rs` scales
// the corner radius (lens normals; 1 = the outline).
float shapeOf(vec2 p, vec4 rc, vec4 info, float rs) {
  vec2 hs = rc.zw * 0.5;
  float n = info.z > 0.0 ? info.z : uGlobal2.y;
  return sdSuperellipseBox(p - (rc.xy + hs), hs, info.x * rs, n);
}

float smin(float a, float b, float k) {
  if (k <= 0.0) return min(a, b);
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

// Lens field (Task 17d, measured: SwiftUI displaces along the normals of a
// rounder rect): the smooth union of the shapes with each corner radius x
// its variant's normal radius scale (capped at half the shorter side by
// sdSuperellipseBox). Its gradient gives the lens normals.
float lensField(vec2 p) {
  float d = 1e6;
  for (int i = 0; i < 16; i++) {
    if (i >= int(uGlobal.x)) break;
    vec4 info = uInfo[i];
    float rs = mix(uVar[5].w, uVar[17].w, info.y);
    d = smin(d, shapeOf(p, uRects[i], info, rs), uGlobal2.x);
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
  float fillScale = 0.0;  // per-shape fillOpacity factor (fill size scaling)
  vec4 tint = vec4(0.0);
  float d = 1e6;
  float wk = uGlobal2.x * 0.5 + 1.0;
  float dmin = 1e6;
  for (int i = 0; i < 16; i++) {
    if (i >= count) break;
    vec4 info = uInfo[i];
    float di = shapeOf(px, uRects[i], info, 1.0);
    d = smin(d, di, uGlobal2.x);
    float e = max(di, 0.0);
    if (e < dmin) {
      float s = exp(-(dmin - e) / wk);
      wsum *= s;
      clearMix *= s;
      halfMin *= s;
      fillScale *= s;
      tint *= s;
      dmin = e;
    }
    float w = exp(-(e - dmin) / wk);
    wsum += w;
    clearMix += w * info.y;
    halfMin += w * 0.5 * min(uRects[i].z, uRects[i].w);
    fillScale += w * info.w;
    tint += w * uTints[i];
  }
  clearMix /= wsum;
  halfMin /= wsum;
  fillScale /= wsum;
  tint /= wsum;

  vec4 A = mix(uVar[0], uVar[12], clearMix);
  vec4 B = mix(uVar[1], uVar[13], clearMix);
  vec4 C = mix(uVar[2], uVar[14], clearMix);
  vec4 D = mix(uVar[3], uVar[15], clearMix);
  vec4 E = mix(uVar[4], uVar[16], clearMix);
  vec4 F = mix(uVar[5], uVar[17], clearMix);
  vec4 G = mix(uVar[6], uVar[18], clearMix);
  vec4 H = mix(uVar[7], uVar[19], clearMix);
  vec4 I = mix(uVar[8], uVar[20], clearMix);
  vec4 J = mix(uVar[9], uVar[21], clearMix);
  vec4 K = mix(uVar[10], uVar[22], clearMix);
  vec4 L4 = mix(uVar[11], uVar[23], clearMix);
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

  float fxp = lensField(px + vec2(1.0, 0.0));
  float fxm = lensField(px - vec2(1.0, 0.0));
  float fyp = lensField(px + vec2(0.0, 1.0));
  float fym = lensField(px - vec2(0.0, 1.0));
  vec2 grad = vec2(fxp - fxm, fyp - fym) + vec2(1e-6);
  float gradLen = length(grad);
  vec2 nrm = grad / gradLen;

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
  float ls = max(decay * sc, 1e-3);
  float ex = exp(-max(depth, 0.0) / ls);
  float v = max(ex - cut, 0.0) / max(1.0 - cut, 1e-6);
  float lensK = A.z * (1.0 - 0.5 * hc) * band * sc;
  float lensAmt = lensK * v;
  // d(lensAmt)/d(depth), for the post-lens blur's Jacobian.
  float dLens = v > 0.0 ? -lensK * ex / ls / max(1.0 - cut, 1e-6) : 0.0;
  // Lens edge term (Task 17d, measured: SwiftUI's lens is steeper in the
  // outer 1-2 pt): an extra inward offset I.y x exp(-depth / I.z).
  float le = I.y * exp(-max(depth, 0.0) / max(I.z, 1e-3));
  lensAmt -= le;
  dLens += le / max(I.z, 1e-3);
  // Vertical-only lens (iOS 26's tab lens): with L.y > 0 the lens bends
  // less where the outline faces sideways, so a capsule's round ends stay
  // clear (weight 1 - L.y x smoothstep(0, 0.7, |nrm.x|)).
  if (L4.y > 0.0) {
    float wv = 1.0 - L4.y * smoothstep(0.0, 0.7, abs(nrm.x));
    lensAmt *= wv;
    dLens *= wv;
  }
  vec2 sp = px + nrm * lensAmt;

  // Frost v2, measured from SwiftUI (Task 17c, tool/fidelity/measure_frost.py):
  // a sharp core plus a wide tail, (1 - w) G(core) + w G(core + wide). The
  // texture is already blurred by the core sigma; the tail is 16 taps of it
  // on two rings (6 + 10; the 2-node Gauss-Laguerre rule for a 2-D Gaussian
  // of sigma E.x), so the input is low-passed and the sparse kernel does not
  // alias. w follows the depth of the point the lens samples (the band shows
  // the interior mirrored, with the interior's frost) relative to the half
  // shorter side, minus a size term for small shapes. Cost: 16 extra taps,
  // only where w > 0 (glass_model.py places them identically).
  // Post-lens blur (Task 17d): SwiftUI applies part of the frost after
  // refraction. The composed blur is sigma x sqrt(1 - share); the rest,
  // per variant K.z = sigma x sqrt(share) (x the frost size scale when
  // K.w > 0), is a 3x3 Gauss-Hermite rule in screen space mapped through
  // the lens's Jacobian: 1 - dL/ddepth along the normal, 1 + L x curvature
  // along the tangent (curvature of the lens field's level set,
  // Laplacian / |gradient|). Skipped below 0.25 px. The centre tap is the
  // plain lens sample `base`, reused by dispersion.
  vec3 base = tex(sp).rgb;
  vec3 col = base;
  float sPost = K.z * (K.w > 0.0 ? min(1.0, halfMin / K.w) : 1.0);
  if (sPost >= 0.25) {
    // The lens field equals the outline's field when no variant rounds it.
    float fc = (uVar[5].w == 1.0 && uVar[17].w == 1.0) ? d : lensField(px);
    float lap = fxp + fxm + fyp + fym - 4.0 * fc;
    float kappa = lap / max(0.5 * gradLen, 1e-3);
    float ja = clamp(1.0 - dLens, -4.0, 4.0) * sPost;
    float jb = clamp(1.0 + lensAmt * kappa, -4.0, 4.0) * sPost;
    vec2 tng = vec2(-nrm.y, nrm.x);
    col = base * 0.44444445;
    for (int i = 0; i < 3; i++) {
      float on = float(i - 1) * 1.7320508;
      float wn = i == 1 ? 0.6666667 : 0.1666667;
      for (int j = 0; j < 3; j++) {
        if (i == 1 && j == 1) continue;
        float ot = float(j - 1) * 1.7320508;
        float wt = j == 1 ? 0.6666667 : 0.1666667;
        col += (wn * wt) * tex(sp + nrm * (ja * on) + tng * (jb * ot)).rgb;
      }
    }
  }
  float hmw = max(halfMin, 1.0);
  float wideW = E.y + (E.z - E.y) * (depth - lensAmt) / hmw;
  if (E.w > 0.0) wideW -= F.x * max(0.0, 1.0 - hmw / E.w);
  wideW = E.x > 0.0 ? clamp(wideW, 0.0, 1.0) : 0.0;
  if (wideW > 0.0) {
    vec3 ring1 = vec3(0.0);
    for (int i = 0; i < 6; i++) {
      float a = float(i) * 1.0471976;
      ring1 += tex(sp + (E.x * 1.0823922) * vec2(cos(a), sin(a))).rgb;
    }
    vec3 ring2 = vec3(0.0);
    for (int i = 0; i < 10; i++) {
      float a = 0.31415927 + float(i) * 0.62831853;
      ring2 += tex(sp + (E.x * 2.6131259) * vec2(cos(a), sin(a))).rgb;
    }
    vec3 wide = ring1 * (0.8535534 / 6.0) + ring2 * (0.1464466 / 10.0);
    col = mix(col, wide, wideW);
  }
  // The dispersed red/blue taps carry the core channel's full frost offset
  // (post-lens blur + wide mix), so dispersion 0 is an exact no-op and a
  // grey backdrop stays grey (the offset must be measured after the wide
  // mix, not before it).
  if (A.w != 0.0) {
    vec3 coreOff = col - base;
    vec2 disp = nrm * lensAmt * abs(A.w);
    float dw = v;
    col.r = mix(col.r, tex(sp + disp).r + coreOff.r, dw);
    // Negative dispersion (iOS's tab lens) moves green with blue, so a
    // blue tint fringes in shades of blue instead of green.
    vec3 sm = tex(sp - disp).rgb + coreOff;
    col.b = mix(col.b, sm.b, dw);
    if (A.w < 0.0) col.g = mix(col.g, sm.g, dw);
  }

  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(luma), col, D.w);

  // Tone LUT (Task 17d, glass_model.tone_apply): 9 grey knots at inputs
  // i/8, hat-sum form, on the frosted backdrop before the fill wash (where
  // SwiftUI's flat-grey response places it); identity knots reproduce col.
  vec3 c8 = col * 8.0;
  col = vec3(G.x)
      + (vec3(G.y) - vec3(G.x)) * clamp(c8, 0.0, 1.0)
      + (vec3(G.z) - vec3(G.y)) * clamp(c8 - 1.0, 0.0, 1.0)
      + (vec3(G.w) - vec3(G.z)) * clamp(c8 - 2.0, 0.0, 1.0)
      + (vec3(H.x) - vec3(G.w)) * clamp(c8 - 3.0, 0.0, 1.0)
      + (vec3(H.y) - vec3(H.x)) * clamp(c8 - 4.0, 0.0, 1.0)
      + (vec3(H.z) - vec3(H.y)) * clamp(c8 - 5.0, 0.0, 1.0)
      + (vec3(H.w) - vec3(H.z)) * clamp(c8 - 6.0, 0.0, 1.0)
      + (vec3(I.x) - vec3(H.w)) * clamp(c8 - 7.0, 0.0, 1.0);

  // Small-shape shadow lift (Task 17d / 8b, fitted): SwiftUI lifts the dark
  // end behind small dark glass. + I.w x size x max(0, 1 - col / K.x)^2,
  // size = max(0, 1 - halfMin / K.y).
  float liftSz = K.y > 0.0 ? max(0.0, 1.0 - halfMin / max(K.y, 1e-3)) : 0.0;
  vec3 lk = max(vec3(1.0) - col / max(K.x, 1e-3), vec3(0.0));
  col += (I.w * liftSz) * lk * lk;

  col = mix(col, D.rgb, B.z * fillScale);
  col *= (1.0 - B.w);
  col = mix(col, tint.rgb, tint.a);

  vec2 L = vec2(cos(uGlobal.z), sin(uGlobal.z));
  float rimW = max(B.x * (1.0 + hc), 0.5);
  float rim = 1.0 - smoothstep(0.0, rimW, depth);
  float spec = rim * (max(dot(nrm, L), 0.0) + L4.x * max(dot(nrm, -L), 0.0));
  col += B.y * (1.0 + hc) * spec;

  // Isotropic rim (Task 17d, measured on clear glass): a mix toward white,
  // alpha J.x ramping to 0 at depth J.y, cut at J.z; scaled by the glass
  // luminance down to J.w (dark mode).
  float ra = J.x * clamp(1.0 - depth / max(J.y, 1e-3), 0.0, 1.0)
      * (1.0 - smoothstep(J.z - 0.5, J.z + 0.5, depth));
  float rl = dot(col, vec3(0.2126, 0.7152, 0.0722));
  ra *= J.w + (1.0 - J.w) * clamp(rl / 0.5, 0.0, 1.0);
  col += (1.0 - col) * ra;

  if (uTouch.z > 0.0) {
    vec2 dt = px - uTouch.xy;
    float gr = max(uTouch.w, 1.0);
    col += F.y * uTouch.z * exp(-dot(dt, dt) / (2.0 * gr * gr));
  }

  fragColor = vec4(clamp(col, 0.0, 1.0) * inside, inside) + shadow;
}
