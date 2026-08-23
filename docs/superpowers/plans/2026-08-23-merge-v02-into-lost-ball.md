# Merge v0.2 Camera/Character Study into the Lost Ball Episode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire the standalone `v02/` preview and make its authored camera and visible GLTF child the default experience for the one playable game, by porting the Lost Ball episode (`src/*.mjs`) from the custom dependency-free WebGL2 renderer onto vendored Three.js.

**Architecture:** `src/logic.mjs` (episode state machine, Emotional Lens math), `src/world.mjs`'s collision data, and `src/audio.mjs` stay unchanged — they never touched the renderer. `src/renderer.mjs` is deleted and replaced by three new focused modules (`src/camera.mjs`, `src/characters.mjs`, `src/scene.mjs`) plus a rewritten `src/game.mjs` orchestrator that wires them together exactly the way today's `game.mjs` wires the old renderer.

**Tech Stack:** Three.js 0.180.0 (already vendored at `src/vendor/three/` after Task 1 — no CDN), native ES modules via `<script type="module">` + import map, Node's built-in test runner for the pure-logic tests.

**Spec:** `docs/superpowers/specs/2026-08-23-merge-v02-into-lost-ball-design.md`

## Global Constraints

- No CDN, no live network dependency at runtime — everything Three.js needs ships vendored in the repo (spec: "Runtime library... vendored locally... no longer loaded from a CDN").
- All work happens on feature branch `feature/merge-v02-into-lost-ball`, never directly on `main` (spec: "Process").
- `PRODUCT_CONTRACT.md`'s vertical-slice boundaries still apply — this changes *how* the existing Lost Ball episode renders, not what it contains: no new mechanics, no additional afternoons, no mobile controls.
- Every intermediate task except Task 6/7 must leave `npm run verify` green; Task 6/7 explicitly call out reduced verification and say why.
- No unauthorized destructive git operations; only create commits, never force-push or delete branches other than the ones this plan itself creates content on.
- Do not push the branch or open a PR — that requires the user's explicit go-ahead outside this plan (spec: process notes; this plan's Task 12).

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `src/logic.mjs` | modified (add `interpolateColor`) | Episode state machine, Emotional Lens math, pure numeric helpers — unchanged behavior, gains one relocated pure function. |
| `src/world.mjs` | modified (trim) | Pure data only: `palette`, `colliders`, `circleIntersectsBox`, `canMoveTo`. No rendering. |
| `src/audio.mjs` | unchanged | Web Audio director. |
| `src/camera.mjs` | new | Authored camera-zone math (`cameraProfile`, `damp`, `inputDirection`) re-tuned to v0.1's coordinate space. |
| `src/characters.mjs` | new | GLTF character loading/animation for player + 3 NPCs, with primitive fallback on load failure. |
| `src/scene.mjs` | new | Three.js static world geometry + episode effect objects (chalk circle, fireflies, ball, home glow). |
| `src/game.mjs` | rewritten | Orchestrator: DOM wiring, episode dispatch (unchanged logic), input, Three.js setup, per-frame update/render. |
| `src/renderer.mjs` | deleted | Superseded by direct Three.js use in `game.mjs`/`scene.mjs`. |
| `src/vendor/three/**` | moved from `v02/vendor/three/` | Vendored Three.js build + GLTFLoader + BufferGeometryUtils. |
| `src/assets/**` | moved from `v02/assets/` | Vendored Kenney characters, house, park props. |
| `index.html` | modified | Import map + `<script type="module">` instead of the bundled classic script. |
| `tools/build-player-bundle.mjs` | deleted | No longer applicable — real ES modules now. |
| `tools/check-files.mjs` | rewritten | Validates the merged single-build file set. |
| `tools/package-site.mjs` | rewritten | Packages one build into `dist/`. |
| `tests/camera.test.mjs` | new | Tests `src/camera.mjs` against v0.1's coordinate space. |
| `tests/v02-camera.test.mjs` | deleted | Superseded by `tests/camera.test.mjs`. |
| `tests/logic.test.mjs` | unchanged | Still exercises `logic.mjs`/`world.mjs`, both API-compatible. |
| `v02/` | deleted | Fully superseded once assets are moved out. |
| `README.md`, `docs/EPISODE_THE_LOST_BALL.md`, `AGENTS.md` | modified | Replace "dependency-free" framing with "vendored Three.js, no CDN." |

---

### Task 1: Branch + relocate vendored assets

**Files:**
- Create branch: `feature/merge-v02-into-lost-ball`
- Move: `v02/vendor/` → `src/vendor/`, `v02/assets/` → `src/assets/`
- Modify: `v02/index.html`, `v02/main.js`, `tools/check-files.mjs`

**Interfaces:**
- Produces: `src/vendor/three/build/three.module.js`, `src/vendor/three/build/three.core.js`, `src/vendor/three/examples/jsm/loaders/GLTFLoader.js`, `src/vendor/three/examples/jsm/utils/BufferGeometryUtils.js`, `src/assets/kenney/{character-male-a,character-female-b,character-male-c}.glb`, `src/assets/kenney/Textures/colormap.png`, `src/assets/house/{house.gltf,house.bin,tiny_treats_texture_1.png}`, `src/assets/park/{tree_large,bush_large,bench,street_lantern}.{gltf,bin}` + `src/assets/park/tiny_treats_texture_1.png` — every later task that references vendored assets uses these exact paths.

- [ ] **Step 1: Create and switch to the feature branch**

```bash
git checkout -b feature/merge-v02-into-lost-ball
```

- [ ] **Step 2: Move the vendored directories with git mv (preserves history)**

```bash
git mv v02/vendor src/vendor
git mv v02/assets src/assets
```

- [ ] **Step 3: Update `v02/index.html`'s import map to point at the new location**

In `v02/index.html`, change:

```html
"three": "./vendor/three/build/three.module.js",
"three/addons/": "./vendor/three/examples/jsm/"
```

to:

```html
"three": "../src/vendor/three/build/three.module.js",
"three/addons/": "../src/vendor/three/examples/jsm/"
```

- [ ] **Step 4: Update `v02/main.js`'s asset base paths**

Change:

```js
const KENNEY_BASE = './assets/kenney/';
const HOUSE_BASE = './assets/house/';
const PARK_BASE = './assets/park/';
```

to:

```js
const KENNEY_BASE = '../src/assets/kenney/';
const HOUSE_BASE = '../src/assets/house/';
const PARK_BASE = '../src/assets/park/';
```

- [ ] **Step 5: Update `tools/check-files.mjs`'s vendored-asset paths**

Replace every `v02/vendor/...` and `v02/assets/...` entry in the `vendoredAssets` array (and the `v02/index.html` / `v02/main.js` references above it) with the `src/vendor/...` / `src/assets/...` equivalents, keeping the rest of the file (the v0.1 bundle checks, the `no CDN` guard) unchanged for now — those get fully rewritten in Task 9.

```js
const vendoredAssets = [
  'src/vendor/three/build/three.module.js',
  'src/vendor/three/build/three.core.js',
  'src/vendor/three/examples/jsm/loaders/GLTFLoader.js',
  'src/vendor/three/examples/jsm/utils/BufferGeometryUtils.js',
  'src/assets/kenney/character-male-a.glb',
  'src/assets/kenney/character-female-b.glb',
  'src/assets/kenney/character-male-c.glb',
  'src/assets/kenney/Textures/colormap.png',
  'src/assets/house/house.gltf',
  'src/assets/house/house.bin',
  'src/assets/house/tiny_treats_texture_1.png',
  'src/assets/park/tree_large.gltf',
  'src/assets/park/bush_large.gltf',
  'src/assets/park/bench.gltf',
  'src/assets/park/street_lantern.gltf',
  'src/assets/park/tiny_treats_texture_1.png',
];
for (const file of vendoredAssets) await access(resolve(root, file));
```

Also update the `v02Html`/`v02Main` reference checks just above it so they still find real strings — `v02/index.html` still contains `'./styles.css'`, `'./main.js'`, and now `'../src/vendor/three/build/three.module.js'`; `v02/main.js` still contains `window.__SMALL_WORLD_V02__` and `character-male-a.glb`, and the `cdn.jsdelivr.net`/`jsdelivr` guard still applies.

- [ ] **Step 6: Run full verification**

```bash
npm run verify
```

Expected: PASS — v0.1's build and v0.2's preview are both still fully functional, just reading assets from the new shared location.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Relocate vendored Three.js and assets from v02/ to src/"
```

---

### Task 2: `src/camera.mjs` — camera zone math for v0.1's coordinate space (TDD)

**Files:**
- Create: `src/camera.mjs`
- Test: `tests/camera.test.mjs`

**Interfaces:**
- Consumes: `clamp`, `lerp`, `smoothstep` from `src/logic.mjs` (already exported there, unchanged signatures: `clamp(value, min=0, max=1)`, `lerp(a,b,t)`, `smoothstep(edge0,edge1,value)`).
- Produces: `cameraProfile(z) -> { distance, height, targetHeight, fov, lateral, lead, authoredYaw }`, `damp(current, target, lambda, dt) -> number`, `inputDirection(inputX, inputZ, cameraYaw) -> { x, z }`. Task 6's `movePlayer`/`updateCamera` call these three by exactly these names and shapes.

v0.1's coordinate space (from `src/world.mjs`'s `canMoveTo`): world bounds `x:[-10,10]`, `z:[-12.5,12]`. The player starts at `z=6.5` (near the home threshold, which sits at `z≈12`), the chalk-circle group is centered at `z=-3.8`, the playground towers sit at `z=-5.6`, and the deepest point of the episode (ball retrieval past the garden wall) is `z=-6.6`. This replaces v0.2's lane/corridor space (`z: 6.05` to `z: -11`) entirely — the three zones below are authored for *this* space.

- [ ] **Step 1: Write the failing test file**

```js
// tests/camera.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { cameraProfile, inputDirection } from '../src/camera.mjs';

