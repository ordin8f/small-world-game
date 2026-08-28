# Verification

There are two builds in this repository, each with its own verification. Neither has an automated test that drives real simulated input through a real render and asserts on what the player would actually see — see "What is not covered" below.

## The Lost Ball (frozen Three.js prototype)

```bash
npm run verify
```

This checks HTML/module references, JavaScript syntax, pure episode and Emotional Lens behavior, the garden collision opening, and static Pages packaging.

This build previously also had `tools/smoke_test.py`, a Playwright browser smoke test that started the WebGL2 canvas, drove movement, and checked that the deterministic episode reached its ending. It was deleted in commit `39dc798` (2026-08-23) as an orphaned script — it was never wired into `npm run verify` or any CI workflow — and was never replaced. No document should claim it still runs.

### Playability defects corrected before community release

- Horizontal screen-relative movement was reversed.
- The visible garden opening was covered by a single collision wall, preventing a normal playthrough.

Regression coverage in `npm run verify` protects both behaviors at the state-machine level, not via a browser smoke test.

### Known limitations

- geometric placeholder characters and environment;
- no touch controls or gamepad support;
- no production animation, facial acting, or voice acting;
- no persistent save because the episode is intentionally short.

## Godot production build

```powershell
godot/tools/verify.ps1
```

Runs, in order: a headless project import (`godot --headless --import`), the full gdUnit4 suite (26 cases across 14 suites, including a driven playthrough and a 16-second camera-collision test), and a release export.

```powershell
godot/tools/shots.ps1
```

Captures screenshots at the fixed route positions used as milestone evidence (six shots per milestone, per `DEMO_PLAN.md` section 7). This is the durable, on-disk evidence a milestone requires under the gate in `DEMO_PLAN.md` section 8.

### Known limitations

- web export currently fails in CI (SIGABRT immediately after `savepack`, 15/15 runs as of 2026-08-28 — `DEMO_PLAN.md` section 1); the Windows desktop build is the verified target, and web export failure is explicitly not a gate;
- `verify.ps1` and `shots.ps1` confirm the build runs and produces images, not that the images look right — a human still has to look at them before a milestone is called done (`DEMO_PLAN.md` section 8, rule 6).

## What is not covered

Neither build has an automated test that plays through the game and asserts on the rendered result. This document used to imply that coverage existed for the browser build, via the now-deleted `smoke_test.py`; it does not exist for either build today. Until that changes, treat the committed screenshots plus an actual human playthrough as the real verification gate, not a substitute for one.
