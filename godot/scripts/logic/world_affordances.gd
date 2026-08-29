class_name WorldAffordances
extends RefCounted
## Static geometry + pure query functions for the courtyard's PLAYABLE
## affordances -- the slide/tower, the garden-bed edging, the stepping
## stones and the puddles that tools/_bootstrap_courtyard.gd already builds as pure
## decoration (see that file's doc comment: it is a one-shot generator for
## *visual* shapes and colliders only, nothing there is interactive).
##
## Mirrors world_bounds.gd's own pattern -- authored constants plus pure,
## side-effect-free query functions, unit-testable without a running scene
## -- so player.gd and the new stepping_stones.gd/puddles.gd only ever ask
## this class "am I near X", never re-derive level geometry themselves.
## Every number below is re-derived from tools/_bootstrap_courtyard.gd's
## own literals (see each section), not eyeballed separately, so a future
## change to the level has one obvious place to follow.

# ---------------------------------------------------------------- tower/slide --
## Left tower (bootstrap's `for x in [-3.4, 3.4]` loop, first iteration) and
## its WorldBounds.COLLIDERS footprint: {"x": -3.4, "z": -12.8, "half_x":
## 1.35, "half_z": 1.35} -- relocated with the rest of the playground in
## the 2026-08-28 world expansion (world_bounds.gd's own doc comment), same
## x and footprint size as before, just deeper (z -5.6 -> -12.8) to sit
## near the new Group position (0, -11).
const TOWER_X := -3.4
const TOWER_Z := -12.8
const TOWER_FOOTPRINT_HALF := 1.35

## Platform deck top: bootstrap's platform cube at y=2.75, scale.y=0.25 ->
## top surface at 2.75 + 0.25/2.
const PLATFORM_TOP_Y := 2.875

## Ground-level point that starts the climb: just outside the tower's
## south (positive-z, courtyard-facing -- the side the player actually
## approaches from) collider face, so the trigger fires just before the
## player would otherwise bump the collider.
const CLIMB_TRIGGER := Vector3(TOWER_X, 0.0, TOWER_Z + TOWER_FOOTPRINT_HALF + 0.4)
const CLIMB_TRIGGER_RADIUS := 0.55

## Standing spot on the platform once climbed, inset from the south edge
## so the player reads as standing ON the deck rather than hanging off it.
const PLATFORM_STAND := Vector3(TOWER_X, PLATFORM_TOP_Y, TOWER_Z + 1.0)

## The slide run. Shares the decorative SLIDE-coloured mesh's x column
## (bootstrap centres that box at x=-3.4) and general z span, but is its
## own authored curve rather than that box's literal tilted surface --
## probing the box's baked transform shows its near-tower end sits BELOW
## ground and its far end floats with nothing under it, so it was never a
## physically continuous ramp to begin with, just a suggestive colour
## block (matches the brief: "There is a slide in this game that you
## cannot slide down"). This is the actual playable path: down and out
## from the platform into the open courtyard, landing clear of the
## tower's own collider footprint. End point holds the same +3.7 z offset
## from TOWER_Z the single-room version authored (was -1.9 at TOWER_Z
## -5.6), now landing at -9.1.
const SLIDE_START := PLATFORM_STAND
const SLIDE_END := Vector3(TOWER_X, 0.0, -9.1)

# ---------------------------------------------------------------- edging --
## Low brick edging around a planting bed by the home threshold (home's
## west flank, x[-6.3,-3.5] z[10.45,13.65] in _bootstrap_courtyard.gd's
## _build_garden_bed()) -- where the balance verb now lives. It used to be
## the tall playground/garden-pocket boundary wall (x=11, still there as a
## boundary, just no longer a balance affordance): the developer's own
## words were "the walking on the edge should be on the side of a brick
## lining of a small garden or area or something -- not the wall, where it
## is." A real garden bed's edging is both better storytelling and what a
## child would actually do, and DEMO_PLAN.md's scale diagnosis makes the
## same point under "order of work" #4.
##
## EDGING_X is the mount edge's own centreline -- the border segment
## facing the path, the side a player walking the porch actually meets.
## Top surface at y = 0.3, a real low garden-edging height (roughly knee
## height on the 1.08 m child), not a wall.
const EDGING_X := -3.7
const EDGING_TOP_Y := 0.3
## A single run the full length of that east border (matches its own
## rendered span exactly, same convention WALL_SEGMENTS used against its
## wall meshes) -- one continuous edge around a small bed, unlike the old
## wall's two segments either side of the garden gap, since there is no
## gap here to model.
const EDGING_SEGMENTS := [
	{"z_min": 10.45, "z_max": 13.65},
]
## How close in x, at ground level, mounts the edging.
const EDGING_MOUNT_X_RANGE := 0.55
## How far off the centreline reads as "still on top" before stepping off.
const EDGING_HALF_WIDTH := 0.3

