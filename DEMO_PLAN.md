# Small World — Demo Plan

> Status: draft for review, 2026-08-28. **Supersedes `GODOT_REBUILD_PLAN.md`.**
> Binding art contract: `docs/ART_DIRECTION.md` + `docs/concept-art/`.
> This file is the ticket source for every task until the demo ships.

## 1. Where the project actually is

Verified on this Windows machine on 2026-08-28, not taken from commit messages:

| Check | Result |
|---|---|
| Godot 4.7.2 installs, project imports | **Pass** — `--headless --import` exits 0 |
| gdUnit4 suite | **Pass** — 24 cases / 14 suites, 0 failures, incl. a driven playthrough and a 16 s camera-collision test |
| Game runs windowed | **Pass** — 14 s+, zero errors, Vulkan + OpenGL both fine |
| Game renders a coherent scene | **Pass** — screenshot captured via in-engine viewport grab |
| Forward+ renderer on this GPU | **Pass** — Vulkan 1.4, AMD Radeon 8060S; volumetric fog, SSAO, glow, ACES all available |
| Web export | **Fail** — 15/15 CI runs abort with SIGABRT (exit 134) immediately after `savepack` |
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

**Note:** the concept sheet survives only as a **320×155 thumbnail** — a mood target, not a matchable reference. Recovering or regenerating a higher-resolution set is a prerequisite for the M2 lighting A/B.

## 6. Architecture change: invert the Emotional Lens

Today: the lens *authors* absolute lighting every frame.
Required: the lens *modulates* an authored base.

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
