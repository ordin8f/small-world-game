// src/characters.mjs
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

const loader = new GLTFLoader();

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

function tuneImported(root, tint) {
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

function limb(radius, length, material, position) {
  const group = new THREE.Group();
  group.position.set(...position);
  const mesh = new THREE.Mesh(new THREE.CapsuleGeometry(radius, length - radius * 2, 4, 8), material);
  mesh.position.y = -length * 0.48;
  mesh.castShadow = true;
  group.add(mesh);
  return { group, mesh };
}

function createFallbackChild(tint) {
  const root = new THREE.Group();
  const tintColor = tint ? new THREE.Color(tint) : new THREE.Color(0xffffff);
  const mat = (base) => new THREE.MeshStandardMaterial({
    color: new THREE.Color(base).multiply(tintColor),
    roughness: 0.92,
    metalness: 0,
  });
  const skin = mat(0xb77c58);
  const shirt = mat(0x445c66);
  const shorts = mat(0x4e5660);
  const shoe = mat(0x5c3e32);
  const hair = mat(0x302823);

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

  root.userData.limbs = { leftArm, rightArm, leftLeg, rightLeg };
  return root;
}

/**
 * Load a vendored Kenney character model and prepare it for use as either
 * the player or a background NPC. Falls back to a primitive humanoid if the
 * GLTF fails to load, so the episode always has a visible, animatable child
 * even if a vendored asset is missing or corrupted.
 */
export async function loadCharacter(url, { targetHeight = 1.05, tint = null, isPlayer = false } = {}) {
  try {
    const gltf = await loadGltf(url);
    const root = gltf.scene;
    tuneImported(root, tint);
    normalizeToHeight(root, targetHeight);
    root.rotation.y = Math.PI; // aligns the model's local +z forward with heading=0 facing -z
    const actions = prepareAnimationSet(root, gltf.animations);
    if (actions) actions.idle.play();
    return { root, actions, mixer: actions?.mixer ?? null, usedFallback: false };
  } catch (error) {
    console.warn(`Character asset failed to load (${url}), using fallback.`, error);
    const root = createFallbackChild(tint);
    return { root, actions: null, mixer: null, usedFallback: true };
  }
}

export function switchAction(current, next) {
  if (!next || current === next) return current;
  next.reset().fadeIn(0.2).play();
  if (current) current.fadeOut(0.2);
  return next;
}

/**
 * Per-frame limb swing for a fallback primitive character (no-op if the
 * character loaded its real GLTF model, since that uses AnimationMixer
 * instead).
 */
export function animateFallback(root, speed01, running, dt, phaseRef) {
  const limbs = root.userData.limbs;
  if (!limbs) return phaseRef;
  const phase = phaseRef + dt * (running ? 10 : 6.6) * speed01;
  const swing = Math.sin(phase) * 0.48 * speed01;
  limbs.leftArm.group.rotation.x = swing;
  limbs.rightArm.group.rotation.x = -swing;
  limbs.leftLeg.group.rotation.x = -swing * 0.76;
  limbs.rightLeg.group.rotation.x = swing * 0.76;
  return phase;
}
