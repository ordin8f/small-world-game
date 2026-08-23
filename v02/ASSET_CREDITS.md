# Small World v0.2 — Prototype Asset Ledger

This preview deliberately uses only freely redistributable prototype assets. The production game may replace any or all of them.

## Character

### Kenney — Mini Characters 1.0

- Original source: https://kenney.nl/assets/mini-characters
- License: CC0 1.0 Universal
- Prototype use: animated player plus two playground NPCs
- Runtime files: `character-male-a.glb`, `character-female-b.glb`, `character-male-c.glb`
- Runtime mirror used for this browser-only prototype: the vendored, license-documented copies in `mengfoong-dev/codex-candidate-assesment-system` on GitHub, delivered through jsDelivr.
- Reason for selection: readable oversized proportions, built-in animation, tiny transfer size, and an intentionally non-realistic silhouette that reads more naturally as a young character than the earlier primitive proxy.

The original Kenney asset page identifies Mini Characters as CC0 and animated. The mirror repository includes the original Kenney license file and identifies the same source package.

## Environment

### Tiny Treats — Homely House 1.0

- Official repository: https://github.com/TinyTreats-Game-Assets/Tiny-Treats-Homely-House-1.0
- License: CC0 1.0 Universal
- Prototype use: one distant house model
- Runtime delivery: official GitHub repository through jsDelivr

### Tiny Treats — Pretty Park 1.0

- Official repository: https://github.com/TinyTreats-Game-Assets/Tiny-Treats-Pretty-Park-1.0
- License: CC0 1.0 Universal
- Prototype use: two trees, one bush, a bench, and a street lantern
- Runtime delivery: official GitHub repository through jsDelivr

## Project-created geometry

The doorway, alley, walls, path, puddles, playground silhouette, lighting setup, camera system, backpack, and fallback child are original prototype geometry/code created for Small World. They are not derived from the external models above.

## Runtime library

- Three.js 0.180.0: https://threejs.org/
- License: MIT
- Browser delivery: jsDelivr npm CDN

## Prototype limitation

v0.2 streams these assets from public CDNs so that visual iteration does not bloat the private repository with temporary models. Once the visual direction is accepted, the selected assets should be vendored, checksummed, and pinned to exact source versions before wider community testing.
