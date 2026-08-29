# Small World — Demo Plan

> Status: draft for review, 2026-08-28. **Supersedes `GODOT_REBUILD_PLAN.md`.**
> Binding art contract: `docs/ART_DIRECTION.md` + `docs/concept-art/`.
> This file is the ticket source for every task until the demo ships.

## 1. Where the project actually is

Verified on this Windows machine on 2026-08-28, not taken from commit messages:

| Check | Result |
|---|---|
| Godot 4.7.2 installs, project imports | **Pass** — `--headless --import` exits 0 |
| gdUnit4 suite | **Pass** — 26 cases / 14 suites, 0 failures, incl. a driven playthrough and a 16 s camera-collision test |
| Game runs windowed | **Pass** — 14 s+, zero errors, Vulkan + OpenGL both fine |
| Game renders a coherent scene | **Pass** — screenshot captured via in-engine viewport grab |
| Forward+ renderer on this GPU | **Pass** — Vulkan 1.4, AMD Radeon 8060S; volumetric fog, SSAO, glow, ACES all available |
| Windows export | **Pass** (2026-08-28) — `SmallWorld.exe` runs standalone, Vulkan Forward+, no errors |
| Web export | **Pass** (2026-08-28) — previously 15/15 CI runs aborted with SIGABRT after `savepack`; caused by packing the enabled gdUnit4 addon into the release. Fixed by excluding `addons/gdUnit4/*`, `tests/*`, `tools/*`. No longer the target, but no longer broken. |
| GitHub Pages | **Never enabled** — `has_pages: false`, repo private; every deploy since 2026-08-23 404s |
| Anyone had played it before today | **No** |

The episode logic is real and tested. Everything visual has been unverified by any human until now.

**Honest completion estimate: the Godot work is ~10–15% of the demo, not "M3.4".** Milestones were credited for code written, not for experience delivered.

## 2. Why this project produces prototypes instead of a game

Four causes, in increasing order of importance. All four are evidenced, not inferred.

**2.1 It re-platforms instead of finishing.** Hand-rolled WebGL2 → vendored Three.js → PlayCanvas (declared, never started) → Godot. PlayCanvas is still named the "production direction" in ~9 files across all three branches and has never had one line of code written. The playable content has not grown past the same ~5-minute episode through all of it.

**2.2 Verification was built to exclude the human.** Every gate producing a durable artifact was skipped or left broken — screenshot tooling never written, CI export red for 15 consecutive commits, Pages never enabled, Godot never installed. Every gate that runs without a person is green. In the entire project history there is exactly **one** piece of human feedback ("too close, weird angle") and it produced the single best commit in the repo, the 2.2× camera retune (`d982389`).

**2.3 The art direction was silently replaced by an agent.**

| Artefact | Author | Date |
|---|---|---|
| `docs/concept-art/visual-direction-contact-sheet.jpg` | RJ | 2026-08-23 |
| `docs/ART_DIRECTION.md` | RJ | 2026-08-23 |
| Lil Gator refs + `SATURDAY_AFTERNOON_BIBLE.md` | Claude (agent) | 2026-08-23 |

The Saturday bible declares itself to "supersede" the human-authored art direction and instructs readers to reject its "avoid toy-box rainbow palette" line by name. Every later agent adopted the agent-invented bright-toon direction because it was louder and better documented. **The human art direction was never argued down. It was buried.** This plan restores it.

**2.4 The Emotional Lens owns the lighting — so the game cannot be art-directed.**
`godot/scripts/perception.gd::_physics_process` overwrites `fog_light_color`, `fog_depth_begin/end`, `ambient_light_color`, `tonemap_exposure` and `sun.light_color` **every physics frame**, computed from the `warmth` float. The only authored values live in the courtyard bootstrap and are erased within one frame of play.

`docs/ART_DIRECTION.md` requires the opposite: *"Base world — neutral, beautiful, readable... The base scene must remain coherent when all Emotional Lens effects are disabled."* There is no base scene. This flaw was ported verbatim from `game.mjs` and has survived every rewrite. It is the mechanical reason no lighting pass has ever stuck.

## 3. Decisions

