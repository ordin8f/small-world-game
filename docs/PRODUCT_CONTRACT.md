# Product Contract

## Experience

- The player controls a young child in third person.
- The world is safe but sometimes uncertain.
- There is no combat and no game-over screen.
- Social mistakes create temporary discomfort, not permanent punishment.
- Progress comes from observation, participation, memory, movement, and small acts of independence.
- The game does not label actions as morally correct or incorrect.
- The player always has a path to recover and continue.
- Ordinary spaces should feel large because of the child's scale and perspective.
- Normal movement must feel responsive; the child is learning confidence and coordination, not basic walking.

## Vertical-slice boundary

The first playable release contains:

- one protagonist;
- one home;
- one courtyard or safe residential transition;
- one playground;
- three other children;
- one parent, initially represented mainly by voice;
- one afternoon;
- one shared playground problem;
- one ending;
- a few story flags that alter reactions and details without producing separate campaigns;
- one carried item at a time;
- no visible inventory grid;
- no visible friendship meter;
- no visible emotion meter.

It does **not** initially contain:

- five complete days;
- an open neighborhood;
- detailed facial morphing;
- free-form dialogue;
- runtime LLMs;
- mobile controls;
- extensive climbing/balance systems;
- online accounts;
- cloud saves;
- final voice acting;
- finished art production.

## First-afternoon loop

1. Character setup.
2. Find the missing shoe.
3. Choose one favorite toy.
4. Leave home.
5. Reach the playground.
6. Play alone.
7. Observe three children already playing.
8. Try to join them.
9. Resolve a small shared problem.
10. Hear the parent call.
11. Collect belongings.
12. Return home.
13. Put belongings away.
14. Finish with a simple drawing reflecting what the player noticed and did.

## Social design

The game must not reduce friendship to selecting a single correct dialogue option. Useful social actions include watching, waiting, waving, approaching, offering an object, joining an activity, accidentally interrupting, recovering, helping, and leaving.

Possible first-slice flags:

```ts
type StoryFlags = {
  watchedBeforeJoining: boolean;
  offeredFavouriteToy: boolean;
  interruptedTheGame: boolean;
  helpedRetrieveBall: boolean;
  returnedWhenCalled: boolean;
};
```

These flags may change dialogue, animation, the goodbye, or the final drawing. They should not create a branching-content explosion.

## Emotional perception

The physical world remains consistent, but the child may perceive it differently depending on emotional state. The system is defined in [`EMOTIONAL_LENS.md`](EMOTIONAL_LENS.md).

Non-negotiable rules:

- emotional state is not displayed as a player-facing percentage, bar, or score;
- the internal prototype model uses `comfort`, `energy`, and `curiosity`;
- emotions are not moralized and there is no reward for maximizing happiness;
- fear, anxiety, boredom, loneliness, frustration, happiness, excitement, and curiosity can all reveal different details or possibilities;
- perception may influence camera, light/color, sound, animation expression, and brief imagination cues;
- basic controls remain reliable in every emotional state;
- essential information cannot depend only on color, subtle sound, or an imagination effect;
- imagination does not alter physical collision or create deceptive navigation;
- the first vertical slice proves only three contrasting lenses: curious/secure, lonely/uncertain, and anxious/seeking-safety.

## Initial performance targets

Treat these as engineering targets to validate, not guarantees:

- minimum 30 FPS at 1280×720 on a representative integrated-GPU laptop;
- target 60 FPS on a typical recent laptop;
- WebGL 2 baseline;
- no more than four animated children visible simultaneously in the slice;
- limited dynamic lighting and shadows;
- most prototype textures 512×512 or lower;
- no expensive post-processing until the slice is already fun and readable.