test('camera opens from the home threshold toward the playground reveal', () => {
  const threshold = cameraProfile(6.5); // player start, near home
  const approach = cameraProfile(0);    // mid-courtyard
  const reveal = cameraProfile(-6);     // playground / garden depth
  assert.ok(threshold.distance < approach.distance);
  assert.ok(approach.distance < reveal.distance);
  assert.ok(threshold.fov < reveal.fov);
  assert.ok(threshold.lead < reveal.lead);
});

test('camera zones are stable past their anchor points', () => {
  const deepThreshold = cameraProfile(12); // at the home doorway
  const deepReveal = cameraProfile(-12);   // far garden wall
  assert.ok(Math.abs(deepThreshold.distance - cameraProfile(7).distance) < 0.01);
  assert.ok(Math.abs(deepReveal.distance - cameraProfile(-5).distance) < 0.01);
});

test('W is forward and D is screen-right at neutral camera yaw', () => {
  const forward = inputDirection(0, 1, 0);
  const right = inputDirection(1, 0, 0);
  assert.ok(forward.z < -0.99);
  assert.ok(Math.abs(forward.x) < 0.01);
  assert.ok(right.x > 0.99);
  assert.ok(Math.abs(right.z) < 0.01);
});

test('inputDirection returns zero for no input', () => {
  assert.deepEqual(inputDirection(0, 0, 0), { x: 0, z: 0 });
});
```

- [ ] **Step 2: Run the test and confirm it fails**

```bash
node --test tests/camera.test.mjs
```

Expected: FAIL — `Cannot find module '../src/camera.mjs'`.

- [ ] **Step 3: Write `src/camera.mjs`**

```js
// src/camera.mjs
import { clamp, lerp, smoothstep } from './logic.mjs';

export function damp(current, target, lambda, dt) {
  return lerp(current, target, 1 - Math.exp(-lambda * dt));
}

export function inputDirection(inputX, inputZ, cameraYaw) {
  const magnitude = Math.hypot(inputX, inputZ);
  if (magnitude < 1e-6) return { x: 0, z: 0 };

  const nx = inputX / magnitude;
  const nz = inputZ / magnitude;
  const forwardX = -Math.sin(cameraYaw);
  const forwardZ = -Math.cos(cameraYaw);
  const rightX = Math.cos(cameraYaw);
  const rightZ = -Math.sin(cameraYaw);

  return {
    x: rightX * nx + forwardX * nz,
    z: rightZ * nx + forwardZ * nz,
  };
}

const THRESHOLD = { distance: 5.4, height: 2.15, targetHeight: 0.95, fov: 50, lateral: 0.4, lead: 0.35, authoredYaw: -0.045 };
const APPROACH  = { distance: 6.6, height: 2.35, targetHeight: 1.0,  fov: 54, lateral: 0.6, lead: 0.9,  authoredYaw: 0.035 };
const REVEAL    = { distance: 7.6, height: 2.55, targetHeight: 1.05, fov: 58, lateral: 0.9, lead: 1.6,  authoredYaw: -0.07 };

function blend(a, b, t) {
  return {
    distance: lerp(a.distance, b.distance, t),
    height: lerp(a.height, b.height, t),
    targetHeight: lerp(a.targetHeight, b.targetHeight, t),
    fov: lerp(a.fov, b.fov, t),
    lateral: lerp(a.lateral, b.lateral, t),
    lead: lerp(a.lead, b.lead, t),
    authoredYaw: lerp(a.authoredYaw, b.authoredYaw, t),
  };
}

export function cameraProfile(z) {
  const thresholdToApproach = smoothstep(7, 3, z);
  const approachToReveal = smoothstep(-2, -5, z);
  return blend(blend(THRESHOLD, APPROACH, thresholdToApproach), REVEAL, approachToReveal);
}
```

(`clamp` is imported for parity with the module's public surface and because Task 6 imports `clamp`/`lerp`/`damp`/`inputDirection`/`cameraProfile` together from this module and `logic.mjs`; it is not otherwise called inside `cameraProfile` — the smoothstep-based blend never needs to clamp the zone parameters.)

- [ ] **Step 4: Run the test and confirm it passes**

```bash
node --test tests/camera.test.mjs
```

Expected: PASS — 4 tests.

- [ ] **Step 5: Commit**

```bash
git add src/camera.mjs tests/camera.test.mjs
git commit -m "Add authored camera-zone math re-tuned to the Lost Ball courtyard"
```

---

### Task 3: `src/characters.mjs` — GLTF character loading module

**Files:**
- Create: `src/characters.mjs`

**Interfaces:**
- Consumes: `THREE` and `GLTFLoader` from the `three` / `three/addons/loaders/GLTFLoader.js` import-map specifiers (resolved once Task 7 wires the import map into `index.html`; this file only needs to be syntactically valid Node-side until then).
- Produces: `async loadCharacter(url, { targetHeight, tint = null, isPlayer = false }) -> { root, actions, mixer, usedFallback }`. `root` is a `THREE.Group` ready to `scene.add()` (or add to a parent group). `actions` is `null` or `{ idle, walk, run, wave }` (each a `THREE.AnimationAction`, `wave` possibly `null`). `mixer` is `null` or the `THREE.AnimationMixer` driving `root`. Task 6 calls `loadCharacter` four times (player + 3 NPCs) and calls `mixer?.update(dt)` every frame for each.

Not unit-testable under Node — `THREE.WebGLRenderer`/`GLTFLoader` need a browser DOM and WebGL2 context, which is why `src/renderer.mjs` and `src/game.mjs` have never had unit tests either (only `src/logic.mjs` and `src/world.mjs`'s pure functions do, per `tests/logic.test.mjs`). This module is verified in Task 10's browser walkthrough.

- [ ] **Step 1: Write `src/characters.mjs`**

```js
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
```

- [ ] **Step 2: Syntax-check the file**

```bash
node --check src/characters.mjs
```

Expected: PASS (no output means the syntax is valid; module-resolution errors for `'three'` are expected and fine at this stage — they only resolve in-browser via Task 7's import map).

- [ ] **Step 3: Commit**

```bash
git add src/characters.mjs
git commit -m "Add GLTF character loading module with primitive fallback"
```

---

### Task 4: `src/scene.mjs` — Three.js static world + episode effects

**Files:**
- Create: `src/scene.mjs`

**Interfaces:**
- Consumes: `palette` from `src/world.mjs` (unchanged export: `{ plaster, plasterLight, ground, path, wood, woodLight, foliage, foliageLight, slide, chalk, puddle, shadow, warmLight, ball }`, each a `[r,g,b]` 0–1 triple).
- Produces: `buildStaticWorld(scene)` (void, adds all courtyard/playground/garden geometry to the given `THREE.Scene`), `createChalkCircle(scene) -> { update(pulse, active) }`, `createFireflies(scene) -> { update(time, intensity, ballPosition) }`, `createBall(scene) -> { setPosition(position), setVisible(visible), setEmissive(amount) }`, `createHomeGlow(scene) -> { update(intensity) }`. Task 6's `frame()` calls each of these `update`/`setPosition`/`setVisible`/`setEmissive` methods every frame with the same values today's `drawScene` computes.

- [ ] **Step 1: Write `src/scene.mjs`**

```js
// src/scene.mjs
import * as THREE from 'three';
import { palette } from './world.mjs';

function hex([r, g, b]) {
  return (Math.round(r * 255) << 16) | (Math.round(g * 255) << 8) | Math.round(b * 255);
}

function material(color, { emissive = 0, alpha = 1, doubleSided = false } = {}) {
  const mat = new THREE.MeshStandardMaterial({
    color: hex(color),
    roughness: 0.92,
    metalness: 0,
    transparent: alpha < 1,
    opacity: alpha,
    side: doubleSided ? THREE.DoubleSide : THREE.FrontSide,
  });
  if (emissive > 0) {
    mat.emissive = new THREE.Color(hex(color));
    mat.emissiveIntensity = emissive;
  }
  return mat;
}

function addShape(scene, kind, position, scale, color, rotation = [0, 0, 0], extra = {}) {
  let geometry;
  if (kind === 'cube') geometry = new THREE.BoxGeometry(1, 1, 1);
  else if (kind === 'sphere') geometry = new THREE.SphereGeometry(0.5, 20, 16);
  else if (kind === 'cylinder') geometry = new THREE.CylinderGeometry(0.5, 0.5, 1, 16);
  else if (kind === 'cone') geometry = new THREE.ConeGeometry(0.5, 1, 16);
  else throw new Error(`Unknown shape: ${kind}`);

  const mesh = new THREE.Mesh(geometry, material(color, extra));
  mesh.position.set(position[0], position[1], position[2]);
  mesh.scale.set(scale[0], scale[1], scale[2]);
  mesh.rotation.set(rotation[0], rotation[1], rotation[2]);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  scene.add(mesh);
  return mesh;
}

