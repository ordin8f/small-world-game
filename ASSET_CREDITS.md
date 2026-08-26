# Small World — Asset Ledger

This repository uses only freely redistributable prototype assets. Restored
from `v02/ASSET_CREDITS.md` (deleted in commit `c16f357` when `v02/` was
merged into the current `src/` layout) and updated for the current file
paths and the Godot rebuild under `godot/` — see `GODOT_REBUILD_PLAN.md`.

## Character

### Kenney — Mini Characters 1.0

- Original source: https://kenney.nl/assets/mini-characters
- License: CC0 1.0 Universal
- Use: animated player plus two playground NPCs (Three.js prototype); also
  the Godot port's player/NPC models (M3.1)
- Runtime files: `src/assets/kenney/character-male-a.glb`,
  `character-female-b.glb`, `character-male-c.glb`,
  `src/assets/kenney/Textures/colormap.png` (Three.js), copied verbatim to
  `godot/assets/kenney/` (Godot; same three .glb files plus
  `Textures/colormap.png`, unmodified)
- Original mirror used to source these files: `mengfoong-dev/codex-candidate-assesment-system`
  on GitHub, delivered through jsDelivr. The files are vendored locally and
  no longer fetched at runtime. The mirror repository includes the original
  Kenney license file and identifies the same source package.
- Reason for selection: readable oversized proportions, built-in animation,
  tiny transfer size, and an intentionally non-realistic silhouette that
  reads more naturally as a young character than a primitive proxy.

## Environment

### Tiny Treats — Homely House 1.0

- Official repository: https://github.com/TinyTreats-Game-Assets/Tiny-Treats-Homely-House-1.0
- License: CC0 1.0 Universal
- Use: one distant house model
- Runtime files: `src/assets/house/house.gltf`, `house.bin`,
  `tiny_treats_texture_1.png`

### Tiny Treats — Pretty Park 1.0

- Official repository: https://github.com/TinyTreats-Game-Assets/Tiny-Treats-Pretty-Park-1.0
- License: CC0 1.0 Universal
- Use: two trees, one bush, a bench, and a street lantern
- Runtime files: `src/assets/park/tree_large.*`, `bush_large.*`, `bench.*`,
  `street_lantern.*`, shared `tiny_treats_texture_1.png`

## Reference material (not runtime assets — comparison references only)

- `docs/reference/lilgator_*.jpg`: official screenshots of *Lil Gator Game*
  (MegaWobble / Playtonic Friends), © their respective rightsholders. Used
  only as a visual quality-bar reference for critique during the Saturday
  Afternoon build; never shipped as a game asset, never redistributed
  outside this repository's own development process.
- `docs/concept-art/visual-direction-contact-sheet.jpg`: original concept
  art created for this project's art-direction process.

## Project-created geometry

The doorway, alley, walls, path, puddles, playground silhouette, lighting
setup, camera system, backpack, and fallback child in the Three.js
prototype are original geometry/code created for Small World, not derived
from the external models above. The same is true of the toon-shader kit,
character rig, and environments under `src/saturday/` (see
`docs/SATURDAY_AFTERNOON_BIBLE.md`).

## Runtime libraries

- Three.js 0.180.0: https://threejs.org/ — License: MIT. Vendored locally
  at `src/vendor/three/` (`build/three.module.js`,
  `examples/jsm/loaders/GLTFLoader.js`,
  `examples/jsm/utils/BufferGeometryUtils.js`), never loaded from a CDN.
- gdUnit4 (Godot rebuild test framework), MikeSchulze/gdUnit4 — License:
  MIT. Vendored locally at `godot/addons/gdUnit4/`.

## Vendoring note

All assets and libraries above are committed to the repository under their
original CC0/MIT terms and pinned to the exact source versions fetched.
Nothing here is loaded from a live third-party host at runtime, so the game
works offline and does not depend on the continued existence of any source
or mirror repository.