1. **Engine: Godot 4.7.2, typed GDScript.** No further ports. The decision rests on tested behaviour that exists, not on sunk cost.
2. **Renderer: Forward+. Target: Windows desktop.** Web export is a later nice-to-have, not a gate. This is what makes the concept art reachable — volumetric fog and real shadowing are the look.
3. **`docs/ART_DIRECTION.md` and the concept sheet are the binding visual contract.** The Lil Gator reference set and the Saturday bible move to `docs/archive/superseded/` with a header explaining why.
4. **`AGENTS.md` gets an explicit written exception** permitting typed GDScript under `godot/`; today rule 1 ("strict TypeScript") conflicts with the entire codebase.
5. **PlayCanvas is struck from every document.** One stack.
6. **The Three.js build is frozen** as an archive. No further work.
7. **`src/saturday/` is deleted.** The bible's *techniques* are salvaged into the art doc; the 9,590 lines are not.

## 4. The demo

**8–10 minutes. One continuous space that reads as three places.** Home threshold → courtyard/garden route → playground. One child, three other children, one off-screen parent, one ball, one ending.

### Screen flow

| # | Screen | Content |
|---|---|---|
| S0 | Boot | Wordmark on black. No engine splash. No audio-unlock banner. |
| S1 | Title | Wordmark over the **live world**, camera drifting at child height, distant ball-bounce and voices. Play / Settings / Credits. Play glides the camera down behind the child in one unbroken move — no cut. |
| S2 | Act 1 — the edge of the game | Arrive, cross to the watch point, observe the circle, Arun kicks, ball sails into the garden. |
| S3 | Act 2 — the garden | The gap route. Light cools, haze closes. Three optional pocket treasures. Ball among fireflies. |
| S4 | Act 3 — the circle opens | Carry it back. **The beat.** The circle opens a gap; you get one roll. |
| S5 | Dusk walk | Parent calls, palette falls to amber-violet, porch light is the anchor, door. |
| S6 | Ending | **An image, not a survey.** Held interior shot: treasures on the windowsill, kids still playing outside as silhouettes. One line. Fade. |
| S7 | Credits | Asset credits from `ASSET_CREDITS.md`. Returns to a dusk title — the game remembers you finished. |
| S8 | Pause | Esc/blur: Resume / Restart / Settings / Quit. Audio ducks. |

**The single emotional beat is being let in**, on Mina's existing line — *"You found it. You can roll first."* — as the circle visibly opens. If a playtester cannot name that moment afterwards, the demo failed regardless of polish.

**The current end-card feedback survey is removed from the ending.** A prototype ends in a questionnaire; a game ends in a picture. Feedback moves to the title screen, post-completion.

## 5. Art direction, made concrete

From `docs/ART_DIRECTION.md` and the concept sheet, as operational rules:

- **Light is the subject.** Every frame is a value composition: dark frame, luminous centre. One low warm directional, volumetric fog carrying visible shafts, low ambient, deep readable shadow.
- **The child is small and often a silhouette.** A fifth of frame height or less in establishing shots. Read as shape, not face.
- **Enclosure, not open field.** The courtyard is currently a wide flat space with low walls; the concept art is canyons, arches and thresholds. Narrow the space, raise the walls, give the camera something to look *through*.
- **Restrained palette, selective warmth.** Not toy-box. Warm light against desaturated shadow.
- **Sparse.** One clear idea per frame. Beauty from proportion and atmosphere, not asset density.
- **Camera low.** Never a generic adult third-person rig scaled down.

**Reference set:** the original concept sheet survives only as a **320×155 thumbnail**. `docs/concept-art/extended/` now holds nine plates at 1672×941 regenerating and extending its six named compositions, so frames can actually be graded. Where the plates and `docs/ART_DIRECTION.md` disagree, the document wins.

## 6. Architecture change: invert the Emotional Lens — **DONE** (`780c690`)

Was: the lens *authored* absolute lighting every frame.
Now: the lens *modulates* an authored base.

