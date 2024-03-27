precision highp float;

// Samplers
varying vec2 vUV;

uniform sampler2D textureSampler;
uniform sampler2D weatherMap;
uniform float time;

uniform vec2 screenSize;
uniform vec3 cameraPosition;
uniform mat4x4 cameraMatrix;
uniform mat4x4 projectionMatrix;

const float divisions = 8.0;

vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float mod289(float x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
  return mod289((x * 34.0 + 10.0) * x);
}

float permute(float x) {
  return mod289((x * 34.0 + 10.0) * x);
}

vec4 taylorInvSqrt(vec4 r) {
  return 1.79284291400159 - 0.85373472095314 * r;
}

float taylorInvSqrt(float r) {
  return 1.79284291400159 - 0.85373472095314 * r;
}

vec4 grad4(float j, vec4 ip) {
  const vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
  vec4 p, s;

  p.xyz = floor(fract(vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
  p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
  s = vec4(lessThan(p, vec4(0.0)));
  p.xyz = p.xyz + (s.xyz * 2.0 - 1.0) * s.www;

  return p;
}

// (sqrt(5) - 1)/4 = F4, used once below
#define F4 (0.309016994374947451)

float snoise(vec4 v) {
  const vec4 C = vec4(
    0.138196601125011, // (5 - sqrt(5))/20  G4
    0.276393202250021, // 2 * G4
    0.414589803375032, // 3 * G4
    -0.447213595499958
  ); // -1 + 4 * G4

  // First corner
  vec4 i = floor(v + dot(v, vec4(F4)));
  vec4 x0 = v - i + dot(i, C.xxxx);

  // Other corners

  // Rank sorting originally contributed by Bill Licea-Kane, AMD (formerly ATI)
  vec4 i0;
  vec3 isX = step(x0.yzw, x0.xxx);
  vec3 isYZ = step(x0.zww, x0.yyz);
  //  i0.x = dot( isX, vec3( 1.0 ) );
  i0.x = isX.x + isX.y + isX.z;
  i0.yzw = 1.0 - isX;
  //  i0.y += dot( isYZ.xy, vec2( 1.0 ) );
  i0.y += isYZ.x + isYZ.y;
  i0.zw += 1.0 - isYZ.xy;
  i0.z += isYZ.z;
  i0.w += 1.0 - isYZ.z;

  // i0 now contains the unique values 0,1,2,3 in each channel
  vec4 i3 = clamp(i0, 0.0, 1.0);
  vec4 i2 = clamp(i0 - 1.0, 0.0, 1.0);
  vec4 i1 = clamp(i0 - 2.0, 0.0, 1.0);

  //  x0 = x0 - 0.0 + 0.0 * C.xxxx
  //  x1 = x0 - i1  + 1.0 * C.xxxx
  //  x2 = x0 - i2  + 2.0 * C.xxxx
  //  x3 = x0 - i3  + 3.0 * C.xxxx
  //  x4 = x0 - 1.0 + 4.0 * C.xxxx
  vec4 x1 = x0 - i1 + C.xxxx;
  vec4 x2 = x0 - i2 + C.yyyy;
  vec4 x3 = x0 - i3 + C.zzzz;
  vec4 x4 = x0 + C.wwww;

  // Permutations
  i = mod289(i);
  float j0 = permute(permute(permute(permute(i.w) + i.z) + i.y) + i.x);
  vec4 j1 = permute(
    permute(
      permute(permute(i.w + vec4(i1.w, i2.w, i3.w, 1.0)) + i.z + vec4(i1.z, i2.z, i3.z, 1.0)) +
        i.y +
        vec4(i1.y, i2.y, i3.y, 1.0)
    ) +
      i.x +
      vec4(i1.x, i2.x, i3.x, 1.0)
  );

  // Gradients: 7x7x6 points over a cube, mapped onto a 4-cross polytope
  // 7*7*6 = 294, which is close to the ring size 17*17 = 289.
  vec4 ip = vec4(1.0 / 294.0, 1.0 / 49.0, 1.0 / 7.0, 0.0);

  vec4 p0 = grad4(j0, ip);
  vec4 p1 = grad4(j1.x, ip);
  vec4 p2 = grad4(j1.y, ip);
  vec4 p3 = grad4(j1.z, ip);
  vec4 p4 = grad4(j1.w, ip);

  // Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;
  p4 *= taylorInvSqrt(dot(p4, p4));

  // Mix contributions from the five corners
  vec3 m0 = max(0.6 - vec3(dot(x0, x0), dot(x1, x1), dot(x2, x2)), 0.0);
  vec2 m1 = max(0.6 - vec2(dot(x3, x3), dot(x4, x4)), 0.0);
  m0 = m0 * m0;
  m1 = m1 * m1;
  return 49.0 *
  (dot(m0 * m0, vec3(dot(p0, x0), dot(p1, x1), dot(p2, x2))) +
    dot(m1 * m1, vec2(dot(p3, x3), dot(p4, x4))));

}

//
// Hash function by Dave_Hoskins
vec4 hash44(vec4 p4) {
  p4 = fract(p4 * vec4(0.1031, 0.103, 0.0973, 0.1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// 4D Cellular (Worley) noise function
float cellular(vec4 p) {
  const float K1 = 0.142857142857; // 1/7
  const float K2 = 0.428571428571; // 3/7
  const float K3 = 0.714285714286; // 5/7

  vec4 Pi = floor(p);
  vec4 Pf = fract(p);
  float F1 = 1e6; // Initialize F1 and F2 to large values
  float F2 = 1e6;

  for (int i = -1; i <= 1; i++) {
    for (int j = -1; j <= 1; j++) {
      for (int k = -1; k <= 1; k++) {
        for (int l = -1; l <= 1; l++) {
          vec4 offset = vec4(i, j, k, l);
          vec4 position = Pi + offset;
          vec4 feature = hash44(position);
          vec4 diff = offset + feature - Pf;
          float dist = dot(diff, diff);

          if (
            dist <
            F1 // If this distance is smaller than the current F1
          ) {
            F2 = F1; // then update F2 to be the old F1
            F1 = dist; // and update F1 to be the new smallest distance
          } else if (
            dist <
            F2 // Otherwise, if this distance is smaller than the current F2
          ) {
            F2 = dist; // then update F2 to be the new second smallest distance
          }
        }
      }
    }
  }

  // Compute the final cellular noise value
  return (F1 + F2) * 0.5;
}

float remap(float value, float inputMin, float inputMax, float outputMin, float outputMax) {
  return outputMin + (value - inputMin) * (outputMax - outputMin) / (inputMax - inputMin);
}

bool intersectRayWithAABB(vec3 rayOrigin, vec3 rayDirection, vec3 aabbMin, vec3 aabbMax) {
  vec3 invDir = 1.0 / rayDirection;
  vec3 t1 = (aabbMin - rayOrigin) * invDir;
  vec3 t2 = (aabbMax - rayOrigin) * invDir;

  vec3 tMin3 = min(t1, t2);
  vec3 tMax3 = max(t1, t2);

  float tMin = max(max(tMin3.x, tMin3.y), tMin3.z);
  float tMax = min(min(tMax3.x, tMax3.y), tMax3.z);

  return tMax >= tMin && tMax >= 0.0;
}

void main(void ) {
  vec3 area_center = vec3(0.0, 0.0, 0.0);
  vec3 area_size = vec3(0.5, 0.25, 0.5);

  vec3 areaMin = area_center - vec3(area_size.x, area_size.y, area_size.z) * 0.5;
  vec3 areaMax = area_center + vec3(area_size.x, area_size.y, area_size.z) * 0.5;

  vec4 c = texture2D(textureSampler, vUV);

  float t = 1.0;
  float scale = 2.0;
  float scaleHigh = 4.0;
  float scaleBest = 8.0;

  vec4 coord = vec4(vUV.x * scale, vUV.y * scale, 1.0 * scale, t);
  vec4 coordHigh = vec4(vUV.x * scaleHigh, vUV.y * scaleHigh, 1.0 * scaleHigh, t);
  vec4 coordBest = vec4(vUV.x * scaleBest, vUV.y * scaleBest, 1.0 * scaleBest, t);
  float celler = cellular(coord);
  float perlin = snoise(coord);

  float r = snoise(coord);
  float g = cellular(coord);
  float b = cellular(coordHigh);
  float a = cellular(coordBest);

  vec4 shape_sample = vec4(r, g, b, a);
  float shape_noise = shape_sample.g * 0.625 + shape_sample.b * 0.25 + shape_sample.a * 0.125;
  shape_noise = -(1.0 - shape_noise);
  shape_noise = remap(shape_sample.r, shape_noise, 1.0, 0.0, 1.0);

  //rayの計算
  vec2 ndc = vUV.xy * 2.0 - 1.0;
  vec4 clipSpace = vec4(ndc, -1.0, 1.0);

  // クリップ空間座標をビュー空間座標に変換
  vec4 viewSpace = inverse(projectionMatrix) * clipSpace;
  viewSpace = vec4(viewSpace.xy, 1.0, 0.0);

  // ビュー空間座標をワールド空間座標に変換
  vec3 worldSpace = (inverse(cameraMatrix) * viewSpace).xyz;
  vec3 rayDirection = normalize(worldSpace - cameraPosition);
  vec3 rayOrigin = cameraPosition;

  //   bool flag = intersectRayWithAABB(rayOrigin, rayDirection, areaMin, areaMax);
  //   if (flag) {
  //     c = vec4(1.0, 0.0, 0.0, 1.0);
  //   }

  gl_FragColor = c;
}