export function buildStaticWorld(scene) {
  // Courtyard shell: deliberately tall, sparse, and child-scaled.
  addShape(scene, 'cube', [0, -0.28, -1], [22, 0.5, 27], palette.ground);
  addShape(scene, 'cube', [0, -0.01, 3.8], [7.2, 0.08, 14.5], palette.path);
  addShape(scene, 'cube', [-10.7, 3.8, -1], [1.1, 8.2, 29], palette.plaster);
  addShape(scene, 'cube', [10.7, 3.8, -1], [1.1, 8.2, 29], palette.plasterLight);
  addShape(scene, 'cube', [0, 4, -13.3], [23, 8.5, 1.1], palette.plaster);

  // Home threshold.
  addShape(scene, 'cube', [-3.8, 2.2, 12.0], [6.7, 4.7, 0.8], palette.plasterLight);
  addShape(scene, 'cube', [3.8, 2.2, 12.0], [6.7, 4.7, 0.8], palette.plasterLight);
  addShape(scene, 'cube', [0, 4.35, 12.0], [1.2, 1.2, 0.8], palette.plasterLight);
  addShape(scene, 'cube', [0, 1.7, 12.15], [2.5, 3.5, 0.18], palette.warmLight, [0, 0, 0], { emissive: 0.9 });

  // Playground towers, bridge, and slide.
  for (const x of [-3.4, 3.4]) {
    addShape(scene, 'cube', [x, 1.25, -5.6], [2.3, 2.4, 2.3], palette.woodLight);
    addShape(scene, 'cube', [x, 2.75, -5.6], [2.7, 0.25, 2.7], palette.wood);
    addShape(scene, 'cone', [x, 4.0, -5.6], [2.0, 1.8, 2.0], palette.woodLight);
    for (const dx of [-0.8, 0.8]) {
      for (const dz of [-0.8, 0.8]) {
        addShape(scene, 'cylinder', [x + dx, 0.5, -5.6 + dz], [0.16, 3.8, 0.16], palette.wood);
      }
    }
  }
  addShape(scene, 'cube', [0, 2.3, -5.6], [4.8, 0.25, 1.15], palette.wood);
  addShape(scene, 'cube', [-3.4, 0.95, -2.9], [1.25, 0.18, 5.2], palette.slide, [-0.54, 0, 0]);

  // Garden wall with one discoverable opening.
  addShape(scene, 'cube', [5.4, 0.55, -5.9], [0.6, 1.2, 4.2], palette.plasterLight);
  addShape(scene, 'cube', [5.4, 0.55, -1.1], [0.6, 1.2, 1.4], palette.plasterLight);
  addShape(scene, 'cube', [8.1, 0.55, -0.8], [4.7, 1.2, 0.6], palette.plasterLight);

  // Puddles, stepping stones, and bench.
  for (const puddle of [
    [-1.5, 0.01, 3.2, 1.6, 0.04, 0.9],
    [2.1, 0.01, 0.8, 1.15, 0.04, 0.75],
    [6.8, 0.01, -4.2, 1.4, 0.04, 0.8],
  ]) {
    addShape(scene, 'sphere', [puddle[0], puddle[1], puddle[2]], [puddle[3], puddle[4], puddle[5]], palette.puddle, [0, 0, 0], { alpha: 0.65 });
  }
  for (const [x, z, s] of [[6.1, -2.5, 0.45], [6.9, -3.2, 0.52], [7.7, -3.9, 0.48], [8.4, -4.7, 0.55]]) {
    addShape(scene, 'sphere', [x, 0.05, z], [s, 0.14, s * 0.85], palette.path);
  }
  addShape(scene, 'cube', [-7.4, 0.7, -0.8], [3.1, 0.25, 0.8], palette.woodLight);
  addShape(scene, 'cube', [-8.5, 0.35, -0.8], [0.18, 1.2, 0.65], palette.wood);
  addShape(scene, 'cube', [-6.3, 0.35, -0.8], [0.18, 1.2, 0.65], palette.wood);

  const addTree = (x, z, scale = 1) => {
    addShape(scene, 'cylinder', [x, 1.25 * scale, z], [0.42 * scale, 2.5 * scale, 0.42 * scale], palette.wood);
    addShape(scene, 'sphere', [x, 3.15 * scale, z], [2.4 * scale, 2.1 * scale, 2.3 * scale], palette.foliage);
    addShape(scene, 'sphere', [x - 0.8 * scale, 3.4 * scale, z + 0.2 * scale], [1.5 * scale, 1.3 * scale, 1.5 * scale], palette.foliageLight);
  };
  addTree(-7.6, 1.7, 1.05);
  addTree(8.3, -8.2, 1.25);
  addTree(7.9, 6.2, 0.9);

  for (const [x, z, s] of [[8.2, -6.1, 1], [7.0, -7.3, 0.8], [9.1, -3.2, 0.85], [-8.7, -6.5, 0.9], [-8.8, 7.5, 1.0], [8.8, 8.6, 0.9]]) {
    addShape(scene, 'sphere', [x, 0.55 * s, z], [1.3 * s, 1.0 * s, 1.1 * s], palette.foliage);
  }
  for (const [x, z] of [[6.2, -5.5], [6.7, -6.3], [8.8, -5.6], [9.0, -7.0], [-8.4, 4.2], [-9.0, 5.0]]) {
    addShape(scene, 'cylinder', [x, 0.25, z], [0.035, 0.5, 0.035], palette.foliageLight);
    addShape(scene, 'sphere', [x, 0.52, z], [0.14, 0.1, 0.14], [0.85, 0.72, 0.42], [0, 0, 0], { emissive: 0.15 });
  }

  // Sparse grass blades soften the route without filling the scene with clutter.
  for (let index = 0; index < 34; index += 1) {
    const side = index % 2 === 0 ? -1 : 1;
    const z = -10.5 + (index * 0.67) % 20;
    const x = side * (4.3 + ((index * 1.91) % 4.4));
    const height = 0.32 + (index % 5) * 0.07;
    addShape(scene, 'cone', [x, height * 0.48, z], [0.12, height, 0.12], index % 3 === 0 ? palette.foliageLight : palette.foliage);
  }
}

export function createChalkCircle(scene) {
  const group = new THREE.Group();
  const marks = [];
  for (let i = 0; i < 18; i += 1) {
    const angle = (i / 18) * Math.PI * 2;
    const mesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.5, 10, 8),
      new THREE.MeshStandardMaterial({ color: hex(palette.chalk), roughness: 0.95 }),
    );
    mesh.position.set(Math.cos(angle) * 2.25, 0.035, -3.65 + Math.sin(angle) * 2.25);
    mesh.rotation.set(0, -angle, 0);
    mesh.receiveShadow = true;
    group.add(mesh);
    marks.push(mesh);
  }
  scene.add(group);

  return {
    update(pulse, active) {
      const color = active ? [0.95, 0.86, 0.62] : palette.chalk;
      const colorHex = hex(color);
      for (const mesh of marks) {
        mesh.scale.set(0.24 + pulse * 0.04, 0.035, 0.12);
        mesh.material.color.setHex(colorHex);
        const emissive = active ? 0.2 + pulse * 0.15 : 0;
        mesh.material.emissive = emissive > 0 ? new THREE.Color(colorHex) : new THREE.Color(0x000000);
        mesh.material.emissiveIntensity = emissive;
      }
    },
  };
}

export function createFireflies(scene) {
  const MAX = 12;
  const meshes = [];
  const mat = new THREE.MeshStandardMaterial({ color: 0xffc247, emissive: 0xffc247, emissiveIntensity: 1.8 });
  for (let i = 0; i < MAX; i += 1) {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(0.045, 8, 8), mat.clone());
    mesh.visible = false;
    scene.add(mesh);
    meshes.push(mesh);
  }

  return {
    update(time, intensity, ballPosition) {
      const count = Math.floor(3 + intensity * 9);
      for (let i = 0; i < MAX; i += 1) {
        const mesh = meshes[i];
        if (i >= count) { mesh.visible = false; continue; }
        mesh.visible = true;
        const angle = time * 0.7 + i * 2.17;
        const radius = 0.65 + (i % 4) * 0.22;
        mesh.position.set(
          ballPosition[0] + Math.cos(angle) * radius,
          ballPosition[1] + 0.45 + Math.sin(angle * 1.7 + i) * 0.35,
          ballPosition[2] + Math.sin(angle) * radius,
        );
        mesh.material.opacity = 0.55 + intensity * 0.4;
        mesh.material.transparent = true;
      }
    },
  };
}

export function createBall(scene) {
  const ball = new THREE.Mesh(
    new THREE.SphereGeometry(0.42, 20, 16),
    new THREE.MeshStandardMaterial({ color: hex(palette.ball), roughness: 0.6 }),
  );
  ball.castShadow = true;
  scene.add(ball);

  const shadow = new THREE.Mesh(
    new THREE.SphereGeometry(0.43, 12, 8),
    new THREE.MeshStandardMaterial({ color: 0x483828, transparent: true, opacity: 0.45 }),
  );
  shadow.scale.set(1, 0.19, 1);
  shadow.rotation.set(0.4, 0.25, 0);
  scene.add(shadow);

  return {
    setPosition(position) {
      ball.position.set(position[0], position[1], position[2]);
      shadow.position.set(position[0] + 0.03, position[1] + 0.01, position[2]);
    },
    setVisible(visible) {
      ball.visible = visible;
      shadow.visible = visible;
    },
    setEmissive(amount) {
      if (amount > 0) {
        ball.material.emissive = new THREE.Color(hex(palette.ball));
        ball.material.emissiveIntensity = amount;
      } else {
        ball.material.emissiveIntensity = 0;
      }
    },
  };
}

