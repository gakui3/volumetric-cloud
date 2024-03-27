precision highp float;

// Samplers
varying vec2 vUV;

uniform sampler2D textureSampler;
uniform sampler2D destSampler;

const float divisions = 8.0;

void main(void ) {
  vec4 c = texture2D(textureSampler, vUV);
  gl_FragColor = c;
}
