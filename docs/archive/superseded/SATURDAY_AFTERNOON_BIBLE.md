# Saturday Afternoon — Build Bible

Shared technical + art contract for every builder/critic agent working on **Saturday Afternoon**,
the toddler-exploration game. Read this before writing or judging any code. Quality bar is
**Lil Gator Game** (MegaWobble/Playtonic) — reference screenshots live in
`docs/reference/lilgator_*.jpg` (checked into the repo so every agent, including critics, can
`Read` them directly).

## Why this doc exists

This repo's older `docs/ART_DIRECTION.md` describes a *different*, deliberately somber/minimalist
prior project ("The Lost Ball"). This bible **supersedes it** for everything under `src/saturday/`.
Do not import ideas like "avoid toy-box rainbow palette" or "no chibi/mascot" from the old doc —
Saturday Afternoon is bright, toon-shaded, and chunky-cute on purpose.

**Hard rule (automatic failure if violated):** no visible character or primary prop may be a raw,
unmodified `THREE.BoxGeometry` / `SphereGeometry` / `CylinderGeometry` / `ConeGeometry` used
directly as a visible mesh. Every visible shape must be faceted/shaped/carved custom geometry —
built with the helpers in `src/saturday/lowpoly.mjs`, or merged/lathed/extruded compound shapes.
Primitives are allowed only as inputs you further shape (e.g. `LatheGeometry` from a hand-authored
profile, `ExtrudeGeometry` from a hand-authored 2D shape, CSG-style boolean unions), never as the
final visible form.

## Tech stack (do not deviate without checking with the orchestrator)

- Vendored Three.js r180 at `src/vendor/three/` (already in repo, GLTFLoader/SkinnedMesh/
  AnimationMixer all present). No CDN, no bundler, no new npm dependencies.
- Plain ES modules, static file serving (`python3 -m http.server`), same as the existing prototype.
- New code lives under `src/saturday/` (a sibling to the existing `src/*.mjs` Lost Ball modules —
  do not edit or delete those; Lost Ball stays playable at `lost-ball.html`).
- Entry point: `saturday.html` at repo root (becomes the new front-door `index.html` once the
  vertical slice is solid — orchestrator handles that swap).
- Every piece that renders something must also expose a **debug harness** — a query param or a
  tiny standalone `debug/<piece>.html` that loads just that piece in isolation (fixed camera,
  no input required) so critics can screenshot it deterministically without playing through the
  whole game. Document the harness URL in a one-line comment at the top of the module.

## Errata (read this section — it corrects mistakes earlier in this doc)

An independent technical reviewer caught real bugs the recipe below would otherwise walk you into.
These corrections are authoritative over anything they contradict elsewhere in this file:

1. **Faceted look vs. outline mesh are not in conflict — do this exactly:** build geometry indexed,
   call `mergeVertices()` then `computeVertexNormals()` to get smooth, averaged per-vertex normals.
   Use those SAME smooth normals for both the visible mesh and the outline extrusion. On the visible
   mesh, set `material.flatShading = true` — Three.js derives flat per-face shading from screen-space
   derivatives at render time, so you get crisp facets *without* needing faceted (non-averaged)
   normals. Faceted/non-averaged normals would instead make the outline shell split apart into
   disconnected plates at every edge — don't do that.
2. **`gradientMap` only samples its red channel** — you cannot bake colored bands into it, the toon
   ramp is always greyscale × `material.color`. Get warm-tinted shadow color from lighting (a warm
   `HemisphereLight` sky/ground pair, or a warm-tinted ambient fill), not from the gradient texture.
   Set `gradientMap.minFilter = gradientMap.magFilter = THREE.NearestFilter`,
   `gradientMap.colorSpace = THREE.NoColorSpace` (it's a ramp/data texture, not a color image).
3. **Outline helper must be one unified implementation using `onBeforeCompile`**, not a bespoke
   `ShaderMaterial` built from scratch. In `toon.mjs`, `createOutline(mesh, { thickness, color })`
   should clone the mesh's geometry, apply a `MeshBasicMaterial` (`side: THREE.BackSide`, the given
   color), and in `onBeforeCompile` inject a position offset along the (smooth) vertex normal —
   scaled by `-mvPosition.z` in view space so outline thickness stays visually constant regardless
   of object scale or camera distance. Using `onBeforeCompile` on a real material means skinning and
   fog come along for free, so the same helper works unmodified for the rigged toddler/NPCs
   (`SkinnedMesh`, sharing the same `THREE.Skeleton`) and for static props. Do not write a separate
   outline path for skinned vs static meshes.
