# Design: Merge v0.2 camera/character study into the v0.1 Lost Ball episode

Status: approved by user 2026-08-23, pending implementation.

## Goal

Retire the standalone `v02/` preview and make its authored camera and
visible animated child the default experience for the one playable
game (`index.html` / `src/*.mjs`). After this change there is exactly
one playable build: the full Lost Ball episode, rendered with Three.js,
using a real animated child model and the authored threshold/alley/
reveal camera instead of the current primitive blob character and
ad-hoc orbit camera.

## Why

- `v02/` was created as a camera/character "feel gate" and was never
  meant to ship standalone — see `v02/README.md`'s own framing
  ("intentionally not the Lost Ball episode... the visual/game-feel
  gate that should have come first"). It has no link from `index.html`
  and no real players will ever find it.
- The shipped, community-tested game (v0.1) has all the actual
  narrative content (episode state machine, Emotional Lens, dialogue,
  ball retrieval) but a blocky primitive character and a generic
  unrestricted orbit camera.
- Running two permanently separate prototypes is the "too many extra
  files between v0.1 and v0.2" problem the user asked to fix. One
  coherent playable build serves both the cleanup goal and the game's
  actual quality.

## Non-goals

- Not the planned PlayCanvas/TypeScript production port (`docs/BACKLOG.md`
  P0 is still unstarted and out of scope here).
- Not adding new episode content, additional afternoons, or new social
  mechanics — this only changes *how* the existing Lost Ball episode
  is rendered and how the character/camera behave.
- Not mobile controls, accounts, or any of the other items
  `PRODUCT_CONTRACT.md` explicitly excludes from the vertical slice.

## What is reused unchanged

- `src/logic.mjs` — `EpisodeDirector` state machine, `EmotionalLens`
  math, `clamp`/`lerp`. Fully renderer-agnostic already.
- `src/world.mjs` — `colliders` array and `canMoveTo`. Collision logic
  doesn't care what draws the frame.
- `src/audio.mjs` — `AudioDirector`. Web Audio API, unaffected by the
  renderer change.
- `v02/camera-model.mjs`'s technique: three authored camera profiles
  (near/mid/far equivalents of threshold/alley/reveal) blended with
  `smoothstep` by depth into the scene, plus `damp`/`inputDirection`.
  The specific z-thresholds and profile numbers are re-tuned to v0.1's
  courtyard (player starts at z=6.5, group/playground at z≈-5.6,
  garden retrieval further out) rather than v0.2's lane (z=6.05 to
  z=-11).
- All vendored v0.2 assets (`v02/vendor/three/`, `v02/assets/`) move to
  `src/vendor/three/` and `src/assets/` — same files, new home under
  the one build.

## What gets rewritten

- `src/renderer.mjs` (custom WebGL2 primitive renderer): deleted.
- `src/world.mjs`'s static geometry (`staticObjects` list and
  `drawStaticWorld`): mechanically translated to a Three.js
  scene-builder function. The list is already declarative
  (`{mesh, position, scale, color, rotation, emissive, alpha}`), so
  this is a 1:1 port using a `box/sphere/cylinder/cone` helper, the
  same pattern `v02/main.js`'s `box()` already used.
- `src/world.mjs`'s `drawChild` (primitive humanoid): removed. The
  player and all three other children (currently three differently
  colored primitive stacks) switch to the vendored Kenney GLTF models
  for visual consistency — one character rig used four times, tinted
  per-character the way `v02/main.js`'s `tuneImported()` already does.
- `src/game.mjs`: becomes the Three.js orchestrator.
  - Scene/renderer/lighting/fog setup borrowed from `v02/main.js`
    (`THREE.WebGLRenderer`, `HemisphereLight` + `DirectionalLight`,
    `Fog`, ACES tone mapping).
  - Episode dispatch (`dispatch`, `nearestInteraction`, dialogue
    scheduling) kept as-is — it doesn't touch rendering.
  - `updateCamera` replaced with the re-tuned zone-based profile
    system in place of the current yaw/pitch/distance orbit lerp.
  - Ball flight, chalk circle, fireflies, and home-glow effects
    rebuilt as small Three.js mesh/material setups with the same
    visual intent as today's primitive versions.
  - `environmentFor(visuals)` (Emotional Lens → color/fog output)
    keeps its existing color-interpolation math; only the last step
    changes, from WebGL uniform writes to
    `scene.fog` / `renderer.toneMappingExposure` /
    `directionalLight.color` assignments.
