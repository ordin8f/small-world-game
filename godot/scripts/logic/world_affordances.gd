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

# --------------------------------------------------------- ground layers --
## The walking plane, and the stack of ground patches laid on it.
##
## player.gd locks the child's Y here and there is no terrain-follow, so
## this is not one height among several: it is THE height, and every
## walkable surface has to sit at or a hair BELOW it. Anything above it is
## ground the child wades through.
##
## The 2026-08-30 park pass introduced a layered stack -- lawn < paving <
## bark < soil < chalk, each a flat slab laid over the base plane, so
## patches overlap freely and the later, more specific one simply wins with
## no seams to keep in sync. That layering is good and is kept exactly.
## What was wrong was the SPACING: authored at 0.02 .. 0.13, it stood the
## plaza 5 cm and the bark pit 7 cm above the child's feet (7 cm is
## ankle-deep on a 1.2 m child, and the bark is under the swing and the
## sandbox, where the camera is closest), and it floated the chalk circle
## -- the mark the objective text and Arun's line both name -- as a hoop
## 8.5 cm off the ground at the exact spot the story happens.
##
## The only thing that spacing has to defeat is coplanar z-fighting, and
## with a reverse-Z depth buffer a millimetre or two does that at these
## distances. So the stack is compressed DOWNWARD from the walking plane
## rather than stacked upward off it: same order, same overlap semantics,
## every top now at or under the child's feet and the largest error a
## centimetre.
##
## These live here rather than in _bootstrap_courtyard.gd because they are
## a fact about where the player stands, not about how the world is drawn:
## player.gd's locked_y, WorldBounds' colliders and the generator's slabs
## all have to agree, and the generator is a one-shot tool no test can
## import.
const WALK_PLANE_Y := 0.0
## Enough to break coplanarity on a 45 m plane, small enough to be invisible.
const SURFACE_STEP := 0.0025
const Y_CHALK := WALK_PLANE_Y
const Y_SOIL := WALK_PLANE_Y - SURFACE_STEP
const Y_BARK := WALK_PLANE_Y - SURFACE_STEP * 2.0
const Y_PAVING := WALK_PLANE_Y - SURFACE_STEP * 3.0
const Y_LAWN := WALK_PLANE_Y - SURFACE_STEP * 4.0
## For a patch that has to draw OVER the layer it borders without becoming
## a layer of its own -- the plaza's edging course. Half a step, so it can
## never land on another layer's height however the stack is retuned; the
## park pass's own 0.005 would have collided with Y_SOIL once the stack
## compressed.
const SURFACE_HAIR := SURFACE_STEP * 0.5

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
## Y is Y_PAVING, not a literal: the bench stands on the laid path, and the
## merge of the park and playground passes briefly had the model on the
## paving while this constant -- and so the collider and the seat -- stayed
## on the base plane 5 cm below it. Deriving it means the whole stack can be
## retuned (as it just was) without the bench silently coming loose again.
const BENCH_POSITION := Vector3(-7.0, Y_PAVING, -9.8)

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


## The yaw that turns a prop's local +Z from `from` toward `to`. Godot's
## Basis(UP, yaw) maps local +Z to (sin yaw, cos yaw), which is what makes
## this atan2(x, z) rather than the usual atan2(z, x).
##
## +Z is the front for bench.gltf specifically -- measured, not assumed: its
## backrest vertices all sit at negative local z. _bootstrap_courtyard.gd
## carried a comment claiming the opposite for a while, which would have put
## every bench in the park 180 degrees out if anyone had believed it while
## authoring one.
static func yaw_facing(from: Vector3, to: Vector3) -> float:
	var direction := to - from
	return atan2(direction.x, direction.z)


