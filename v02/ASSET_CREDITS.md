# Small World v0.2 — Prototype Asset Ledger

This preview deliberately uses only freely redistributable prototype assets. The production game may replace any or all of them.

## Character

### Kenney — Mini Characters 1.0

- Original source: https://kenney.nl/assets/mini-characters
- License: CC0 1.0 Universal
- Prototype use: animated player plus two playground NPCs
- Runtime files: `character-male-a.glb`, `character-female-b.glb`, `character-male-c.glb`
- Original mirror used to source these files: `mengfoong-dev/codex-candidate-assesment-system` on GitHub, delivered through jsDelivr. The three `.glb` files are now vendored locally at `v02/assets/kenney/` and no longer fetched at runtime.
- Reason for selection: readable oversized proportions, built-in animation, tiny transfer size, and an intentionally non-realistic silhouette that reads more naturally as a young character than the earlier primitive proxy.

The original Kenney asset page identifies Mini Characters as CC0 and animated. The mirror repository includes the original Kenney license file and identifies the same source package.

## Environment

### Tiny Treats — Homely House 1.0

- Official repository: https://github.com/TinyTreats-Game-Assets/Tiny-Treats-Homely-House-1.0
- License: CC0 1.0 Universal
- Prototype use: one distant house model
- Runtime files: vendored locally at `v02/assets/house/` (`house.gltf`, `house.bin`, `tiny_treats_texture_1.png`)

### Tiny Treats — Pretty Park 1.0

- Official repository: https://github.com/TinyTreats-Game-Assets/Tiny-Treats-Pretty-Park-1.0
- License: CC0 1.0 Universal
- Prototype use: two trees, one bush, a bench, and a street lantern
- Runtime files: vendored locally at `v02/assets/park/` (`tree_large.*`, `bush_large.*`, `bench.*`, `street_lantern.*`, shared `tiny_treats_texture_1.png`)

## Project-created geometry

The doorway, alley, walls, path, puddles, playground silhouette, lighting setup, camera system, backpack, and fallback child are original prototype geometry/code created for Small World. They are not derived from the external models above.

## Runtime library

- Three.js 0.180.0: https://threejs.org/
- License: MIT
- Delivery: vendored locally at `v02/vendor/three/` (`build/three.module.js`, `examples/jsm/loaders/GLTFLoader.js`, `examples/jsm/utils/BufferGeometryUtils.js`), no longer loaded from a CDN

## Vendoring note

All assets above and the Three.js runtime are committed to the repository under their original CC0/MIT terms and pinned to the exact source versions fetched above. Nothing in `v02/` is loaded from a live third-party host at runtime, so the preview works offline and does not depend on the continued existence of the mirror repositories.
