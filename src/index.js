import * as BABYLON from '@babylonjs/core';

import quadVert from './shaders/quadVert.glsl?raw';
import quadFrag from './shaders/quadFrag.glsl?raw';
import debug from './shaders/debug.glsl?raw';
import clouds from './shaders/clouds.glsl?raw';

//publicフォルダに配置した画像を読み込む
import testimg from '/testimg.png';

const canvas = document.getElementById('renderCanvas');
const engine = new BABYLON.Engine(canvas);
const scene = new BABYLON.Scene(engine);
const camera = new BABYLON.FreeCamera('camera1', new BABYLON.Vector3(0, 5, -10), scene);
camera.setTarget(BABYLON.Vector3.Zero());

camera.attachControl(canvas, true);

const light = new BABYLON.HemisphericLight('light1', new BABYLON.Vector3(0, 1, 0), scene);
light.intensity = 1.0;

// 元のテクスチャ
const src = new BABYLON.Texture(testimg, scene);
// 出力先のテクスチャ
const dest = new BABYLON.RenderTargetTexture('output', 1024, scene);

const quadScene = new BABYLON.Scene(engine);
const quadCamera = new BABYLON.FreeCamera('quadCamera', new BABYLON.Vector3(0, 0, -1), quadScene);

let time = 0;

var quad = BABYLON.MeshBuilder.CreatePlane('quad', { size: 2 }, quadScene);
var shaderMaterial = new BABYLON.ShaderMaterial(
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

dest.renderList.push(quad);
quadScene.customRenderTargets.push(dest);

// 球体を作成してマテリアルを適用し、レンダーターゲットテクスチャをテクスチャとして使用
var sphere = BABYLON.MeshBuilder.CreateSphere('sphere', { diameter: 2, segments: 32 }, scene);
sphere.position.y = 1;

var sphereMaterial = new BABYLON.StandardMaterial('sphereMat', scene);
sphereMaterial.diffuseTexture = dest;
sphere.material = sphereMaterial;

BABYLON.Effect.ShadersStore['cloudsFragmentShader'] = clouds;
var cloudsPP = new BABYLON.PostProcess(
  'Clouds',
  'clouds',
  ['destSampler'],
  ['destSampler'],
  1.0,
  camera
);
cloudsPP.onApply = function (effect) {
  effect.setTexture('destSampler', dest);
};

BABYLON.Effect.ShadersStore['debugFragmentShader'] = debug;
var debugPP = new BABYLON.PostProcess(
  'Debug',
  'debug',
  ['destSampler'],
  ['destSampler'],
  1.0,
  camera
);

debugPP.onApply = function (effect) {
  effect.setTexture('destSampler', dest);
};

let flag = false;
src.onLoadObservable.add(() => {
  quadScene.render();
  // dest.render();
  flag = true;
});

// Render every frame
engine.runRenderLoop(() => {
  if (flag) {
    time += engine.getDeltaTime() * 0.001;
    shaderMaterial.setFloat('time', time);
    quadScene.render();
  }
  scene.render();
});
