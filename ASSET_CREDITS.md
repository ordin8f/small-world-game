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
- Use: one distant house model. Not wired into the Three.js prototype (
  buildStaticWorld() is entirely procedural primitives); placed in the
  Godot port (M3.2), just beyond the home threshold's z<=12 walkable
  bound
- Runtime files: `src/assets/house/house.gltf`, `house.bin`,
  `tiny_treats_texture_1.png` (vendored, unused by src/); copied verbatim
  to `godot/assets/house/` (Godot, in use)

### Tiny Treats — Pretty Park 1.0

- Official repository: https://github.com/TinyTreats-Game-Assets/Tiny-Treats-Pretty-Park-1.0
- License: CC0 1.0 Universal
- Use: two trees, one bush, a bench, and a street lantern. Not wired into
  the Three.js prototype (buildStaticWorld() is entirely procedural
  primitives); placed in the Godot port (M3.2) -- tree_large.gltf
  replaces the three procedural trunk+foliage trees at their same
  positions, bench.gltf replaces the procedural bench, bush_large.gltf
  replaces one of six procedural foliage spheres (the other five stay
  procedural, generic scattered shrubbery), street_lantern.gltf is new
  along the path near the home threshold
- Runtime files: `src/assets/park/tree_large.*`, `bush_large.*`, `bench.*`,
  `street_lantern.*`, shared `tiny_treats_texture_1.png` (vendored, unused
  by src/); copied verbatim to `godot/assets/park/` (Godot, in use)

### Kenney — Nature Kit 2.1

- Original source: https://kenney.nl/assets/nature-kit
- License: CC0 1.0 Universal (`License.txt` inside the downloaded pack
  states "Creative Commons Zero, CC0";
  http://creativecommons.org/publicdomain/zero/1.0/)
- Use: 3 flat rock variants, used for the courtyard's 4 stepping-stone
  positions (detailed-assets toggle, see below) — the same spots
  `tools/_bootstrap_courtyard.gd`'s primitive fallback and
  `scripts/logic/world_affordances.gd`'s `stone_index_at()` already used
- Runtime files: `godot/assets/nature/rock_smallFlatA.glb`,
  `rock_smallFlatB.glb`, `rock_smallFlatC.glb` (Godot only; not used by
  `src/`), selected from Models/GLTF format/ in the official zip
- Modified before vendoring: the stock files carry two materials named
  "dirt" (tan) and "grass" (a bright, saturated teal-green placeholder
  colour, not this project's own grass tone) at `roughnessFactor: 1,
  metallicFactor: 1`. Per `docs/ART_DIRECTION.md`'s restrained-palette/
  no-shiny-PBR rule, both materials were rewritten in place (glTF JSON
  chunk only — mesh/binary data untouched) to this project's own
  `PATH`/`FOLIAGE` palette constants (`tools/_bootstrap_courtyard.gd`) at
  `roughness 0.92, metallic 0` before the files were added to the repo,
  so they already match the environment's matte floor with no runtime
  dependency. The unmodified originals are not vendored anywhere in this
  repository.
- Reason for selection: CC0, tiny (3-4.5 KB each, no external texture),
  and a genuinely better-defined flat-stone silhouette than the
  primitive fallback's squashed sphere, at the same footprint.

## Detailed vs primitive assets

`tools/_bootstrap_courtyard.gd` can build the courtyard two ways, chosen
by the `AssetMode` toggle (`godot/scripts/logic/asset_mode.gd`):

- **detailed** (default): the vendored glTF/glb props above, for
  tree/bush/bench/lamp/rock;
- **primitive**: today's `BoxMesh`/`SphereMesh`/`CylinderMesh` shapes for
  those same 5 "kinds", at the same positions — for fast iteration when
  the exact look doesn't matter.

Both modes build a complete, playable level from the same generator;
detailed mode falls back to the primitive shape (with a console warning,
never a crash) if a listed asset is ever missing. Nothing else in the
scene — the courtyard shell, playground, walls, grass, puddles — has a
detailed equivalent; per `docs/ART_DIRECTION.md` those are meant to stay
plain geometry regardless of this toggle.

To switch: edit `godot/project.godot`'s `[small_world]` section
(`assets/use_detailed=true` or `false`), or set
`small_world/assets/use_detailed` in the editor's Project Settings —
either way, without opening a scene — then regenerate and reimport:

```
godot --headless --path godot --script res://tools/_bootstrap_courtyard.gd
godot --headless --path godot --import
```

`scenes/main.tscn` instances `courtyard.tscn` by reference, so it never
needs regenerating itself.

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
