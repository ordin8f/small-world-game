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

## How far above a seat's TOP SURFACE the player node has to sit for the
## rider to read as sitting on it rather than in it. Kenney's seated clips
## translate the root bone down to seat height and character_visual.gd's
## _apply() already compensates that (see _root_drop_for()); this is the
## small residual left over once it has, measured on the swing and reused
## unchanged by the bench and the slide so the three cannot disagree.
const SEATED_RIDER_LIFT := 0.16

# ------------------------------------------------------------ tower stairs --
## Real, built access to the deck (developer, 2026-08-30: "there should be a
## better way to climb up to the tower with the slide, than just via the
## slide itself"). Before this there was a climb, but it was a 0.55 m
## trigger circle at a blank tower face -- nothing to see and nothing to
## climb, so the slide looked like the only route up and the ascent itself
## read as a teleport.
##
## Three flights of assets/kenney_town/stairs-wood-handrail.glb against the
## tower's WEST flank, climbing in +x toward it. West rather than south
## because the south face is the slide's: up one side and down the other is
## the clearest possible read of a play tower, and it keeps the staircase
## broadside to the camera as the player approaches from the lane (+z)
## instead of hidden behind the tower.
##
## The kit model is a 1 x 1 m module (measured with tools/_probe_prop_bounds.gd:
## eight treads climbing y 0.09 -> 1.00 over x -0.52 -> 0.50, the 0.02 either
## side being the tread nosing that overhangs the step below), so scaling it
## by STAIR_MODULE makes three flights land exactly on the deck with no seam.
const STAIR_FLIGHTS := 3
const STAIR_MODULE := PLATFORM_TOP_Y / 3.0
## The model's own x extent about its origin, in module units.
const STAIR_MODEL_BACK := 0.52
const STAIR_MODEL_FRONT := 0.50
## The staircase sits slightly toward the approach side of the west flank,
## clear of the featured bush at (-8.7, -13.7).
const STAIR_Z := -12.25
const STAIR_HALF_WIDTH := 0.3
## Top tread lands exactly on the deck's west edge.
const STAIR_TOP_X := TOWER_X - TOWER_FOOTPRINT_HALF
## Origin of the TOP flight; the others step back one module each.
const STAIR_TOP_FLIGHT_X := STAIR_TOP_X - STAIR_MODEL_FRONT * STAIR_MODULE
## Ground-level foot of the bottom flight -- the far end of the whole run.
const STAIR_FOOT_X := STAIR_TOP_FLIGHT_X - (STAIR_FLIGHTS - 1) * STAIR_MODULE - STAIR_MODEL_BACK * STAIR_MODULE

## Ground-level point that starts the climb: just off the bottom step, so
## the trigger fires as the player walks into the foot of the stairs and
## before they bump WorldBounds' own staircase collider.
const CLIMB_TRIGGER := Vector3(STAIR_FOOT_X - 0.4, 0.0, STAIR_Z)
const CLIMB_TRIGGER_RADIUS := 0.55

## Where the ascent ends: the top tread, level with the deck but still
## beside it. The player steps in from here onto PLATFORM_STAND.
const CLIMB_TOP := Vector3(STAIR_TOP_X, PLATFORM_TOP_Y, STAIR_Z)

## Standing spot on the platform once climbed -- a step in from the top of
## the stairs, and lined up with the slide's own mouth so walking on toward
## the courtyard is what starts the ride.
const PLATFORM_STAND := Vector3(TOWER_X - 0.35, PLATFORM_TOP_Y, STAIR_Z)

