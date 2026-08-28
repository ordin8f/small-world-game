# Small World

A minimalistic 3D narrative game about an ordinary afternoon in the life of a young child. The world is deliberately small, but it should feel enormous through scale, light, sound, uncertainty, curiosity, and imagination.

The longer-term objective is one complete 15–20 minute vertical slice:

**Home → get ready → playground → play alone → approach children → shared activity → parent calls → collect belongings → return home → put things away → end-of-day drawing.**

## Current plan of record

**[`DEMO_PLAN.md`](DEMO_PLAN.md) is the plan of record and the ticket source for every task until the demo ships.** It records where the project actually stands — verified on-machine, not taken from commit messages — why it has produced prototypes instead of a finished game for months, and the milestones (M0–M6) to a shippable Windows demo.

In short: the engine is **Godot 4.7.2, typed GDScript, Forward+ renderer, targeting Windows desktop**. That decision is made and verified; there are no more engine ports planned. The episode logic is real and gdUnit4-tested. The visual/art-direction work in Godot is not done yet — see `DEMO_PLAN.md` for the honest completion estimate.

## Design north star

- Minimal environment, exceptional composition and lighting.
- Third-person camera designed from a child's height rather than an adult camera scaled down.
- Ordinary spaces become adventure through scale and perception.
- No combat, game-over loop, morality meter, visible friendship bar, or visible emotion meter.
- Emotional state changes how the child **perceives** the same physical world.
- Fear, boredom, loneliness, happiness, anxiety, curiosity, and excitement are not success/failure states.
- Imagination appears as brief perceptual transformations rather than separate fantasy levels.

## The Lost Ball — frozen browser prototype

Before the Godot rebuild, the project built a shorter episode from the middle of the larger arc as a dependency-free browser prototype: **The Lost Ball**. The child recognizes the other children but is not yet part of their game. When their ball escapes into a quiet garden, retrieving it becomes the social and emotional turning point.

The prototype includes:

- child-height third-person movement through one compact courtyard and playground;
- a complete observe → retrieve → return → join → go-home episode;
- the Emotional Lens changing camera, fog, lighting, sound, and attention without showing an emotion score;
- generated ambience and event sounds with no downloaded audio assets;
- mute and reduced-motion controls;
- a local feedback form that copies or downloads notes — nothing is sent anywhere automatically;
- no account, telemetry, backend, or external runtime dependency.

See [`PLAYTEST.md`](PLAYTEST.md) to run it locally, and [`docs/PLAYTEST.md`](docs/PLAYTEST.md) for playtest scope, success criteria, and the data boundary.

**This build is now frozen** as a reference archive (`DEMO_PLAN.md` decision 6). It did its job — proving out child-scale navigation, the social action loop, and the Emotional Lens — and is not receiving further feature work. The Godot build is a fresh implementation informed by what this prototype validated, not an automated port of this code.

## Production stack

- Godot 4.7.2, typed GDScript
- Forward+ renderer
- gdUnit4 for automated tests, run via `godot/tools/verify.ps1`
- Windows desktop build (web export is a later nice-to-have, not a gate)
- No runtime generative AI

## Documents

- [`DEMO_PLAN.md`](DEMO_PLAN.md) — plan of record: current status, decisions, milestones, and gates
- [`docs/PRODUCT_CONTRACT.md`](docs/PRODUCT_CONTRACT.md) — non-negotiable experience and scope rules
- [`docs/ART_DIRECTION.md`](docs/ART_DIRECTION.md) — binding minimal child-scale visual language, composition, light, materials, and concept-art targets
- [`docs/EMOTIONAL_LENS.md`](docs/EMOTIONAL_LENS.md) — comfort/energy/curiosity model and perception system
- [`docs/EPISODE_THE_LOST_BALL.md`](docs/EPISODE_THE_LOST_BALL.md) — playable episode contract
- [`docs/AGENT_ORCHESTRATION.md`](docs/AGENT_ORCHESTRATION.md) — bounded implementation roles and merge gates
- [`docs/PLAYTEST.md`](docs/PLAYTEST.md) — playtest scope, success criteria, and the data boundary
- [`docs/VERIFICATION.md`](docs/VERIFICATION.md) — what verification actually exists, for both builds
- [`docs/concept-art/`](docs/concept-art/) — refined visual references
- [`docs/archive/superseded/`](docs/archive/superseded/) — retired direction and documents, kept for record and salvage value
- [`AGENTS.md`](AGENTS.md) — guardrails for local coding agents
- [`ASSET_CREDITS.md`](ASSET_CREDITS.md) — sources and licenses for every vendored asset and library
- [`GODOT_REBUILD_PLAN.md`](GODOT_REBUILD_PLAN.md) — the in-progress Godot 4.7 rebuild (`godot/lost-ball-port` branch)

Earlier planning documents — [`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) and [`docs/BACKLOG.md`](docs/BACKLOG.md) — were written for the original PlayCanvas/TypeScript direction described above, which was decided but never built. `DEMO_PLAN.md` supersedes them for active work; they remain for the design intent that still applies (route beats, social approaches, Emotional Lens tuning).

## Core principle

> Ordinary childhood should feel like an adventure without needing to turn the world into a fantasy world.