- `index.html`: switches from a bundled non-module script
  (`tools/build-player-bundle.mjs` output) to `<script type="module">`
  plus an import map pointing at `./src/vendor/three/...`, matching
  how `v02/index.html` already worked.
- `tools/build-player-bundle.mjs`: deleted (no longer applicable once
  the build is a real ES module using import maps).
- `tools/check-files.mjs`: rewritten to check the merged file set
  (single `src/` tree, vendored assets, module-based `index.html`)
  instead of today's parallel v0.1-bundle + v02-preview checks.
- `tools/package-site.mjs`: simplified to package one build instead of
  copying `v02/` alongside the bundled player.
- `v02/` directory: deleted entirely once its contents have moved.

## Data flow (unchanged shape, new implementation)

```
input (keys/pointer) -> movePlayer() -> world.canMoveTo() -> player.position
player.position -> cameraProfile(z) [re-tuned zones] -> camera transform
episode events -> EpisodeDirector -> dispatch() -> dialogue/audio/ball state
EpisodeDirector + distanceFromGroup -> EmotionalLens -> visuals
visuals -> environmentFor() -> Three.js fog/tone-mapping/light color
frame(now) -> movePlayer, updateBall, updateCamera, updateAtmosphere, renderer.render(scene, camera)
```

This is the same control flow as today's `game.mjs`; only the last
step of each branch (how visuals actually get drawn) changes.

## Error handling

- If the GLTF character fails to load (network/parse failure even
  though assets are local — e.g. a corrupted vendor file), fall back
  to a simple primitive humanoid, mirroring `v02/main.js`'s existing
  `createFallbackChild()` pattern. The episode must remain completable
  even if character art fails.
- If Three.js itself fails to initialize (unsupported browser/WebGL2
  unavailable), show the existing `#unsupported` panel — same
  behavior `game.mjs` already has for the old `WebGLRenderer` catch
  block, just guarding `THREE.WebGLRenderer` construction instead.

## Testing / verification

- `tests/logic.test.mjs` — unchanged, still exercises
  `EpisodeDirector`/`EmotionalLens`, which don't change.
- `tests/v02-camera.test.mjs` — adapted to test the merged, re-tuned
  camera profile against v0.1's actual coordinate space (rename to
  reflect it's no longer a "v02" test).
- `npm run verify` updated end-to-end: `check-files.mjs` validates the
  new single-build file set, `build:site` packages one build into
  `dist/`.
- Manual browser verification (same method used for the vendoring
  work): serve `dist/` locally, load in Chrome, confirm zero
  non-localhost network requests, and play the full episode arc start
  to finish (arrive → observe → ball kicked → retrieve → return →
  invited → join → mother calls → home → ending) confirming the
  Emotional Lens visual shifts still read and no state gets stuck.

## Process

Implemented on a feature branch (not directly against `main`), matching
how every prior change in this repo has landed (see git history — all
merged work came through a branch + PR). `main`'s current working game
stays untouched until this is verified and explicitly merged.

## Documentation updates required

- `README.md`: "Prototype versus production stack" section currently
  says the playtest is "dependency-free." Needs to say it now uses
  Three.js (vendored locally, no CDN) instead of claiming zero
  dependencies.
- `docs/EPISODE_THE_LOST_BALL.md`: "Prototype technology decision"
  section says "dependency-free WebGL2 rather than the planned
  production PlayCanvas/TypeScript stack" — update to describe the
  vendored-Three.js approach and why (camera/character quality gate
  from v0.2 justified the change).
- `AGENTS.md`: the "Lost Ball prototype exception" section's "Do not
  add a framework... without an explicit ticket" line is satisfied by
  this spec acting as that explicit ticket; note that Three.js is now
  the sanctioned framework for `src/*` and update the wording so it
  doesn't read as still forbidding it.