## The sittable bench's yaw, derived from where it stands toward what it
## looks at. A function rather than a constant because GDScript const
## expressions cannot call atan2 -- but it is still one derivation, not a
## hand-copied angle. The 90.0 degrees this replaced was close enough to
## look right and wrong enough to miss the circle.
static func bench_yaw() -> float:
	return yaw_facing(BENCH_POSITION, BENCH_FACES)


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
## Low brick edging around planting beds -- where the balance verb lives.
## It used to be the tall playground/garden-pocket boundary wall (x=11,
## still there as a boundary, just no longer a balance affordance): the
## developer's own words were "the walking on the edge should be on the
## side of a brick lining of a small garden or area or something -- not
## the wall, where it is." A real garden bed's edging is both better
## storytelling and what a child would actually do.
##
## 2026-08-30 generalised this from ONE bed's ONE east-facing centreline
## (x=-3.7, the home threshold bed) into a set of independent straight
## EDGES, because the developer's own follow-up ask was "the brick lane
## around each of the small gardens" -- every planting bed in the park,
## not just the one by the door. An edge is just two ground-level
## endpoints (Vector2(x, z) each); the player's balance is always measured
## PERPENDICULAR to whichever edge they're on and their travel PARALLEL to
## it (edge_tangent()/edge_normal()/edge_coords() below), never "x" or "z"
## specifically -- that's what lets a bed whose long side runs in z serve
## the exact same verb as one whose long side runs in x, with no
## orientation branch anywhere.
##
## Every edge is DERIVED from the same rectangle
## (_bootstrap_courtyard.gd's _planting_bed() calls, mirrored here as
## PARK_BEDS) that builds the visible kerb, so a bed added later gets a
## matching mount for free and the two can never drift apart the way this
## project's slide/ride and bench/seat pairs once did (see this file's
## WALK_PLANE_Y and BENCH_POSITION doc comments for that history). The
## home bed is the one exception: it predates PARK_BEDS, is built by hand
## in _build_garden_bed() rather than _planting_bed(), and its four
## borders were authored to numbers that don't quite satisfy the tidy
## "outer footprint = cx +/- w/2" arithmetic PARK_BEDS relies on (its
## east border sits at EDGING_X=-3.7, its west border's own centreline at
## -6.15 -- 0.05 m short of where a symmetric w=2.8 rectangle would put
## it). Rather than nudge already-shipped, already-verified geometry to
## fit a formula, HOME_BED_EDGE is kept as its own small directly-authored
## edge, unchanged in every number from the original EDGING_X/EDGING_SEGMENTS
## this replaces -- still single-sourced (_build_garden_bed() reads
## EDGING_X same as before), just reshaped to the same {a, b} shape every
## other edge uses so player.gd never has to know which kind it mounted.
const EDGING_TOP_Y := 0.3
## Perpendicular distance, at ground level, that mounts the edging.
const EDGING_MOUNT_X_RANGE := 0.55
## How far off the centreline reads as "still on top" before stepping off.
const EDGING_HALF_WIDTH := 0.3

## The home bed's mount edge -- see the doc comment above for why this one
## is hand-authored rather than derived from PARK_BEDS. Same x (-3.7) and
## z run (10.45..13.65) the original EDGING_X/EDGING_SEGMENTS held.
const EDGING_X := -3.7
const HOME_BED_EDGE := {"a": Vector2(EDGING_X, 10.45), "b": Vector2(EDGING_X, 13.65)}

## Kerb height for _planting_bed()'s four borders. Was a local 0.26 m
## literal inside that function -- 0.04 m short of EDGING_TOP_Y, which
## would have floated every park bed's balancer 4 cm above its own kerb
## the moment it became mountable, the exact "visual and affordance
## authored separately" defect this pass was warned about. Unified here
## so _planting_bed() and every edge derived from PARK_BEDS agree by
## construction; "around 0.3 m, knee height" was already the brief for
## the balance verb, so this also happens to match it.
const PARK_BED_KERB_H := EDGING_TOP_Y
## Kerb thickness for _planting_bed()'s four borders, and the amount its
## north/south caps overhang past w/2 to cover the corners (matching that
## function's own construction) -- read from here so a mountable +z/-z
## side's length can agree with what actually got built.
const PARK_BED_KERB_T := 0.24

