import * as BABYLON from '@babylonjs/core';
import Stats from 'stats-js';
import GUI from 'lil-gui';

import quadVert from './shaders/quadVert.glsl?raw';
import quadFrag from './shaders/quadFrag.glsl?raw';
import debug from './shaders/debug.glsl?raw';
import clouds from './shaders/clouds.glsl?raw';

// import testimg from '/testimg.png';
// import blueNoiseImg from '/BlueNoise.png';

let time = 0;

// statsの設定
const stats = new Stats();
stats.showPanel(0); // 0: fps, 1: ms, 2: mb, 3+: custom
document.body.appendChild(stats.dom);

// guiの設定
const gui = new GUI();
const params = {
  lightTotalSteps: 4,
  cloudsAreaWidth: 2.0,
  cloudsAreaDepth: 2.0,
  lightDirX: 0.1,
  lightDirY: 1.0,
  lightDirZ: -0.1,
  shapeStepSize: 0.05,
  lightColor: [1.0, 1.0, 1.0],
  shadowIntensity: 1.8,
  cellularNoiseAmplitude: 0.5,
  cellularNoiseFrequency: 2.0,
  perlinNoiseAmplitude: 0.5,
  perlinNoiseFrequency: 2.0,
  cloudsDenscityOffset: 0.0,
};

gui.add(params, 'cloudsAreaWidth', 1.0, 4.0, 0.2);
gui.add(params, 'cloudsAreaDepth', 1.0, 4.0, 0.2);

const lightSettings = gui.addFolder('Light');
lightSettings.add(params, 'lightDirX', -1.0, 1.0, 0.1);
lightSettings.add(params, 'lightDirY', -1.0, 1.0, 0.1);
lightSettings.add(params, 'lightDirZ', -1.0, 1.0, 0.1);
lightSettings.add(params, 'lightTotalSteps', 0, 8, 1);
lightSettings.addColor(params, 'lightColor');
lightSettings.add(params, 'shadowIntensity', 0.0, 10.0, 0.1);

const shapeSettings = gui.addFolder('Shape');
shapeSettings.add(params, 'shapeStepSize', 0.01, 0.1, 0.01);
shapeSettings.add(params, 'cellularNoiseAmplitude', 0.0, 1.0, 0.1);
shapeSettings.add(params, 'cellularNoiseFrequency', 0.1, 2.5, 0.1);
// shapeSettings.add(params, 'perlinNoiseAmplitude', 0.0, 1.0, 0.1);
// shapeSettings.add(params, 'perlinNoiseFrequency', 0.1, 2.5, 0.1);
shapeSettings.add(params, 'cloudsDenscityOffset', 0.0, 0.1, 0.001);

const canvas = document.getElementById('renderCanvas');
const engine = new BABYLON.Engine(canvas);
const scene = new BABYLON.Scene(engine);

const camera = new BABYLON.ArcRotateCamera(
  'Camera',
  -1.57,
  1.57,
  3,
  new BABYLON.Vector3(0, 0, 0),
  scene
);
// camera.setPosition(new BABYLON.Vector3(0, 0, 10));
camera.inertia = 0.3;
// camera.wheelPrecision = 100;
camera.attachControl(canvas, true);

const light = new BABYLON.DirectionalLight('light1', new BABYLON.Vector3(0.1, 1, -0.1), scene);
light.intensity = 1.0;

const weatherMap = new BABYLON.RenderTargetTexture('weatherMap', 1024, scene);

const quadScene = new BABYLON.Scene(engine);
const quadCamera = new BABYLON.FreeCamera('quadCamera', new BABYLON.Vector3(0, 0, -1), quadScene);

// weathre mapをレンダリングするための処理
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
quad.material = shaderMaterial;

weatherMap.renderList.push(quad);
quadScene.customRenderTargets.push(weatherMap);

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
    'lightSteps',
    'cloudsAreaWidth',
    'cloudsAreaDepth',
    'lightDirX',
    'lightDirY',
    'lightDirZ',
    'shapeStepSize',
    'lightColor',
    'shadowIntensity',
    'cellularNoiseAmplitude',
    'cellularNoiseFrequency',
    // 'perlinNoiseAmplitude',
    // 'perlinNoiseFrequency',
    'cloudsDenscityOffset',
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
  effect.setInt('lightSteps', params.lightTotalSteps);
  effect.setFloat('cloudsAreaWidth', params.cloudsAreaWidth);
  effect.setFloat('cloudsAreaDepth', params.cloudsAreaDepth);
  effect.setFloat('lightDirX', params.lightDirX);
  effect.setFloat('lightDirY', params.lightDirY);
  effect.setFloat('lightDirZ', params.lightDirZ);
  effect.setFloat('shapeStepSize', params.shapeStepSize);
  effect.setVector3(
    'lightColor',
    new BABYLON.Vector3(params.lightColor[0], params.lightColor[1], params.lightColor[2])
  );
  effect.setFloat('shadowIntensity', params.shadowIntensity);
  effect.setFloat('cellularNoiseAmplitude', params.cellularNoiseAmplitude);
  effect.setFloat('cellularNoiseFrequency', params.cellularNoiseFrequency);
  // effect.setFloat('perlinNoiseAmplitude', params.perlinNoiseAmplitude);
  // effect.setFloat('perlinNoiseFrequency', params.perlinNoiseFrequency);
  effect.setFloat('cloudsDenscityOffset', params.cloudsDenscityOffset);
};

// weathre mapをデバッグ用に表示するための処理
// BABYLON.Effect.ShadersStore.debugFragmentShader = debug;
// const debugPP = new BABYLON.PostProcess(
//   'Debug',
//   'debug',
//   ['destSampler'],
//   ['destSampler'],
//   1.0,
//   camera
// );
// debugPP.onApply = function (effect) {
//   effect.setTexture('destSampler', weatherMap);
// };

// Render every frame
engine.runRenderLoop(() => {
  stats.begin();

  // quadScene.render();
  time += engine.getDeltaTime() * 0.001;
  scene.render();

  stats.end();
});
