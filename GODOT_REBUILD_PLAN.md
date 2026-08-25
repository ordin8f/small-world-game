# Godot rebuild — The Lost Ball port (`godot/`)

> Status: approved plan, 2026-08-25. Implementation happens on branch `godot/lost-ball-port`; this file is the ticket source for every task. Companion docs: `docs/IMPLEMENTATION_PLAN.md` (long-term milestones), `docs/EPISODE_THE_LOST_BALL.md` (the episode being ported), `AGENTS.md` (agent rules).

## Context

The repo has two prototypes. **The Lost Ball** (`main`, vendored Three.js in `src/*.mjs`) works: a 10-beat, ~5-minute episode with a real objective, a deterministic state machine, an authored camera, and an "Emotional Lens" that bends camera/fog/colour without ever showing a meter. **Saturday Afternoon** (branch `claude/saturday-afternoon-game-fxdh08`) does not: it was built by a builder/critic agent loop whose critics judged *screenshots of isolated debug harnesses*, never play. It shipped with the follow camera outside the starting room's walls (solid beige screen within a second of pressing W), a walk speed of 0.34 m/s, and no objective — its prompt asked for a visual bar, not a game.

Decision (2026-08-25): rebuild in **Godot 4.7, GDScript** (Godot's C#/.NET has no web export), in `godot/` in this repo, developed locally on this Windows 11 machine. **First target is a 1:1 port of The Lost Ball** — proven design, tiny scope, known numbers — to validate three things before any new content: the toolchain (headless import/test/export), web deploy to GitHub Pages, and an agent working agreement in which nothing passes unless the game is *played* (input-driven playthrough tests plus a critic loading the exported web build at the real play camera). Saturday Afternoon's toddler content becomes episode 2 afterwards, with beats — out of scope here.

Godot gives us the exact things that broke: `SpringArm3D` camera collision, `CharacterBody3D` movement, an editor where a 2 m-wide room is obvious, `AnimationTree` for the Kenney clips, and a headless test runner.

## Verified constraints (Aug 2026)

- Godot 4.7 stable via `winget install -e --id GodotEngine.GodotEngine`. Not installed yet — Task 0.0. Web export needs the export templates installed too (Editor → Manage Export Templates, or the `.tpz` from `godotengine/godot-builds`).
- Web export with **Thread Support = off** needs no COOP/COEP headers → works on GitHub Pages. Output `index.html .js .wasm .pck .png`; serve locally with `python -m http.server`. Web export supports only the **Compatibility (WebGL2)** renderer [VERIFY in 4.7].
- Headless CLI: `godot --headless --path godot --import`; `godot --headless --path godot --export-release "Web" build/web/index.html`; gdUnit4 CLI `res://addons/gdUnit4/bin/GdUnitCmdTool.gd`. gdUnit4 `SceneRunner`: `simulate_action_press/_pressed`, `simulate_key_press/_pressed`, `simulate_frames`, `await_input_processed` [VERIFY signatures against the installed version].
- `JavaScriptBridge.eval` lets the web build publish state to `window` and read commands back [VERIFY return types; fallback `create_callback`].
- Repo CI: `verify.yml` runs `npm run verify`; `pages.yml` publishes `dist/`, which `tools/package-site.mjs` **wipes and rebuilds from `src/` only**. `tools/check-files.mjs` is a whitelist (adding `godot/` breaks nothing). `.gitignore` has no `.godot/` entry.
- Assets already vendored (CC0/MIT by prose only — no credits file; the v0.2 merge deleted `v02/ASSET_CREDITS.md`): `src/assets/kenney/character-{male-a,female-b,male-c}.glb` — rigged, 32 clips incl. `idle, walk, sprint, pick-up, sit, emote-yes, emote-no, attack-kick-right` (no `wave`); `src/assets/park/{tree_large,bush_large,bench,street_lantern}.gltf`; `src/assets/house/house.gltf`; `docs/reference/lilgator_*.jpg`, `docs/concept-art/visual-direction-contact-sheet.jpg`.
- Three.js source facts to mirror: player walks **2.65 m/s, runs 4.1** (`src/game.mjs:345`); `getVisuals().cameraDistance/cameraFov/saturation/sway` are computed but **never applied** in `game.mjs` (camera uses only `cameraProfile`) — port them behind a `lens_camera_enabled` flag, default off, so the baseline stays 1:1.

## Source of truth for the port

| From | To (`godot/`) | Notes |
|---|---|---|
| `src/logic.mjs` — `EpisodeDirector`, `STATE_COPY`, `ALLOWED`, `emotionalTarget`, `EmotionalLens`, `getVisuals`, `dominantEmotion`, `clamp/lerp/smoothstep/interpolateColor` | `scripts/logic/episode_director.gd`, `emotional_lens.gd`, `lens_math.gd` | Verbatim. States `ARRIVE→OBSERVED→BALL_IN_FLIGHT→FIND_BALL→RETURN_BALL→INVITED→GO_HOME→COMPLETE`; events `observe, ball_kicked, ball_landed, ball_picked_up, ball_returned, joined, entered_home`; out-of-order → `false`. Lens eases `1-exp(-dt*1.7)`, clamps 0..1. |
| `src/camera.mjs` — `cameraProfile(z)`, `damp`, `inputDirection` | `scripts/logic/camera_profile.gd` | Zones THRESHOLD/APPROACH/REVEAL (distance 12/14/16, height 3.2/3.6/4.0, target 1.15/1.2/1.25, fov 46/48/50, lateral 0.55/0.85/1.25, lead 0.5/1.2/2.1, yaw −0.045/+0.035/−0.07), smoothstep blends z 7→3 and −2→−5, clamps x ±9.65, z −12.55..11.05. Fixed rig, no orbit. |
| `src/world.mjs` — colliders, bounds, `circleIntersectsBox`, `canMoveTo`, palette | `scripts/logic/world_bounds.gd`, `scenes/courtyard.tscn` | 11 box colliders (garden wall in two pieces leaving the gap at z≈−3); bounds x ±10, z −12.5..12; player r 0.32. Points: start [0,0,6.5]; group [0,0,−3.8]; watch r2.3 @[0,0,−1.2]; ball lands [8.6,0.45,−6.6] r1.45; return r2.1; join r2.2 @[0,0,−3.1]; door r1.8 @[0,0,10.8]. |
| `src/game.mjs` — dispatch switch (192–236), dialogue lines (132–141), trigger radii (170–188), ball flight/carry (360–374), camera rig (384–411), fog/light mapping (413–428), NPC defs (89–93) | `scripts/game.gd` (autoload), `scenes/ball.tscn`, `scripts/perception.gd` | Timers: `ball_kicked` 2.6 s after OBSERVED; flight 1.8 s sin-arc [0.5,0.45,−3.7]→[8.6,0.45,−6.6] then `ball_landed`; Mom's line 3.0 s into GO_HOME; end card 1.9 s after COMPLETE. Ball emissive only in FIND_BALL. |
| `tests/logic.test.mjs`, `tests/camera.test.mjs` | `godot/tests/unit/*.gd` | Same 9 assertions, plus new playthrough tests (below). |
| `index.html`, `styles.css` | `scenes/ui/*.tscn` | Title card, "Right now" objective, prompt, subtitle/dialogue card, Sound / Reduce-motion, end card with feedback copy, restart. No meters. |
| `docs/PRODUCT_CONTRACT.md`, `docs/EMOTIONAL_LENS.md`, `docs/ART_DIRECTION.md`, `AGENTS.md` | binding, unchanged | No scoring/collectibles/meters; controls responsive in every state; info never colour-only; assets copied, never edited. |

## Layout

```
godot/
  project.godot  export_presets.cfg  addons/gdUnit4/
  scenes/   main.tscn courtyard.tscn player.tscn camera_rig.tscn ball.tscn interaction_zone.tscn
            ui/hud.tscn ui/title_card.tscn ui/end_card.tscn
  scripts/  game.gd player.gd camera_rig.gd ball.gd perception.gd debug_overlay.gd debug_bridge.gd
  scripts/logic/  lens_math.gd emotional_lens.gd episode_director.gd camera_profile.gd world_bounds.gd
  tests/    unit/*.gd  play/*.gd  helpers/drive.gd
  assets/   copied from src/assets/** (unmodified) + .import sidecars (committed)
  tools/    godot.ps1|sh  import.*  test.*  export.*  serve.*  verify.*  shots.*
  build/web/   (gitignored)
```

## M0 — Foundation (kill-criteria milestone)

**0.0 Install (user runs).** `winget install -e --id GodotEngine.GodotEngine`; open the editor once and install export templates for 4.7; put the `_console.exe` on PATH or set `GODOT_BIN`. Accept: `godot --version` prints `4.7.stable`.

**0.1 Project skeleton.** `godot/project.godot`: `rendering_method="gl_compatibility"`, 1280×720, stretch `canvas_items/expand`, physics 60 Hz. Input map: `move_forward/back/left/right` (WASD + arrows), `run` (Shift), `interact` (E/Space), `restart` (R), `debug_toggle` (F3). Autoloads `Game`, `DebugBridge`. `.gitignore` += `godot/.godot/`, `godot/build/`, `godot/reports/`. Accept: `godot --headless --path godot --import` exits 0.

**0.2 Web export preset + tool scripts.** `export_presets.cfg`: preset "Web", thread support off [VERIFY key `variant/thread_support=false`], path `build/web/index.html`. `tools/` (PowerShell + bash pairs): `godot` resolves `$GODOT_BIN`/PATH; `import`, `test`, `export`, `serve` (`python -m http.server 8081 --directory godot/build/web`), `verify` = import → test → export → assert the five output files exist. Accept: `godot/tools/verify.ps1` green; critic loads `http://localhost:8081/` in Chrome, sees the Godot splash, console clean.

**0.3 gdUnit4.** Vendor the gdUnit4 release for 4.7 into `godot/addons/gdUnit4` [VERIFY version], enable in `project.godot`. `test`: `godot --headless --path godot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --add res://tests --ignoreHeadlessMode` [VERIFY flags]. One smoke test. Accept: CLI reports 1 passed; a deliberately failing test returns non-zero (then remove it).

**0.4 Debug overlay + JS bridge.** `debug_overlay.gd` (CanvasLayer, F3): state, beat index, player pos, comfort/energy/curiosity, dominant emotion, camera pos — mirrors `game.mjs:470–481`. `debug_bridge.gd`: on web, each frame `JavaScriptBridge.eval("window.__SMALL_WORLD__=<json>")`; with `?debug=1`, poll `window.__SW_QUEUE__` and execute `{cmd:"press",action,frames}`, `{cmd:"teleport",x,z}`, `{cmd:"dispatch",event}` via `Input.action_press` / direct calls [VERIFY eval return type; fallback `create_callback`]. Accept: critic reads `JSON.stringify(window.__SMALL_WORLD__)` in Chrome; pushes a `press` and sees position change.

**0.5 CI + Pages.** New `.github/workflows/godot.yml` (push/PR): install Godot 4.7 + templates on ubuntu (`chickensoft-games/setup-godot` or direct download from `godotengine/godot-builds` [VERIFY]), run `godot/tools/verify.sh`, upload `godot/build/web` as artifact. `pages.yml`: same Godot steps before `npm run verify`. `tools/package-site.mjs`: after copying `src/`, if `godot/build/web` exists copy it to `dist/godot/` (Three.js build untouched at `/`). Accept: Pages `/godot/` loads the splash; `/` still plays the Three.js build.

**0.6 Asset credits.** Add repo-root `ASSET_CREDITS.md`: Kenney characters + colormap (CC0), Tiny Treats props/textures [VERIFY source + licence], Three.js (MIT), reference screenshots (© Playtonic/MegaWobble, reference only). Link from `README.md`.

**Kill criteria (end of M0):** headless export fails, or the export does not boot on localhost in Chrome → stop, fall back to PlayCanvas (the README's stated production direction).

## M1 — Player, camera, greybox

**1.1 Pure ports + unit tests.** `lens_math.gd`, `camera_profile.gd` (`profile(z)`, `input_direction(x,z,yaw)`, `damp`), `world_bounds.gd` (`COLLIDERS`, `circle_intersects_box`, `can_move_to`) verbatim from `src/camera.mjs`, `src/world.mjs`. Tests port `tests/camera.test.mjs` and the garden-gap case of `tests/logic.test.mjs`. Verify: `tools/test`.

**1.2 Greybox courtyard.** `courtyard.tscn`: floor; one `StaticBody3D`+`BoxShape3D` per entry of `world.mjs:20–31` (size 2·half, height 2.4) plus an invisible bound at z=12.3; visual CSG/`MeshInstance3D` copies of `scene.mjs:43–116` (towers, bridge, slide, home threshold, puddles, bench) in `palette` colours, matte. `Marker3D` per key point with radius metadata. Sun `DirectionalLight3D` + `WorldEnvironment` from `game.mjs:41–59`. Accept: `tests/play/test_garden_gap.gd` — teleport to (4.2,0,−3.0), hold `move_right` 90 frames → x > 6.0; at z=−5.9 and −1.1 → x stays < 4.75. Human: the gap reads child-sized.

**1.3 Player.** `player.tscn`: `CharacterBody3D`, `CapsuleShape3D` r 0.32, y locked, placeholder capsule 1.08 m. `player.gd`: `@export walk_speed := 2.65`, `run_speed := 4.1` (the source's values; re-tune only from play feedback); direction = `CameraProfile.input_direction(x, z, profile.authored_yaw)`; `move_and_slide()`; heading eased as `game.mjs:354–355`. Accept: `tests/play/test_player_movement.gd` — hold `move_forward` 120 frames → Δz ≈ −walk_speed·2 s ±15 %; with `run` ≈ run_speed; zero input → zero velocity. (This is the Saturday Afternoon failure, guarded.) Human: WASD responsive.

**1.4 Camera rig.** `camera_rig.tscn`: pivot `Node3D` → `SpringArm3D` → `Camera3D`. Per frame: `p = CameraProfile.profile(player.z)`; desired position/look target exactly as `game.mjs:391–410` (lateral, height, lead, clamps); pivot at look target, arm oriented toward desired position, `spring_length = distance`, `add_excluded_object(player)`, `look_at(target)`; damp fov λ 5.5, position λ 7.3 (16 with reduced motion) [VERIFY SpringArm3D axis convention]. No orbit. Accept: `tests/play/test_camera_never_in_geometry.gd` — `helpers/drive.gd` steers start → watch → gap → ball → group → door; every frame a raycast head→camera (excluding player) is empty, camera y ≥ 0.6, inside clamps. Human + critic on the web build: three zone changes visible, never clips.

## M2 — Episode

**2.1 Logic autoloads + unit tests.** `episode_director.gd` (`state, history, start(now), dispatch(event, now) -> bool, copy(), emotional_target(distance_from_group)`), `emotional_lens.gd` (`set_target, nudge, update(dt), get_visuals()`), `dominant_emotion` — verbatim from `src/logic.mjs`. Tests port `tests/logic.test.mjs` 1:1 (derived emotion; ease+clamp; out-of-order rejected; 7 events → COMPLETE, history size 8).

**2.2 Orchestration.** `game.gd` autoload: director + lens, `run_id` + `schedule(callable, secs)` via `create_timer` (respects `Engine.time_scale` so tests can accelerate), `dispatch(event)` mirroring `game.mjs:192–236` incl. dialogue lines and the three timers; signals `state_changed, dialogue_shown, prompt_changed`; `reset()`. `interaction_zone.tscn` (`Area3D` + cylinder, radius from `game.mjs:170–188`, active only in its state) at watch/ball/group/join/door; `interact` dispatches the active zone's event.

**2.3 Ball, children, end.** `ball.gd`: sphere r 0.42; on BALL_IN_FLIGHT a 1.8 s `Tween` sin-arc (`game.mjs:361–369`) then `dispatch("ball_landed")`; carried offset (0.36 side, y 0.88); hidden with the group from INVITED unless carried; emissive only in FIND_BALL; never below y 0.45; reset by `restart`. Three placeholder capsules at `NPC_DEFS` (`game.mjs:89–93`). Accept: `tests/play/test_playthrough.gd` — `Engine.time_scale = 8` [VERIFY with SceneRunner], drive to each zone, press `interact`, await timers; assert the full 7-event sequence, `COMPLETE`, history 8, end card visible, ball always within 1.45 of walkable ground. **This test gates every later task.**

**2.4 UI.** `hud.tscn`: objective ("Right now"), prompt, dialogue card, `Sound on`/`Reduce motion`, title card "Begin the afternoon", end card with the three questions + notes + "Copy playtest notes" (`DisplayServer.clipboard_set`; web fallback via `JavaScriptBridge` [VERIFY]) + "Play again". Copy text from `index.html`. Vignette/warmth: full-screen `ColorRect` shader replicating `styles.css:37–43`, uniforms from `get_visuals()`. Accept: playthrough asserts objective text == `STATE_COPY[state].objective` after each transition; human confirms readability without colour.

**2.5 Perception.** `perception.gd`: per frame `lens.set_target(director.emotional_target(dist_to_group))`, `update(dt)`, apply: fog begin/end from `fogNear/fogFar`, fog/sun/ambient colours via `interpolate_color` (`game.mjs:414–423`), exposure 0.82→1.12, saturation [VERIFY `Environment` adjustments in Compatibility]; fireflies `CPUParticles3D` (12, around ball) emitting only in FIND_BALL; home glow 0.65+pulse in GO_HOME/COMPLETE; lens camera modulation behind `lens_camera_enabled`. Audio: minimal port of `src/audio.mjs` (three drones with mood gains, three chimes) via `AudioStreamGenerator` [VERIFY latency on web, threads off]. Accept: unit test — FIND_BALL far from group → lower comfort → smaller fogNear than ARRIVE; critic plays start-to-end on the web build and confirms the world visibly changes between BALL_IN_FLIGHT and INVITED with no meter.

## M3 — Look

**3.1 Characters.** Copy `src/assets/kenney/*` → `godot/assets/kenney/`; player instance scaled to 1.08 m, rotated π (`characters.mjs:126`), NPCs 1.0 m. `AnimationTree` over speed with `idle/walk/sprint`; Mina `emote-yes` on `ball_returned`, Arun `attack-kick-right` on `ball_kicked` [VERIFY imported clip names]. Accept: playthrough green; screenshot at start shows a walk cycle.

**3.2 Props.** `park/*`, `house/*` at `scene.mjs:87–107` positions. Visual only — 1.2's collision bodies untouched (tests guard them).

**3.3 Materials + three moods.** Matte `StandardMaterial3D` (roughness ≥ 0.78, metallic 0), palette from `world.mjs:3–18`. Three `Environment`/sun presets (late afternoon for ARRIVE..RETURN_BALL, invitation warmth for INVITED, dusk for GO_HOME/COMPLETE) blended by `warmth`. World must read well with the lens disabled.

**3.4 Screenshot A/B.** `tools/shots` + `scripts/screenshot_route.gd`: windowed run drives the 1.4 route, saves six PNGs (threshold, watch, gap, ball, circle, door). Critic repeats in Chrome at the same positions (bridge teleport) against `docs/reference/lilgator_*.jpg` and the concept contact sheet. Accept: playthrough green **and** critic passes the six frames for scale, sparseness, warm light/deep shadow.

## Working agreement for agents (replaces the Saturday Afternoon critique protocol)

- One task per agent; ticket format from `AGENTS.md` (files allowed/forbidden, acceptance, verification).
- Nothing passes without `godot/tools/verify` green: import, every gdUnit4 test including the playthrough, web export.
- The critic must load the exported build from `tools/serve` in Chrome, play the relevant beat with real input (keys or the bridge), read `window.__SMALL_WORLD__`, and screenshot at the play camera. Screenshots of isolated scenes or the editor do not count.
- Builders report measured numbers (m/s, seconds per beat, camera hits) — not adjectives.
- Commit only after verify passes; binary assets copied, never edited; no new dependencies beyond gdUnit4.

## Verification (end-to-end)

1. `godot/tools/verify.ps1` — import, unit + play tests, web export, output files present.
2. `godot/tools/serve.ps1`, then in Chrome at `http://localhost:8081/?debug=1`: play start → end by keyboard; `window.__SMALL_WORLD__` reports `COMPLETE` with 8 history entries; no console errors.
3. `npm run verify` still green on `main` (Three.js build untouched); after 0.5, Pages serves `/` (Three.js) and `/godot/` (Godot).
4. Human playtest per `docs/PLAYTEST_SUCCESS_CRITERIA.md`: finishes without instructions, finds the garden route without an arrow, can describe the mood shift with no meter on screen.

## Next after this plan

Episode 2 — the Saturday Afternoon toddler content — gets its own design doc first (beats, objective, ending, in the style of `docs/EPISODE_THE_LOST_BALL.md`) before any Godot work; its art recipe reuses `docs/SATURDAY_AFTERNOON_BIBLE.md` palette/proportions, not the Three.js code.
