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
- Use: the courtyard's vegetation and small garden dressing, resolved by
  kind through `scripts/prop_library.gd` (detailed-assets toggle, see
  below). 3 flat rock variants for the 4 stepping-stone positions — the
  same spots `tools/_bootstrap_courtyard.gd`'s primitive fallback and
  `scripts/logic/world_affordances.gd`'s `stone_index_at()` already used
  — plus, added in the models pass: 6 tree species (replacing five
  instances of one repeated Tiny Treats tree), 3 bushes, 3 flowers, 2
  grass tufts, a 1 m fence panel, 2 plant pots, a stump and a log.
- Runtime files (Godot only; not used by `src/`), all selected from
  `Models/GLTF format/` in the official zip:
  - `godot/assets/nature/rock_smallFlatA.glb`, `rock_smallFlatB.glb`,
    `rock_smallFlatC.glb`
  - `godot/assets/kenney_nature/` — `tree_default.glb`, `tree_oak.glb`,
    `tree_detailed.glb`, `tree_tall.glb`, `tree_thin.glb`,
    `tree_plateau.glb`, `plant_bush.glb`, `plant_bushDetailed.glb`,
    `plant_bushLarge.glb`, `fence_simple.glb`, `fence_planks.glb`,
    `pot_large.glb`, `pot_small.glb`, `flower_redA.glb`,
    `flower_yellowA.glb`, `flower_purpleA.glb`, `grass.glb`,
    `grass_large.glb`, `stump_round.glb`, `log.glb`
  Only the GLB files actually referenced were vendored; the pack's OBJ
  and FBX copies of the same models, and the ~300 models this project
  does not use, were not added to the repository.
- Modified before vendoring: the stock files carry flat material colours
  in an unrelated stylised palette — "grass"/"leafsGreen" are a bright
  saturated teal-green, "woodBark"/"wood" a salmon-orange — at
  `roughnessFactor: 1, metallicFactor: 1`. Per `docs/ART_DIRECTION.md`'s
  restrained-palette/no-shiny-PBR rule, every material was rewritten in
  place (glTF JSON chunk only — mesh/binary data untouched) to this
  project's own palette constants from `tools/_bootstrap_courtyard.gd`
  (`FOLIAGE`, `WOOD`, `WOOD_LIGHT`, `PATH`, `PLASTER`, and the same
  `flower_color` the primitive flowers use) at `roughness 0.92,
  metallic 0`. The unmodified originals are not vendored anywhere in
  this repository.
- Colour space: glTF `baseColorFactor` is LINEAR, while the palette
  constants are sRGB values assigned straight to `albedo_color` by
  `_mesh()`. The palette therefore has to be converted before it is
  written into a `.glb`, or the model imports far too light — verified by
  probing the imported `StandardMaterial3D`, where an un-converted
  `FOLIAGE` of `0.18, 0.34, 0.22` came back as `0.461, 0.618, 0.506`, a
  pale sage instead of a deep green. The three rock files predate the
  models pass and had exactly this defect; they were re-materialed with
  the conversion applied at the same time as the new files, so all 23
  models now import to `albedo_color` values identical to the palette the
  primitive fallbacks use.
- Reason for selection: CC0, tiny (4-30 KB each, no external texture —
  336 KB for all 20 new models), one coherent low-poly style across every
  kind the world needed, and genuinely better-defined silhouettes than
  the primitive fallbacks (a trunk with real branches instead of two
  spheres on a stick; a tuft of bent blades instead of a cone).

### Kenney — Fantasy Town Kit 2.0

