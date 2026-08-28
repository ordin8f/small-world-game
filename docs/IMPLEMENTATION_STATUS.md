# Implementation Status

## Completed for the early (Three.js) build

- one middle episode, The Lost Ball;
- dependency-free WebGL2 renderer and static browser packaging;
- child-height movement and camera;
- deterministic episode state machine;
- Emotional Lens integration;
- subtitle/objective UI, mute, reduced motion, restart, and local feedback export;
- GitHub Actions verification (`npm run verify` on every push/PR);
- a GitHub Pages deployment workflow (`.github/workflows/pages.yml`) — note: GitHub Pages itself has never been enabled on this (private) repository, so this workflow has never actually published a reachable URL, verified 2026-08-28 (see `DEMO_PLAN.md` section 1);
- agent ownership contracts and playtest planning material (see `docs/PLAYTEST.md`);
- regression fixes for screen-relative movement and the garden opening.

## Where the Godot production build stands

See `DEMO_PLAN.md` section 1 for the full, on-machine-verified status. In short: the engine installs and the project imports cleanly, the gdUnit4 test suite passes, and the windowed build runs and renders. Almost nothing visual has been human-verified. `DEMO_PLAN.md` estimates the Godot work at roughly 10–15% of the demo, tracked against milestones M0–M6 there, not the P0–P8 backlog below.

## Not yet production-complete

- the Godot build reaching demo quality (`DEMO_PLAN.md` milestones M0–M6);
- production character/environment assets and the inverted Emotional Lens architecture (`DEMO_PLAN.md` section 6);
- final animation, facial acting, sound design, and voice acting;
- broader accessibility matrix and device support;
- evidence-based tuning from playtest feedback — none has been collected yet; no community playtest has run (`docs/PLAYTEST.md`);
- additional afternoons or the full home-to-playground vertical slice.
