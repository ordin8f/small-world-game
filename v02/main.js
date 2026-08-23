import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import {
  cameraProfile,
  clamp,
  clampPlayerPosition,
  damp,
  inputDirection,
} from './camera-model.mjs';

const THREE_VERSION = '0.180.0';
const KENNEY_BASE = './assets/kenney/';
const HOUSE_BASE = './assets/house/';
const PARK_BASE = './assets/park/';

const canvas = document.querySelector('#game');
const loading = document.querySelector('#loading');
const loadingStatus = document.querySelector('#loading-status');
const loadingFill = document.querySelector('#loading-fill');
const startButton = document.querySelector('#start');
const hud = document.querySelector('#hud');
const moment = document.querySelector('#moment');
const toast = document.querySelector('#toast');

const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.7));
renderer.setSize(window.innerWidth, window.innerHeight, false);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.08;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0xb7b09d, 10, 38);

const camera = new THREE.PerspectiveCamera(46, window.innerWidth / window.innerHeight, 0.05, 100);
camera.position.set(0.4, 1.5, 9.3);

const clock = new THREE.Clock();
const loader = new GLTFLoader();

const hemi = new THREE.HemisphereLight(0xd7e4e4, 0x74634e, 2.15);
scene.add(hemi);

const sun = new THREE.DirectionalLight(0xffd59a, 3.1);
sun.position.set(-7, 11, 8);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -14;
sun.shadow.camera.right = 14;
sun.shadow.camera.top = 14;
sun.shadow.camera.bottom = -14;
sun.shadow.camera.near = 0.5;
sun.shadow.camera.far = 38;
sun.shadow.bias = -0.0004;
scene.add(sun);

const homeGlow = new THREE.PointLight(0xffb35c, 4.8, 9, 1.7);
homeGlow.position.set(0, 1.7, 8.15);
scene.add(homeGlow);

const palette = {
  plaster: 0xc8b79b,
  path: 0xb7a184,
  grass: 0x66785e,
  grassLight: 0x78866a,
  wood: 0x69513b,
  slide: 0xb85f43,
  playground: 0x91745a,
};

function standardMaterial(color, roughness = 0.9) {
  return new THREE.MeshStandardMaterial({ color, roughness, metalness: 0 });
}

function box(name, size, position, material, rotation = [0, 0, 0]) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(...size), material);
  mesh.name = name;
  mesh.position.set(...position);
  mesh.rotation.set(...rotation);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  scene.add(mesh);
  return mesh;
}

function buildBaseWorld() {
  const grass = new THREE.Mesh(
    new THREE.PlaneGeometry(40, 52),
    standardMaterial(palette.grass, 1),
  );
  grass.rotation.x = -Math.PI / 2;
  grass.position.set(0, -0.13, -5);
  grass.receiveShadow = true;
  scene.add(grass);

  box('path', [4.55, 0.18, 20], [0, -0.08, -1.2], standardMaterial(palette.path, 0.98));
  box('park-ground', [12.4, 0.16, 8.8], [0, -0.09, -9.1], standardMaterial(palette.grassLight, 1));

  const plaster = standardMaterial(palette.plaster, 0.97);
  const wood = standardMaterial(palette.wood, 0.93);
  box('threshold-left', [2.35, 4.4, 0.42], [-1.92, 2.15, 7.55], plaster);
  box('threshold-right', [2.35, 4.4, 0.42], [1.92, 2.15, 7.55], plaster);
  box('threshold-lintel', [1.55, 1.55, 0.42], [0, 3.62, 7.55], plaster);
  box('frame-left', [0.15, 2.8, 0.18], [-0.86, 1.38, 7.31], wood);
  box('frame-right', [0.15, 2.8, 0.18], [0.86, 1.38, 7.31], wood);
  box('frame-top', [1.85, 0.15, 0.18], [0, 2.76, 7.31], wood);
  box('interior-floor', [5.2, 0.16, 4.3], [0, -0.04, 9.55], standardMaterial(0x7e654e, 0.96));

  const glowMaterial = new THREE.MeshBasicMaterial({ color: 0xffc66f, transparent: true, opacity: 0.27 });
  const glowPlane = new THREE.Mesh(new THREE.PlaneGeometry(1.55, 2.75), glowMaterial);
  glowPlane.position.set(0, 1.38, 7.74);
  scene.add(glowPlane);

  box('wall-left', [0.48, 4.9, 14.6], [-3.14, 2.28, 0.15], standardMaterial(0xaa9c87, 0.98));
  box('wall-right', [0.48, 5.45, 14.6], [3.14, 2.55, 0.15], standardMaterial(0x9b8f80, 0.98));

  box('mass-left-a', [4.3, 6.8, 7.2], [-5.6, 3.1, 2.4], standardMaterial(0x8c8275, 1));
  box('mass-right-a', [4.6, 7.7, 6.8], [5.7, 3.55, 1.0], standardMaterial(0x877d72, 1));
  box('mass-left-b', [3.8, 5.4, 5.3], [-5.0, 2.45, -4.7], standardMaterial(0xa2927f, 1));

  const puddleMat = new THREE.MeshPhysicalMaterial({
    color: 0x677a7f,
    roughness: 0.18,
    metalness: 0,
    transmission: 0.05,
    transparent: true,
    opacity: 0.58,
  });
  for (const [x, z, sx, sz] of [
    [-0.7, 2.4, 1.25, 0.52],
    [0.8, -0.8, 0.85, 0.38],
    [-0.45, -3.7, 1.55, 0.52],
  ]) {
    const puddle = new THREE.Mesh(new THREE.CircleGeometry(0.62, 40), puddleMat.clone());
    puddle.rotation.x = -Math.PI / 2;
    puddle.scale.set(sx, sz, 1);
    puddle.position.set(x, 0.018, z);
    scene.add(puddle);
  }

  buildPlayground();
}

