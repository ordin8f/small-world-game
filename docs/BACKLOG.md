# Initial Backlog

> **Status:** written for the original PlayCanvas/TypeScript direction, which was decided but never implemented (`DEMO_PLAN.md` section 2.1). `DEMO_PLAN.md`'s milestones (M0–M6) are the current ticket source and supersede the P0–P8 milestones below. This backlog is kept for the design intent in P1–P6 (route beats, social approaches, Emotional Lens tuning) that still applies to the Godot build.

Work in order. Do not move to a new milestone until the preceding exit gate is met.

## P0 — Foundation

### P0-01 Project scaffold

Create a code-first Godot 4.7.2 project using typed GDScript.

Acceptance:
- project imports headless (`godot --headless --import`);
- default scene renders;
- release export succeeds;
- no uncaught errors in the Godot log;
- Git history remains clean.

### P0-02 Engineering guardrails

Add gdUnit4, and headless import/test/export commands with CI-ready verification.

Acceptance:
```powershell
godot/tools/import.ps1
godot/tools/test.ps1
godot/tools/export.ps1
```
All pass.

### P0-03 Debug harness

Add a development-only overlay with FPS, scene, player coordinates, narrative state, and recent domain events.

## P1 — Movement, camera, greybox

### P1-01 Input actions

Create an input abstraction for move, look, interact, cancel, and pause. Gameplay systems must not read raw keys directly.

### P1-02 Child controller

Implement stable capsule/kinematic movement, grounding, gravity, acceleration, deceleration, slope limits, step handling, and facing direction.

### P1-03 Camera

Implement third-person follow/orbit, vertical limits, collision avoidance, and indoor distance adjustment.

### P1-04 Greybox route

Build a primitive-only route from bedroom to playground and back. Do not add production art.

Exit gate:
- first-time tester can traverse bedroom → doorway → courtyard → playground → home;
- camera is usable everywhere;
- intended boundaries feel natural;
- player does not need a minimap.

## P2 — Interaction

### P2-01 Interaction focus

One readable nearby interactable receives focus. Prevent selection through walls and prompt flicker.

### P2-02 Carrying and placement

One carried item at a time. Support pickup, carry, safe drop, placement zones, and recovery of important objects.

## P3 — Narrative framework

### P3-01 Typed event bus

Create typed domain events without embedding narrative progression inside the bus.

### P3-02 Narrative Director

Implement chapter/beat state, entry actions, completion events, transition, debug restart/skip, and save restoration.

### P3-03 Day-one content skeleton

Represent these beats as data:

```text
GET_READY
CHOOSE_TOY
LEAVE_HOME
REACH_PLAYGROUND
PLAY_ALONE
OBSERVE_GROUP
ATTEMPT_TO_JOIN
SHARED_PROBLEM
JOIN_GAME
MOTHER_CALLS
COLLECT_THINGS
RETURN_HOME
PUT_AWAY
DRAWING
COMPLETE
```

## P4 — Social slice

Add three placeholder children, authored reactions, observing/waving/approach behaviors, temporary rejection, recovery, a shared problem, and goodbye.

Required approaches:
1. Watch first, then approach.
2. Approach directly.
3. Interrupt accidentally, recover, and later help.

All three must eventually reach shared play without a dead end.

## P5 — Return-home loop

Add parent call, repeated call if ignored, belongings check, directional accessibility cue, home return, put-away routine, and final drawing.

## P5.5 — Emotional Lens prototype

### P5.5-01 Emotional state model

Implement continuous `comfort`, `energy`, and `curiosity` values, event-driven deltas, smoothing/decay where appropriate, developer presets, and unit tests. Do not add a player-facing meter.

### P5.5-02 Perception Director

Map emotional state to parameters without owning narrative progression. Initial channels:
- camera profile;
- restrained light/color parameters;
- audio mix;
- animation-expression hooks;
- imagination-cue triggers.

### P5.5-03 Three perception studies

Prototype and A/B compare:
1. curious/secure trip toward playground;
2. lonely/uncertain observation of the group;
3. anxious/seeking-safety dusk return.

Acceptance:
- neutral and emotional versions can be toggled instantly in debug mode;
- basic movement/camera remain predictable;
- no objective relies only on emotional effects;
- emotion state is visible only in developer tools;
- imagination cues do not alter collision or required navigation.

## P6 — Art and animation

Only after the greybox slice is playable end-to-end:
- one shared child skeleton;
- modular hair/material variants;
- minimal, child-scale environment following `ART_DIRECTION.md`;
- lighting/composition matched against the approved concept-art references;
- animation blending;
- ambient audio and footsteps;
- restrained tactile materials;
- no photorealistic or clutter-heavy asset direction.

## P7 — Performance and accessibility

Add quality presets, compression, subtitle controls, reduced camera motion, browser smoke tests, and asset-size reports.

## P8 — Additional afternoons

Only after the vertical slice passes its product and performance gates.