## One _planting_bed() rectangle -- outer footprint centre (cx, cz) and
## full size (w, d) along x and z, exactly the arguments that function
## takes -- and which of its four sides are worth balancing on ("+x",
## "-x", "+z" and/or "-z", see _bed_side_edge() for what each means).
## _bootstrap_courtyard.gd's _build_park_ground() drives its
## _planting_bed() calls from this same table, so a bed's kerb and its
## mount can never disagree, and a bed added here gets both for free.
##
## Not every side of every bed is included:
##  - the gate-flank beds' outer side sits against the gate pier/boundary;
##    the inner side, facing the gate opening a player actually walks
##    through, is the one a passer-by meets (same "facing the path"
##    reasoning EDGING_X's own original comment gave for the home bed).
##  - the arcade run's near-wall side sits 0.05 m off the arcade wall's
##    own face (_build_arcade_wall(), centre z=-24, thickness 1.2) -- no
##    room for a child to stand there. The far side, facing the open lawn,
##    is clear and is the long axis (5.68 m with the kerb's own corner
##    overhang).
##  - the west hedge run's near-wall side sits 0.25 m off the west
##    boundary wall (x=-22.8, half-width 0.4); the far side, facing the
##    lawn, is the natural approach and the bed's own long axis (4.2 m).
## All three groups have room on exactly one side; none were dropped for
## being too short -- even the gate beds' 1.5 m run clears
## EDGING_MOUNT_X_RANGE*2 with room for a real, if brief, few steps.
const PARK_BEDS := [
	{"cx": -4.3, "cz": -5.1, "w": 2.6, "d": 1.5, "sides": ["+x"]},
	{"cx": 4.3, "cz": -5.1, "w": 2.6, "d": 1.5, "sides": ["-x"]},
	{"cx": -16.0, "cz": -22.6, "w": 5.2, "d": 1.5, "sides": ["+z"]},
	{"cx": -8.0, "cz": -22.6, "w": 5.2, "d": 1.5, "sides": ["+z"]},
	{"cx": 0.0, "cz": -22.6, "w": 5.2, "d": 1.5, "sides": ["+z"]},
	{"cx": 8.0, "cz": -22.6, "w": 5.2, "d": 1.5, "sides": ["+z"]},
	{"cx": 16.0, "cz": -22.6, "w": 5.2, "d": 1.5, "sides": ["+z"]},
	{"cx": -21.4, "cz": -8.0, "w": 1.5, "d": 4.2, "sides": ["+x"]},
	{"cx": -21.4, "cz": -13.5, "w": 1.5, "d": 4.2, "sides": ["+x"]},
	{"cx": -21.4, "cz": -19.0, "w": 1.5, "d": 4.2, "sides": ["+x"]},
]


## One side of a PARK_BEDS rectangle as an edge, {"a": Vector2, "b":
## Vector2} in world (x, z) -- matching the exact span _planting_bed()
## renders for that side. "+x"/"-x" are the east/west borders (length d,
## no overhang, same as that function's own KERB_T-wide meshes); "+z"/"-z"
## are the north/south caps (length w + 2*PARK_BED_KERB_T, since those
## meshes run wide enough to cover the corners where the side borders
## meet them).
static func _bed_side_edge(bed: Dictionary, side: String) -> Dictionary:
	var cx: float = bed["cx"]
	var cz: float = bed["cz"]
	var w: float = bed["w"]
	var d: float = bed["d"]
	match side:
		"+x":
			return {"a": Vector2(cx + w * 0.5, cz - d * 0.5), "b": Vector2(cx + w * 0.5, cz + d * 0.5)}
		"-x":
			return {"a": Vector2(cx - w * 0.5, cz - d * 0.5), "b": Vector2(cx - w * 0.5, cz + d * 0.5)}
		"+z":
			return {"a": Vector2(cx - w * 0.5 - PARK_BED_KERB_T, cz + d * 0.5), "b": Vector2(cx + w * 0.5 + PARK_BED_KERB_T, cz + d * 0.5)}
		"-z":
			return {"a": Vector2(cx - w * 0.5 - PARK_BED_KERB_T, cz - d * 0.5), "b": Vector2(cx + w * 0.5 + PARK_BED_KERB_T, cz - d * 0.5)}
	push_error("WorldAffordances._bed_side_edge: unknown side '%s'" % side)
	return {}