export function createHomeGlow(scene) {
  const plane = new THREE.Mesh(
    new THREE.PlaneGeometry(2.0, 3.0),
    new THREE.MeshStandardMaterial({
      color: hex(palette.warmLight),
      transparent: true,
      opacity: 0.28,
      emissive: new THREE.Color(hex(palette.warmLight)),
      emissiveIntensity: 0.25,
      side: THREE.DoubleSide,
    }),
  );
  plane.position.set(0, 1.7, 11.82);
  scene.add(plane);

  return {
    update(intensity) {
      plane.material.opacity = 0.28 + 0.28 * intensity;
      plane.material.emissiveIntensity = 0.25 + intensity * 0.75;
    },
  };
}
```

- [ ] **Step 2: Syntax-check the file**

```bash
node --check src/scene.mjs
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add src/scene.mjs
git commit -m "Add Three.js static world and episode effect objects"
```

---

### Task 5: Trim `src/world.mjs` to pure data, relocate `interpolateColor`

**Files:**
- Modify: `src/world.mjs`
- Modify: `src/logic.mjs`

**Interfaces:**
- Produces: `src/world.mjs` keeps exporting `palette`, `colliders`, `circleIntersectsBox`, `canMoveTo` with identical signatures (Task 4's `scene.mjs` already imports `palette` from here; `tests/logic.test.mjs` already imports `canMoveTo` from here). `src/logic.mjs` gains `export function interpolateColor(a, b, t)`, used by Task 6's `game.mjs`.

- [ ] **Step 1: Remove the rendering functions and `staticObjects` from `src/world.mjs`**

Delete from `src/world.mjs`: the `staticObjects` array and its `add()` builder, `drawStaticWorld`, `drawChalkCircle`, `drawFireflies`, `drawChild`, `drawBall`, `drawHomeGlow`, and `interpolateColor` (moved out, not deleted — see Step 2). The file should now contain only: the `palette` export, the `colliders` export, `circleIntersectsBox`, and `canMoveTo`, plus the `import { clamp, lerp } from './logic.mjs';` line trimmed to `import { clamp } from './logic.mjs';` since `lerp` was only used by the deleted rendering functions.

Resulting file:

```js
// src/world.mjs
import { clamp } from './logic.mjs';

export const palette = Object.freeze({
  plaster: [0.68, 0.62, 0.52],
  plasterLight: [0.78, 0.71, 0.58],
  ground: [0.36, 0.37, 0.29],
  path: [0.66, 0.57, 0.40],
  wood: [0.34, 0.20, 0.12],
  woodLight: [0.62, 0.38, 0.20],
  foliage: [0.18, 0.34, 0.22],
  foliageLight: [0.34, 0.50, 0.28],
  slide: [0.80, 0.30, 0.16],
  chalk: [0.78, 0.76, 0.62],
  puddle: [0.20, 0.32, 0.37],
  shadow: [0.06, 0.07, 0.065],
  warmLight: [1.0, 0.66, 0.28],
  ball: [0.83, 0.53, 0.18]
});

export const colliders = [
  { x: -10.7, z: -1, halfX: 0.6, halfZ: 15 },
  { x: 10.7, z: -1, halfX: 0.6, halfZ: 15 },
  { x: 0, z: -13.3, halfX: 11.5, halfZ: 0.6 },
  { x: -3.4, z: -5.6, halfX: 1.35, halfZ: 1.35 },
  { x: 3.4, z: -5.6, halfX: 1.35, halfZ: 1.35 },
  { x: 5.4, z: -5.9, halfX: 0.35, halfZ: 2.1 },
  { x: 5.4, z: -1.1, halfX: 0.35, halfZ: 0.7 },
  { x: 8.1, z: -0.8, halfX: 2.35, halfZ: 0.35 },
  { x: 8.3, z: -8.2, halfX: 1.0, halfZ: 1.0 },
  { x: -7.6, z: 1.7, halfX: 0.65, halfZ: 0.65 }
];

export function circleIntersectsBox(x, z, radius, box) {
  const nearestX = clamp(x, box.x - box.halfX, box.x + box.halfX);
  const nearestZ = clamp(z, box.z - box.halfZ, box.z + box.halfZ);
  const dx = x - nearestX;
  const dz = z - nearestZ;
  return dx * dx + dz * dz < radius * radius;
}

export function canMoveTo(x, z, radius = 0.32) {
  if (x < -10 || x > 10 || z < -12.5 || z > 12) return false;
  return !colliders.some((box) => circleIntersectsBox(x, z, radius, box));
}
```

- [ ] **Step 2: Add `interpolateColor` to `src/logic.mjs`**

`interpolateColor` is pure color-lerp math with no rendering dependency; it belongs alongside `clamp`/`lerp`/`smoothstep`, not deleted. Add this export to `src/logic.mjs` (near `lerp`):

```js
export function interpolateColor(a, b, t) {
  return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
}
```

- [ ] **Step 3: Run the existing logic/world tests**

```bash
node --test tests/logic.test.mjs
```

Expected: PASS — all 5 existing tests, including "garden wall leaves the intended child-sized opening traversable" (which imports `canMoveTo` from `src/world.mjs`), unaffected by this trim.

- [ ] **Step 4: Commit**

```bash
git add src/world.mjs src/logic.mjs
git commit -m "Trim world.mjs to pure collision/palette data, relocate interpolateColor to logic.mjs"
```

---

### Task 6: Rewrite `src/game.mjs` as the Three.js orchestrator

**Files:**
- Modify: `src/game.mjs` (full rewrite)

**Interfaces:**
- Consumes: `EpisodeDirector`, `EpisodeState`, `EmotionalLens`, `clamp`, `lerp`, `interpolateColor` from `src/logic.mjs`; `canMoveTo` from `src/world.mjs`; `cameraProfile`, `damp`, `inputDirection` from `src/camera.mjs`; `loadCharacter`, `switchAction`, `animateFallback` from `src/characters.mjs`; `buildStaticWorld`, `createChalkCircle`, `createFireflies`, `createBall`, `createHomeGlow` from `src/scene.mjs`; `AudioDirector` from `src/audio.mjs`; `THREE` from `'three'`.
- Produces: `window.__SMALL_WORLD__` debug hook with the same shape as today (`director`, `lens`, `player`, `camera`, `dispatch`, `resetGame`, `ballPosition` getter, `activePrompt` getter) — `tools/check-files.mjs` (Task 9) checks for this hook by the same name.

This is the largest task. `game.mjs` keeps every function that doesn't touch rendering completely unchanged in behavior (dialogue scheduling, episode dispatch, UI text, feedback export) and replaces every function that does.

**Important coordinate-convention change:** v0.1's old renderer used `forward = [sin(yaw), 0, cos(yaw)]`. `src/camera.mjs`'s `inputDirection` (adopted from v0.2) uses the opposite sign convention: `forward = [-sin(yaw), 0, -cos(yaw)]`, where `yaw=0` faces `-z`. To keep "W moves toward the playground" correct, `player.heading` and the camera's authored yaw both now resolve around `0` instead of `Math.PI` at the start of the episode (previously `Math.PI` under the old, opposite convention). This task's `movePlayer`/`updateCamera`/`resetGame` reflect that.

- [ ] **Step 1: Write the new `src/game.mjs`**

```js
// src/game.mjs
import * as THREE from 'three';
import { EpisodeDirector, EpisodeState, EmotionalLens, clamp, lerp, interpolateColor } from './logic.mjs';
import { canMoveTo } from './world.mjs';
import { cameraProfile, damp, inputDirection } from './camera.mjs';
import { loadCharacter, switchAction, animateFallback } from './characters.mjs';
import { buildStaticWorld, createChalkCircle, createFireflies, createBall, createHomeGlow } from './scene.mjs';
import { AudioDirector } from './audio.mjs';

const canvas = document.querySelector('#game-canvas');
const startScreen = document.querySelector('#start-screen');
const startButton = document.querySelector('#start-button');
const unsupported = document.querySelector('#unsupported');
const hud = document.querySelector('#hud');
const objectiveText = document.querySelector('#objective-text');
const prompt = document.querySelector('#prompt');
const promptText = document.querySelector('#prompt-text');
const dialogueCard = document.querySelector('#dialogue-card');
const dialogueSpeaker = document.querySelector('#dialogue-speaker');
const dialogueText = document.querySelector('#dialogue-text');
const debugPanel = document.querySelector('#debug-panel');
const muteButton = document.querySelector('#mute-button');
const motionButton = document.querySelector('#motion-button');
const endScreen = document.querySelector('#end-screen');
const endSummary = document.querySelector('#end-summary');
const restartButton = document.querySelector('#restart-button');
const copyFeedback = document.querySelector('#copy-feedback');
const copyStatus = document.querySelector('#copy-status');

let renderer, scene, threeCamera, sun, hemi;
try {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.6));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;

  scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0x4f6070, 10, 27);

  threeCamera = new THREE.PerspectiveCamera(56, canvas.clientWidth / Math.max(1, canvas.clientHeight), 0.08, 120);

  hemi = new THREE.HemisphereLight(0x9fb0c0, 0x4a4030, 1.6);
  scene.add(hemi);

  sun = new THREE.DirectionalLight(0xffd59a, 2.4);
  sun.position.set(5.5, 10, 3.5);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.camera.left = -14;
  sun.shadow.camera.right = 14;
  sun.shadow.camera.top = 14;
  sun.shadow.camera.bottom = -14;
  sun.shadow.camera.near = 0.5;
  sun.shadow.camera.far = 40;
  sun.shadow.bias = -0.0004;
  scene.add(sun);

  buildStaticWorld(scene);
} catch (error) {
  console.error(error);
  unsupported.hidden = false;
  startScreen.hidden = true;
  throw error;
}

const chalkCircle = createChalkCircle(scene);
const fireflies = createFireflies(scene);
const ballObject = createBall(scene);
const homeGlow = createHomeGlow(scene);

const director = new EpisodeDirector();
const lens = new EmotionalLens();
const audio = new AudioDirector();
const keys = new Set();

const player = {
  position: [0, 0, 6.5],
  heading: 0,
  walkCycle: 0,
  moving: false,
  running: false
};
const playerGroup = new THREE.Group();
scene.add(playerGroup);

const NPC_DEFS = [
  { name: 'Mina', url: '', kenney: 'character-female-b.glb', position: [-0.95, 0, -3.8], heading: 0.2, tint: 0xf1eadc },
  { name: 'Arun', url: '', kenney: 'character-male-c.glb', position: [0.35, 0, -4.25], heading: -0.1, tint: 0xead9c2 },
  { name: 'Third', url: '', kenney: 'character-male-a.glb', position: [1.45, 0, -3.55], heading: -0.4, tint: 0xc9d3e0 },
];
const ASSET_BASE = './src/assets/kenney/';
let playerCharacter = null;
let npcCharacters = [];
let fallbackPhase = 0;

