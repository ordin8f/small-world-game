# Agent Acceptance Matrix

| Track | Owns | Must demonstrate | Must not change |
|---|---|---|---|
| World and camera | scale, route, camera, collision | route is readable and traversable | narrative state and dialogue |
| Gameplay | input, interaction, object/state recovery | episode completes deterministically | art direction and Emotional Lens targets |
| Emotional Lens | comfort, energy, curiosity outputs | perception changes without a visible score | physical collision and story progression |
| Narrative and social | objectives, timing, short dialogue, gestures | belonging is conveyed through action | renderer and movement mathematics |
| Accessibility and QA | keyboard, focus, subtitles, reduced motion, browser checks | blockers are reproducible and regression-tested | product scope without approval |
| Release | CI, Pages packaging, tester handoff | a verified static build is shareable | gameplay behavior for deployment convenience |
| Production port | PlayCanvas/TypeScript boundary | validated mechanics have explicit port criteria | premature rewrite before playtest evidence |
