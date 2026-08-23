# Art Direction

## North star

**Minimalistic, extremely beautiful, and always framed from the child's experience of scale.**

The environment should not look like an adult-designed playground presented to a small avatar. It should feel like the world as a young child experiences it: large, incomplete, inviting, sometimes intimidating, and full of ordinary details that can become adventures.

Reference qualities include the sense of discovery and visual restraint found in games such as *RiME* and *ABZÛ*, combined with the strong child-scale framing and environmental storytelling associated with games such as *Little Nightmares*, *LIMBO*, and *REANIMAL*. The project should not copy their characters, worlds, palette, or horror tone.

## What the current concept art established

The strongest direction is:

- low child-height camera;
- a very small protagonist inside large compositions;
- sparse environments rather than cluttered scenes;
- warm natural light with deep but readable shadow;
- architecture and vegetation doing most of the visual storytelling;
- restrained materials rather than glossy realism;
- a small number of strong shapes in each frame;
- paths and destinations composed cinematically;
- beauty emerging from light, proportion, atmosphere, and silence rather than asset density.

## World scale

The child is small. The environment should repeatedly remind the player of that without exaggerating everything into fantasy.

Examples:

- door handles sit high;
- beds and tables occupy large visual masses;
- a stair feels like a route rather than a trivial step;
- a narrow alley can feel like a canyon;
- grass beside a wall can reach the child's waist;
- playground structures can read like architecture;
- a puddle occupies enough screen space to become interesting;
- adults, when shown, are often partially framed from the child's height.

## Composition

Prefer frames with one clear idea.

Good:

```text
child + doorway + light
child + long path + distant playground
child + edge of playground + group of children
child + darkening lane + warm home window
```

Avoid filling every space with props, signs, collectibles, UI icons, decorative clutter, or environmental noise.

The player's eye should usually understand the image before reading any interface.

## Geometry

Use simplified but believable 3D forms.

- broad architectural planes;
- strong silhouettes;
- modest geometric detail;
- bevels only where they improve light response;
- foliage clustered into readable masses;
- props chosen for narrative value rather than density;
- collision geometry substantially simpler than render geometry.

Do not pursue photorealistic microdetail.

## Materials

Materials should feel tactile but understated:

- chalky plaster;
- matte painted wood;
- worn stone;
- soft fabric;
- dusty metal;
- simple leaves and grass;
- slightly imperfect painted playground surfaces.

Avoid:

- excessive gloss;
- plastic-looking PBR everywhere;
- procedural detail for its own sake;
- ultra-sharp high-frequency textures;
- noisy normal maps.

## Lighting

Light is a primary art asset.

The vertical slice should prove at least three lighting moods using largely the same environment:

### Morning / home

Warm directional light enters through a door or window. The interior is quiet and protected. The outside is inviting but larger and brighter.

### Late afternoon / playground

Golden directional light creates long readable shapes. Dust, leaves, and subtle atmospheric depth can make the open space feel expansive without adding more geometry.

### Dusk / return

The environment becomes cooler and quieter while windows and the home doorway become warm anchors. The scene should feel vulnerable, not horrific.

## Color

Use a restrained environmental palette with selective warmth rather than a toy-box rainbow.

The child and key interactive elements can carry slightly clearer color separation, but should still belong to the world.

Emotion-driven color changes must be subtle. The base scene must remain coherent when all Emotional Lens effects are disabled.

## Character direction

The protagonist should be stylized rather than chibi, anime, or realistic.

Desired qualities:

- believable preschool proportions;
- slightly simplified head/face;
- readable silhouette at distance;
- expressive posture more important than facial animation;
- simple clothing with one or two recognizable details;
- no oversized eyes or mascot-like exaggeration;
- no heavy backpack unless required by story context.

For the first slice, customization should remain modular and minimal.

## Camera as art direction

Camera placement is part of the visual identity.

Default framing should be low enough that:

- furniture feels large;
- adults are not automatically centered at eye level;
- walls and doors create strong vertical shapes;
- playground structures rise above the player;
- the horizon can disappear in enclosed passages and open dramatically in safe/open spaces.

Do not use a generic adult-height third-person camera scaled down with the character.

## Environmental storytelling

Use a small number of concrete details:

- child's drawing taped imperfectly to a wall;
- one toy under a bed;
- chalk marks outside;
- wet footprints near a puddle;
- a ball visible beyond a fence;
- flowers growing from a crack;
- a parent seen in a lit window;
- signs of other children before the group is encountered.

Each detail should either reveal life, guide attention, support a mechanic, or reinforce scale.

## UI

The world should carry most of the information.

Prefer:

- no minimap;
- no persistent quest panel;
- no visible friendship bar;
- no visible emotion meter;
- very small contextual prompts only when necessary;
- subtitles and accessibility UI that can be adjusted independently.

## Emotional Lens relationship

The physical environment is authored once. Emotional perception changes how it is framed and noticed.

See [`EMOTIONAL_LENS.md`](EMOTIONAL_LENS.md).

Art production should therefore separate:

1. **Base world** — neutral, beautiful, readable.
2. **Perception parameters** — camera, light/color, audio, animation emphasis.
3. **Imagination cues** — brief authored overlays or transformations.

This prevents every emotion from requiring a duplicate environment.

## Concept art in this repository

The images under [`concept-art/`](concept-art/) are reference targets for mood, composition, scale, and lighting. They are not literal asset specifications.

Key images:

- `small-world-childs-journey.jpg` — overall visual language and journey framing;
- `golden-alley-to-playground.jpg` — small child against a large, inviting route;
- `golden-light-through-door.jpg` — home scale and the threshold between safety and exploration;
- `child-golden-hour-walkway.jpg` — route composition and low camera;
- `golden-hour-playground.jpg` — playground as architecture, not colorful clutter;
- `twilight-path-home.jpg` — dusk vulnerability and the warm-home anchor.

## Production test

Before creating finished assets, build one greybox route and light it three ways. If the scene does not already feel compelling with simple geometry, the solution is not more texture detail.