function buildPlayground() {
  const timber = standardMaterial(palette.playground, 0.9);
  const terracotta = standardMaterial(palette.slide, 0.82);
  const roofMat = standardMaterial(0xc6aa78, 0.94);
  const towerZ = -11.15;

  for (const x of [-1.18, 1.18]) {
    for (const dx of [-0.55, 0.55]) {
      for (const dz of [-0.55, 0.55]) {
        box('playground-post', [0.15, 2.7, 0.15], [x + dx, 1.34, towerZ + dz], timber);
      }
    }
    box('playground-deck', [1.45, 0.16, 1.45], [x, 1.93, towerZ], timber);
    const roof = new THREE.Mesh(new THREE.ConeGeometry(1.08, 0.82, 4), roofMat);
    roof.position.set(x, 3.03, towerZ);
    roof.rotation.y = Math.PI / 4;
    roof.castShadow = true;
    scene.add(roof);
  }

  box('playground-bridge', [1.2, 0.16, 1.05], [0, 1.95, towerZ], timber);
  box('bridge-rail-left', [1.2, 0.62, 0.08], [0, 2.28, towerZ - 0.48], timber);
  box('bridge-rail-right', [1.2, 0.62, 0.08], [0, 2.28, towerZ + 0.48], timber);
  box('slide', [1.04, 0.13, 3.9], [-1.18, 1.02, -9.57], terracotta, [-0.56, 0, 0]);
  box('slide-side-left', [0.08, 0.25, 3.9], [-1.68, 1.12, -9.57], terracotta, [-0.56, 0, 0]);
  box('slide-side-right', [0.08, 0.25, 3.9], [-0.68, 1.12, -9.57], terracotta, [-0.56, 0, 0]);
}

buildBaseWorld();

const player = new THREE.Group();
player.position.set(0, 0, 6.05);
scene.add(player);
const visualPivot = new THREE.Group();
player.add(visualPivot);
const fallback = createFallbackChild();
visualPivot.add(fallback.root);
const backpack = createBackpack();
player.add(backpack);

let playerMixer = null;
let playerActions = null;
let currentAction = null;
let modelLoaded = false;
let npcWaveMixer = null;
let npcWaveAction = null;
let npcWavePlayed = false;

function createFallbackChild() {
  const root = new THREE.Group();
  const skin = standardMaterial(0xb77c58, 0.96);
  const shirt = standardMaterial(0x445c66, 0.95);
  const shorts = standardMaterial(0x4e5660, 0.96);
  const shoe = standardMaterial(0x5c3e32, 0.96);
  const hair = standardMaterial(0x302823, 1);

  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.22, 0.34, 5, 10), shirt);
  torso.position.y = 0.64;
  torso.castShadow = true;
  root.add(torso);

  const head = new THREE.Mesh(new THREE.SphereGeometry(0.245, 18, 14), skin);
  head.position.y = 1.05;
  head.castShadow = true;
  root.add(head);

  const hairCap = new THREE.Mesh(new THREE.SphereGeometry(0.252, 18, 10, 0, Math.PI * 2, 0, Math.PI * 0.58), hair);
  hairCap.position.y = 1.08;
  hairCap.castShadow = true;
  root.add(hairCap);

  const leftArm = limb(0.07, 0.42, skin, [-0.29, 0.67, 0]);
  const rightArm = limb(0.07, 0.42, skin, [0.29, 0.67, 0]);
  const leftLeg = limb(0.085, 0.46, shorts, [-0.12, 0.29, 0]);
  const rightLeg = limb(0.085, 0.46, shorts, [0.12, 0.29, 0]);
  root.add(leftArm.group, rightArm.group, leftLeg.group, rightLeg.group);

  for (const x of [-0.12, 0.12]) {
    const foot = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.09, 0.27), shoe);
    foot.position.set(x, 0.045, -0.055);
    foot.castShadow = true;
    root.add(foot);
  }

  return { root, leftArm, rightArm, leftLeg, rightLeg };
}

