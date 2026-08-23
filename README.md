# Small World

A browser-first, minimalistic 3D narrative game about an ordinary afternoon in the life of a young child. The world is deliberately small, but it should feel enormous through scale, light, sound, uncertainty, curiosity, and imagination.

The first objective is one complete 15–20 minute vertical slice:

**Home → get ready → playground → play alone → approach children → shared activity → parent calls → collect belongings → return home → put things away → end-of-day drawing.**

## Design north star

- Minimal environment, exceptional composition and lighting.
- Third-person camera designed from a child's height rather than an adult camera scaled down.
- Ordinary spaces become adventure through scale and perception.
- No combat, game-over loop, morality meter, visible friendship bar, or visible emotion meter.
- Emotional state changes how the child **perceives** the same physical world.
- Fear, boredom, loneliness, happiness, anxiety, curiosity, and excitement are not success/failure states.
- Imagination appears as brief perceptual transformations rather than separate fantasy levels.

## Technical direction

- PlayCanvas Engine
- TypeScript
- Vite
- Blender → GLB/glTF asset pipeline
- Vitest for unit/content tests
- Playwright for browser smoke/E2E tests
- `localStorage` for prototype saves
- Static browser deployment
- No runtime generative AI

## Documents

- [`docs/PRODUCT_CONTRACT.md`](docs/PRODUCT_CONTRACT.md) — non-negotiable experience and scope rules
- [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md) — minimal child-scale visual language, composition, light, materials, and concept-art targets
- [`docs/EMOTIONAL_LENS.md`](docs/EMOTIONAL_LENS.md) — comfort/energy/curiosity model and perception system
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) — architecture, systems, milestones, gates, risks, and asset strategy
- [`docs/BACKLOG.md`](docs/BACKLOG.md) — ordered first implementation tickets
- [`docs/concept-art/`](docs/concept-art/) — refined visual references
- [`AGENTS.md`](AGENTS.md) — guardrails for local coding agents

## Core principle

> Ordinary childhood should feel like an adventure without needing to turn the world into a fantasy world.
