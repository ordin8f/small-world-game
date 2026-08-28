# AI Coding-Agent Rules

These rules apply to every coding task unless a ticket explicitly overrides one.

1. Use strict TypeScript.
2. Do not use `any` without a written justification.
3. Do not add dependencies unless the ticket explicitly permits it.
4. Do not couple story progression directly to scene-object scripts.
5. Communicate gameplay through typed domain events.
6. Keep engine-specific objects (Godot nodes and resources) outside the pure narrative state machine wherever practical.
7. All content IDs must be stable and unique.
8. Validate external JSON/content before using it.
9. Important story objects must have recovery behavior if dropped or lost.
10. Every new system requires tests or a documented manual verification procedure.
11. Run format, lint, typecheck, tests, and the production build before declaring completion.
12. Report every changed file and every known limitation.
13. Never claim visual behavior was verified unless the game was actually launched and inspected.
14. Do not replace a working subsystem merely to simplify the current ticket.
15. Do not modify binary 3D/audio assets unless the ticket explicitly asks for it.
16. Prefer small, reviewable tickets over broad autonomous rewrites.
17. Never implement features listed under `Decisions to postpone` unless explicitly requested.
18. `docs/ART_DIRECTION.md` (with `docs/concept-art/`) is the binding visual contract for camera, scale, composition, environment, and lighting work. The Lil Gator Game reference set and the Saturday Afternoon build bible are superseded — see `docs/archive/superseded/README.md` — and must not be used as direction.
19. Treat `docs/EMOTIONAL_LENS.md` as the contract for emotional-state and perception work; do not introduce a player-facing emotion score without an explicit design change.
20. Emotional/perception systems must not mutate physical collision or silently control narrative progression.

## Required ticket format

Each task given to an AI coding agent should state:

- Goal
- Relevant architecture
- Files it may modify
- Files it must not modify
- Required behavior
- Non-goals
- Acceptance tests
- Verification commands
- Expected completion report

## The Godot production exception

For the production build under `godot/`:

- Typed GDScript is permitted, and is in fact the production language for this track, even though rule 1 says strict TypeScript — that rule was written for an earlier PlayCanvas/TypeScript direction that was decided but never implemented (`DEMO_PLAN.md` section 2.1). `DEMO_PLAN.md` decision 1 is the record of the actual engine decision. Treat untyped GDScript the way rule 2 treats `any`: it needs a written justification.
- Godot 4.7.2, Forward+ renderer, Windows desktop build. Web export is a later nice-to-have, not a gate (`DEMO_PLAN.md` section 8).
- gdUnit4, vendored under `godot/addons/gdUnit4/`, is the sanctioned test framework for this track.
- Run `godot/tools/verify.ps1` (headless import, the gdUnit4 suite, and a release export) and `godot/tools/shots.ps1` (route screenshots — in progress, not yet landed) before claiming a milestone complete. Rule 13 still applies: running the verification scripts is not the same as launching and playing the build yourself.
- `DEMO_PLAN.md` is the ticket source for this track until the demo ships, including its milestone gates and kill criteria.

## The Lost Ball prototype exception

`src/*.mjs`, `index.html`, and `styles.css` are a frozen browser prototype (`DEMO_PLAN.md` decision 6), kept as a reference archive rather than a track receiving further feature work:

- JavaScript modules are permitted even though rule 1 says strict TypeScript. This is a closed exception for existing code, not a precedent for new non-Godot work.
- Three.js is the sanctioned rendering library for this prototype, vendored locally under `src/vendor/three/` — see `docs/superpowers/specs/2026-08-23-merge-v02-into-lost-ball-design.md` for the explicit ticket that approved it. Do not add any *other* framework, backend, account system, telemetry, or CDN without a new explicit ticket, and do not switch Three.js back to a CDN reference.
- Keep episode state, emotional perception, rendering, and release concerns separated (`src/logic.mjs`, `src/camera.mjs` / `src/characters.mjs` / `src/scene.mjs`, and `src/game.mjs`'s orchestration respectively).
- Run `npm run verify` and inspect the prototype in a WebGL2 browser before claiming completion.
- Follow the ownership boundaries in `docs/AGENT_ORCHESTRATION.md`.