function limb(radius, length, material, position) {
  const group = new THREE.Group();
  group.position.set(...position);
  const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(radius, length - radius * 2, 4, 8), material);
  mesh.position.y = -length * 0.48;
  mesh.castShadow = true;
  group.add(mesh);
  return { group, mesh };
}

function createBackpack() {
  const group = new THREE.Group();
  const red = standardMaterial(0x9d4e3b, 0.94);
  const dark = standardMaterial(0x5a3e31, 0.96);
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.42, 0.18), red);
  body.position.set(0, 0.72, 0.18);
  body.castShadow = true;
  group.add(body);
  const flap = new THREE.Mesh(new THREE.BoxGeometry(0.30, 0.12, 0.05), dark);
  flap.position.set(0, 0.84, 0.29);
  group.add(flap);
  return group;
}

function tuneImported(root, tint = null) {
  root.traverse((object) => {
    if (!object.isMesh) return;
    object.castShadow = true;
    object.receiveShadow = true;
    const materials = Array.isArray(object.material) ? object.material : [object.material];
    for (const material of materials) {
      if (!material) continue;
      if ('roughness' in material) material.roughness = Math.max(material.roughness ?? 0.5, 0.78);
      if ('metalness' in material) material.metalness = 0;
      if (tint && material.color) material.color.multiply(new THREE.Color(tint));
    }
  });
}

function normalizeToHeight(root, targetHeight) {
  root.updateMatrixWorld(true);
  let bounds = new THREE.Box3().setFromObject(root);
  const size = new THREE.Vector3();
  bounds.getSize(size);
  if (size.y > 0.0001) root.scale.multiplyScalar(targetHeight / size.y);
  root.updateMatrixWorld(true);
  bounds = new THREE.Box3().setFromObject(root);
  root.position.y -= bounds.min.y;
  root.updateMatrixWorld(true);
}

function loadGltf(url) {
  return new Promise((resolve, reject) => loader.load(url, resolve, undefined, reject));
}

function findClip(clips, matcher) {
  return clips.find((clip) => matcher.test(clip.name)) ?? null;
}

function prepareAnimationSet(root, clips) {
  if (!clips?.length) return null;
  const mixer = new THREE.AnimationMixer(root);
  const idle = findClip(clips, /idle|stand/i) ?? clips[0];
  const walk = findClip(clips, /walk/i) ?? idle;
  const run = findClip(clips, /run|jog|sprint/i) ?? walk;
  const wave = findClip(clips, /wave|hello|greet/i);
  return {
    mixer,
    idle: mixer.clipAction(idle),
    walk: mixer.clipAction(walk),
    run: mixer.clipAction(run),
    wave: wave ? mixer.clipAction(wave) : null,
  };
}

function switchAction(next) {
  if (!next || currentAction === next) return;
  next.reset().fadeIn(0.2).play();
  if (currentAction) currentAction.fadeOut(0.2);
  currentAction = next;
}

async function loadPlayerModel() {
  const gltf = await loadGltf(`${KENNEY_BASE}character-male-a.glb`);
  const model = gltf.scene;
  tuneImported(model, 0xf4eee2);
  normalizeToHeight(model, 1.08);
  model.rotation.y = Math.PI;
  visualPivot.add(model);
  fallback.root.visible = false;
  playerActions = prepareAnimationSet(model, gltf.animations);
  playerMixer = playerActions?.mixer ?? null;
  if (playerActions) switchAction(playerActions.idle);
  modelLoaded = true;
  return model;
}

async function loadNpc(url, position, heading, height = 1.02) {
  const gltf = await loadGltf(url);
  const root = gltf.scene;
  tuneImported(root, 0xf1eadc);
  normalizeToHeight(root, height);
  root.rotation.y = heading + Math.PI;
  root.position.set(...position);
  scene.add(root);
  const actions = prepareAnimationSet(root, gltf.animations);
  actions?.idle?.play();
  return { root, actions };
}

