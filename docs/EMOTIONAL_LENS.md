# Emotional Lens

## Purpose

The child's emotional state changes **how the world is perceived**, not the underlying truth of the world.

The system should make a small environment feel psychologically large. The same bedroom, alley, courtyard, and playground can feel safe, lonely, exciting, strange, or magical depending on what has just happened to the child.

This is not a health, sanity, happiness, or morality system.

## Core rule

> Every emotion reveals something. No emotion is a failure state.

Do not show a conventional emotion meter such as `Fear 72%` or `Happiness +10` during normal play. The player should infer the child's state from presentation and behavior.

## Internal model

Use three continuous values rather than a large set of independent named emotions:

```ts
type EmotionalState = {
  comfort: number;   // 0..1: unsafe/uncertain -> secure
  energy: number;    // 0..1: quiet/tired -> activated/excited
  curiosity: number; // 0..1: disengaged -> strongly drawn to explore
};
```

Named emotions are interpretive regions, not hard modes.

| Approximate state | Comfort | Energy | Curiosity |
|---|---:|---:|---:|
| Afraid | Low | High | Low/medium |
| Anxious | Low | High | Medium |
| Lonely | Low | Low | Low/medium |
| Frustrated | Low/medium | High | Low |
| Bored | Medium/high | Low | Low |
| Calm | High | Low | Medium |
| Happy | High | Medium/high | Medium |
| Excited | High | High | High |
| Curious / wonder | Any | Any | High |

The mapping should be fuzzy and blended. Avoid abrupt switches between named states.

## Emotional inputs

Emotional values change because of events in the world, not because the player presses an emotion button.

Examples:

- parent leaves the room briefly -> comfort may fall slightly;
- favorite toy is carried -> comfort may recover;
- other children reject an approach -> comfort falls, energy may rise;
- another child waves or invites the player -> comfort rises;
- the player waits without stimulation -> energy and curiosity may fall;
- a butterfly, strange sound, puddle, or moving curtain catches attention -> curiosity rises;
- the parent calls from home at dusk -> energy may rise while comfort depends on distance and context;
- returning to a warm doorway -> comfort rises strongly.

All changes should be gradual unless the event is genuinely sudden.

## Perception channels

The Emotional Lens can influence five presentation channels. It should usually change only a few at once.

### 1. Camera

Possible effects:

- afraid/anxious: slightly closer framing, reduced peripheral openness, slower recentering;
- lonely: wider composition with more negative space around the child;
- happy/excited: slightly wider camera and more forward-looking composition;
- curious: camera framing subtly favors interesting environmental details.

Do not change camera behavior enough to make controls inconsistent or uncomfortable.

### 2. Light and color

Possible effects:

- afraid: longer perceived shadows, cooler midtones, stronger contrast in ambiguous areas;
- bored: slightly flatter color separation and less visual sparkle;
- happy: warmer light and clearer color relationships;
- curious: small points of light, reflection, movement, or color become easier to notice;
- secure/home: warm local light can feel unusually inviting against a darker exterior.

The base art direction remains beautiful in every state. Emotional grading must not become a heavy Instagram-style filter.

### 3. Sound

Possible effects:

- anxious: distant voices become harder to parse, isolated environmental noises gain salience;
- afraid: ordinary creaks, wind, pipes, footsteps, and leaves become more spatially prominent;
- lonely: distant children remain audible but feel far away;
- happy: ambient music gains harmonic layers or additional instruments;
- bored: repeated household sounds become noticeable until curiosity finds a new focus;
- curious: small directional sounds become clearer and can lead exploration.

Never make essential gameplay information inaudible. Accessibility cues must remain reliable.

### 4. Animation and movement expression

The controller's responsiveness should not change materially, but animation can communicate state:

- hesitant head movement;
- holding the favorite toy closer;
- smaller idle gestures when uncertain;
- quicker steps when excited;
- lingering gaze when curious;
- shoulders relaxing as comfort rises.

The player must never lose control because the child is experiencing an emotion.

