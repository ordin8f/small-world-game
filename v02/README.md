# v0.2 — Character + Camera Study

This is intentionally **not** the Lost Ball episode. It is the visual/game-feel gate that should have come first.

## Question being tested

Does it feel good to control a visible child through one beautiful, child-scale composition?

The prototype contains only:

- one visible animated player character;
- two distant playground children;
- a warm home threshold;
- a short alley;
- one playground reveal;
- authored third-person camera zones;
- restrained player look control;
- golden-hour lighting and atmospheric depth.

It deliberately excludes puzzles, dialogue trees, inventories, friendship meters, the Lost Ball sequence, and most Emotional Lens logic.

## Controls

- `WASD` / arrow keys — move
- drag mouse/pointer — glance around within a limited authored range
- `Shift` — run

## Camera philosophy

The player retains movement agency, but not an unrestricted orbit camera. The camera opens in three stages:

1. **Threshold** — close and low; the child is large enough to read, the doorway frames the path.
2. **Alley** — a little farther back with a slight lateral offset; the environment becomes the adventure.
3. **Playground reveal** — wider and more distant; the child becomes visibly small in the social space.

The camera gently springs back toward the authored composition after a player glance.

## Acceptance gate

Do not add the Lost Ball mechanics until:

1. the player character is consistently visible and readable;
2. `W`, `A`, `S`, `D` feel correct relative to the camera;
3. the camera never feels like a generic unrestricted third-person orbit;
4. the playground reveal makes the player want to keep walking;
5. screenshots taken during normal play no longer look like an engineering greybox.