async function loadCharacters() {
  playerCharacter = await loadCharacter(`${ASSET_BASE}character-male-a.glb`, { targetHeight: 1.08, tint: 0xf4eee2, isPlayer: true });
  playerGroup.add(playerCharacter.root);

  npcCharacters = await Promise.all(NPC_DEFS.map(async (def) => {
    const character = await loadCharacter(`${ASSET_BASE}${def.kenney}`, { targetHeight: 1.0, tint: def.tint });
    character.root.position.set(def.position[0], def.position[1], def.position[2]);
    character.root.rotation.y = def.heading + Math.PI;
    scene.add(character.root);
    if (character.actions) character.actions.idle.play();
    return { ...character, name: def.name };
  }));
}
const charactersReady = loadCharacters();

const groupPosition = [0, 0, -3.8];
const ballStart = [0.5, 0.45, -3.7];
const ballEnd = [8.6, 0.45, -6.6];
let ballPosition = [...ballStart];
let ballFlight = 0;
let carryingBall = false;
let started = false;
let reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let lastFrame = performance.now();
let dialogueTimer = 0;
let debugVisible = false;
let dragActive = false;
let previousPointer = [0, 0];
let lookYaw = 0;
let lookPitch = 0;
let activePrompt = null;
let runId = 0;

const dialogues = {
  arrival: ['Other children', 'They are playing the circle game again.'],
  watch: ['Mina', 'It only counts if it stays inside the chalk.'],
  kick: ['Arun', 'Oh—no. It went through the garden gap.'],
  pickup: ['You', 'It is muddier than it looked from far away.'],
  return: ['Mina', 'You found it. You can roll first.'],
  join: ['Arun', 'Stand here. Not too close. Ready?'],
  mother: ['Mom, somewhere above', 'Honey, the light is going. Come home now.'],
  home: ['You', 'Tomorrow, they might already be waiting.']
};

function schedule(callback, delay) {
  const scheduledRun = runId;
  window.setTimeout(() => {
    if (scheduledRun === runId) callback();
  }, delay);
}

function showDialogue([speaker, text], duration = 3.2) {
  dialogueSpeaker.textContent = speaker;
  dialogueText.textContent = text;
  dialogueCard.hidden = false;
  dialogueTimer = duration;
}

function hideDialogue() {
  dialogueCard.hidden = true;
  dialogueTimer = 0;
}

function setObjective() {
  objectiveText.textContent = director.copy().objective;
}

function distance2D(a, b) {
  return Math.hypot(a[0] - b[0], a[2] - b[2]);
}

function nearestInteraction() {
  const state = director.state;
  if (state === EpisodeState.ARRIVE && distance2D(player.position, [0, 0, -1.2]) < 2.3) {
    return { label: 'Watch the children', event: 'observe' };
  }
  if (state === EpisodeState.FIND_BALL && distance2D(player.position, ballEnd) < 1.45) {
    return { label: 'Pick up the ball', event: 'ball_picked_up' };
  }
  if (state === EpisodeState.RETURN_BALL && distance2D(player.position, groupPosition) < 2.1) {
    return { label: 'Give the ball back', event: 'ball_returned' };
  }
  if (state === EpisodeState.INVITED && distance2D(player.position, [0, 0, -3.1]) < 2.2) {
    return { label: 'Join the circle', event: 'joined' };
  }
  if (state === EpisodeState.GO_HOME && distance2D(player.position, [0, 0, 10.8]) < 1.8) {
    return { label: 'Go inside', event: 'entered_home' };
  }
  return null;
}

function mina() { return npcCharacters.find((c) => c.name === 'Mina'); }

function dispatch(eventName) {
  if (!director.dispatch(eventName)) return false;
  setObjective();
  audio.chime(
    eventName === 'ball_kicked'
      ? 'uneasy'
      : eventName === 'ball_returned' || eventName === 'entered_home'
        ? 'warm'
        : 'soft'
  );

  switch (director.state) {
    case EpisodeState.OBSERVED:
      showDialogue(dialogues.watch);
      schedule(() => dispatch('ball_kicked'), 2600);
      break;
    case EpisodeState.BALL_IN_FLIGHT:
      showDialogue(dialogues.kick, 2.6);
      ballFlight = 0;
      break;
    case EpisodeState.FIND_BALL:
      break;
    case EpisodeState.RETURN_BALL:
      carryingBall = true;
      showDialogue(dialogues.pickup);
      break;
    case EpisodeState.INVITED:
      carryingBall = false;
      ballPosition = [0.45, 0.42, -3.9];
      showDialogue(dialogues.return, 3.7);
      { const m = mina(); if (m?.actions?.wave) m.actions.wave.reset().setLoop(THREE.LoopOnce, 1).fadeIn(0.2).play(); }
      break;
    case EpisodeState.GO_HOME:
      showDialogue(dialogues.join, 3.2);
      schedule(() => showDialogue(dialogues.mother, 4.2), 3000);
      break;
    case EpisodeState.COMPLETE:
      showDialogue(dialogues.home, 2.5);
      schedule(showEnding, 1900);
      break;
    default:
      break;
  }
  return true;
}

function interact() {
  if (activePrompt) dispatch(activePrompt.event);
}

function resetGame() {
  runId += 1;
  director.state = EpisodeState.ARRIVE;
  director.start();
  lens.value = { comfort: 0.38, energy: 0.48, curiosity: 0.58 };
  lens.target = { ...lens.value };
  player.position = [0, 0, 6.5];
  player.heading = 0;
  player.walkCycle = 0;
  player.moving = false;
  lookYaw = 0;
  lookPitch = 0;
  ballPosition = [...ballStart];
  ballFlight = 0;
  carryingBall = false;
  endScreen.hidden = true;
  hud.hidden = false;
  copyStatus.textContent = '';
  setObjective();
  showDialogue(dialogues.arrival, 3.5);
  canvas.focus();
}

async function begin() {
  started = true;
  startScreen.hidden = true;
  hud.hidden = false;
  await audio.start();
  await charactersReady;
  director.start();
  setObjective();
  showDialogue(dialogues.arrival, 3.5);
  canvas.focus();
}

startButton.addEventListener('click', begin);
restartButton.addEventListener('click', resetGame);

muteButton.addEventListener('click', () => {
  audio.setMuted(!audio.muted);
  muteButton.textContent = audio.muted ? 'Sound off' : 'Sound on';
  muteButton.setAttribute('aria-pressed', String(audio.muted));
});

motionButton.addEventListener('click', () => {
  reducedMotion = !reducedMotion;
  motionButton.textContent = reducedMotion ? 'Motion reduced' : 'Reduce motion';
  motionButton.setAttribute('aria-pressed', String(reducedMotion));
});

window.addEventListener('keydown', (event) => {
  if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(event.code)) {
    event.preventDefault();
  }
  keys.add(event.code);
  if ((event.code === 'KeyE' || event.code === 'Space') && started && endScreen.hidden) interact();
  if (event.code === 'KeyR' && started) resetGame();
  if (event.code === 'F2') {
    event.preventDefault();
    debugVisible = !debugVisible;
    debugPanel.hidden = !debugVisible;
  }
});

window.addEventListener('keyup', (event) => keys.delete(event.code));
window.addEventListener('blur', () => keys.clear());

canvas.addEventListener('pointerdown', (event) => {
  dragActive = true;
  previousPointer = [event.clientX, event.clientY];
  canvas.setPointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointerup', (event) => {
  dragActive = false;
  canvas.releasePointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointercancel', () => { dragActive = false; });
canvas.addEventListener('pointermove', (event) => {
  if (!dragActive || reducedMotion) return;
  const dx = event.clientX - previousPointer[0];
  const dy = event.clientY - previousPointer[1];
  previousPointer = [event.clientX, event.clientY];
  lookYaw = clamp(lookYaw - dx * 0.0045, -0.36, 0.36);
  lookPitch = clamp(lookPitch + dy * 0.0025, -0.12, 0.2);
});

function angleDelta(target, current) {
  return Math.atan2(Math.sin(target - current), Math.cos(target - current));
}

function movePlayer(dt) {
  const x = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0)
    - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0);
  const z = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0)
    - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0);
  const magnitude = Math.hypot(x, z);
  player.moving = magnitude > 0.01;
  player.running = keys.has('ShiftLeft') || keys.has('ShiftRight');
  if (!player.moving) return;

  const profile = cameraProfile(player.position[2]);
  const yaw = profile.authoredYaw + lookYaw;
  const direction = inputDirection(x, z, yaw);
  const speed = player.running ? 4.1 : 2.65;
  const dx = direction.x * speed * dt;
  const dz = direction.z * speed * dt;

  const nextX = player.position[0] + dx;
  if (canMoveTo(nextX, player.position[2])) player.position[0] = nextX;
  const nextZ = player.position[2] + dz;
  if (canMoveTo(player.position[0], nextZ)) player.position[2] = nextZ;

  const targetHeading = Math.atan2(-direction.x, -direction.z);
  player.heading += angleDelta(targetHeading, player.heading) * Math.min(1, dt * 10);
  player.walkCycle += dt * (player.running ? 10 : 7);
  audio.step(performance.now() / 1000, player.running);
}

function updateBall(dt) {
  if (director.state === EpisodeState.BALL_IN_FLIGHT) {
    ballFlight = clamp(ballFlight + dt / 1.8);
    const arc = Math.sin(ballFlight * Math.PI) * 2.1;
    ballPosition = [
      lerp(ballStart[0], ballEnd[0], ballFlight),
      lerp(ballStart[1], ballEnd[1], ballFlight) + arc,
      lerp(ballStart[2], ballEnd[2], ballFlight)
    ];
    if (ballFlight >= 1) dispatch('ball_landed');
  } else if (carryingBall) {
    const side = [Math.cos(player.heading) * 0.36, 0, -Math.sin(player.heading) * 0.36];
    ballPosition = [player.position[0] + side[0], 0.88, player.position[2] + side[2]];
  }
}