async function loadStatic(url, position, rotationY, height, tint = null) {
  const gltf = await loadGltf(url);
  const root = gltf.scene;
  tuneImported(root, tint);
  normalizeToHeight(root, height);
  root.rotation.y = rotationY;
  root.position.x = position[0];
  root.position.y += position[1];
  root.position.z = position[2];
  scene.add(root);
  return root;
}

const assetTasks = [
  ['child', loadPlayerModel()],
  ['house', loadStatic(`${HOUSE_BASE}house.gltf`, [-7.4, 0, 5.2], 0.35, 5.4, 0xe4d4bc)],
  ['tree A', loadStatic(`${PARK_BASE}tree_large.gltf`, [-5.0, 0, -6.7], 0.2, 5.1, 0xcbd3b3)],
  ['tree B', loadStatic(`${PARK_BASE}tree_large.gltf`, [4.8, 0, -9.5], -0.45, 5.8, 0xc4cfad)],
  ['bush', loadStatic(`${PARK_BASE}bush_large.gltf`, [-3.7, 0, -5.8], 0.1, 1.8, 0xc7cfad)],
  ['bench', loadStatic(`${PARK_BASE}bench.gltf`, [3.25, 0, -6.9], -1.25, 1.05, 0xe0cfb2)],
  ['lamp', loadStatic(`${PARK_BASE}street_lantern.gltf`, [-2.65, 0, -5.8], 0.2, 3.25, 0xe4d3b7)],
  ['Mina', loadNpc(`${KENNEY_BASE}character-female-b.glb`, [-0.85, 0, -7.8], 0.15)],
  ['Arun', loadNpc(`${KENNEY_BASE}character-male-c.glb`, [0.72, 0, -8.15], -0.2)],
];

let loadedCount = 0;
let failedAssets = [];

function finishLoading() {
  loadingStatus.textContent = modelLoaded
    ? 'Character, camera and scene are ready.'
    : 'The CC0 character did not arrive, so the built-in child fallback will be used.';
  if (failedAssets.length) {
    loadingStatus.textContent += ` (${failedAssets.length} optional asset${failedAssets.length === 1 ? '' : 's'} unavailable.)`;
  }
  startButton.hidden = false;
}

for (const [label, task] of assetTasks) {
  task
    .then((value) => {
      if (label === 'Mina') {
        npcWaveMixer = value.actions?.mixer ?? null;
        npcWaveAction = value.actions?.wave ?? null;
      }
    })
    .catch((error) => {
      failedAssets.push(label);
      console.warn(`Asset failed: ${label}`, error);
    })
    .finally(() => {
      loadedCount += 1;
      const progress = Math.round((loadedCount / assetTasks.length) * 100);
      loadingFill.style.width = `${Math.max(8, progress)}%`;
      loadingStatus.textContent = `Preparing the afternoon… ${progress}%`;
      if (loadedCount === assetTasks.length) finishLoading();
    });
}

let started = false;
const keys = new Set();
let dragActive = false;
let pointerX = 0;
let pointerY = 0;
let lookYaw = 0;
let lookPitch = 0;
let heading = 0;
let walkPhase = 0;
let revealTriggered = false;
let controlsFadeTimer = 0;

startButton.addEventListener('click', () => {
  started = true;
  loading.hidden = true;
  hud.hidden = false;
  canvas.focus();
  showToast('The playground is at the end of the lane.', 2800);
});

window.addEventListener('keydown', (event) => {
  if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(event.code)) event.preventDefault();
  keys.add(event.code);
});
window.addEventListener('keyup', (event) => keys.delete(event.code));
window.addEventListener('blur', () => keys.clear());

