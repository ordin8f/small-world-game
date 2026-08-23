# Implementation Plan

## 1. Build philosophy

Build the project as a sequence of gated prototypes. Each stage must prove one part of the experience before more content or higher-quality artwork is introduced.

The first deliverable is one complete 15–20 minute afternoon:

> Home → get ready → travel to the playground → play alone → approach other children → participate in a shared activity → hear the parent calling → collect belongings → return home → put things away → complete the day.

The core validation question is:

> Can ordinary childhood actions feel meaningful, playful, and emotionally engaging without combat, danger, scoring, or complicated game systems?

## 2. Recommended stack

| Layer | Choice |
|---|---|
| Game engine | PlayCanvas Engine |
| Language | TypeScript |
| Build system | Vite |
| 3D authoring | Blender |
| Runtime asset format | GLB/glTF |
| Asset optimization | glTF Transform |
| Unit/content testing | Vitest |
| Browser/E2E testing | Playwright |
| Prototype save | `localStorage` |
| Hosting | Static browser hosting |
| Runtime AI | None |

Use WebGL 2 as the compatibility/performance baseline. Treat WebGPU as an optional enhancement rather than a requirement.

## 3. Visual direction

Aim for stylized, painterly 3D rather than photorealism:

- simplified readable shapes;
- low-to-medium polygon models;
- soft matte materials;
- hand-painted or intentionally simple color variation;
- warm light and clear silhouettes;
- slightly exaggerated proportions;
- bright color without glossy/plastic surfaces.

The world should feel large from the child's perspective. A curb, latch, puddle, swing, doorway, and sandbox can all become meaningful because of scale and context rather than because of artificial puzzle machinery.

## 4. Vertical-slice beats

| Beat | Activity | System under test |
|---|---|---|
| Character setup | Simple appearance + favorite toy | Customization/save |
| Find shoe | Search and place shoe | Observation/interaction |
| Choose toy | Ball, car, or stuffed animal | Carrying/content variation |
| Leave home | Door and safe transition | Controller/camera |
| Reach playground | Environmental navigation | Readability |
| Play alone | One playground interaction | Basic play |
| Observe group | Watch three children | Social observation |
| Join attempt | Watch/wave/approach/offer | Social variation |
| Shared problem | Retrieve or help with an object | Cooperation |
| Parent calls | Hear and understand call | Audio/narrative |
| Return | Collect belongings and go home | Memory/routine |
| Finish day | Put away items and draw | Closure/reflection |

## 5. Architecture

Use typed events and a central Narrative Director rather than direct cross-system calls.

```text
Keyboard / Mouse
       │
       ▼
Input System
       │
       ▼
Player Controller ──────── Camera Controller
       │
       ▼
Interaction System
       │
       ▼
Domain Events
       │
       ├──────────► Narrative Director
       │                  │
       │                  ├──► Objectives
       │                  ├──► NPC states
       │                  ├──► Dialogue
       │                  ├──► Audio
       │                  └──► Save flags
       │
       └──────────► Animation and feedback
```

A scene object should emit facts. It should not control the whole story.

Example:

```text
ball.retrieved
```

The Narrative Director interprets that event and decides whether to advance the story, change an NPC state, play dialogue, or set a flag.

## 6. Core systems

### Application bootstrap

Responsibilities:
- initialize PlayCanvas;
- choose graphics quality;
- load scenes;
- show loading progress;
- handle pause/resume;
- report unsupported graphics capability cleanly.

Do not place gameplay logic here.

### Input abstraction

Use named actions, not raw key checks spread through the codebase:

```ts
type InputAction =
  | "move"
  | "look"
  | "interact"
  | "cancel"
  | "pause";
```

### Child movement controller

Normal movement must be pleasant and predictable. Use kinematic/capsule movement rather than ragdoll locomotion.

Initial movement states:

```text
IDLE
WALK
RUN
CARRY_IDLE
CARRY_WALK
INTERACT
SIT
CONTEXT_CLIMB
```