function updateEmotion(dt) {
  const distanceFromGroup = distance2D(player.position, groupPosition);
  lens.setTarget(director.emotionalTarget({ distanceFromGroup }));
  const value = lens.update(dt);
  audio.setMood(value);
  return lens.getVisuals();
}

function updateCamera(dt) {
  const profile = cameraProfile(player.position[2]);
  if (!dragActive || reducedMotion) {
    lookYaw = damp(lookYaw, 0, 2.0, dt);
    lookPitch = damp(lookPitch, 0, 2.3, dt);
  }

  const yaw = profile.authoredYaw + lookYaw;
  const sin = Math.sin(yaw);
  const cos = Math.cos(yaw);
  const desired = new THREE.Vector3(
    player.position[0] + sin * profile.distance + cos * profile.lateral,
    profile.height + lookPitch * 2.8,
    player.position[2] + cos * profile.distance - sin * profile.lateral,
  );
  desired.x = clamp(desired.x, -9.65, 9.65);
  desired.z = clamp(desired.z, -12.55, 11.05);

  const alpha = 1 - Math.exp(-dt * (reducedMotion ? 16 : 7.3));
  threeCamera.position.lerp(desired, alpha);
  threeCamera.fov = damp(threeCamera.fov, profile.fov, 5.5, dt);
  threeCamera.updateProjectionMatrix();

  const forward = new THREE.Vector3(-sin, 0, -cos);
  const target = new THREE.Vector3(player.position[0], profile.targetHeight, player.position[2])
    .addScaledVector(forward, profile.lead);
  threeCamera.lookAt(target);
}

function applyEnvironment(visuals) {
  const warm = visuals.warmth;
  const fogColor = interpolateColor([0.23, 0.28, 0.33], [0.72, 0.58, 0.39], warm);
  const ambientColor = interpolateColor([0.22, 0.24, 0.28], [0.45, 0.40, 0.31], warm);
  const lightColor = interpolateColor([0.58, 0.65, 0.76], [1.08, 0.84, 0.54], warm);
  scene.fog.color.setRGB(...fogColor);
  scene.fog.near = visuals.fogNear;
  scene.fog.far = visuals.fogFar;
  sun.color.setRGB(...lightColor);
  hemi.groundColor.setRGB(...ambientColor);
  renderer.toneMappingExposure = lerp(0.82, 1.12, warm);
  document.documentElement.style.setProperty('--vignette', visuals.vignette.toFixed(3));
  document.documentElement.style.setProperty('--warmth', warm.toFixed(3));
  document.documentElement.style.setProperty('--sky-top', warm > 0.55 ? '#798b91' : '#4f6070');
  document.documentElement.style.setProperty('--sky-bottom', warm > 0.55 ? '#e8c486' : '#aa917b');
}

function updateScene(time, visuals, dt) {
  playerGroup.position.set(player.position[0], 0, player.position[2]);
  playerGroup.rotation.y = player.heading;
  if (playerCharacter) {
    if (playerCharacter.actions) {
      const next = player.moving
        ? (player.running ? playerCharacter.actions.run : playerCharacter.actions.walk)
        : playerCharacter.actions.idle;
      playerCharacter.actions.current = switchAction(playerCharacter.actions.current, next);
      playerCharacter.mixer?.update(dt);
    } else {
      fallbackPhase = animateFallback(playerCharacter.root, player.moving ? 1 : 0, player.running, dt, fallbackPhase);
    }
  }
  for (const character of npcCharacters) character.mixer?.update(dt);

  const pulse = (Math.sin(time * 2.1) + 1) / 2;
  chalkCircle.update(pulse, director.state === EpisodeState.ARRIVE || director.state === EpisodeState.INVITED);

  const hiddenWithGroup = [EpisodeState.INVITED, EpisodeState.GO_HOME, EpisodeState.COMPLETE].includes(director.state);
  const ballVisible = !hiddenWithGroup || carryingBall;
  ballObject.setVisible(ballVisible);
  if (ballVisible) {
    ballObject.setPosition(ballPosition);
    ballObject.setEmissive(director.state === EpisodeState.FIND_BALL ? visuals.curiosityGlow * 0.55 : 0);
  }

  if (director.state === EpisodeState.FIND_BALL) {
    fireflies.update(time, visuals.curiosityGlow, ballPosition);
  } else {
    fireflies.update(time, 0, ballPosition);
  }

  homeGlow.update(director.state === EpisodeState.GO_HOME || director.state === EpisodeState.COMPLETE ? 0.65 + pulse * 0.25 : 0);
}

function updateUI(visuals) {
  activePrompt = nearestInteraction();
  prompt.hidden = !activePrompt;
  if (activePrompt) promptText.textContent = activePrompt.label;
  if (debugVisible) {
    debugPanel.textContent = [
      `state: ${director.state}`,
      `emotion: ${visuals.emotion}`,
      `comfort: ${lens.value.comfort.toFixed(2)}`,
      `energy: ${lens.value.energy.toFixed(2)}`,
      `curiosity: ${lens.value.curiosity.toFixed(2)}`,
      `position: ${player.position[0].toFixed(2)}, ${player.position[2].toFixed(2)}`,
      `ball: ${ballPosition.map((value) => value.toFixed(2)).join(', ')}`,
      `reducedMotion: ${reducedMotion}`
    ].join('\n');
  }
}

function showEnding() {
  hud.hidden = true;
  endScreen.hidden = false;
  const seconds = Math.round(director.elapsed() / 1000);
  const minutes = Math.max(1, Math.round(seconds / 60));
  endSummary.textContent = `The children made room for you. You finished this playtest in about ${minutes} minute${minutes === 1 ? '' : 's'}. No emotion score was shown; the world changed around the feeling instead.`;
}

function feedbackText() {
  const data = new FormData(document.querySelector('#feedback-form'));
  const notes = document.querySelector('#feedback-notes').value.trim();
  const elapsed = Math.round(director.elapsed() / 1000);
  return [
    'SMALL WORLD — THE LOST BALL PLAYTEST',
    `Date: ${new Date().toISOString()}`,
    `Browser: ${navigator.userAgent}`,
    `Approx. completion time: ${elapsed}s`,
    `World felt child-sized: ${data.get('scale') || 'not answered'}`,
    `Emotional shift: ${data.get('emotion') || 'not answered'}`,
    `Would play another afternoon: ${data.get('continue') || 'not answered'}`,
    `Notes: ${notes || 'none'}`
  ].join('\n');
}

copyFeedback.addEventListener('click', async () => {
  const text = feedbackText();
  try {
    await navigator.clipboard.writeText(text);
    copyStatus.textContent = 'Playtest notes copied.';
  } catch {
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'small-world-playtest.txt';
    link.click();
    URL.revokeObjectURL(url);
    copyStatus.textContent = 'Playtest notes downloaded.';
  }
});

function resize() {
  const width = canvas.clientWidth || window.innerWidth;
  const height = canvas.clientHeight || window.innerHeight;
  renderer.setSize(width, height, false);
  threeCamera.aspect = width / Math.max(1, height);
  threeCamera.updateProjectionMatrix();
}

function frame(now) {
  const dt = Math.min(0.05, Math.max(0, (now - lastFrame) / 1000));
  lastFrame = now;
  if (started && endScreen.hidden) {
    movePlayer(dt);
    updateBall(dt);
    if (dialogueTimer > 0) {
      dialogueTimer -= dt;
      if (dialogueTimer <= 0) hideDialogue();
    }
  }
  const visuals = updateEmotion(dt);
  updateCamera(dt);
  applyEnvironment(visuals);
  updateScene(now / 1000, visuals, dt);
  if (started && endScreen.hidden) updateUI(visuals);
  renderer.render(scene, threeCamera);
  requestAnimationFrame(frame);
}

window.addEventListener('resize', resize);
resize();
requestAnimationFrame(frame);

// Intentional smoke-test/debug hook; not shown in the player UI.
window.__SMALL_WORLD__ = {
  director,
  lens,
  player,
  camera: threeCamera,
  dispatch,
  resetGame,
  get ballPosition() { return [...ballPosition]; },
  get activePrompt() { return activePrompt; }
};
```

**Note on `playerCharacter.actions.current`:** `characters.mjs`'s `loadCharacter` returns `actions` as `{ idle, walk, run, wave }` without a `current` field; this task's `updateScene` stores the in-progress action on that object at runtime (`playerCharacter.actions.current = switchAction(...)`) rather than adding a new export to `characters.mjs` — this is intentional, keeping `characters.mjs`'s returned shape exactly as documented in Task 3 while `game.mjs` tracks per-instance playback state itself, the same way `v02/main.js` tracked its own module-level `currentAction` variable.

- [ ] **Step 2: Syntax-check the new file**

```bash
node --check src/game.mjs
```

Expected: PASS.

- [ ] **Step 3: Run the tests unaffected by this rewrite**

```bash
node --test tests/logic.test.mjs tests/camera.test.mjs
```

Expected: PASS — `game.mjs` doesn't export anything these tests import, so this just re-confirms `logic.mjs`/`world.mjs`/`camera.mjs` are still solid before moving on.

`npm run verify` is **not** expected to pass yet: `tools/check-files.mjs` still asserts the old bundle/HTML shape (Task 9 rewrites it) and `index.html` still points at `src/game.bundle.js` (Task 7 cuts it over). That's expected at this intermediate point, not a regression.

- [ ] **Step 4: Commit**

```bash
git add src/game.mjs
git commit -m "Rewrite game.mjs as the Three.js orchestrator"
```

---

### Task 7: Cutover `index.html`

**Files:**
- Modify: `index.html`

**Interfaces:**
- Consumes: `src/vendor/three/build/three.module.js`, `src/vendor/three/examples/jsm/` (Task 1's relocated paths), `src/game.mjs` (Task 6).

- [ ] **Step 1: Replace the script tag with an import map + module script**

In `index.html`, change:

```html
    <script defer src="./src/game.bundle.js"></script>
