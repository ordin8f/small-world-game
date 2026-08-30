# Carefree — The Lost Ball

A dependency-free WebGL2 playtest episode for the Carefree concept.

## Run locally

```bash
npm run verify
npm run serve
```

Open `http://localhost:8080`.

## Controls

- WASD / arrow keys: move
- Drag mouse: orbit camera
- Shift: run
- E / Space: interact
- R: restart episode
- F2: development emotion/state panel

## Scope

This is a frozen experience prototype (`DEMO_PLAN.md` decision 6), not the production engine foundation. It validated child-scale navigation, a social action loop, and the Emotional Lens; the production build is a fresh implementation in Godot 4.7.2, not an automated port of this code.

See [`docs/PLAYTEST.md`](docs/PLAYTEST.md) for playtest scope, success criteria, and the data boundary.