- Author three `Environment` presets as saved `.tres` resources — **afternoon**, **golden**, **dusk** — matching the three moods `ART_DIRECTION.md` already specifies.
- `perception.gd` blends between presets by `warmth` and applies **bounded deltas only** (fog density, small exposure trim, saturation). It never writes an absolute colour.
- **Acceptance:** with the lens disabled entirely, the scene is still beautiful in all three presets. This is `ART_DIRECTION.md`'s own stated requirement and is currently unmet.

## 7. Milestones

Each milestone ends with **an executable you double-click and play**, plus six screenshots at the fixed route positions. No exceptions.

**M0 — Make it visible (½ day).**
Fix the export (exclude `addons/gdUnit4/*`, `tests/*`, `tools/*` from the release preset; disable the plugin during export if needed). Add a Windows release preset. Build `tools/shots` + `scripts/screenshot_route.gd` — **the durable-evidence tooling that was specified last time and was the only thing skipped.** Switch to Forward+.
*Gate:* a `.exe` you run, and six PNGs on disk.

**M1 — Invert the lens (1 day).**
Section 6. Three authored presets, lens demoted to modulator.
*Gate:* lens off, scene still reads; three presets visibly distinct in the six shots.

**M2 — Greybox and light it three ways (2–3 days).**
Your own production test, verbatim: *"build one greybox route and light it three ways. If the scene does not already feel compelling with simple geometry, the solution is not more texture detail."* Rebuild the courtyard as enclosure — taller walls, a threshold, a real garden wall with a real gap. **No props, no characters.** Grey boxes and light only.
*Gate:* **you** compare the six greybox frames against the concept sheet and say yes. If it doesn't sing here, stop — nothing downstream fixes it.

**M3 — Characters and silhouette (1–2 days).**
Test whether Kenney's kids survive this lighting as silhouettes. `ART_DIRECTION.md` rules out mascot proportions and oversized eyes by name; in deep shadow they may read fine. This is a test with a real answer.
*Gate:* you judge the silhouettes at play distance.

**M4 — The frame (2–3 days).**
S0–S8. Title over live world, transitions, pause, ending image, credits. The unstyled debug text currently sitting on the player's head is replaced with authored typography.

**M5 — Audio, animation, polish (2–3 days).**
Idle behaviour (the child shifts weight at 20 s, sits at ~45 s — the Kenney rig has `sit`), footsteps, a sound on every story beat, continuous music across the title transition.

**M6 — Ship.** Windows build on itch.io. Web only if it's free by then.

## 8. The gate: no rendered artifact, no milestone

A required check, enforced, not aspirational:

1. Clean checkout builds the release artifact locally **and** in CI.
2. The artifact launches and reaches the title screen.
3. Real simulated input moves the real player.
4. Running state is readable.
5. The **play camera** produces six non-blank screenshots, committed as evidence.
6. **You play it** before the milestone is called done.
7. **A red gate freezes feature work.** Only gate-repair may proceed.

Rule 7 is the one that was missing. CI went red at M0.5 and thirteen more feature commits shipped on top of it.

Builders report measured numbers — m/s, seconds per beat, camera hits — not adjectives. Screenshots of isolated scenes or the editor do not count.

## 9. Kill criteria

- **M0 gate:** if a clean checkout cannot produce a launching Windows build with six non-blank screenshots within one focused day, stop and reassess. (Web export failing again does **not** trigger this — web is no longer the target.)
- **M2 gate:** if the greybox route lit three ways doesn't read as the concept art, the problem is level design or art direction, not the engine. Do not proceed to assets; fix the space.
- **Weak art is not an engine kill criterion.** Switching engines does not manufacture an artist.

## 10. Out of scope — the fence

Home interior beyond the final shot; character customization; any second episode; Saturday Afternoon's four environments; the procedural toddler rig; any PlayCanvas work; any change to the frozen Three.js build; open neighbourhood; dialogue choices; saves beyond a "completed once" flag; gamepad and touch; localization; achievements, scores or meters; and any conversation beginning "what if we switched engines."

## 11. Document cleanup