```

to:

```html
    <script type="importmap">
      {
        "imports": {
          "three": "./src/vendor/three/build/three.module.js",
          "three/addons/": "./src/vendor/three/examples/jsm/"
        }
      }
    </script>
    <script type="module" src="./src/game.mjs"></script>
```

Leave every other element in `index.html` untouched — `#game-canvas`, `#start-screen`, `#hud`, `#dialogue-card`, `#end-screen`, `#unsupported`, the feedback form, and the inline boot-failure-detection script all stay exactly as they are, since `src/game.mjs`'s DOM lookups (Task 6) use the same IDs.

- [ ] **Step 2: Confirm the boot-failure timer still applies to module scripts**

The existing inline script waits 1200ms after `window.load` and checks `window.__SMALL_WORLD__`. Module scripts (`type="module"`) are deferred by default per the HTML spec — they execute after the document is parsed, same timing class as `defer` on a classic script — so this detection logic needs no change. Read the inline script in `index.html` once more after Step 1 to confirm it still references `window.__SMALL_WORLD__` (not `window.__SMALL_WORLD_V02__` or any other name) and leave it as-is.

- [ ] **Step 3: Manual smoke check (full `npm run verify` isn't wired up until Task 9)**

```bash
python -m http.server 8080
```

Open `http://localhost:8080/index.html` in a browser, open the console, and confirm no module-resolution errors (e.g. `Failed to resolve module specifier "three"`) appear before moving to Task 8. Stop the server afterward.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "Cut index.html over to the Three.js module build"
```

---

### Task 8: Delete obsolete files

**Files:**
- Delete: `src/renderer.mjs`, `tools/build-player-bundle.mjs`, `tests/v02-camera.test.mjs`, `v02/` (entire directory)

- [ ] **Step 1: Delete the superseded renderer, bundler, and old camera test**

```bash
git rm src/renderer.mjs
git rm tools/build-player-bundle.mjs
git rm tests/v02-camera.test.mjs
```

- [ ] **Step 2: Delete the entire `v02/` directory**

`v02/vendor/` and `v02/assets/` were already moved out in Task 1; everything remaining in `v02/` (`index.html`, `main.js`, `camera-model.mjs`, `README.md`, `ASSET_CREDITS.md`, `styles.css`) is now fully superseded by `src/*.mjs` + `src/camera.mjs` + `src/characters.mjs` + `src/scene.mjs`.

```bash
git rm -r v02
```

- [ ] **Step 3: Confirm nothing else references the deleted files**

```bash
grep -rn "renderer.mjs\|build-player-bundle\|v02-camera.test\|v02/" --include="*.mjs" --include="*.html" --include="*.json" --include="*.js" . 2>/dev/null | grep -v node_modules
```

Expected: no matches other than this plan document and the design spec (both under `docs/superpowers/`, informational, not executable). If `tools/check-files.mjs` or `tools/package-site.mjs` still show matches, that's expected — Task 9 rewrites them next.

- [ ] **Step 4: Commit**

```bash
git commit -m "Remove the old WebGL2 renderer, player bundler, and standalone v02 preview"
```

---

### Task 9: Update `tools/check-files.mjs` and `tools/package-site.mjs`

**Files:**
- Modify: `tools/check-files.mjs`
- Modify: `tools/package-site.mjs`

**Interfaces:**
- Consumes: the vendored-asset paths from Task 1, `index.html`'s import-map shape from Task 7, `window.__SMALL_WORLD__`'s shape from Task 6.

- [ ] **Step 1: Rewrite `tools/check-files.mjs`**

```js
// tools/check-files.mjs
import { access, readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const required = [
  'index.html',
  'styles.css',
  'src/game.mjs',
  'src/logic.mjs',
  'src/world.mjs',
  'src/audio.mjs',
  'src/camera.mjs',
  'src/characters.mjs',
  'src/scene.mjs',
  'src/vendor/three/build/three.module.js',
  'src/vendor/three/build/three.core.js',
  'src/vendor/three/examples/jsm/loaders/GLTFLoader.js',
  'src/vendor/three/examples/jsm/utils/BufferGeometryUtils.js',
  'src/assets/kenney/character-male-a.glb',
  'src/assets/kenney/character-female-b.glb',
  'src/assets/kenney/character-male-c.glb',
  'src/assets/kenney/Textures/colormap.png',
  'src/assets/house/house.gltf',
  'src/assets/house/house.bin',
  'src/assets/house/tiny_treats_texture_1.png',
  'src/assets/park/tree_large.gltf',
  'src/assets/park/bush_large.gltf',
  'src/assets/park/bench.gltf',
  'src/assets/park/street_lantern.gltf',
  'src/assets/park/tiny_treats_texture_1.png',
];
for (const file of required) await access(resolve(root, file));

const html = await readFile(resolve(root, 'index.html'), 'utf8');
for (const reference of ['./styles.css', './src/vendor/three/build/three.module.js', 'type="module"', './src/game.mjs']) {
  if (!html.includes(reference)) throw new Error(`index.html is missing ${reference}`);
}

for (const relative of ['src/game.mjs', 'src/camera.mjs', 'src/characters.mjs', 'src/scene.mjs']) {
  const source = await readFile(resolve(root, relative), 'utf8');
  if (source.includes('cdn.jsdelivr.net') || source.includes('jsdelivr') || /https?:\/\//.test(source)) {
    throw new Error(`${relative} must not stream assets from a live CDN.`);
  }
}

const gameSource = await readFile(resolve(root, 'src/game.mjs'), 'utf8');
if (!gameSource.includes('window.__SMALL_WORLD__')) throw new Error('game.mjs is missing the smoke-test hook.');
if (!gameSource.includes('character-male-a.glb')) throw new Error('game.mjs is missing the visible player asset route.');

console.log('Small World file set looks consistent.');
```

- [ ] **Step 2: Rewrite `tools/package-site.mjs`**

```js
// tools/package-site.mjs
import { cp, mkdir, rm } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dist = resolve(root, 'dist');

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });

for (const file of ['index.html', 'styles.css', '.nojekyll']) {
  await cp(resolve(root, file), resolve(dist, file));
}
await cp(resolve(root, 'src'), resolve(dist, 'src'), { recursive: true });

console.log('Packaged Small World: The Lost Ball into dist/.');
```

- [ ] **Step 3: Update `package.json`'s `check`/`verify` scripts**

The old `check` script ran `node --check` against `src/renderer.mjs` (now deleted) and didn't cover the new modules. Update `package.json`:

```json
"check": "node tools/check-files.mjs && node --check src/game.mjs && node --check src/world.mjs && node --check src/logic.mjs && node --check src/audio.mjs && node --check src/camera.mjs && node --check src/characters.mjs && node --check src/scene.mjs",
```

(`verify` and `test` stay the same — `verify` already runs `check && test && build:site`.)

- [ ] **Step 4: Run full verification**

```bash
npm run verify
```

Expected: PASS — this is the first time since Task 6 that the full pipeline runs end to end. If it fails, the error will point at whichever file-existence or content check doesn't match; fix the mismatch (most likely a stale path) rather than loosening the check.

- [ ] **Step 5: Commit**

```bash
git add tools/check-files.mjs tools/package-site.mjs package.json
git commit -m "Update check-files and package-site for the merged single build"
```

---

### Task 10: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the automated pipeline**

```bash
npm run verify
```

Expected: PASS (checks, `tests/logic.test.mjs` + `tests/camera.test.mjs`, `dist/` build).

- [ ] **Step 2: Serve the built site**

```bash
cd dist
python -m http.server 8080
```

- [ ] **Step 3: Load in Chrome and confirm no external requests**

Using the claude-in-chrome tools (`tabs_context_mcp` → `navigate` to `http://localhost:8080/index.html` → `read_network_requests`), confirm every request's URL starts with `http://localhost:8080/`. Any `cdn.jsdelivr.net` or other external host in the list is a failure — find and fix the source (most likely a stray absolute URL that Task 1 or Task 9 missed).

- [ ] **Step 4: Confirm no console errors**

`read_console_messages` with `onlyErrors: true`. Expected: no entries. Any WebGL/Three.js/module-resolution error here must be fixed before continuing.

- [ ] **Step 5: Play the full episode arc and record pass/fail against each checkpoint**

Using `computer` (click/key actions) and `screenshot`, walk through the episode start to finish, checking off each row:

| Checkpoint | Expected | Pass? |
|---|---|---|
| Start screen → "Begin the afternoon" | Loads without the `#unsupported` panel showing | |
| Arrival | Player visible as the Kenney character (not a primitive fallback, unless intentionally testing the fallback path), camera in the threshold zone (tighter, closer) | |
| Approach the chalk circle (`observe`) | Dialogue "It only counts if it stays inside the chalk." appears; chalk ring shows the active/warm tint | |
| Ball kicked (`ball_kicked`, automatic after ~2.6s) | Dialogue "Oh—no. It went through the garden gap."; ball visibly arcs toward `ballEnd` | |
| Ball lands (`ball_landed`, automatic) | Objective updates to "Find the ball beyond the low garden wall."; fireflies appear near the ball | |
| Walk through the garden-wall gap and pick up the ball | `canMoveTo` lets the player through the gap at `x≈5.4, z≈-3.0` (not through the wall segments); prompt "Pick up the ball" appears near `ballEnd`; pressing E/Space fires `ball_picked_up` | |
| Carry the ball back to the group | Ball follows the player at a fixed offset; dialogue "It is muddier than it looked from far away." | |
| Return the ball (`ball_returned`) | Dialogue "You found it. You can roll first."; camera moves back toward the approach/reveal zone as `z` decreases | |
| Get invited (`joined` prompt near the circle) | Mina's wave animation plays once (or, on fallback, no error is thrown when `actions` is `null`); dialogue "Stand here. Not too close. Ready?", then "Honey, the light is going. Come home now." after ~3s | |
| Walk home and enter (`entered_home`) | Home-glow plane brightens as `z` approaches `10.8`+; final dialogue "Tomorrow, they might already be waiting."; ending screen appears with elapsed time | |
| Emotional Lens color shift | Fog/light color visibly warms and cools across at least two of: arrival (curious/secure), ball-in-garden (uncertain), return home (settling) — compare screenshots at two states | |
| Debug panel (`F2`) | Shows `state`, `emotion`, `comfort/energy/curiosity`, `position`, `ball`, `reducedMotion` — same fields as before | |
| Restart (`R`) | Returns to `ARRIVE`, player position/heading/camera reset without a stuck dialogue or frozen state | |

- [ ] **Step 6: Stop the local server**

```bash
# stop the python http.server process started in Step 2
```

- [ ] **Step 7: Record results**

If every row in Step 5's table passes, this task is complete — no commit needed (verification-only task). If anything fails, fix it in the relevant earlier task's file, rerun `npm run verify`, and repeat this task's browser walkthrough before moving on.

---

### Task 11: Documentation updates

**Files:**
- Modify: `README.md`, `docs/EPISODE_THE_LOST_BALL.md`, `AGENTS.md`

- [ ] **Step 1: Update `README.md`'s "Prototype versus production stack" section**

Replace:

```markdown
### Prototype versus production stack

The early playtest is a dependency-free WebGL2 build so it can be deployed as a single static site and used to validate the experience immediately. It is intentionally not the final engine architecture. Mechanics that survive playtesting can be ported into the planned PlayCanvas/TypeScript production vertical slice.
```

with:

```markdown
### Prototype versus production stack

The playtest is a static-site build using vendored Three.js (no CDN, no build step, no external runtime dependency — see `docs/superpowers/specs/2026-08-23-merge-v02-into-lost-ball-design.md` for why the original dependency-free WebGL2 renderer was replaced) so it can be deployed as a single static site and used to validate the experience immediately. It is intentionally not the final engine architecture. Mechanics that survive playtesting can be ported into the planned PlayCanvas/TypeScript production vertical slice.
```

- [ ] **Step 2: Update `docs/EPISODE_THE_LOST_BALL.md`'s "Prototype technology decision" section**

Replace:

```markdown
## Prototype technology decision

This playtest is dependency-free WebGL2 rather than the planned production PlayCanvas/TypeScript stack. That is intentional: the playtest URL has no build dependency, no external CDN, and can validate the emotional and spatial design before production architecture hardens. Successful mechanics can then be ported into the PlayCanvas vertical slice.
```

with:

```markdown
## Prototype technology decision

This playtest uses vendored Three.js rather than the planned production PlayCanvas/TypeScript stack. It moved off the original hand-written WebGL2 renderer once the v0.2 camera/character study (see `v02/README.md`'s history in git — the standalone preview was retired once its results were folded in) showed the visual/game-feel bar a visible animated child and an authored camera could clear. The playtest URL still has no build dependency and no external CDN — Three.js and every character/environment asset are committed to the repository under their original CC0/MIT terms rather than streamed — so it still validates the emotional and spatial design before production architecture hardens. Successful mechanics can then be ported into the PlayCanvas vertical slice.
```

- [ ] **Step 3: Update `AGENTS.md`'s "The Lost Ball prototype exception" section**

Replace:

```markdown
## The Lost Ball prototype exception

For the dependency-free WebGL2 experience prototype in `src/*.mjs`, `index.html`, and `styles.css`:

- JavaScript modules are permitted even though the production direction remains strict TypeScript.
- Do not add a framework, backend, account system, telemetry, or CDN without an explicit ticket.
- Keep episode state, emotional perception, rendering, and release concerns separated.
- Run `npm run verify` and inspect the prototype in a WebGL2 browser before claiming completion.
- Follow the ownership boundaries in `docs/AGENT_ORCHESTRATION.md`.
```

with:

```markdown
## The Lost Ball prototype exception

For the browser experience prototype in `src/*.mjs`, `index.html`, and `styles.css`:

- JavaScript modules are permitted even though the production direction remains strict TypeScript.
- Three.js is the sanctioned rendering library for this prototype, vendored locally under `src/vendor/three/` — see `docs/superpowers/specs/2026-08-23-merge-v02-into-lost-ball-design.md` for the explicit ticket that approved it. Do not add any *other* framework, backend, account system, telemetry, or CDN without a new explicit ticket, and do not switch Three.js back to a CDN reference.
- Keep episode state, emotional perception, rendering, and release concerns separated (`src/logic.mjs`, `src/camera.mjs` / `src/characters.mjs` / `src/scene.mjs`, and `src/game.mjs`'s orchestration respectively).
- Run `npm run verify` and inspect the prototype in a WebGL2 browser before claiming completion.
- Follow the ownership boundaries in `docs/AGENT_ORCHESTRATION.md`.
```

- [ ] **Step 4: Commit**

```bash
git add README.md docs/EPISODE_THE_LOST_BALL.md AGENTS.md
git commit -m "Update docs to describe the vendored-Three.js prototype"
```

---

### Task 12: Final state check (no push, no PR)

**Files:** none

- [ ] **Step 1: Confirm a clean working tree**

```bash
git status
```

Expected: `nothing to commit, working tree clean` on `feature/merge-v02-into-lost-ball`.

- [ ] **Step 2: Confirm `main` is untouched**

```bash
git log main..feature/merge-v02-into-lost-ball --oneline
git diff main --stat
```

Expected: every changed file is one this plan touched (Tasks 1–11's file lists); `main` itself has no new commits from this work.

- [ ] **Step 3: Stop here**

Do not `git push` and do not open a pull request. Per this project's git-safety norms and the spec's "Process" section, report the branch name and this task's checklist results back to the user and wait for their explicit go-ahead before pushing or requesting review.

---

## Self-Review

**Spec coverage:**
- "What is reused unchanged" (logic.mjs, world.mjs collision, audio.mjs, camera-model.mjs technique, vendored assets) → Tasks 1, 2, 5.
- "What gets rewritten" (renderer.mjs deleted, world.mjs geometry → scene.mjs, drawChild → GLTF characters, game.mjs orchestrator, index.html module cutover, build-player-bundle.mjs deleted, check-files.mjs/package-site.mjs rewritten, v02/ deleted) → Tasks 2–9.
- "Data flow" diagram → reflected directly in Task 6's `movePlayer`/`updateCamera`/`dispatch`/`updateEmotion`/`applyEnvironment`/`frame` structure.
- "Error handling" (GLTF fallback, WebGL2/Three.js unavailable) → Task 3's `loadCharacter` try/catch + fallback, Task 6's `try`/`catch` around renderer construction.
- "Testing / verification" → Tasks 2 (TDD), 9 (`npm run verify` first full pass), 10 (browser walkthrough with the exact episode arc named in the spec).
- "Documentation updates required" (README, EPISODE_THE_LOST_BALL, AGENTS) → Task 11, each with real replacement prose.
- "Process" (feature branch, no direct `main` changes) → Task 1 Step 1, Task 12.

**Placeholder scan:** No "TBD"/"TODO" strings; every code block is complete, working source rather than a description. The one place I deliberately left an authored (not spec-derived) judgment call — `src/camera.mjs`'s exact zone numbers and `src/game.mjs`'s lighting setup — is real, specific code, not a placeholder; Task 10's browser walkthrough is where those get tuned against actual play if they don't feel right, which is normal for camera/lighting authoring and is called out explicitly in Task 10 rather than hidden.

**Type/name consistency checked across tasks:**
- `cameraProfile(z)` returns `{ distance, height, targetHeight, fov, lateral, lead, authoredYaw }` in Task 2 and is destructured with exactly those field names in Task 6.
- `damp(current, target, lambda, dt)` and `inputDirection(inputX, inputZ, cameraYaw) -> { x, z }` signatures match between Task 2's implementation and Task 6's calls.
- `loadCharacter(url, { targetHeight, tint, isPlayer })` returns `{ root, actions, mixer, usedFallback }` in Task 3; Task 6 only reads `root`/`actions`/`mixer`, consistent with that shape (`usedFallback` is available but unused, not a broken reference).
- `switchAction(current, next)` in Task 3 takes and returns an action reference; Task 6's `updateScene` calls it as `playerCharacter.actions.current = switchAction(playerCharacter.actions.current, next)`, matching the signature exactly (this is why Task 6 has an explicit note about tracking `.current` at the call site rather than inside `characters.mjs`).
- `animateFallback(root, speed01, running, dt, phaseRef) -> number` in Task 3 matches Task 6's `fallbackPhase = animateFallback(...)` call.
- `buildStaticWorld(scene)`, `createChalkCircle(scene)`, `createFireflies(scene)`, `createBall(scene)`, `createHomeGlow(scene)` in Task 4 match Task 6's construction calls and the `.update`/`.setPosition`/`.setVisible`/`.setEmissive` method names used in `updateScene`.
- `palette`, `colliders`, `circleIntersectsBox`, `canMoveTo` remain exported from `src/world.mjs` after Task 5's trim, matching every consumer (Task 4's `scene.mjs`, Task 6's `game.mjs`, `tests/logic.test.mjs`).
- `interpolateColor(a, b, t)` added to `src/logic.mjs` in Task 5 matches its usage in Task 6's `applyEnvironment`.

No gaps found; no task added to backfill a missing requirement.
