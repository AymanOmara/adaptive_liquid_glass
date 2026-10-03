#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

uniform vec2 uSize;
uniform vec4 uArr[4];
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  float arrayOk = step(0.24, uArr[2].x) * step(uArr[2].x, 0.26);
  fragColor = vec4(p.x / uSize.x, p.y / uSize.y, (uSize.x / 4096.0) * arrayOk, 1.0);
}