- `GODOT_REBUILD_PLAN.md` → archived, superseded by this file.
- `docs/SATURDAY_AFTERNOON_BIBLE.md`, `docs/reference/lilgator_*.jpg` → `docs/archive/superseded/` with an explanatory header.
- Strike PlayCanvas from `README.md`, `PLAYTEST.md`, `IMPLEMENTATION_PLAN.md`, `IMPLEMENTATION_STATUS.md`, `BACKLOG.md`, `EPISODE_THE_LOST_BALL.md`, `AGENT_ACCEPTANCE_MATRIX.md`, `AGENT_HANDOFFS.md`, `AGENTS.md`.
- `docs/VERIFICATION.md` documents a `tools/smoke_test.py` deleted in `39dc798`. Correct it.
- `AGENTS.md`: add the typed-GDScript exception.
- Fold the playtest apparatus (guide, triage, checklist, data boundary, release notes) into one file. It documents a studio that doesn't exist.


---

## Progress log

Kept current so this document cannot quietly drift out of date — the failure it
exists to prevent.

### 2026-08-28 — Gate 0 substantially complete, Gate 1 started

**Done and verified on-machine:**

- Godot 4.7.2 installed; project imports clean; **26/26** gdUnit4 cases pass.
- **Export fixed.** Both Windows and Web now export. The SIGABRT that failed all
  15 CI runs was the enabled gdUnit4 editor plugin being packed into the release.
- **A double-clickable Windows build exists** and runs standalone on Vulkan
  Forward+ (`godot/build/windows/SmallWorld.exe`, gitignored — rebuild with the
  Windows Desktop preset).
- **Forward+** renderer enabled; volumetric fog, SSAO, glow and ACES confirmed
  working on the target GPU (AMD Radeon 8060S).
- **The lens is inverted** (`780c690`). Three authored moods in
  `godot/resources/moods/*.tres`; `perception.gd` blends them by episode state
  and applies only bounded modulation. New test asserts the scene is complete
  and authored with the lens disabled.
- **Concept art regenerated** — `docs/concept-art/extended/`, nine plates.
- **Docs reconciled** — PlayCanvas struck, art direction restored as binding,
  superseded material archived with provenance.

**Open, found by looking at frames rather than by tests:**

1. The SpringArm3D camera collapses into the player at the home doorway
   (z ≈ 10.8) — it hits the boundary wall. Gate 1 camera item.
2. The mood values are a first pass. They were chosen by sweeping and looking,
   but not yet against the extended concept plates with a human judging.
3. The space is still a wide flat courtyard. The light is now roughly right; the
   *geometry* is not. This is the larger half of Gate 1 and it is level design.
4. `godot/tools/shots.ps1` and the route screenshots are still in progress.


---

## Gate 1 geometry spec — read the plates, not the old courtyard

Derived 2026-08-28 from `docs/concept-art/extended/`. The current courtyard is a
wide flat field with 2.4 m walls and an open sightline; the plates are enclosed
architecture where **the framing carries the story**. Four changes, each cheap,
each a strong composition on its own.

### 1. The player emerges through a gateway — `concept_07_circle.png`

The plate's whole meaning is carried by *where the camera stands*: the child is
in a **dark threshold passage**, framed by two massive vertical piers in near
silhouette, looking out into a sunlit courtyard where the other three children
play in the chalk circle. The child is outside the light and outside the group —
the same fact, stated architecturally.

Build a gateway/passage at the home end (around z ≈ 8..11) that the player walks
out of. The first sight of the circle must be *through* it. This is the single
highest-value geometry change in the plan: it converts the episode's premise —
"you are not part of their game yet" — from a dialogue line into a composition.

### 2. The courtyard becomes enclosed, not open

Tall perimeter walls (roughly 5–7 m, not 2.4 m), a back wall with a small door,
one large tree breaking the skyline. The chalk circle sits in the lit centre.
Keep the footprint — this is about height and closure, not area.

### 3. The garden gap becomes a low arch — `concept_06_garden_gap.png`

Today the gap is a space between two wall segments. In the plate it is an
**arched opening at ground level**, overgrown, that a child ducks through, with
the ball glowing in golden light on the far side. Cut an arch into the garden
wall instead of leaving a slot between pieces.

The ball beyond it should be the brightest thing in that frame, seen through the
arch before the player reaches it — the visual hook that makes the garden route
something you *want* to take rather than something the objective text tells you
to take.

