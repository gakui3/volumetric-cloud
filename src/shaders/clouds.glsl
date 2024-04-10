precision highp float;

// Samplers
varying vec2 vUV;

uniform sampler2D textureSampler;
uniform sampler2D weatherMap;
uniform sampler2D blueNoiseTex;

uniform vec2 screenSize;
uniform vec3 cameraPosition;
uniform mat4x4 cameraMatrix;
uniform mat4x4 projectionMatrix;
uniform float time;
// uniform vec3 lightDirection;
uniform int lightSteps;
uniform float cloudsAreaWidth;
uniform float cloudsAreaDepth;
uniform float lightDirX;
uniform float lightDirY;
uniform float lightDirZ;

const float cloudsAreaHeight = 0.5;
// const float cloudsAreaWidth = 1.0;
// const float cloudsAreaDepth = 1.0;
// const float stepSize = 0.01;
const vec3 area_center = vec3(0.0, 0.0, 0.0);
// const vec3 area_size = vec3(1.0, 0.5, 1.0);
// const float g_c = 0.75; //
// const float g_d = 1.0; //雲のグローバルな不透明度
const float heightMapFactor = 0.95;
// const vec3 noiseWeights = vec3(10.5, 7.25, 2.125);
// const vec3 detailWeights = vec3(0.99, 0.21, 0.15);
// const float volumeOffset = 2.5;
// const int lightSteps = 5;
const float transmitThreshold = 0.65;
const float outScatterMultiplier = 0.5;
const float inScatterMultiplier = 0.25;
// const vec3 lightDirection = vec3(0.3, 1.0, -0.1);
const float rayOffset = 0.01;

vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float mod289(float x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

// Modulo 7 without a division
vec4 mod7(vec4 x) {
  return x - floor(x * (1.0 / 7.0)) * 7.0;
}

vec4 permute(vec4 x) {
  return mod289((x * 34.0 + 10.0) * x);
}

vec3 permute(vec3 x) {
  return mod289((34.0 * x + 10.0) * x);
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

float snoiseFbm(vec4 v, int octaves) {
  float f = 0.0;
  float amplitude = 0.5;
  float frequency = 1.0;

  for (int i = 0; i < octaves; i++) {
    f += amplitude * snoise(frequency * v);
    frequency *= 2.0;
    amplitude *= 0.5;
  }

  return f;
}
//
// Hash function by Dave_Hoskins
vec4 hash44(vec4 p4) {
  p4 = fract(p4 * vec4(0.1031, 0.103, 0.0973, 0.1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

vec2 cellular2x2x2(vec3 P) {
  #define K (0.142857142857) // 1/7
  #define Ko (0.428571428571) // 1/2-K/2
  #define K2 (0.020408163265306) // 1/(7*7)
  #define Kz (0.166666666667) // 1/6
  #define Kzo (0.416666666667) // 1/2-1/6*2
  #define jitter (0.8) // smaller jitter gives less errors in F2
  vec3 Pi = mod289(floor(P));
  vec3 Pf = fract(P);
  vec4 Pfx = Pf.x + vec4(0.0, -1.0, 0.0, -1.0);
  vec4 Pfy = Pf.y + vec4(0.0, 0.0, -1.0, -1.0);
  vec4 p = permute(Pi.x + vec4(0.0, 1.0, 0.0, 1.0));
  p = permute(p + Pi.y + vec4(0.0, 0.0, 1.0, 1.0));
  vec4 p1 = permute(p + Pi.z); // z+0
  vec4 p2 = permute(p + Pi.z + vec4(1.0)); // z+1
  vec4 ox1 = fract(p1 * K) - Ko;
  vec4 oy1 = mod7(floor(p1 * K)) * K - Ko;
  vec4 oz1 = floor(p1 * K2) * Kz - Kzo; // p1 < 289 guaranteed
  vec4 ox2 = fract(p2 * K) - Ko;
  vec4 oy2 = mod7(floor(p2 * K)) * K - Ko;
  vec4 oz2 = floor(p2 * K2) * Kz - Kzo;
  vec4 dx1 = Pfx + jitter * ox1;
  vec4 dy1 = Pfy + jitter * oy1;
  vec4 dz1 = Pf.z + jitter * oz1;
  vec4 dx2 = Pfx + jitter * ox2;
  vec4 dy2 = Pfy + jitter * oy2;
  vec4 dz2 = Pf.z - 1.0 + jitter * oz2;
  vec4 d1 = dx1 * dx1 + dy1 * dy1 + dz1 * dz1; // z+0
  vec4 d2 = dx2 * dx2 + dy2 * dy2 + dz2 * dz2; // z+1

  // Sort out the two smallest distances (F1, F2)
  #if 0
  // Cheat and sort out only F1
  d1 = min(d1, d2);
  d1.xy = min(d1.xy, d1.wz);
  d1.x = min(d1.x, d1.y);
  return vec2(sqrt(d1.x));
  #else
  // Do it right and sort out both F1 and F2
  vec4 d = min(d1, d2); // F1 is now in d
  d2 = max(d1, d2); // Make sure we keep all candidates for F2
  d.xy = d.x < d.y ? d.xy : d.yx; // Swap smallest to d.x
  d.xz = d.x < d.z ? d.xz : d.zx;
  d.xw = d.x < d.w ? d.xw : d.wx; // F1 is now in d.x
  d.yzw = min(d.yzw, d2.yzw); // F2 now not in d2.yzw
  d.y = min(d.y, d.z); // nor in d.z
  d.y = min(d.y, d.w); // nor in d.w
  d.y = min(d.y, d2.x); // F2 is now in d.y
  return sqrt(d.xy); // F1 and F2
  #endif
}

vec2 cellularFbm(vec3 v, int octaves) {
  float f = 0.0;
  float amplitude = 0.5;
  float frequency = 1.0;

  for (int i = 0; i < octaves; i++) {
    f += amplitude * cellular2x2x2(v * frequency).x;
    frequency *= 2.0;
    amplitude *= 0.5;
  }

  return vec2(f, 1.0);
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

float beer(float d) {
  return exp(-d);
}

float heightMap(float h) {
  return mix(1.0, (1.0 - beer(1.0 * h)) * beer(4.0 * h), heightMapFactor);
}

vec3 getCloudAreaCoord(vec3 position) {
  mat4 cloudsMatrix = mat4(
    vec4(cloudsAreaWidth, 0.0, 0.0, 0.0),
    vec4(0.0, cloudsAreaWidth, 0.0, 0.0),
    vec4(0.0, 0.0, cloudsAreaDepth, 0.0),
    vec4(area_center, 1.0)
  );
  mat4 inverseCloudsMatrix = inverse(cloudsMatrix);

  vec3 localPosition = (inverseCloudsMatrix * vec4(position, 1.0)).xyz;
  // vec3 centeredPosition = localPosition - area_center;
  vec3 cloudsArea = vec3(cloudsAreaWidth, cloudsAreaHeight, cloudsAreaDepth);
  vec3 normalizedPosition = (localPosition + cloudsArea * 0.5) / cloudsArea;
  // normalizedPosition.y = heightMap(normalizedPosition.y);
  // vec2 weatherMapCoords = normalizedPosition.xz;
  return normalizedPosition;
}

vec3 getCloudsAreaMin() {
  return area_center - vec3(cloudsAreaWidth, cloudsAreaHeight, cloudsAreaDepth) * 0.5;
}

vec3 getCloudsAreaMax() {
  return area_center + vec3(cloudsAreaWidth, cloudsAreaHeight, cloudsAreaDepth) * 0.5;
}

float calculateDensity(vec3 position) {
  vec3 normalizedPosition = getCloudAreaCoord(position);

  //正規化したpositionの高さを取得
  // float p_h = normalizedPosition.y;
  // float shape_noise = snoise(vec4(weatherMapCoords * 2.0, 1.0, 1.0));
  // vec4 wc = texture2D(weatherMap, weatherMapCoords);

  float scale = 1.0;
  vec4 coord = vec4(
    normalizedPosition.x + time * 0.025,
    normalizedPosition.y * 0.5,
    normalizedPosition.z,
    1.0
  );

  float noise = clamp(snoise(coord * scale), 0.0, 1.0);
  // float fbm = dot(vec3(noise), normalize(noiseWeights));

  float shape0 = cellular2x2x2(coord.xyz * 2.0).x;
  float shape1 = cellular2x2x2(coord.xyz * 10.0).x;
  float shape2 = cellular2x2x2(coord.xyz * 30.0).x;

  float detail0 = cellular2x2x2(coord.xyz * 10.0).x;
  float detail2 = cellular2x2x2(coord.xyz * 20.0).x;

  float shapefbm = clamp(pow(snoiseFbm(coord, 3), 3.0) * 50.0, 0.0, 1.0);
  float detailfbm =
    1.0 - clamp(clamp(pow(cellularFbm(coord.xyz * 2.0, 4).x, 5.0), 0.0, 1.0) * 50.0, 0.0, 1.0);
  float shape = mix(shapefbm, detailfbm, 0.95);
  // shapefbm = shapefbm * heightMapValue;
  // shapefbm = dot(vec3(shapefbm), normalize(noiseWeights)) * heightMapValue;
  // detailfbm = dot(vec3(detailfbm), normalize(detailWeights)) * (1.0 - heightMapValue);

  // float cloudDensity = shapefbm + 10.0 * 0.1;

  float density = pow(shape, 2.0) * 5.0; //shape - detailfbm * pow(1.0 - shapefbm, 3.0) * 2.0;
  return density;
}

float maxComponent(vec3 vec) {
  return max(max(vec.x, vec.y), vec.z);
}
float minComponent(vec3 vec) {
  return min(min(vec.x, vec.y), vec.z);
}

vec2 slabs(vec3 p1, vec3 p2, vec3 rayPos, vec3 invRayDir) {
  vec3 t1 = (p1 - rayPos) * invRayDir;
  vec3 t2 = (p2 - rayPos) * invRayDir;
  return vec2(maxComponent(min(t1, t2)), minComponent(max(t1, t2)));
}

vec2 rayBox(vec3 boundsMin, vec3 boundsMax, vec3 rayPos, vec3 invRayDir) {
  vec2 slabD = slabs(boundsMin, boundsMax, rayPos, invRayDir);
  float toBox = max(0.0, slabD.x);
  return vec2(toBox, max(0.0, slabD.y - toBox));
}

float lightmarch(vec3 position) {
  vec3 L = normalize(vec3(lightDirX, lightDirY, lightDirZ));

  vec3 areaMin = getCloudsAreaMin();
  vec3 areaMax = getCloudsAreaMax();
  vec3 boundsMin = areaMin;
  vec3 boundsMax = areaMax;

  vec2 rayToBox = rayBox(boundsMin, boundsMax, position, 1.0 / L);
  float stepSize = rayToBox.y / float(lightSteps);

  float density = 0.0;
  vec3 pos = position;

  for (int i = 0; i < lightSteps; i++) {
    pos += L * stepSize;
    density += max(0.0, calculateDensity(pos) * stepSize * 5.0);
  }

  // float transmit = beer(density * (1.0 - outScatterMultiplier));
  float transmit = beer(density);
  // float transmit = density;
  return transmit;
}

void main(void ) {
  vec3 areaMin = getCloudsAreaMin();
  vec3 areaMax = getCloudsAreaMax();

  vec4 cameraImage = texture2D(textureSampler, vUV);

  float t = 1.0;
  float scale = 2.0;
  float scaleHigh = 4.0;
  float scaleBest = 8.0;

  //   vec4 coord = vec4(vUV.x * scale, vUV.y * scale, 1.0 * scale, t);
  //   vec4 coordHigh = vec4(vUV.x * scaleHigh, vUV.y * scaleHigh, 1.0 * scaleHigh, t);
  //   vec4 coordBest = vec4(vUV.x * scaleBest, vUV.y * scaleBest, 1.0 * scaleBest, t);
  //   float celler = cellular(coord);
  //   float perlin = snoise(coord);

  //   float r = snoise(coord);
  //   float g = cellular(coord);
  //   float b = cellular(coordHigh);
  //   float a = cellular(coordBest);

  //   vec4 shape_sample = vec4(r, g, b, a);
  //   float shape_noise = shape_sample.g * 0.625 + shape_sample.b * 0.25 + shape_sample.a * 0.125;
  //   shape_noise = -(1.0 - shape_noise);
  //   shape_noise = remap(shape_sample.r, shape_noise, 1.0, 0.0, 1.0);

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

  vec3 boundsMin = areaMin;
  vec3 boundsMax = areaMax;
  vec3 D = rayDirection;

  vec2 rayToBox = rayBox(boundsMin, boundsMax, cameraPosition, 1.0 / D);

  if (rayToBox.y <= 0.01) {
    gl_FragColor = cameraImage;
    return;
  }

  // vec3 boxHit = cameraPosition + D * rayToBox.x;
  // float density = calculateDensity(boxHit, inverseCloudsMatrix);
  // vec3 stepColor = vec3(density);
  // c.xyz = stepColor;

  float randomOffset = snoise(vec4(vUV * 500.0, 0.0, 1.0));
  // float randomOffset = texture2D(blueNoiseTex, vUV * 100000.0).y;
  float offset = randomOffset * 0.01;

  // 各レイのステップ数を計算
  float stepLimit = rayToBox.y;
  float stepSize = 0.05;
  float transmit = 1.0;
  vec3 I = vec3(0.0);

  for (float t = 0.0; t < stepLimit; t += stepSize) {
    vec3 currentPos = cameraPosition + D * (rayToBox.x + t);

    float density = calculateDensity(currentPos) * stepSize;

    if (density > 0.0) {
      I += density * transmit * lightmarch(currentPos);
      transmit *= beer(density);
    }
  }

  vec3 c = I + cameraImage.xyz * transmit;
  // vec3 c = I * 2.0;

  gl_FragColor = vec4(c, 1.0);
}