# ------------------------------------------------------------------ slide --
## THE SLIDE'S TOP SURFACE -- authored once, here, and nowhere else.
##
## This used to be two definitions that were quietly different, and the
## developer caught it by playing (2026-08-30: "the slide surface doesn't
## align with the slide itself"). The scripted ride ran from PLATFORM_STAND
## (z -11.8) at 46.8 degrees; the visual plank ran from the deck's own edge
## (z -11.45) at 50.0 degrees; and _slide_plank() centred its box on the
## line it was given, putting the plank's top face half a thickness above
## it. Three separate offsets, so the rider started over the deck, crossed
## through the plank partway down, and rode inside it the rest of the way.
## The old comment in _bootstrap_courtyard.gd claimed the two "can never
## drift apart again" because both derived from the same constants. They
## derived from DIFFERENT constants; that claim was false, and it is gone.
##
## Now there is one line. slide_surface_point() is the plank's top face;
## _bootstrap_courtyard.gd builds the plank by hanging it BELOW that face
## and the rails from the same two points, and slide_ride_position() is
## that same face lifted by SEATED_RIDER_LIFT. tests/play/
## test_slide_ride_on_the_plank.gd measures the ride against the plank as
## actually built in scenes/courtyard.tscn, so the two can be checked
## against each other rather than merely asserted to agree.
const SLIDE_SURFACE_TOP := Vector3(TOWER_X, PLATFORM_TOP_Y, TOWER_Z + TOWER_FOOTPRINT_HALF)
const SLIDE_SURFACE_FOOT := Vector3(TOWER_X, 0.05, -9.1)
## Width of the bed, and how far off its centreline still counts as being
## at the slide's mouth when walking off the deck's south edge.
const SLIDE_WIDTH := 1.25
const SLIDE_MOUTH_HALF_X := 0.7

## The launch hop at the foot -- "accelerate down, a small launch at the
## bottom" (brief). Fraction of the ride spent on the plank vs. in the air,
## and how high the hop goes. These live here rather than in player.gd so
## the whole path is one pure function the test can sample.
const SLIDE_RIDE_FRACTION := 0.82
const SLIDE_LAUNCH_HEIGHT := 0.4
## Where the hop puts the child down: past the kicker at the plank's foot,
## on open ground clear of the tower's own collider footprint.
const SLIDE_END := Vector3(TOWER_X, 0.0, SLIDE_SURFACE_FOOT.z + 0.55)

# ------------------------------------------------------------------ bench --
## The park bench west of the chalk circle. Until now it was scenery you
## walked straight through: assets/park/bench.gltf had no COLLIDERS entry
## and no affordance at all (developer, 2026-08-30: "I can't sit on the
## bench and go right through it"). Position is unchanged from the openness
## pass -- _bootstrap_courtyard.gd now takes it from here rather than
## repeating the literal.
## y is Y_PAVING from _bootstrap_courtyard.gd: the park pass laid a flagstone
## plaza over the base plane, so a bench at y=0 now sinks 5 cm into it and
## takes its collider and its seat down with it.
const BENCH_POSITION := Vector3(-7.0, 0.05, -9.8)

## What a sitter looks at: the chalk circle at the Group marker, where the
## other children are. The generator's own comment already said the bench
## was "set back on the chalk circle's west side facing it" -- it was drawn
## at rotation 0 (facing the lane) and so never was. Sitting somewhere is a
## thing you do to watch something; facing the bench at what there is to
## watch is most of what makes the verb worth having.
const BENCH_FACES := Vector3(0.0, 0.0, -11.0)

## Seat top surface, measured on the model with tools/_probe_prop_bounds.gd:
## the mesh has two full-width horizontal slabs, an apron at y 0.20..0.30
## and the seat at y 0.45..0.55, under a backrest that carries on to 1.41.
const BENCH_SEAT_TOP_Y := 0.5
## Where along the seat's own depth (local +z is out of the backrest, and
## the seat spans local z -0.40..0.60) the sitter's weight goes -- a little
## forward of the backrest, not jammed against it.
const BENCH_SEAT_LOCAL_Z := -0.15
## Generous enough to offer the prompt from outside the bench's own
## collider, which stands 1.10 m off centre on its long axis and stops the
## player 0.32 m short of that again.
const BENCH_SIT_RADIUS := 1.9
## How far in front of the seat standing up puts the player. Clear of the
## collider, still inside BENCH_SIT_RADIUS -- unlike the swing, standing up
## from a bench and being able to sit straight back down is the right
## behaviour, not a re-trigger bug.
const BENCH_STAND_FORWARD := 1.5


## The bench's yaw, from BENCH_POSITION toward BENCH_FACES. A function
## rather than a constant because GDScript const expressions cannot call
## atan2 -- but it is still one derivation, not a hand-copied angle.
static func bench_yaw() -> float:
	var to_target := BENCH_FACES - BENCH_POSITION
	return atan2(to_target.x, to_target.z)


