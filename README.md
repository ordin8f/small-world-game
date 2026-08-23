# Small World

A browser-first, stylized 3D narrative game about an ordinary afternoon in the life of a young child: getting ready, walking to a playground, playing, approaching other children, making friends, hearing a parent call, and returning home.

The first objective is not to build a full game. It is to prove one complete 15–20 minute vertical slice:

**Home → get ready → playground → play alone → approach children → shared activity → parent calls → collect belongings → return home → put things away → end-of-day drawing.**

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

## Repository status

This initial commit contains the product contract, implementation roadmap, AI-agent working rules, and first development backlog. Gameplay code starts with milestone P0-01.

## Documents

- [`docs/PRODUCT_CONTRACT.md`](docs/PRODUCT_CONTRACT.md) — non-negotiable experience and scope rules
- [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) — architecture, systems, milestones, gates, risks, and asset strategy
- [`docs/BACKLOG.md`](docs/BACKLOG.md) — ordered first implementation tickets
- [`AGENTS.md`](AGENTS.md) — guardrails for local coding agents

## Core principle

Ordinary childhood actions should feel meaningful without combat, danger, scoring, morality meters, or overcomplicated systems.