4. **`mergeGeometries` requires consistent indexing.** `ExtrudeGeometry` is non-indexed by default;
   `LatheGeometry`/`BoxGeometry` are indexed. Call `.toNonIndexed()` on every input (or otherwise
   normalize) before merging, or `BufferGeometryUtils.mergeGeometries` throws.
5. A raw `ShaderMaterial` (the sky dome) does **not** get Three.js's automatic output color-space
   handling — end your fragment shader with `#include <colorspace_fragment>` or colors will look off
   once composited with everything else.
6. Set `renderer.toneMapping = THREE.NoToneMapping` in the one canonical renderer setup (see
   `render.mjs` below) — `ACESFilmicToneMapping` (the Three.js default in newer examples) desaturates
   and crushes contrast, which fights the flat-saturated toon look the whole game depends on.

## Extended architecture (added after initial foundation build started)

A few more shared modules are foundation-level, not per-piece, because retrofitting them across
four separately-built environments is much more expensive than building them once, up front, with
a frozen API:

- `palette.mjs` — the game's named color constants (grass green, path tan, sky/dusk gradient stops,
  outline ink, skin/hair/outfit tone options, etc.) as plain exported values. Every piece imports
  colors from here; nobody hardcodes hex values inline.
- `worldScale.mjs` — shared scale/unit constants (toddler eye height, a "step" unit other geometry
  sizes relative to, curb height, etc.) so every environment agrees on scale with the character.
- `camera.mjs` — the **one** owner of camera framing: low, child-height, wide-ish FOV, mid-distance
  third-person follow, matching the reference screenshots' framing. Every debug harness AND the
  integrated game must use this module for its camera — don't hand-roll a one-off camera per piece,
  or critic screenshots won't be comparable to each other or to the reference.
- `render.mjs` — the **one** owner of renderer/scene setup: creates the `THREE.WebGLRenderer` with
  the correct color space and `NoToneMapping`, sets up fog, and exposes a single
  `mountScene(canvas, sceneSetupFn)`-style entry point that every debug harness and the final game
  both call, so an isolated harness screenshot and the integrated build render identically.
- `imagination.mjs` — the generic imagination-transform **contract and effect**, built once:
  `registerImaginable(object3D, { altBuilder, hint })` marks any prop as transformable; a shared
  update loop shows a small sparkle/highlight cue when the toddler is near, and swaps to the alt
  visual (with a toon "pop" — brief scale/color flourish, not a physics change) on interact, then
  reverts. Environment pieces just call `registerImaginable(...)` on 1–2 of their own props — they
  do not reimplement the transform mechanism.
- `treasure.mjs` — the generic pocket-treasure **system**, built once: a small `TreasureItem`
  factory (custom faceted geometry per bible modeling rules — bottle cap, pretty rock, feather,
  acorn, etc.), pickup-radius interaction, and a small diegetic-feeling pocket/pouch UI showing what's
  been collected. Environment pieces scatter instances via this API; they do not build their own
  pickup logic.
- Audio is **one owner, one `AudioContext`.** A single `src/saturday/audio.mjs` covers both the
  lo-fi afternoon→dusk ambience *and* toddler/NPC gibberish — two separate audio modules would fight
  over the browser's autoplay-unlock gesture and end up with two contexts. Gibberish is exposed as a
  function this shared module offers, not a parallel system.
- The wobbly movement controller and the toddler rig are **one owner** (whoever builds
  `toddler.mjs` also owns `movementController.mjs` immediately after) — animation state (walk cycle
  phase, lean, stagger, curb-teeter pose) is driven directly by controller state, so splitting them
  across two agents with no shared context produces a rig and a controller that don't agree on
  their interface.
- **Asset strategy is hybrid, not "model everything by hand."** Hand-author the toddler character
  and the shader/lowpoly/procedural-texture kit — those are what a blind A/B actually scrutinizes.
  For environment props (furniture, playground equipment, fences, house exteriors), prefer sourcing
  real CC0-licensed low-poly asset packs (kenney.nl and quaternius.com are both reachable) and
  **re-materializing** them with this game's toon material + outline helper + palette, rather than
  hand-lathing every couch and slide from primitives — that is a far better hours-to-quality trade,
  and visual unity comes from the shared shader/palette pass over sourced geometry, not from every
  prop being bespoke-modeled. The repo already has some unused Kenney GLTF/GLB props under
  `src/assets/park/` and `src/assets/house/` (bench, bush, tree, lantern, house) — check those before
  fetching more. A sourced asset still must pass through the toon material + outline pipeline; an
  untouched PBR-shaded GLB dropped in unmodified will look inconsistent with everything else and is
  a fail on its own terms even though it's "real geometry."

