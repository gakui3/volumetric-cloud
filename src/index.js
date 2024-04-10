import * as BABYLON from '@babylonjs/core';
import Stats from 'stats-js';

import quadVert from './shaders/quadVert.glsl?raw';
import quadFrag from './shaders/quadFrag.glsl?raw';
import debug from './shaders/debug.glsl?raw';
import clouds from './shaders/clouds.glsl?raw';

// publicフォルダに配置した画像を読み込む
import testimg from '/testimg.png';
import blueNoiseImg from '/BlueNoise.png';

const stats = new Stats();
stats.showPanel(0); // 0: fps, 1: ms, 2: mb, 3+: custom
document.body.appendChild(stats.dom);

const canvas = document.getElementById('renderCanvas');
const engine = new BABYLON.Engine(canvas);
const scene = new BABYLON.Scene(engine);
// const camera = new BABYLON.FreeCamera('camera1', new BABYLON.Vector3(0.0, 0.1, -10), scene);
// camera.setTarget(BABYLON.Vector3.Zero());

const camera = new BABYLON.ArcRotateCamera('Camera', 0, 0, 10, new BABYLON.Vector3(0, 0, 0), scene);
camera.setPosition(new BABYLON.Vector3(0, 0, 10));

camera.attachControl(canvas, true);

const light = new BABYLON.DirectionalLight('light1', new BABYLON.Vector3(0.1, 1, -0.1), scene);
light.intensity = 1.0;

// 元のテクスチャ
const src = new BABYLON.Texture(testimg, scene);
// 出力先のテクスチャ
const weatherMap = new BABYLON.RenderTargetTexture('weatherMap', 1024, scene);

const quadScene = new BABYLON.Scene(engine);
const quadCamera = new BABYLON.FreeCamera('quadCamera', new BABYLON.Vector3(0, 0, -1), quadScene);

const blueNoiseTex = new BABYLON.Texture(blueNoiseImg, scene);

let time = 0;

const quad = BABYLON.MeshBuilder.CreatePlane('quad', { size: 2 }, quadScene);
const shaderMaterial = new BABYLON.ShaderMaterial(
  'shaderMaterial',
  quadScene,
  {
    vertexSource: quadVert,
    fragmentSource: quadFrag,
  },
  {
    attributes: ['position', 'uv'],
    uniforms: ['textureSampler', 'time'],
  }
);
shaderMaterial.setTexture('textureSampler', src);
quad.material = shaderMaterial;

weatherMap.renderList.push(quad);
quadScene.customRenderTargets.push(weatherMap);

// 球体を作成してマテリアルを適用し、レンダーターゲットテクスチャをテクスチャとして使用
// var sphere = BABYLON.MeshBuilder.CreateSphere('sphere', { diameter: 2, segments: 32 }, scene);
// var sphereMaterial = new BABYLON.StandardMaterial('sphereMat', scene);
// sphereMaterial.diffuseTexture = weatherMap;
// sphere.material = sphereMaterial;

BABYLON.Effect.ShadersStore.cloudsFragmentShader = clouds;
const cloudsPP = new BABYLON.PostProcess(
  'Clouds',
  'clouds',
  [
    'weatherMap',
    'blueNoiseTex',
    'time',
    'screenSize',
    'cameraMatrix',
    'projectionMatrix',
    'cameraPosition',
  ],
  ['weatherMap', 'blueNoiseTex'],
  1.0,
  camera
);
cloudsPP.onApply = function (effect) {
  effect.setTexture('weatherMap', weatherMap);
  effect.setFloat('time', time);
  effect.setVector2(
    'screenSize',
    new BABYLON.Vector2(engine.getRenderWidth(), engine.getRenderHeight())
  );
  effect.setVector3('cameraPosition', camera.position);
  effect.setMatrix('cameraMatrix', camera.getViewMatrix());
  effect.setMatrix('projectionMatrix', camera.getProjectionMatrix());
  // effect.setTexture('blueNoiseTex', new BABYLON.Texture(blueNoiseTex, scene));
  // effect.setVector3('lightDirection', light.direction);
  // console.log(light.direction);
};

BABYLON.Effect.ShadersStore.debugFragmentShader = debug;
const debugPP = new BABYLON.PostProcess(
  'Debug',
  'debug',
  ['destSampler'],
  ['destSampler'],
  1.0,
  camera
);

debugPP.onApply = function (effect) {
  effect.setTexture('destSampler', weatherMap);
};

let flag = false;
src.onLoadObservable.add(() => {
  quadScene.render();
  // dest.render();
  flag = true;
});

// Render every frame
engine.runRenderLoop(() => {
  stats.begin();
  if (flag) {
    shaderMaterial.setFloat('time', time);
    quadScene.render();
  }
  time += engine.getDeltaTime() * 0.001;
  scene.render();
  stats.end();
});
