# Early Build Verification

The Lost Ball prototype is treated as an integrated browser episode rather than only as disconnected source files.

## Automated repository checks

```bash
npm run verify
```

This checks HTML/module references, JavaScript syntax, pure episode and Emotional Lens behavior, the garden collision opening, and static Pages packaging.

## Browser smoke coverage

`tools/smoke_test.py` verifies:

- the WebGL2 canvas starts;
- forward movement follows the visible camera direction;
- right movement moves right on screen;
- the deterministic episode reaches its ending;
- the browser reports no uncaught errors.

## Playability defects corrected before community release

- Horizontal screen-relative movement was reversed.
- The visible garden opening was covered by a single collision wall, preventing a normal playthrough.

Regression coverage now protects both behaviors.

## Known limitations

- geometric placeholder characters and environment;
- no touch controls or gamepad support;
- no production animation, facial acting, or voice acting;
- no persistent save because the episode is intentionally short;
- the local browser smoke script requires a Chromium/Playwright environment and is not part of the lightweight hosted verification job.