## Every mountable edge in the park: the hand-authored home bed plus one
## entry per (bed, side) pair PARK_BEDS lists. The single list player.gd
## and near_edging_mount() both work from.
static func edging_edges() -> Array:
	var edges: Array = [HOME_BED_EDGE]
	for bed in PARK_BEDS:
		for side in bed["sides"]:
			edges.append(_bed_side_edge(bed, side))
	return edges


## Unit vector along the edge, from a to b -- "forward" along the run.
## Vector2's (x, y) holds world (x, z) throughout this section, the same
## convention STONES/PUDDLES already use for ground-plane math.
static func edge_tangent(edge: Dictionary) -> Vector2:
	return (edge["b"] - edge["a"]).normalized()


## Unit vector perpendicular to the edge, in the ground plane -- the axis
## drift/lean is measured on. Rotated +90 degrees from the tangent in
## this specific direction (not the other one) so that for the home
## bed's own north-south edge this reduces to exactly "+world x", the
## sign every pre-existing balance number (_wall_offset, the dismount
## landing, the visual lean) was authored against -- the generalisation
## has to reduce to the original for the one edge that already shipped.
static func edge_normal(edge: Dictionary) -> Vector2:
	var t := edge_tangent(edge)
	return Vector2(t.y, -t.x)


static func edge_length(edge: Dictionary) -> float:
	return (edge["b"] - edge["a"]).length()


## Splits (x, z) into how far ALONG the edge (0 at a, edge_length() at b)
## and how far ACROSS it (signed, edge_normal() direction, 0 on the
## centreline) the point sits -- the one decomposition mounting,
## balancing and dismounting all need, regardless of which way the edge
## runs.
static func edge_coords(edge: Dictionary, x: float, z: float) -> Dictionary:
	var a: Vector2 = edge["a"]
	var p := Vector2(x, z) - a
	return {"along": p.dot(edge_tangent(edge)), "across": p.dot(edge_normal(edge))}


## World (x, z) for a point `along` an edge's own run and `across` it --
## the inverse of edge_coords(), and the only place player.gd converts
## a local (along, across) pair back to global_position.
static func edge_point(edge: Dictionary, along: float, across: float) -> Vector2:
	return edge["a"] + edge_tangent(edge) * along + edge_normal(edge) * across


## Index into edging_edges() of the edge (x, z) is close enough to mount,
## or -1 if none -- on the ground, within EDGING_MOUNT_X_RANGE across it
## and somewhere along its actual run (no overshoot tolerance here; that's
## _process_wall_walk()'s own clamp headroom for staying mounted, not for
## getting on in the first place).
static func edging_edge_index_at(x: float, z: float) -> int:
	var edges := edging_edges()
	for i in range(edges.size()):
		var c := edge_coords(edges[i], x, z)
		var along: float = c["along"]
		if along < 0.0 or along > edge_length(edges[i]):
			continue
		if absf(c["across"]) <= EDGING_MOUNT_X_RANGE:
			return i
	return -1


## True if (x, z), at ground level, is close enough to any edge to mount
## it. Kept as a plain bool query (rather than every caller checking
## edging_edge_index_at() != -1 itself) since that's most of this
## function's own test coverage from before the generalisation.
static func near_edging_mount(x: float, z: float) -> bool:
	return edging_edge_index_at(x, z) != -1

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
