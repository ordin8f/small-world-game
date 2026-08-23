# AI Coding-Agent Rules

These rules apply to every coding task unless a ticket explicitly overrides one.

1. Use strict TypeScript.
2. Do not use `any` without a written justification.
3. Do not add dependencies unless the ticket explicitly permits it.
4. Do not couple story progression directly to scene-object scripts.
5. Communicate gameplay through typed domain events.
6. Keep PlayCanvas-specific objects outside the pure narrative state machine wherever practical.
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
18. Treat `docs/ART_DIRECTION.md` as the visual contract for camera, scale, composition, and environment work.
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

## The Lost Ball prototype exception

For the browser experience prototype in `src/*.mjs`, `index.html`, and `styles.css`:

- JavaScript modules are permitted even though the production direction remains strict TypeScript.
- Three.js is the sanctioned rendering library for this prototype, vendored locally under `src/vendor/three/` — see `docs/superpowers/specs/2026-08-23-merge-v02-into-lost-ball-design.md` for the explicit ticket that approved it. Do not add any *other* framework, backend, account system, telemetry, or CDN without a new explicit ticket, and do not switch Three.js back to a CDN reference.
- Keep episode state, emotional perception, rendering, and release concerns separated (`src/logic.mjs`, `src/camera.mjs` / `src/characters.mjs` / `src/scene.mjs`, and `src/game.mjs`'s orchestration respectively).
- Run `npm run verify` and inspect the prototype in a WebGL2 browser before claiming completion.
- Follow the ownership boundaries in `docs/AGENT_ORCHESTRATION.md`.
