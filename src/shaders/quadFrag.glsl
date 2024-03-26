#version 300 es

precision highp float;

in vec2 vUv;
out vec4 fragColor;
uniform sampler2D textureSampler;

void main(void ) {
  //   fragColor = vec4(1.0, 0.0, 0.0, 1.0);
  vec2 uv = vec2(1.0 - vUv.x, 1.0 - vUv.y);
  fragColor = texture(textureSampler, uv);
}