### 5. Imagination overlays

Imagination is the strongest expression of the system, but should be brief and selective.

Examples:

- a puddle briefly reads as a sea;
- a sofa becomes a mountain ridge in silhouette;
- a cardboard box suggests a boat;
- a crack in the pavement becomes a canyon or river;
- ants become a procession;
- a pile of clothes briefly resembles a person when afraid;
- playground towers feel castle-like when excited;
- the illuminated doorway home feels impossibly safe after an anxious return.

These are perceptual moments, not separate fantasy levels. They should dissolve naturally back into the ordinary environment.

## Example: the same path twice

### Afternoon — curious and secure

The child walks from home toward the playground.

- camera is open;
- warm sunlight catches puddles and leaves;
- a butterfly or chalk mark pulls attention sideways;
- neighborhood sounds are clear and pleasant;
- the playground feels like a destination to discover.

### Dusk — anxious and tired

The child walks the same route home after being called.

- geometry is unchanged;
- camera is a little closer;
- long shadows dominate familiar walls;
- a drainpipe, coat, bush, or gate can briefly look ambiguous;
- the parent's voice and warm doorway become strong anchors;
- reaching home visibly releases the tension.

This should create vulnerability and adventure without turning the game into horror.

## Gameplay loop

```text
WORLD EVENT
    ↓
EMOTIONAL STATE
    ↓
PERCEPTUAL LENS
    ↓
PLAYER NOTICES DIFFERENT THINGS
    ↓
PLAYER ACTION
    ↓
NEW WORLD EVENT / EMOTIONAL CHANGE
```

The system is valuable only when perception changes what the player is likely to notice, approach, avoid, or interpret.

## Architecture

Keep emotion calculation separate from rendering and narrative logic.

```text
Domain Events
    │
    ├──► Narrative Director
    │
    └──► Emotional State Model
              │
              ▼
        Perception Director
          ├─ Camera profile
          ├─ Lighting/color parameters
          ├─ Audio mix parameters
          ├─ Animation expression
          └─ Imagination cues
```

Suggested interfaces:

```ts
type EmotionalDelta = Partial<{
  comfort: number;
  energy: number;
  curiosity: number;
}>;

type EmotionEvent = {
  id: string;
  delta: EmotionalDelta;
  durationMs?: number;
};

interface EmotionalStateModel {
  getState(): Readonly<EmotionalState>;
  apply(event: EmotionEvent): void;
  update(dt: number): void;
}
```

The Perception Director reads emotional state. It should not own or mutate story progression.

## Prototype scope

For the first vertical slice, do **not** implement the full system.

Prove only three contrasted lenses:

1. **Curious / secure** — first trip toward playground.
2. **Lonely / uncertain** — observing children from the edge of play.
3. **Anxious / seeking safety** — dusk return after the parent calls.

Each lens should initially affect only:

- one camera parameter set;
- one restrained color/light profile;
- one audio mix profile;
- one or two authored imagination cues.

If these three moments do not materially improve the experience, do not expand the system.

## Debugging

The emotional model may be visible in the developer overlay even though it is hidden from players.

Show:

```text
Comfort     0.42
Energy      0.73
Curiosity   0.61
Dominant interpretation: anxious/curious
Active perception profile: dusk_return_v1
```

Provide debug controls to:

- freeze emotional state;
- set each axis directly;
- apply named test presets;
- disable visual effects while keeping logic active;
- disable audio effects while keeping logic active;
- compare base world and perceived world instantly.

## Guardrails

- No visible emotion score in ordinary gameplay.
- No reward for maximizing happiness.
- No punishment for fear, boredom, loneliness, frustration, or anxiety.
- No diagnosis or clinical labeling.
- No emotion should make basic controls unreliable.
- No essential objective may depend only on a subtle color or audio change.
- Imagination must not contradict physical collision or navigation.
- Do not use emotional state to force a moral interpretation of social choices.
- Avoid turning fear into horror unless a later design decision explicitly changes the genre.