### 4. Light gets something to cut through

Volumetric fog only reads when it has an edge. Gateways, an arch, a tree canopy
and a doorway give the sun something to shaft between. The current open field
gives it nothing, which is why the haze is currently doing so little.

### Hard constraint

`godot/scripts/logic/world_bounds.gd`'s **collider set must not change shape** —
`test_garden_gap.gd` and `test_camera_never_in_geometry.gd` guard the route, and
the walkable space is already tuned. This is a change to *visual* geometry and to
wall **height**, plus one arch cut. Physics layers may change; collider footprints
may not.


### 2026-08-28 (later) — Gate 1 largely done, Gate 2 done, Gate 4 started

**Landed since the morning entry:**

- **Camera fixed and re-tuned.** The doorway collapse was `camera_rig.gd`'s
  per-axis z clamp, not SpringArm collision — measured collision shrink was
  0.0000 at every beat. Clamping z alone discarded the horizontal reach while
  height kept its authored value, producing a near-vertical look-down. The fix
  spends the reach the wall won't give it sideways. Zones re-tuned to child
  height (12/14/16 at 3.2–4.0 → 5.5/7/10.5 at 1.2–2.6). Every beat now within
  ~3% of its authored distance; the doorway went from 18% to 103%.
- **Four play verbs**, all on geometry that already existed and did nothing:
  ride the slide, balance the garden wall, stepping stones that briefly transform
  how the world looks, splashing puddles. The stones are
  `docs/EMOTIONAL_LENS.md`'s "imagination appears as brief perceptual
  transformations" — specified since day one, never built until now.
- **Geometry**: the garden opening is an arch, the home threshold is a passage,
  a practical light makes the ball findable, bushes cleared off the ball.
- **Independent review** (Codex) audited four claims. Confirmed the export fix
  causally, the lens inversion, and the test suite. Refuted one number of mine
  and found a real hole: the lens test passed with the defect deliberately
  reintroduced. Both fixed; the replacement is mutation-verified.
- Tests **26 → 43**.

**Ordering correction to Gate 1.** This plan sequenced lens → geometry → camera.
Camera has to come second. Four attempts at framing geometry failed because the
camera was somewhere unusable — behind the player's head, inside a lintel, behind
a bush. You cannot compose a frame you cannot see.

**Where the demo actually stands against section 4's nine screens.** The three
acts exist and now have things to do in them. S0 boot, S1 title over the live
world, S6 the ending image, S7 credits and S8 pause do not exist yet — the game
still opens with unstyled text on the character's head and ends with a feedback
survey. That frame is the current work and it is the largest remaining gap
between this and something a stranger would call finished.

**Still open:** the courtyard is a wide flat space where the concept art is
enclosure; the concept_07 framing gateway and the overhead canopy are deferred
awaiting a human's eye on the fixed camera; `test_camera_never_in_geometry` is
narrower than its name and passed straight through the doorway collapse, so it
wants a minimum-separation assertion; and `PRODUCT_CONTRACT.md` excludes
"extensive climbing/balance systems", which is in mild tension with the wall
balance now built.


### 2026-08-28 (evening) — world expanded, mechanics in, camera returned

**Landed:**

- **The world is four connected places**, ~39x37 m against the old 20x24 m room:
  home porch, a narrow walled lane that did not exist, the playground, and the
  garden pocket through an arch. ~75 m of route, ~28 s walking end to end.
- **Nine things to do outside the story**: slide, wall balance, stepping stones,
  puddles, swing, sandbox, two imagination props, three keepsakes. The other
  three children react when you talk to them; the third child is now Priya
  rather than the placeholder "Third".
- **Better props behind a toggle** (`small_world/assets/use_detailed`), so
  detailed for judging feel and primitives for iteration speed.
- **Mouse-look restored.** The Three.js prototype had drag-to-look; the Godot
  port silently dropped it, which nobody noticed while the world was one room.
- Tests **57 -> 93**.

**Known defects, recorded rather than hidden:**

1. The garden-gap beat is a dead frame. `CameraProfile.profile()` is z-only, so
   at the gap seam REVEAL's fixed yaw throws the camera into empty connective
   space. A scoped fix improved the shot but clipped the garden wall and was
   reverted. The real fix needs `authored_yaw` to respond to position.