canvas.addEventListener('pointerdown', (event) => {
  dragActive = true;
  pointerX = event.clientX;
  pointerY = event.clientY;
  canvas.setPointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointerup', (event) => {
  dragActive = false;
  canvas.releasePointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointercancel', () => { dragActive = false; });
canvas.addEventListener('pointermove', (event) => {
  if (!dragActive) return;
  const dx = event.clientX - pointerX;
  const dy = event.clientY - pointerY;
  pointerX = event.clientX;
  pointerY = event.clientY;
  lookYaw = clamp(lookYaw - dx * 0.0045, -0.36, 0.36);
  lookPitch = clamp(lookPitch + dy * 0.0025, -0.055, 0.115);
});

function showToast(text, duration = 2400) {
  toast.textContent = text;
  toast.hidden = false;
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => { toast.hidden = true; }, duration);
}

function angleDelta(target, current) {
  return Math.atan2(Math.sin(target - current), Math.cos(target - current));
}

function animateFallback(speed01, running, dt) {
  if (!fallback.root.visible) return;
  walkPhase += dt * (running ? 10 : 6.6) * speed01;
  const swing = Math.sin(walkPhase) * 0.48 * speed01;
  fallback.leftArm.group.rotation.x = swing;
  fallback.rightArm.group.rotation.x = -swing;
  fallback.leftLeg.group.rotation.x = -swing * 0.76;
  fallback.rightLeg.group.rotation.x = swing * 0.76;
  fallback.root.position.y = Math.abs(Math.sin(walkPhase * 2)) * 0.018 * speed01;
}

function updatePlayer(dt) {
  const inputX = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0)
    - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0);
  const inputZ = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0)
    - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0);
  const moving = Math.hypot(inputX, inputZ) > 0.01;
  const running = keys.has('ShiftLeft') || keys.has('ShiftRight');

  const profile = cameraProfile(player.position.z);
  const cameraYaw = profile.authoredYaw + lookYaw;
  const direction = inputDirection(inputX, inputZ, cameraYaw);

  if (moving) {
    const speed = running ? 2.9 : 1.82;
    const next = clampPlayerPosition(
      player.position.x + direction.x * speed * dt,
      player.position.z + direction.z * speed * dt,
    );
    player.position.x = next.x;
    player.position.z = next.z;

    const targetHeading = Math.atan2(-direction.x, -direction.z);
    heading += angleDelta(targetHeading, heading) * Math.min(1, dt * 11);
    player.rotation.y = heading;
  }

  if (playerActions) switchAction(moving ? (running ? playerActions.run : playerActions.walk) : playerActions.idle);
  animateFallback(moving ? 1 : 0, running, dt);
  playerMixer?.update(dt);
  npcWaveMixer?.update(dt);

  if (player.position.z < -4.8 && !revealTriggered) {
    revealTriggered = true;
    moment.textContent = 'The lane opens. Someone looks over.';
    showToast('One of the children notices you.', 3200);
    if (npcWaveAction && !npcWavePlayed) {
      npcWavePlayed = true;
      npcWaveAction.reset().setLoop(THREE.LoopOnce, 1).fadeIn(0.2).play();
    }
  }
  if (player.position.z < -7.5) moment.textContent = 'You made it to the playground.';

  controlsFadeTimer += dt;
  if (controlsFadeTimer > 10) document.querySelector('.controls')?.classList.add('faded');
}

function updateCamera(dt) {
  const profile = cameraProfile(player.position.z);
  if (!dragActive) {
    lookYaw = damp(lookYaw, 0, 2.0, dt);
    lookPitch = damp(lookPitch, 0, 2.3, dt);
  }

  const yaw = profile.authoredYaw + lookYaw;
  const sin = Math.sin(yaw);
  const cos = Math.cos(yaw);
  const desired = new THREE.Vector3(
    player.position.x + sin * profile.distance + cos * profile.lateral,
    profile.height + lookPitch * 2.8,
    player.position.z + cos * profile.distance - sin * profile.lateral,
  );

  desired.x = clamp(desired.x, -2.72, 2.72);
  if (player.position.z < -4.5) desired.x = clamp(desired.x, -5.7, 5.7);

  const alpha = 1 - Math.exp(-7.3 * dt);
  camera.position.lerp(desired, alpha);
  camera.fov = damp(camera.fov, profile.fov, 5.5, dt);
  camera.updateProjectionMatrix();

  const forward = new THREE.Vector3(-sin, 0, -cos);
  const target = new THREE.Vector3(player.position.x, profile.targetHeight, player.position.z)
    .addScaledVector(forward, profile.lead);
  camera.lookAt(target);
}

function updateAtmosphere(dt) {
  const reveal = THREE.MathUtils.smoothstep(-player.position.z, 3.5, 9.5);
  renderer.toneMappingExposure = damp(renderer.toneMappingExposure, 1.08 + reveal * 0.05, 1.7, dt);
  scene.fog.far = damp(scene.fog.far, 38 + reveal * 7, 1.5, dt);
}

function resize() {
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.7));
  renderer.setSize(window.innerWidth, window.innerHeight, false);
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);

function frame() {
  const dt = Math.min(clock.getDelta(), 0.05);
  if (started) updatePlayer(dt);
  updateCamera(dt);
  updateAtmosphere(dt);
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

window.__SMALL_WORLD_V02__ = {
  version: '0.2-character-camera',
  three: THREE_VERSION,
  player,
  camera,
  cameraProfile,
  get modelLoaded() { return modelLoaded; },
  get failedAssets() { return [...failedAssets]; },
};

frame();