Do not implement a general jump initially. Balance and climbing are contextual mechanics for later milestones.

### Camera

Requirements:
- low child-scale third-person perspective;
- smooth follow;
- manual orbit;
- wall collision avoidance;
- indoor distance adjustment;
- no prolonged camera penetration;
- optional reduced-motion mode later.

Greybox rooms around the camera constraints rather than designing finished rooms first.

### Interaction system

All interactive objects share a common contract:

```ts
interface Interactable {
  id: string;
  getPrompt(): string;
  canInteract(context: InteractionContext): boolean;
  interact(context: InteractionContext): void;
}
```

Initial interactions:
- inspect;
- pick up;
- carry;
- put down;
- place;
- open/close;
- sit;
- play;
- wave;
- observe.

Prompts should describe actions concretely: `Pick up ball`, `Put shoes here`, `Watch`, `Wave`.

### Carrying

Keep it deliberately constrained:
- one carried item;
- hand/two-hand attachment points;
- carrying can change locomotion animation;
- placement zones accept only relevant items;
- story-critical objects recover if lost;
- no inventory screen.

### Narrative Director

The Narrative Director owns the current chapter and beat.

A simple content model is enough:

```ts
type BeatDefinition = {
  id: string;
  objective?: string;
  enterActions?: StoryAction[];
  completionEvents: string[];
  completeActions?: StoryAction[];
  nextBeat?: string;
};
```

Do not build a visual scripting system for the first slice.

### NPC behavior

Do not use an LLM or complex emergent simulation for the children.

Each child needs:
- current activity;
- a few waypoint locations;
- animation state;
- attention target;
- small authored reaction set;
- story-flag awareness;
- authored dialogue variants.

Example NPC states:

```text
PLAYING
WAITING
WATCHING_PLAYER
RESPONDING
INVITING
OBJECTING
HELPING
CELEBRATING
SAYING_GOODBYE
```

For the first slice, three simple temperaments are sufficient: open, protective of the existing game, and quiet/following.

### Dialogue/audio

- authored and deterministic;
- subtitles for every important spoken line;
- temporary local TTS allowed during development;
- final voice acting postponed;
- parent call must remain understandable even for players who cannot rely on directional sound alone;
- dialogue must skip/interruption safely.

### Save system

Initial save shape:

```ts
type SaveData = {
  version: number;
  customization: CharacterCustomization;
  currentBeat: string;
  flags: StoryFlags;
  settings: PlayerSettings;
};
```

Use `localStorage` initially. Include a save-version field from day one.

### Debug system

Development overlay should include:
- FPS/frame time;
- current chapter/beat;
- objectives;
- story flags;
- player coordinates;
- teleport destinations;
- restart/advance beat controls;
- reset save;
- NPC states;
- recent event log.

This is especially important when local AI agents are modifying code.

## 7. Art and asset strategy

### Greybox first

Use boxes, cylinders, ramps, flat colors, capsule children, and labels until the complete loop is playable.

Do not let attractive assets hide weak navigation, camera behavior, movement, or social design.

### Character strategy

Use:
- one base body;
- one skeleton;
- shared animations;
- multiple hair meshes;
- material/texture variants;
- simple clothing color parameters.

Avoid detailed facial morphing during the first slice.

### Environment packaging

Possible logical GLBs:

```text
home-shell.glb
home-props.glb
courtyard-shell.glb
playground.glb
playground-props.glb
```

Keep collision meshes simple and intentionally authored.

### Asset validation

Check every imported asset for:
- scale;
- orientation;
- pivot;
- material count;
- texture size;
- triangle count;
- skeleton compatibility;
- animation names;
- unused nodes;
- file size.

Automate repeatable inspection/compression rather than relying on manual cleanup.

## 8. Milestones and gates

### Milestone 0 — Foundation

Build project scaffold, strict TypeScript, verification scripts, docs, loading screen, and debug overlay.

Exit:
- dev server and production build work;
- lint/typecheck/tests pass;
- basic scene loads in Chrome and Firefox;
- no uncaught errors.

