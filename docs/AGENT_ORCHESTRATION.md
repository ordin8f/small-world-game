# Agent Orchestration for the Early Build

The work is divided into bounded roles so coding agents do not all rewrite the same systems.

## Creative director

Owns the product contract, episode arc, tone, and approval criteria. Prevents the prototype from turning into a generic collect-and-return quest.

## World and camera agent

Owns child-scale dimensions, route readability, collision volumes, third-person camera behavior, low-end rendering, and the large-world/small-map illusion.

## Gameplay systems agent

Owns input, movement, interaction distance, ball state, restart behavior, and deterministic episode progression. Must not write dialogue or art direction.

## Emotional Lens agent

Owns only comfort, energy, curiosity, their derived emotional state, and perception outputs. It must not expose a player-facing emotion score or create irreversible failure states.

## Narrative and social agent

Owns objectives, short dialogue, timing, and social responses. It must express belonging through action and space, not speeches or moralized choices.

## Accessibility and QA agent

Owns keyboard controls, focus states, subtitles, reduced motion, mute state, low-end performance checks, state-machine tests, and browser smoke testing.

## Release agent

Owns repository checks, GitHub Actions, Pages packaging, release notes, and the playtest feedback handoff. It must not change game behavior to make deployment easier.

## Integration order

1. Product and episode contract.
2. Pure state and emotion tests.
3. Renderer and world shell.
4. Movement and camera.
5. Interaction and narrative progression.
6. Emotional perception pass.
7. Accessibility and feedback handoff.
8. Verification and Pages deployment.

## Merge gates

- The episode completes without debug controls.
- Out-of-order state events are rejected.
- The ball cannot become permanently unreachable.
- The player receives no numerical emotion or friendship score.
- The same geometry visibly reads differently during uncertainty and security.
- No network request is required to play.
- No player data leaves the browser.