# ---------------------------------------------------------------- stones --
## Four stones just past the garden gap, bootstrap's `for stone in [...]`
## loop -- same positions relative to the gap (x=WALL_X, z=-8, the gap's
## own midpoint) as the single-room version held relative to its gap.
## Capture radius here is authored generously (the render mesh itself is
## only ~0.2-0.28 m) so crossing them reads as a hop-friendly game, not a
## pixel-precise one.
const STONES := [
	{"x": 11.7, "z": -7.7, "radius": 0.5},
	{"x": 12.5, "z": -8.4, "radius": 0.55},
	{"x": 13.3, "z": -9.1, "radius": 0.52},
	{"x": 14.0, "z": -9.9, "radius": 0.58},
]
## Bounding region (padded around the 4 stones) the "the gap reads as
## water" imagination cue is confined to -- outside it, ordinary ground is
## just ordinary ground, never almost-lava.
const STONES_REGION := {"x_min": 11.1, "x_max": 14.6, "z_min": -10.5, "z_max": -7.1}

# --------------------------------------------------------------- puddles --
## Three puddles, bootstrap's `for p in [...]` loop of
## [x, y, z, scale_x, scale_y, scale_z] on a radius-0.5 sphere mesh, so
## world radius = 0.5 * scale. First two sit in the lane (unchanged --
## the lane's own x[-3,3]/z[-4,8] footprint already contained them, see
## world_bounds.gd's doc comment on the four places); the third is the
## garden one, relocated with the rest of that pocket.
const PUDDLES := [
	{"x": -1.5, "z": 3.2, "rx": 0.8, "rz": 0.45},
	{"x": 2.1, "z": 0.8, "rx": 0.575, "rz": 0.375},
	{"x": 12.4, "z": -9.4, "rx": 0.7, "rz": 0.4},
]


static func near_climb_trigger(x: float, z: float) -> bool:
	return Vector2(x - CLIMB_TRIGGER.x, z - CLIMB_TRIGGER.z).length() < CLIMB_TRIGGER_RADIUS


## The edging segment (an entry of EDGING_SEGMENTS) containing `z`, or {}
## if none.
static func edging_segment_at_z(z: float) -> Dictionary:
	for segment in EDGING_SEGMENTS:
		if z >= segment["z_min"] and z <= segment["z_max"]:
			return segment
	return {}


## True if (x, z), at ground level, is close enough to the edging's base
## to mount it.
static func near_edging_mount(x: float, z: float) -> bool:
	if absf(x - EDGING_X) > EDGING_MOUNT_X_RANGE:
		return false
	return not edging_segment_at_z(z).is_empty()


## Index (0..3) of the stone (x, z) is standing on, or -1 if it's in a gap.
static func stone_index_at(x: float, z: float) -> int:
	for i in range(STONES.size()):
		var s: Dictionary = STONES[i]
		if Vector2(x - s["x"], z - s["z"]).length() <= s["radius"]:
			return i
	return -1


static func in_stones_region(x: float, z: float) -> bool:
	return x >= STONES_REGION["x_min"] and x <= STONES_REGION["x_max"] \
		and z >= STONES_REGION["z_min"] and z <= STONES_REGION["z_max"]


## Index (0..2) of the puddle (x, z) is standing in, or -1 if none.
static func puddle_index_at(x: float, z: float) -> int:
	for i in range(PUDDLES.size()):
		var p: Dictionary = PUDDLES[i]
		var dx: float = (x - p["x"]) / p["rx"]
		var dz: float = (z - p["z"]) / p["rz"]
		if dx * dx + dz * dz <= 1.0:
			return i
	return -1
