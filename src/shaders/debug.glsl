precision highp float;

// Samplers
varying vec2 vUV;

uniform sampler2D textureSampler;
uniform sampler2D destSampler;

const float divisions = 8.0;

void main(void ) {
  vec2 uv = vec2(1.0 - vUV.x, 1.0 - vUV.y);

  vec2 repeatUV = vec2(fract(uv.x * 8.0), fract(uv.y * divisions));
  float xIdx = floor(uv.x * divisions);
  float yIdx = floor(uv.y * divisions);
  // vec2 ruv = vec2(1.0 - uv.x, uv.y);

  vec4 c = texture2D(textureSampler, vUV);
  //   vec4 c = texture2D(destSampler, vUV);

  if (xIdx == 0.0 && yIdx == 0.0) {
    vec4 col = texture2D(destSampler, repeatUV);
    c = vec4(col.x, col.x, col.x, 1.0);
  }
  if (xIdx == 0.0 && yIdx == 1.0) {
    vec4 col = texture2D(destSampler, repeatUV);
    c = vec4(col.y, col.y, col.y, 1.0);
  }
  if (xIdx == 0.0 && yIdx == 2.0) {
    vec4 col = texture2D(destSampler, repeatUV);
    c = vec4(col.z, col.z, col.z, 1.0);
  }
  if (xIdx == 0.0 && yIdx == 3.0) {
    vec4 col = texture2D(destSampler, repeatUV);
    c = vec4(col.w, col.w, col.w, 1.0);
  }

  gl_FragColor = c;
}
