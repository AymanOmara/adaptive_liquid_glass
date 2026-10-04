#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 uSize;
uniform vec4 uArr[4];   // uArr[2].x = 0.25 (array check); uArr[3].x > 0.5 = pass-through;
                        // uArr[3].y = exact readout mode (see main)
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  // uArr[3].y = 1..4: exact readout of fragX, fragY, uSize.x, uSize.y as
  // (low byte, high byte, fraction).
  int mode = int(uArr[3].y + 0.5);
  if (mode > 0) {
    float q = mode == 1 ? p.x : mode == 2 ? p.y : mode == 3 ? uSize.x : uSize.y;
    float f = floor(q);
    fragColor = vec4(mod(f, 256.0) / 255.0, floor(f / 256.0) / 255.0, fract(q), 1.0);
    return;
  }
  if (uArr[3].x > 0.5) {
    vec2 uv = p / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
#endif
    fragColor = texture(uTexture, uv);
    return;
  }
  float arrayOk = step(0.24, uArr[2].x) * step(uArr[2].x, 0.26);
  fragColor = vec4(p.x / uSize.x, p.y / uSize.y, (uSize.x / 4096.0) * arrayOk, 1.0);
}