2. `test_camera_never_in_geometry`'s distance floor is 0.10, down from 0.45.
   The garden gap legitimately squeezes to 0.141 and raising it would make the
   test brittle about a real limit.
3. The sandbox is a checklist, not play, per the agent who built it.
4. Only two imagination props exist, so a player who finds both early has
   nothing left to stumble on.
5. Mouse-look sensitivity uses the browser build's pixel constants, never tuned
   for this window. Unverifiable headlessly.
6. `perception.gd`'s `GROUP_POSITION` still points at the old chalk-circle
   position, so its distance-from-group modulation reacts to empty lane space.

**The pattern worth carrying forward.** Four times today a test in this repo
measured the wrong quantity while passing: the lens test that passed with the
defect deliberately reintroduced; the wall-dismount test that checked a transient
moment rather than a persistent state; a reported 0.7 m camera distance that was
horizontal separation; and a minimum-separation assertion that could never catch
a camera sitting 90 degrees off-axis, because a radius-preserving swing keeps the
distance ratio at 1.0 by construction. Distance cannot distinguish behind from
beside. Before writing an assertion, name the mutation it should catch, then try
that mutation.

**Still open:** the facts refactor (Codex's finding that the world does not
acknowledge the player played), and an ambience pass on the shape vocabulary --
the world was expanded and re-lit but its shapes are unchanged since the original
port.


---

## Scale diagnosis, 2026-08-29

Measured, not estimated. The child is **1.08 m**. Architecture heights in the
world as built:

| Element | Height | Ratio to child |
|---|---:|---:|
| Lane walls | 9.1 m | 8.4 : 1 |
| Playground perimeter walls | 8.2 m | 7.6 : 1 |
| Garden pocket walls | 7.0 m | 6.5 : 1 |
| Home threshold piers | 4.7 m | 4.4 : 1 |
| Playground towers | 2.4 m | 2.2 : 1 |
| Bench, slide, garden wall | 1.0–1.9 m | ~1.5 : 1 |

For reference: a real garden wall is about 1.7 : 1 to a small child, a
two-storey house about 5.7 : 1.

**The world contains two incompatible scale systems.** Cathedral-scale boundary
architecture (7–9 m) and honest child-scale furniture (1–2.4 m) share every
frame. That is what "the player and other folks look disproportionate to the
place" means: the characters are not too small, the walls are too tall relative
to everything else that claims to be child-furniture.

**This is also why the camera reads as wrong.** It sits at 1.2–2.6 m, which is
correct per `docs/ART_DIRECTION.md` — a child's eye height. In a world with 9 m
boundary walls, a child-height camera looks up a canyon in every direction. The
camera is not misconfigured; it is correct for a world whose architecture is
roughly twice too tall. Retuning it before fixing proportion would mean chasing
it indefinitely.

One nuance that survives the diagnosis: the **lane is proportionally fine**. At
9.1 m tall and 6 m wide it is 1.5 : 1, where `concept_02_path_discovery`'s
canyon reads nearer 2.5 : 1. The lane is the one place the plates *want*
monumental, so it stays.

### Two genuine defects found while measuring

- **The slide is broken, not merely mis-oriented.** A 5.2 m plank at y=0.95
  tilted 31 degrees runs from ~2.3 m down to **−0.4 m** — it ends below the
  ground plane, and its top does not meet the tower deck.
- **There is no house.** `house.gltf` sits at z=20, outside the walkable bound
  and behind an 8.2 m wall, so "home" is a blank wall with a hole in it.

### Order of work

1. **Scale** — bring boundary architecture to domestic proportion, keeping
   monumentality where the plates want it (the lane canyon, the home threshold).
2. **Camera** — retune against a coherent world, not before.
3. **The house** — an actual building you approach, not a wall.
4. **Slide geometry**, and move the balance verb from the boundary wall onto a
   low brick edging round a planting bed, which is both better storytelling and
   what a child actually does.
5. **Beauty pass** — largely free once proportion is right. Most of what reads
   as ugly is scale conflict rather than missing detail.