## Where the player node goes when they sit: on the seat's top surface,
## lifted by SEATED_RIDER_LIFT the same way the swing lifts its rider.
static func bench_sit_position() -> Vector3:
	var local := Vector3(0.0, BENCH_SEAT_TOP_Y + SEATED_RIDER_LIFT, BENCH_SEAT_LOCAL_Z)
	return BENCH_POSITION + Basis(Vector3.UP, bench_yaw()) * local


## Where they end up on standing back up -- a step out in front of the seat,
## on the ground.
static func bench_stand_position() -> Vector3:
	var local := Vector3(0.0, 0.0, BENCH_STAND_FORWARD)
	return BENCH_POSITION + Basis(Vector3.UP, bench_yaw()) * local


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


## World position of stair flight `index` (0 = the bottom one) -- the model's
## own origin, which sits at the base of the flight. _bootstrap_courtyard.gd
## places the meshes from this, and stair_surface_y_at_x() below assumes it,
## so the built staircase and the ascent the player actually walks are the
## same run of numbers.
static func stair_flight_origin(index: int) -> Vector3:
	var from_top := float(STAIR_FLIGHTS - 1 - index)
	return Vector3(STAIR_TOP_FLIGHT_X - from_top * STAIR_MODULE, float(index) * STAIR_MODULE, STAIR_Z)


## Height of the staircase's walking surface at `x` -- flat ground before
## the bottom step, deck height at the top tread, a straight ramp through
## the step noses in between. A ramp rather than eight discrete treads on
## purpose: the child's feet land on the noses either way, and a stepped
## curve would make the ascent stutter without reading any differently.
static func stair_surface_y_at_x(x: float) -> float:
	var t := (x - STAIR_FOOT_X) / (STAIR_TOP_X - STAIR_FOOT_X)
	return LensMath.clamp_value(t, 0.0, 1.0) * PLATFORM_TOP_Y


## A point on the slide's TOP SURFACE, `u` of the way down it (0 = the deck
## edge, 1 = the foot). The single authored definition of where the slide
## is; the plank mesh hangs below this line and the ride sits above it.
static func slide_surface_point(u: float) -> Vector3:
	return SLIDE_SURFACE_TOP.lerp(SLIDE_SURFACE_FOOT, LensMath.clamp_value(u, 0.0, 1.0))


## Height of that surface directly under a given z -- the form the
## alignment test wants, and the one a reader can check by eye.
static func slide_surface_y_at_z(z: float) -> float:
	var span := SLIDE_SURFACE_FOOT.z - SLIDE_SURFACE_TOP.z
	return slide_surface_point((z - SLIDE_SURFACE_TOP.z) / span).y


## Where the player node sits `u` of the way down: on the surface, lifted so
## the child's seat is on it rather than buried in the plank.
static func slide_seat_point(u: float) -> Vector3:
	return slide_surface_point(u) + Vector3(0.0, SEATED_RIDER_LIFT, 0.0)


## The whole ride as one pure function of normalised time: an accelerating
## descent along the surface (SLIDE_RIDE_FRACTION of it) and then a short
## forward hop off the foot that lands on SLIDE_END. player.gd only advances
## the clock and hands `t` to this, so the path the player actually travels
## and the path a test samples are the same code.
static func slide_ride_position(t: float) -> Vector3:
	var tc := LensMath.clamp_value(t, 0.0, 1.0)
	if tc < SLIDE_RIDE_FRACTION:
		var rt := tc / SLIDE_RIDE_FRACTION
		return slide_seat_point(rt * rt)  # accelerating, not linear
	var lt := (tc - SLIDE_RIDE_FRACTION) / (1.0 - SLIDE_RIDE_FRACTION)
	var from := slide_seat_point(1.0)
	var hop := sin(lt * PI) * SLIDE_LAUNCH_HEIGHT
	return Vector3(
		lerpf(from.x, SLIDE_END.x, lt),
		lerpf(from.y, SLIDE_END.y, lt) + hop,
		lerpf(from.z, SLIDE_END.z, lt),
	)


## True when the player, walking around the tower deck, is over the slide's
## own mouth rather than somewhere else along the deck's south edge. Without
## this the ride started from anywhere on that edge and snapped the child up
## to a metre sideways onto the plank as it began.
static func at_slide_mouth(x: float, z: float) -> bool:
	if absf(x - SLIDE_SURFACE_TOP.x) > SLIDE_MOUTH_HALF_X:
		return false
	return z > SLIDE_SURFACE_TOP.z - 0.15


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
