class_name WorldAffordances
extends RefCounted
## Static geometry + pure query functions for the courtyard's PLAYABLE
## affordances -- the slide/tower, the garden wall, the stepping stones and
## the puddles that tools/_bootstrap_courtyard.gd already builds as pure
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
## its WorldBounds.COLLIDERS footprint (frozen; see that file's own doc
## comment): {"x": -3.4, "z": -5.6, "half_x": 1.35, "half_z": 1.35}.
const TOWER_X := -3.4
const TOWER_Z := -5.6
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
## tower's own collider footprint (which ends at z=-4.25).
const SLIDE_START := PLATFORM_STAND
const SLIDE_END := Vector3(TOWER_X, 0.0, -1.9)

# ------------------------------------------------------------------- wall --
## Garden wall (bootstrap's two PLASTER_LIGHT wall meshes at x=5.4). Top
## surface at y = 0.55 (origin) + 1.2/2 (its own render height) = 1.15.
const WALL_X := 5.4
const WALL_TOP_Y := 1.15
const WALL_SEGMENTS := [
	{"z_min": -8.0, "z_max": -3.8},
	{"z_min": -1.8, "z_max": -0.4},
]
## How close in x, at ground level, mounts the wall.
const WALL_MOUNT_X_RANGE := 0.75
## Matches WorldBounds.COLLIDERS' half_x for these segments (0.35) plus a
## hair of slack -- how far sideways off the centerline reads as "still
## on top" before the player has visibly stepped off.
const WALL_HALF_WIDTH := 0.4

# ---------------------------------------------------------------- stones --
## Four stones, bootstrap's `for stone in [...]` loop. Capture radius here
## is authored generously (the render mesh itself is only ~0.2-0.28 m) so
## crossing them reads as a hop-friendly game, not a pixel-precise one.
const STONES := [
	{"x": 6.1, "z": -2.5, "radius": 0.5},
	{"x": 6.9, "z": -3.2, "radius": 0.55},
	{"x": 7.7, "z": -3.9, "radius": 0.52},
	{"x": 8.4, "z": -4.7, "radius": 0.58},
]
## Bounding region (padded around the 4 stones) the "the gap reads as
## water" imagination cue is confined to -- outside it, ordinary ground is
## just ordinary ground, never almost-lava.
const STONES_REGION := {"x_min": 5.5, "x_max": 9.0, "z_min": -5.3, "z_max": -1.9}

# --------------------------------------------------------------- puddles --
## Three puddles, bootstrap's `for p in [...]` loop of
## [x, y, z, scale_x, scale_y, scale_z] on a radius-0.5 sphere mesh, so
## world radius = 0.5 * scale.
const PUDDLES := [
	{"x": -1.5, "z": 3.2, "rx": 0.8, "rz": 0.45},
	{"x": 2.1, "z": 0.8, "rx": 0.575, "rz": 0.375},
	{"x": 6.8, "z": -4.2, "rx": 0.7, "rz": 0.4},
]


static func near_climb_trigger(x: float, z: float) -> bool:
	return Vector2(x - CLIMB_TRIGGER.x, z - CLIMB_TRIGGER.z).length() < CLIMB_TRIGGER_RADIUS


## The wall segment (an entry of WALL_SEGMENTS) containing `z`, or {} if none.
static func wall_segment_at_z(z: float) -> Dictionary:
	for segment in WALL_SEGMENTS:
		if z >= segment["z_min"] and z <= segment["z_max"]:
			return segment
	return {}


## True if (x, z), at ground level, is close enough to the wall's base to
## mount it.
static func near_wall_mount(x: float, z: float) -> bool:
	if absf(x - WALL_X) > WALL_MOUNT_X_RANGE:
		return false
	return not wall_segment_at_z(z).is_empty()


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