## The toon look — concrete recipe

Study `docs/reference/lilgator_*.jpg` before writing shaders. Key ingredients:

1. **Cel-shaded materials.** Use `THREE.MeshToonMaterial` with a hand-built 3-step `gradientMap`
   (a tiny `NearestFilter` canvas texture: dark band / mid band / lit band). Every toon material in
   the game should share one or two gradient maps from `src/saturday/toon.mjs` so lighting reads
   consistently.
2. **Thick black outlines.** Inverted-hull technique: for every outlined mesh, add a sibling mesh
   with the same geometry, `THREE.BackSide`, solid black/near-black `MeshBasicMaterial`-like
   shader, vertices pushed outward along their normals in the vertex shader by a small world-space
   thickness (roughly 1.5–3% of the object's size — tune per object scale). Implement once as
   `createOutline(mesh, thickness, color)` in `toon.mjs` and reuse everywhere. This is cheap and
   needs no post-processing pipeline.
3. **Faceted, low-subdivision geometry.** Visible bevels and flat facets are a *feature* — do not
   smooth-shade. Use `computeVertexNormals()` off flat-faceted geometry so faces read distinctly.
4. **Painterly cutout foliage**, not modeled leaves. Trees/bushes are 3–5 crossed quads (like
   classic billboard "tree cards") textured with a procedurally painted alpha-cutout canvas texture
   (soft blobby cluster silhouette, 2–3 tone color variation, slightly ragged/brushy edge noise) —
   see `proceduralTextures.mjs`. This is how the reference gets that soft painted canopy look cheaply.
5. **Painted-looking ground/sky.** Sky is a large inverted-sphere dome with a vertical gradient
   shader (warm near horizon → deeper blue/purple at zenith, retuned per time-of-day) plus a
   handful of soft painted cloud billboards drifting slowly. Ground is vertex-colored terrain with
   a procedurally painted mottled grass/dirt texture (radial color-blob noise), not a flat solid
   color and not photoreal PBR.
6. **Warm, saturated, high-contrast palette.** Reference the screenshots directly for hue choices —
   saturated greens/oranges/blues, deep warm-brown shadows, cream/white highlights. Avoid muddy
   desaturated tones.
7. **Expressive characters over facial detail.** Big simple eyes (dark oval/almond, one bright
   catchlight highlight quad), minimal mouth, posture and silhouette carry emotion.

`src/saturday/lowpoly.mjs` should provide reusable modeling helpers so builders aren't fighting
raw Three.js each time, e.g.:

```js
export function roundedBox(w, h, d, bevel = 0.08, segments = 2) { /* BoxGeometry -> bevel via
  extra edge loops or a small ExtrudeGeometry with roundedRect shape */ }
export function taperedCapsule(radiusTop, radiusBottom, height, radialSegments = 7) { /* lathe */ }
export function lathe(profilePoints, radialSegments = 8) { /* wraps THREE.LatheGeometry */ }
export function extrudeProfile(shapePoints, depth, bevelSize = 0.05) { /* wraps ExtrudeGeometry */ }
export function mergeGeometries(geometries) { /* BufferGeometryUtils.mergeGeometries, single
  outline + single draw call per compound object */ }
```
Low `radialSegments` (6–9) is correct — it's what produces the visible facets in the reference art.

## Toddler character spec (highest-scrutiny asset — gets its own dedicated builder+critic round)

- Proportions: preschooler, **not** an adult scaled down. Head ≈ 40–45% of standing height. Short
  limbs, round soft belly, small hands/feet, low center of gravity.
- Face: two large simple eyes (dark, slightly asymmetric size is okay — adds charm), tiny nose dot
  or none, small simple mouth shape swappable for a couple of expressions (neutral / open-mouth
  delighted / concerned).
- Hair: chunky faceted geometry shapes (a few merged lathed/extruded blobs), not a texture decal.
- Outfit: simple flat-color garment read as its own faceted shell over the torso (e.g. overalls or
  a striped tee as separate geometry, not just vertex paint on the body) — one or two accent colors
  max, plus bare feet or simple rounded shoes.
- Rig: a small `THREE.Skeleton` (6–10 bones: root/hips, spine, head, 2× arm, 2× leg is plenty) driven
  by hand-authored procedural animation curves (no external animation files needed) — idle sway,
  wobbly toddler walk/run (wide stance, slight overcorrecting lean, arms out for balance), sit,
  point, pick-up, wave, a "wobble-teeter" pose for curb balancing, and a small delighted hop/spin
  for imagination-transform / treasure-found moments.
- Movement feel: never a smooth adult glide. Slight over-rotation on turns, a bit of a stagger on
  start/stop, arms instinctively out to the sides when moving fast or balancing.

## Day-cycle: afternoon → dusk

One authored lighting/audio timeline the whole game rides on (reuse the *structure* of the old
`docs/ART_DIRECTION.md` lighting-mood idea, not its somber palette):

- **Bright afternoon** (start): high warm directional "sun", saturated colors, short-ish shadows,
  upbeat lo-fi ambience (birds, distant wind chimes, soft tape-hiss lo-fi loop).
- **Golden late-afternoon** (mid): sun lowers, longer amber shadows, richer oranges, ambience adds
  more presence (rustling leaves, a distant dog, playground sounds).
- **Dusk** (end): cooler blue/violet ambient fill, warm practical lights turn on (house windows,
  porch light) as strong warm anchors, ambience quiets (crickets fading in, wind calming) — cozy,
  not scary, mirrors the old doc's "vulnerable, not horrific" instinct.

Drive this off a single `dayProgress` 0→1 value (time-based or progress-based, orchestrator will
decide) that every system (sky shader, directional light, fog, audio mix) reads — do not hardcode
separate "modes"; interpolate.

## Screenshot / critique protocol (for critics)

1. Start a static server on a free port, e.g.
   `cd /home/user/small-world-game && python3 -m http.server 8099 &` (background it, `kill %1` when
   done, pick a different port per agent to avoid clashes if several critics run concurrently).
2. Playwright (npm package, not just the browser) is **not** in this repo's `node_modules` — it's
   installed globally. Do NOT run `npm install playwright` in the repo (don't touch package.json)
   and do NOT run `playwright install` (browsers are pre-fetched, downloading is blocked). Instead
   run Node with the global module path, e.g.:
   ```bash
   NODE_PATH=/opt/node22/lib/node_modules node -e "
   const { chromium } = require('playwright');
   (async () => {
     const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
     const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
     await page.goto('http://localhost:8099/<harness>.html', { waitUntil: 'load', timeout: 15000 });
     await page.waitForTimeout(500); // let the first frame render / animation settle
     await page.screenshot({ path: '/absolute/path/out.png' });
     await browser.close();
   })().catch(e => { console.error('FAIL', e); process.exit(1); });
   "
   ```
   This exact pattern was smoke-tested and confirmed working in this environment — use it as-is.
3. `Read` the resulting PNG alongside 1–2 of the most relevant `docs/reference/lilgator_*.jpg`
   files side by side and do an honest blind-style A/B: if you didn't know which was which, would
   this piece read as coming from the same game as the reference? Judge silhouette quality,
   faceting/outline presence, color/light quality, and (for characters) whether it could be mistaken
   for unmodeled primitives.
4. Report: pass/fail against the bar, and the **single biggest gap** — not a laundry list. One
   clear, actionable next fix beats ten minor nitpicks.

## Module layout so far

```
src/saturday/
  toon.mjs                 # gradient-map toon materials + onBeforeCompile outline helper
  lowpoly.mjs               # faceted modeling helper kit
  proceduralTextures.mjs    # canvas-painted alpha/foliage/ground/cloud textures
  sky.mjs                   # toon sky dome + clouds + day-cycle lighting rig
  palette.mjs                # named color constants
  worldScale.mjs             # shared scale/unit constants
  camera.mjs                 # the one owner of camera framing
  render.mjs                 # the one owner of renderer/scene mount setup
  imagination.mjs            # imaginable-prop contract + transform effect
  treasure.mjs                # pocket-treasure item factory + pickup + pouch UI
  audio.mjs                   # single-AudioContext ambience + gibberish owner
  toddler.mjs                  # toddler character factory + rig + procedural animation
  movementController.mjs       # wobbly movement/curb-balance, drives toddler rig state
  livingRoom.mjs / backyard.mjs / sidewalk.mjs / playground.mjs   # environments (hybrid: sourced+re-materialized props)
  ...                          # further modules added as built
docs/reference/lilgator_*.jpg   # official Lil Gator Game screenshots, ground truth for critics
```