- Original source: https://kenney.nl/assets/fantasy-town-kit
- License: CC0 1.0 Universal (`License.txt` inside the downloaded pack states
  "License: (Creative Commons Zero, CC0)";
  http://creativecommons.org/publicdomain/zero/1.0/)
- Use: the built structures, as opposed to the planting the Nature Kit
  covers. Currently the two play-tower roofs, replacing bare `CylinderMesh`
  cones. `wall-door.glb`, `wall-window-shutters.glb` and
  `stairs-wood-handrail.glb` are vendored and registered as the `door`,
  `window` and `stairs` kinds but are NOT yet placed — see the note on the
  house below.
- Runtime files: `godot/assets/kenney_town/roof-high-point.glb`,
  `wall-door.glb`, `wall-window-shutters.glb`, `stairs-wood-handrail.glb`,
  **and `godot/assets/kenney_town/Textures/colormap.png`** (Godot only),
  selected from `Models/GLB format/` in the official zip. 115 KB for all five;
  the pack's OBJ/FBX copies and its other ~160 models were not vendored.
- The atlas is REQUIRED, not optional. These models do not embed their
  texture — each declares `images: [{"uri": "Textures/colormap.png"}]`,
  resolved relative to the .glb — and they share one 512x512 atlas between
  them, which is why a single file serves all four. glTF has no albedo colour
  to fall back on when a `baseColorTexture` fails to resolve, so a model
  vendored without it imports pure white; with this scene's glow pass on top,
  the two tower roofs rendered as glowing white lampshades. Note that
  `godot/assets/kenney/Textures/colormap.png` is a DIFFERENT atlas (Mini
  Characters, verified by checksum) — pointing these models at it would land
  every UV on the wrong swatch.
- Vendoring the atlas is necessary but not sufficient: Godot keys its import
  cache on the model file, so a .glb first imported while the texture was
  absent stays untextured through later `--import` runs. Its `.import`
  sibling has to be deleted to force a reimport. `tools/verify.ps1`'s
  `== assets ==` step (`tools/_check_asset_textures.gd`) now fails the build
  on both conditions.
- NOT re-materialed before vendoring, and deliberately so: unlike the Nature
  Kit these carry a texture rather than a `baseColorFactor`, so the
  sRGB-to-linear palette rewrite described above does not apply to them and
  must not be attempted. Their stock terracotta/stone/wood already sits close
  to this world's warm palette.
- Reason for selection: CC0, small, and the only surveyed kit with the
  vocabulary this courtyard is actually built from — pointed roofs, arches,
  stone and plaster walls, doorways, stairs with handrails.

### Playground equipment — no CC0 source found

The slide and the swing frame have no vendored model and are built from
primitives. This is a search result, not an oversight: kenney.nl's full 3D
catalogue and quaternius.com's complete pack list were both checked, and
neither has a playground kit. The web results for "CC0 playground slide
swing" are aggregator sites whose per-model licences are unverifiable, which
is not a basis for vendoring into this repository.

The slide is additionally one this project should not replace with a stock
model even if one appeared: its geometry is derived from
`WorldAffordances.PLATFORM_TOP_Y` and `SLIDE_END`, which is what keeps the
visual plank and the scripted ride from drifting apart. Its side rails and
end kicker are built from those same two authored points, through the same
`_slide_plank()`, for the same reason.

## Detailed vs primitive assets

`tools/_bootstrap_courtyard.gd` can build the courtyard two ways, chosen
by the `AssetMode` toggle (`godot/scripts/logic/asset_mode.gd`):

- **detailed** (default): the vendored glTF/glb props above, for
  tree/bush/rock/fence_post/flower/grass_tuft/flowerpot/bench/lamp;
- **primitive**: today's `BoxMesh`/`SphereMesh`/`CylinderMesh` shapes for
  those same kinds, at the same positions — for fast iteration when the
  exact look doesn't matter.

Which model a kind resolves to, and the scale that makes it come out the
size the primitive was, live in `godot/scripts/prop_library.gd`. That
file also carries a second, code-level switch, `PropLibrary.USE_MODELS`,
for flipping models off without touching ProjectSettings; either switch
being false yields primitives.

Both modes build a complete, playable level from the same generator;
detailed mode falls back to the primitive shape (with a console warning,
never a crash) if a listed asset is ever missing. Some kinds are
deliberately primitive in BOTH modes and have no vendored model at all —
the house's door and windows (no CC0 modular equivalent was found), the
swing frame (likewise), and the slide, whose geometry is derived from
`WorldAffordances.PLATFORM_TOP_Y`/`SLIDE_END` so the visual plank and the
scripted ride cannot drift apart. `PropLibrary.KINDS_WITHOUT_MODELS`
lists them. Nothing else in the scene — the courtyard shell, playground
towers, walls, puddles — has a detailed equivalent either; per
`docs/ART_DIRECTION.md` those are meant to stay plain geometry.

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

## Audio — no vendored files at all

There is no audio in this repository: no `.wav`, no `.ogg`, no
`godot/assets/audio/` directory, and nothing to license. Every sound in the
game is synthesised from scratch at runtime by
`godot/scripts/audio_director.gd`, which bakes short `AudioStreamWAV`
buffers once at startup and plays them through ordinary
`AudioStreamPlayer` nodes.

That covers the ambience drones, the chimes, footsteps, splashes, the slide
whoosh, the sand pat, the swing creak — and, since 2026-08-30, the
background music: an eight-voice sustained pad and a sparse music-box
melody, both generated by the same file.

The music was written as DSP rather than vendored as CC0 audio on purpose.
A downloaded loop plays the same at 2pm and at dusk; this one is driven by
the same authored mood arc as the lighting, so the chord changes as the
afternoon does. See the MUSIC block at the top of `audio_director.gd` for
the design, and `godot/tools/_probe_music.gd` for the renderer that writes
it out to `.wav` so it can be listened to and measured.

If audio files are ever vendored, they belong in this section with per-file
source and license, under the same CC0/MIT rules as everything above.

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