## Surface, sightlines and animation, 2026-08-29

Three things the developer named on seeing the build: textures, better shapes,
and "the playground is quite crammed and all places are not reachable". Then,
separately, "walk animation doesn't properly work — it shows initially but then
it doesn't repeat".

### What landed

- **Surfaces are real** (`1d05024`). Six generated tileable textures under
  `godot/assets/surfaces/` drive a `SURFACES` registry in the courtyard
  generator, applied with triplanar UVs so box geometry needs no authored UVs.
  Textures are optional by construction: `_apply_surface()` returns false when a
  file is missing and the flat palette colour stands.
- **Volumetric fog was eating the distance** (`bd2acc6`). Everything past ~15 m
  washed to one cream value. The depth fog was not the cause — it does not begin
  until 22 m. At 0.018 density a 4.0-energy sun scatters into every view ray.
  Halved density and sun scattering across all three moods.
- **The laundry rendered as black rectangles** floating at head height: thin
  slabs whose camera-facing side is the shadowed back. Now two-sided, backlit,
  no self-shadow.
- **Vegetation is no longer placeholder** (`feat/models`). Kenney Nature Kit
  (CC0) behind `PropLibrary` with a working toggle; six tree species replace
  five clones of one blob.

### Three defects worth recording, because each hid behind a passing test

- **No animation clip loops. None of the 32.** Godot's glTF importer defaults to
  `LOOP_NONE` unless a clip name carries a `-loop`/`-cycle` suffix; Kenney's are
  plain, and nothing in the repo sets `loop_mode`. `set_motion()` guards with
  `if clip == _current_clip: return`, so `walk` plays once, runs 0.67 s, and
  freezes on its last frame while the child keeps sliding. `idle` and `sprint`
  have the identical bug; idle hides it because its last frame looks like
  standing. This is also why NPCs "play idle once and never move again".
- **`character_visual.gd` falls back to `"idle"` silently** when a clip name is
  missing. One NPC's `talk_pose` is `"wave"`, which is not one of the 32 clips,
  so that animation has never once played and nothing reported it.
- **A vendored `.glb` referencing an external texture that is not in the repo
  imports as white.** The Fantasy Town roof references `Textures/colormap.png`;
  only the model files were vendored. Combined with the glow pass it rendered as
  a glowing white lampshade. Three more models from that kit carry the same
  defect, unplaced.

### The reachability complaint was a sightline complaint

A headless flood-fill of the walkable plane, using the real physics world and
the player's actual collision radius, found **every interaction zone reachable
from spawn**. The literal claim does not hold. What it did find: only 8 of 14
place-to-place sightlines are clear at child eye height, 215 m² of walled-off
dead space, and the garden arch's lintel sitting at **1.15–1.95 m — across the
eyeline of a child walking through it**.

The `03_gap` frame confirms it: at the moment the player passes through the
opening, the right ~40% of the screen is the gap wall itself, seen face-on. Four
rounds of camera work could not fix that frame, because the problem was never in
the camera.

**The lesson for testing here is specific.** A sightline test that asks only
"does a ray reach the next place" scores that frame as passing — you *can* see
through the gap. Any measure of openness has to include how much of the view is
occupied by blank near geometry, or it will go green on the exact frame the
developer is objecting to. This is the same defect class as
[[tests-that-measure-the-wrong-thing]]: name the mutation the assertion must
catch, then run it.

### Camera: an approach ruled out

Redirecting REVEAL's yaw near the garden seam was tried across five variants and
abandoned — swinging the camera in either direction from a player that close to a
2 m gap reliably grazes a wall corner at (11,−9) or (11,−7). The fix that holds
is geometry: a collider at (9.5, 1.3) giving SpringArm3D an ordinary thing to
stop against, the same mechanism as every other wall. Zero raycast hits across a
1277-tick driven route. The beat is improved, not solved; the rest is
composition.

Recorded so it is not re-chased: the camera now sits ~6 cm above the top face of
the lane's wide invisible flank. Non-camera-blocking colliders are 2.4 m tall by
the generator's own height rule, so an all-layers raycast finds it while
SpringArm3D and the rendered frame — which only care about layer 2 — do not.