### Milestone 1 — Movement/camera

Build placeholder character, movement, collision, camera follow/orbit/collision, and a tiny indoor/outdoor test route.

Exit:
A first-time tester can navigate the route without fighting the controls or camera.

### Milestone 2 — Greybox world

Build bedroom, home transition, courtyard, playground, sandbox, swing, wall/fence, and return route.

Exit:
The playground is discoverable, boundaries are natural, and the camera works everywhere.

### Milestone 3 — Interaction/objects

Build focus, prompts, pickup, carry, placement, doors, missing shoe, favorite toy, ball, and object recovery.

Exit:
The player can complete the shoe/toy/carry loop and cannot permanently lose required objects.

### Milestone 4 — Narrative sequencing

Build event bus, Narrative Director, objectives, flags, save/resume, debug restart, and the full afternoon skeleton as data.

Exit:
The afternoon runs from start to finish with placeholder text/actors, and beat ordering can change without rewriting object scripts.

### Milestone 5 — NPC/social encounter

Build three placeholder children, play loops, attention, reactions, invitation/objection/recovery, shared problem, and goodbye.

Exit:
Watching first, approaching directly, or accidentally interrupting can all converge naturally on shared play.

### Milestone 6 — Return home

Build time transition, parent call, repeat call, belongings check, home route, put-away, drawing, and end screen.

Exit:
The full chapter is playable without debug commands.

### Milestone 7 — Visual/animation pass

Add shared child rig, modular appearances, stylized environment, lighting, animation blending, ambience, footsteps, and interaction sounds.

Exit:
The art is coherent, customization does not multiply rigs, animation does not visibly snap, and environmental readability remains strong.

### Milestone 8 — Performance/accessibility/browser validation

Add quality presets, resolution scaling, compression, subtitle controls, reduced camera motion, browser testing, and asset-size reports.

Exit:
Chrome/Firefox complete the chapter; low-quality mode reaches the minimum target on the chosen reference laptop; production output contains no development controls.

### Milestone 9 — Additional afternoons

Only now add disagreement, repair, helping another child, growing independence, changing playground activities, and larger imagination moments.

Expansion should primarily add content, not replace the core architecture.

## 9. Local-AI workflow

Give coding agents one bounded ticket at a time.

Recommended loop:

1. Select one ticket.
2. Give the agent exact scope and acceptance tests.
3. Run the agent.
4. Inspect changed files rather than accepting its summary.
5. Run all verification commands.
6. Launch and manually test the relevant scene.
7. Capture console errors/screenshots/test output where useful.
8. Compare against the milestone exit gate.
9. Commit only after it passes.
10. Move to the next ticket.

Avoid prompts such as `build the childhood game`. Broad autonomous prompts are likely to create tightly coupled systems that look complete before they are structurally sound.

## 10. Major risks

| Risk | Mitigation |
|---|---|
| Ordinary activity is not engaging | Prove full greybox afternoon before art production |
| Indoor camera is frustrating | Build camera and room greybox together |
| Social play becomes a dialogue quiz | Prefer observation, timing, proximity, gesture, and shared action |
| Customization consumes production | One skeleton + modular cosmetics |
| AI-generated assets drift stylistically | One art specification + manual asset approval |
| Physics becomes slapstick | Kinematic controller + simple collisions |
| Story scripts tangle together | Typed events + central Narrative Director |
| Browser bundle becomes heavy | Asset budgets, reports, compression, quality presets |
| Multiple days multiply work prematurely | Complete one vertical slice first |
| Game moralizes childhood behavior | Recoverable outcomes, no scores/morality labels |

## 11. Decisions to postpone

Do not decide these until the vertical slice works:

- final title;
- exact number of afternoons;
- mobile support;
- advanced face customization;
- alternate protagonist options;
- additional neighborhoods;
- full voice acting;
- procedural dialogue;
- weather;
- large fantasy sequences;
- online/cloud saves;
- achievements;
- controller support;
- localization;
- monetization;
- final distribution platform.
