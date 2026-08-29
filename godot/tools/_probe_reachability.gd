extends SceneTree
## Headless reachability + sightline probe: floods the walkable plane of
## scenes/courtyard.tscn from the player's spawn and reports, for every
## interaction zone and named landmark, whether it can actually be stood in
## and how far the walk is -- then measures what can be SEEN from each place.
##
## Run with:
##   godot --headless --path godot --script res://tools/_probe_reachability.gd
##
## Why the real physics world and not WorldBounds.can_move_to(): player.gd's
## _physics_process drives the body with move_and_slide() only -- it never
## calls can_move_to(). The StaticBody3D set that _bootstrap_courtyard.gd's
## _add_wall_colliders() bakes into courtyard.tscn is therefore the ONLY
## thing that decides where a player can go, and can_move_to() is a
## logic-side mirror of it that no movement code consults. Probing the
## logic mirror would measure the mirror, not the world.
##
## courtyard.tscn alone is the whole collision set: every other node in the
## world (props via _prop(), the CSG arcade, swing.tscn, sandbox.tscn,
## pocket_treasure.tscn) is visual-only with no CollisionShape3D anywhere,
## so nothing in main.tscn adds an obstacle this scene doesn't already have.
##
## The capsule is READ OFF scenes/player.tscn (radius, height and the
## CollisionShape3D's own Y offset), never hardcoded -- a probe that guesses
## the radius measures a player that doesn't exist.

const STEP := 0.5

## Grid origin chosen so the spawn (0, 10) lands exactly on a node, and
## wide enough to spill well outside every wall -- cells beyond the world
## are how the probe notices a perimeter leak instead of assuming there
## isn't one.
const X_MIN := -18.0
const Z_MIN := -22.0
const X_CELLS := 85  # -18.0 .. 24.0
const Z_CELLS := 81  # -22.0 .. 18.0

## WorldBounds.can_move_to()'s loose outer envelope. Used only to classify
## the report (inside = the world's own bounding box, outside = backdrop
## space), never to decide walkability.
const ENV_X_MIN := -16.6
const ENV_X_MAX := 22.6
const ENV_Z_MIN := -20.3
const ENV_Z_MAX := 16.3

const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## name, x, z, radius. Radius is the distance from the point at which the
## thing counts as reached: an interaction zone's own trigger radius
## (interaction_zone.gd ZONE_DATA), a verb's own mount radius, or 0.75 for
## a plain landmark you simply have to be able to walk up to.
const ZONES := [
	["Watch", 0.0, -8.0, 2.3],
	["BallEnd", 14.0, -12.0, 1.45],
	["Return", 0.0, -11.0, 2.1],
	["Join", 0.0, -10.3, 2.2],
	["Door", 0.0, 13.0, 1.8],
]

const LANDMARKS := [
	["Spawn/Start", 0.0, 10.0, 0.75],
	["HomePorchWest", -5.0, 10.0, 0.75],
	["HomePorchEast", 5.0, 10.0, 0.75],
	["GardenBedEdging", -3.7, 12.05, 0.75],
	["LaneMouthNorth", 0.0, 7.0, 0.75],
	["LaneMiddle", 0.0, 2.0, 0.75],
	["LaneMouthSouth", 0.0, -3.0, 0.75],
	["ChalkCircle/Group", 0.0, -11.0, 0.75],
	["TowerWestClimb", -3.4, -11.05, 0.55],
	["SlideEnd", -3.4, -9.1, 0.75],
	["TowerEastApproach", 3.4, -11.05, 0.75],
	["Swing", 6.5, -8.0, 1.3],
	["Sandbox", -10.5, -8.0, 1.6],
	["Bench", -7.0, -8.0, 0.9],
	["BushFeature", -8.7, -13.7, 0.9],
	["Treasure:Marble", 9.2, -5.0, 1.1],
	["Treasure:Stone", 18.0, -8.0, 1.1],
	["Treasure:Feather", -8.7, -4.5, 1.1],
	["GardenGapArch", 11.0, -8.0, 0.75],
	["SteppingStones", 12.85, -8.8, 0.75],
	["PuddleLaneNorth", -1.5, 3.2, 0.75],
	["PuddleLaneSouth", 2.1, 0.8, 0.75],
	["PuddleGarden", 12.4, -9.4, 0.75],
	["GardenPocketEast", 20.0, -10.0, 0.75],
	["PlaygroundSWCorner", -14.0, -18.0, 0.75],
	["PlaygroundSECorner", 14.0, -18.0, 0.75],
	["PlaygroundNWFlank", -14.0, -5.0, 0.75],
	["PlaygroundNEFlank", 14.0, -18.5, 0.75],
	["ArcadeCentre", 0.0, -18.5, 0.75],
]

## Child eye height. Everything the sightline half of this probe measures is
## measured from here, not from the camera -- "can you see the next place
## from this one" is a question about the world's proportions, and the
## camera's own height is a separate, tunable thing.
const EYE_Y := 1.2
## REVEAL's authored camera height (camera_profile.gd), the highest the view
## ever gets. Used only by the dead-space visibility pass -- the sightline
## and horizon metrics stay at EYE_Y, since "can you see the next place" is
## a question about the world's proportions rather than about this camera.
const CAMERA_Y := 2.6
const SIGHT_MAX := 45.0
const FAN_RAYS := 72

## from_name, from_x, from_z, to_name, to_x, to_z. Each pair is a
## "standing here, can I see there" question about a route the player
## actually takes.
const SIGHTLINES := [
	["Spawn", 0.0, 10.0, "LaneMiddle", 0.0, 2.0],
	["Spawn", 0.0, 10.0, "ChalkCircle", 0.0, -11.0],
	["LaneMouthNorth", 0.0, 7.0, "LaneMouthSouth", 0.0, -3.0],
	["LaneMiddle", 0.0, 2.0, "ChalkCircle", 0.0, -11.0],
	["LaneMouthSouth", 0.0, -3.0, "Swing", 6.5, -8.0],
	["LaneMouthSouth", 0.0, -3.0, "Sandbox", -10.5, -8.0],
	["LaneMouthSouth", 0.0, -3.0, "GardenGapArch", 11.0, -8.0],
	["ChalkCircle", 0.0, -11.0, "Swing", 6.5, -8.0],
	["ChalkCircle", 0.0, -11.0, "Sandbox", -10.5, -8.0],
	["ChalkCircle", 0.0, -11.0, "GardenGapArch", 11.0, -8.0],
	["Swing", 6.5, -8.0, "GardenGapArch", 11.0, -8.0],
	["Swing", 6.5, -8.0, "Sandbox", -10.5, -8.0],
	["GardenPocket", 14.0, -12.0, "ChalkCircle", 0.0, -11.0],
	["ChalkCircle", 0.0, -11.0, "Door", 0.0, 13.0],
]

## Where the 360-degree openness fan is taken from -- one viewpoint per
## place the player stands in for any length of time.
const VIEWPOINTS := [
	["Spawn", 0.0, 10.0],
	["LaneMiddle", 0.0, 2.0],
	["LaneMouthSouth", 0.0, -3.0],
	["ChalkCircle", 0.0, -11.0],
	["Swing", 6.5, -8.0],
	["Sandbox", -10.5, -8.0],
	["GardenGapArch", 11.0, -8.0],
	["BallEnd", 14.0, -12.0],
]

## A direction counts as open when nothing along it rises more than this
## far above the horizontal. 15 degrees is roughly "a 3 m wall at 7 m, or a
## 1.6 m garden wall at 1.5 m" -- past it the thing in the way is filling
## enough of the view to close the space down.
const OPEN_HORIZON_DEG := 15.0

var _space: PhysicsDirectSpaceState3D
var _params: PhysicsShapeQueryParameters3D
var _capsule_y := 0.54
var _occluders: Array = []
var _skyline: Array = []


func _initialize() -> void:
	await _run()


func _run() -> void:
	var courtyard: Node3D = (load("res://scenes/courtyard.tscn") as PackedScene).instantiate()
	get_root().add_child(courtyard)

	var capsule := _player_capsule()
	print("player capsule (read from scenes/player.tscn): radius=%.3f height=%.3f shape_y=%.3f" % [
		capsule.radius, capsule.height, _capsule_y,
	])

	# Two frames: one for the tree to enter, one for the physics server to
	# have actually committed every StaticBody3D's transform. Querying on
	# frame zero returns an empty world.
	await physics_frame
	await physics_frame

	_space = courtyard.get_world_3d().direct_space_state
	_params = PhysicsShapeQueryParameters3D.new()
	_params.shape = capsule
	_params.collision_mask = 1  # layer 1 = movement, the layer player.gd's body collides on
	_params.collide_with_areas = false
	_params.collide_with_bodies = true

	print("grid: %.2f m spacing, x[%.1f, %.1f] z[%.1f, %.1f] (%d x %d = %d cells)" % [
		STEP, X_MIN, X_MIN + (X_CELLS - 1) * STEP, Z_MIN, Z_MIN + (Z_CELLS - 1) * STEP,
		X_CELLS, Z_CELLS, X_CELLS * Z_CELLS,
	])

	var free := _free_grid()
	var spawn := _cell_of(0.0, 10.0)
	if not free[_index(spawn)]:
		printerr("FATAL: the spawn cell (0, 10) is itself blocked -- nothing to flood from.")
		quit(1)
		return

	var dist := _flood(free, spawn)
	_report(free, dist)

	_collect_occluders(courtyard)
	_report_sightlines()
	_report_invisible_walls(courtyard, free, dist, STEP * STEP)
	_report_dead_space_visibility(free, dist, STEP * STEP, EYE_Y, "child eye")
	_report_dead_space_visibility(free, dist, STEP * STEP, CAMERA_Y, "REVEAL camera")
	_report_geometry_in_walkable_space(dist)
	quit(0)


## The player's real collision capsule, straight off the scene file. Also
## records the CollisionShape3D's own Y offset so the probe queries at the
## same height the body actually occupies.
func _player_capsule() -> CapsuleShape3D:
	var player: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	var found: CapsuleShape3D = null
	for child in player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			found = (child.shape as CapsuleShape3D).duplicate()
			_capsule_y = child.position.y
			break
	player.free()
	if found == null:
		printerr("FATAL: no CapsuleShape3D found under scenes/player.tscn's root.")
		quit(1)
	return found


func _index(cell: Vector2i) -> int:
	return cell.y * X_CELLS + cell.x


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(round((x - X_MIN) / STEP)), int(round((z - Z_MIN) / STEP)))


func _world_of(cell: Vector2i) -> Vector2:
	return Vector2(X_MIN + cell.x * STEP, Z_MIN + cell.y * STEP)


func _in_envelope(p: Vector2) -> bool:
	return p.x >= ENV_X_MIN and p.x <= ENV_X_MAX and p.y >= ENV_Z_MIN and p.y <= ENV_Z_MAX


## True for every cell the capsule fits in standing still. Says nothing
## about whether you can GET there -- that's _flood()'s job.
func _free_grid() -> PackedByteArray:
	var free := PackedByteArray()
	free.resize(X_CELLS * Z_CELLS)
	for zi in range(Z_CELLS):
		for xi in range(X_CELLS):
			var p := _world_of(Vector2i(xi, zi))
			_params.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, _capsule_y, p.y))
			_params.motion = Vector3.ZERO
			free[zi * X_CELLS + xi] = 1 if _space.intersect_shape(_params, 1).is_empty() else 0
	return free


## Breadth-first flood on 4-connected neighbours. Each step is confirmed
## with a SWEPT capsule cast, not just "both endpoints are free" -- two free
## cells 0.5 m apart can still have a wall corner between them, and a probe
## that only samples points would report a route through it.
## Returns step-count per cell (-1 = never reached).
func _flood(free: PackedByteArray, start: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(X_CELLS * Z_CELLS)
	dist.fill(-1)
	dist[_index(start)] = 0

	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var here := _world_of(cell)
		for delta in NEIGHBORS:
			var next: Vector2i = cell + delta
			if next.x < 0 or next.x >= X_CELLS or next.y < 0 or next.y >= Z_CELLS:
				continue
			var next_index := _index(next)
			if dist[next_index] != -1 or free[next_index] == 0:
				continue
			_params.transform = Transform3D(Basis.IDENTITY, Vector3(here.x, _capsule_y, here.y))
			_params.motion = Vector3(delta.x * STEP, 0.0, delta.y * STEP)
			var cast: PackedFloat32Array = _space.cast_motion(_params)
			if cast.size() < 1 or cast[0] < 0.999:
				continue  # a wall corner sits between these two free cells
			dist[next_index] = dist[_index(cell)] + 1
			queue.append(next)
	return dist


func _report(free: PackedByteArray, dist: PackedInt32Array) -> void:
	var cell_area := STEP * STEP
	var reachable := 0
	var free_inside := 0
	var reachable_inside := 0
	var leaked := 0
	for i in range(dist.size()):
		var cell := Vector2i(i % X_CELLS, i / X_CELLS)
		var inside := _in_envelope(_world_of(cell))
		if free[i] == 1 and inside:
			free_inside += 1
		if dist[i] < 0:
			continue
		reachable += 1
		if inside:
			reachable_inside += 1
		else:
			leaked += 1

	print("")
	print("=== TARGETS ===")
	print("%-22s %8s %8s %10s %12s %s" % ["target", "x", "z", "radius", "reach", "walk (m)"])
	print("-".repeat(78))
	var unreachable: Array[String] = []
	for group in [["ZONE", ZONES], ["LANDMARK", LANDMARKS]]:
		print("-- %s --" % group[0])
		for entry in group[1]:
			var result := _nearest(dist, entry[1], entry[2], entry[3])
			var reach_text := "YES" if result["reached"] else "NO"
			var walk_text := "%.1f" % (result["steps"] * STEP) if result["reached"] else "--"
			print("%-22s %8.2f %8.2f %10.2f %12s %s" % [
				entry[0], entry[1], entry[2], entry[3], reach_text, walk_text,
			])
			if not result["reached"]:
				unreachable.append("%s (%s)" % [entry[0], group[0]])

	print("")
	print("=== SPACE ===")
	print("reachable cells:        %5d  (%.1f m^2)" % [reachable, reachable * cell_area])
	print("  inside envelope:      %5d  (%.1f m^2)" % [reachable_inside, reachable_inside * cell_area])
	print("  OUTSIDE envelope:     %5d  <- perimeter leak if non-zero" % leaked)
	print("free-but-unreachable inside envelope: %5d cells (%.1f m^2)" % [
		free_inside - reachable_inside, (free_inside - reachable_inside) * cell_area,
	])

	_report_dead_space(free, dist, cell_area)

	print("")
	if unreachable.is_empty():
		print("VERDICT: every listed target is reachable from spawn.")
	else:
		print("VERDICT: %d unreachable target(s): %s" % [unreachable.size(), ", ".join(unreachable)])


## Nearest reachable cell within `radius` of (x, z). "Reached" means the
## player can stand somewhere that satisfies the target, not that the exact
## authored point is free -- a zone centred inside a bush is still usable if
## its trigger radius spills onto open ground.
func _nearest(dist: PackedInt32Array, x: float, z: float, radius: float) -> Dictionary:
	var best := -1
	var span := int(ceil(radius / STEP)) + 1
	var centre := _cell_of(x, z)
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := centre + Vector2i(dx, dz)
			if cell.x < 0 or cell.x >= X_CELLS or cell.y < 0 or cell.y >= Z_CELLS:
				continue
			var p := _world_of(cell)
			if Vector2(p.x - x, p.y - z).length() > radius:
				continue
			var d := dist[_index(cell)]
			if d >= 0 and (best < 0 or d < best):
				best = d
	return {"reached": best >= 0, "steps": best}


## Connected components of free-but-unreachable space inside the envelope --
## the "you can see it but can never stand in it" list, named by extent so
## each one is findable in the generator rather than just counted.
func _report_dead_space(free: PackedByteArray, dist: PackedInt32Array, cell_area: float) -> void:
	var seen := PackedByteArray()
	seen.resize(free.size())
	print("")
	print("=== DEAD SPACE (free, inside envelope, unreachable from spawn) ===")
	var components := 0
	for start_index in range(free.size()):
		if seen[start_index] == 1 or free[start_index] == 0 or dist[start_index] >= 0:
			continue
		var start := Vector2i(start_index % X_CELLS, start_index / X_CELLS)
		if not _in_envelope(_world_of(start)):
			continue
		var queue: Array[Vector2i] = [start]
		seen[start_index] = 1
		var head := 0
		var count := 0
		var min_p := Vector2(INF, INF)
		var max_p := Vector2(-INF, -INF)
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			count += 1
			var p := _world_of(cell)
			min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
			max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
			for delta in NEIGHBORS:
				var next: Vector2i = cell + delta
				if next.x < 0 or next.x >= X_CELLS or next.y < 0 or next.y >= Z_CELLS:
					continue
				var next_index := _index(next)
				if seen[next_index] == 1 or free[next_index] == 0 or dist[next_index] >= 0:
					continue
				if not _in_envelope(_world_of(next)):
					continue
				seen[next_index] = 1
				queue.append(next)
		# One-cell slivers along a wall face are quantisation, not a room.
		if count < 4:
			continue
		components += 1
		print("  #%d  %6.1f m^2   x[%.1f, %.1f]  z[%.1f, %.1f]" % [
			components, count * cell_area, min_p.x, max_p.x, min_p.y, max_p.y,
		])
	if components == 0:
		print("  (none)")


# ------------------------------------------------------------- sightlines --
# The other half of "crammed". Reachability says whether a place can be
# entered; this says whether it can be SEEN from the place before it, which
# is what actually makes a bounded world read as open rather than as a
# corridor of rooms. Measured against RENDER geometry, not colliders --
# collider heights are deliberately uniform (5.0 / 2.4, see
# _bootstrap_courtyard.gd's _wall_collider()) and so say nothing about
# whether you can look over a wall.


## Every rendered thing that spans child eye height, as a world-space AABB.
## No name or type heuristics: "does this mesh's own box contain y = EYE_Y"
## IS the definition of an occluder at eye level, so ground, paths, plinths,
## fences and flowers drop out on their own and walls, trees and bushes stay
## in. Trees included is correct -- a tree really does interrupt a view --
## but note an AABB is the canopy's full width, so a "blocked by Tree" line
## below is a worst case, not a solid wall.
func _collect_occluders(root: Node) -> void:
	_occluders.clear()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is GeometryInstance3D):
			continue
		var local: AABB = (node as GeometryInstance3D).get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var box: AABB = (node as GeometryInstance3D).global_transform * local
		# Anything rising above the eye at all feeds the horizon metric --
		# including things whose base is above eye height, like a canopy.
		if box.end.y > EYE_Y:
			_skyline.append(box)
		if box.position.y > EYE_Y or box.end.y < EYE_Y:
			continue
		_occluders.append({"name": str(node.name), "box": box})
	print("")
	print("occluders spanning eye height (y=%.2f): %d, rising above it: %d" % [
		EYE_Y, _occluders.size(), _skyline.size(),
	])


## How high, in degrees above the horizontal, the tallest thing along this
## direction rises. This is the honest openness question, and a flat
## "distance to first blocker" answers it badly: a 1.6 m garden wall 4 m
## away stops a horizontal eye-height ray exactly as a 7 m canyon wall 4 m
## away does, but you look straight over the first and not the second. The
## whole point of lowering a wall is that it stops closing the view while
## still bounding the space, and a metric that cannot see that difference
## would score every lowered wall as no improvement at all.
func _horizon_deg(origin: Vector3, dir: Vector3) -> float:
	var highest := 0.0
	for box in _skyline:
		if box.has_point(origin):
			continue
		var t := _ray_box(origin, dir, box)
		if t < 0.0 or t > SIGHT_MAX:
			continue
		var rise: float = box.end.y - EYE_Y
		var angle := rad_to_deg(atan2(rise, maxf(t, 0.01)))
		if angle > highest:
			highest = angle
	return highest


## Distance along `dir` at which the view from `origin` first meets
## something, capped at SIGHT_MAX. Returns {"dist", "name"}.
func _first_hit(origin: Vector3, dir: Vector3) -> Dictionary:
	var best := SIGHT_MAX
	var best_name := ""
	for occluder in _occluders:
		var box: AABB = occluder["box"]
		# You are never blocked by something you are standing inside. A tree
		# canopy's AABB swallows the ground under the tree, and a low arch's
		# own lintel swallows the threshold you walk through -- both would
		# otherwise report a 0 m view in every direction from that spot.
		if box.has_point(origin):
			continue
		var t := _ray_box(origin, dir, box)
		if t >= 0.0 and t < best:
			best = t
			best_name = occluder["name"]
	return {"dist": best, "name": best_name}


## Slab test. Hand-rolled rather than AABB.intersects_ray() so the
## origin-inside-box case is explicit rather than implementation-defined.
func _ray_box(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var t_min := -INF
	var t_max := INF
	for axis in range(3):
		var o: float = origin[axis]
		var d: float = dir[axis]
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if absf(d) < 1e-9:
			if o < lo or o > hi:
				return -1.0
			continue
		var t1 := (lo - o) / d
		var t2 := (hi - o) / d
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
	if t_max < maxf(t_min, 0.0):
		return -1.0
	return maxf(t_min, 0.0)


func _report_sightlines() -> void:
	print("")
	print("=== SIGHTLINES (eye height %.1f m, render geometry) ===" % EYE_Y)
	print("%-18s -> %-18s %8s %8s  %s" % ["from", "to", "range", "clear", "first blocker"])
	print("-".repeat(78))
	var clear_count := 0
	for line in SIGHTLINES:
		var from := Vector3(line[1], EYE_Y, line[2])
		var to := Vector3(line[4], EYE_Y, line[5])
		var span := from.distance_to(to)
		var hit := _first_hit(from, (to - from).normalized())
		var clear: bool = hit["dist"] >= span - 0.05
		if clear:
			clear_count += 1
		print("%-18s -> %-18s %7.1fm %8s  %s" % [
			line[0], line[3], span, "YES" if clear else "no",
			"--" if clear else "%s at %.1fm" % [hit["name"], hit["dist"]],
		])
	print("clear: %d / %d" % [clear_count, SIGHTLINES.size()])

	print("")
	print("=== OPENNESS FAN (%d rays) ===" % FAN_RAYS)
	print("median dist = how far you see along the ground; horizon = how high")
	print("the tallest thing in each direction rises; open = share of the 360")
	print("where that stays under %.0f deg. Openness is the horizon columns." % OPEN_HORIZON_DEG)
	print("%-18s %10s %10s %12s %12s %8s" % [
		"viewpoint", "med dist", "max dist", "med horizon", "max horizon", "open",
	])
	print("-".repeat(76))
	for point in VIEWPOINTS:
		var origin := Vector3(point[1], EYE_Y, point[2])
		var distances: Array[float] = []
		var horizons: Array[float] = []
		var open_rays := 0
		for i in range(FAN_RAYS):
			var angle := TAU * float(i) / float(FAN_RAYS)
			var dir := Vector3(sin(angle), 0.0, cos(angle))
			distances.append(_first_hit(origin, dir)["dist"] as float)
			var horizon := _horizon_deg(origin, dir)
			horizons.append(horizon)
			if horizon < OPEN_HORIZON_DEG:
				open_rays += 1
		distances.sort()
		horizons.sort()
		print("%-18s %9.1fm %9.1fm %11.1fd %11.1fd %7d%%" % [
			point[0], distances[FAN_RAYS / 2], distances[FAN_RAYS - 1],
			horizons[FAN_RAYS / 2], horizons[FAN_RAYS - 1],
			round(100.0 * open_rays / FAN_RAYS),
		])


# -------------------------------------------------------- invisible walls --
# The third failure mode, and the one that most directly produces "all
# places are not reachable": collision with nothing rendered above it. The
# ground mesh is a single 42x40 m plane covering every room and the space
# between them, so a player standing at the lane mouth sees open ground
# running east and west and walks into a wall that isn't there. Such a cell
# is neither "reachable" nor "dead space" -- it reads as solid to the
# physics probe and as floor to the eye, so it appears in neither table
# above. It needs its own.


## Blocked cells inside the envelope with no rendered geometry standing on
## them. `_occluders` only holds meshes crossing EYE_Y, so this builds its
## own footprint list: anything at least KNEE_Y tall, which keeps the ground
## plane and the path strip out while catching low walls and plinths.
func _report_invisible_walls(root: Node, free: PackedByteArray, dist: PackedInt32Array, cell_area: float) -> void:
	const KNEE_Y := 0.5
	var footprints: Array[Rect2] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is GeometryInstance3D):
			continue
		var local: AABB = (node as GeometryInstance3D).get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var box: AABB = (node as GeometryInstance3D).global_transform * local
		if box.end.y < KNEE_Y:
			continue
		footprints.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))

	var invisible := PackedByteArray()
	invisible.resize(free.size())
	var total := 0
	for i in range(free.size()):
		if free[i] == 1:
			continue
		var p := _world_of(Vector2i(i % X_CELLS, i / X_CELLS))
		if not _in_envelope(p):
			continue
		var covered := false
		for rect in footprints:
			# grow() by the capsule radius: a cell is blocked when the
			# capsule touches a wall, which happens up to one radius short
			# of the wall's own face. Without this every real wall would
			# report a one-cell invisible fringe.
			if rect.grow(_params.shape.radius).has_point(p):
				covered = true
				break
		if not covered:
			invisible[i] = 1
			total += 1

	# Frontage is the number that actually corresponds to the felt defect.
	# The deep interior of an invisible slab is unreachable and unseeable and
	# therefore harmless; what the player experiences is the SURFACE of it --
	# every step of the walkable region's perimeter where they see floor
	# continue and are stopped by nothing. Measured in metres of edge, not
	# square metres of volume.
	var frontage := 0.0
	var frontage_at: Array[Vector2] = []
	for i in range(free.size()):
		# REACHABLE, not merely free. An earlier version tested free[i] and
		# so counted the perimeter of the unreachable pockets beside home
		# as well -- 23.5 m of "defect" along a boundary no player can ever
		# stand next to. Frontage only means anything measured from ground
		# the player can actually be standing on.
		if dist[i] < 0:
			continue
		var cell := Vector2i(i % X_CELLS, i / X_CELLS)
		if not _in_envelope(_world_of(cell)):
			continue
		for delta in NEIGHBORS:
			var next: Vector2i = cell + delta
			if next.x < 0 or next.x >= X_CELLS or next.y < 0 or next.y >= Z_CELLS:
				continue
			if invisible[_index(next)] == 1:
				frontage += STEP
				frontage_at.append(_world_of(next))

	print("")
	print("=== INVISIBLE WALLS (blocked, inside envelope, nothing rendered on them) ===")
	print("frontage walked into: %.1f m of walkable perimeter  <- the felt defect" % frontage)
	print("total volume:         %d cells (%.1f m^2)" % [total, total * cell_area])
	# The exact spots, not just the count -- a frontage number you can't
	# locate is a number you can't act on.
	if not frontage_at.is_empty():
		var listed := PackedStringArray()
		for p in frontage_at:
			listed.append("(%.1f, %.1f)" % [p.x, p.y])
		print("  at: %s" % ", ".join(listed))
	var seen := PackedByteArray()
	seen.resize(free.size())
	var components := 0
	for start_index in range(invisible.size()):
		if invisible[start_index] == 0 or seen[start_index] == 1:
			continue
		var queue: Array[Vector2i] = [Vector2i(start_index % X_CELLS, start_index / X_CELLS)]
		seen[start_index] = 1
		var head := 0
		var count := 0
		var min_p := Vector2(INF, INF)
		var max_p := Vector2(-INF, -INF)
		while head < queue.size():
			var cell: Vector2i = queue[head]
			head += 1
			count += 1
			var p := _world_of(cell)
			min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
			max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
			for delta in NEIGHBORS:
				var next: Vector2i = cell + delta
				if next.x < 0 or next.x >= X_CELLS or next.y < 0 or next.y >= Z_CELLS:
					continue
				var next_index := _index(next)
				if invisible[next_index] == 0 or seen[next_index] == 1:
					continue
				seen[next_index] = 1
				queue.append(next)
		if count < 4:
			continue
		components += 1
		print("  #%d  %6.1f m^2   x[%.1f, %.1f]  z[%.1f, %.1f]" % [
			components, count * cell_area, min_p.x, max_p.x, min_p.y, max_p.y,
		])
	if components == 0:
		print("  (none)")


# ------------------------------------------------- dead space, seen or not --
# "No dead space the player can SEE but never stand in" is a conditional, and
# the condition is the whole question. The three unreachable pockets this
# world has all sit outside a room's own wall, which is either fine (nobody
# can see them, they are just the gap between the rooms' shapes and the
# bounding box) or the exact defect the brief names -- and reasoning about
# wall heights from a chair cannot tell the two apart. This measures it.


## For each unreachable pocket, whether any of it can be seen from anywhere
## the player can actually stand. Rays go from a standing eye to near ground
## level over the dead cell, because the thing that would look wrong is
## seeing FLOOR you cannot walk on, not seeing the air above it.
## `view_y` is the height the WORLD IS SEEN FROM, and it is deliberately run
## twice by the caller: once at the child's own eye height and once at
## REVEAL's authored camera height (camera_profile.gd), which is more than
## twice as high. The player does not look through the child's eyes -- they
## look through a camera that rises to 2.6 m -- so testing only at eye
## height would understate what is visible and could clear dead space that
## the actual game shows.
func _report_dead_space_visibility(free: PackedByteArray, dist: PackedInt32Array, cell_area: float, view_y: float, label: String) -> void:
	const VIEWER_STRIDE := 4  # sample standing positions every 2 m
	const TARGET_STRIDE := 2  # and dead ground every 1 m
	const TARGET_Y := 0.3

	var viewers: Array[Vector2] = []
	for zi in range(0, Z_CELLS, VIEWER_STRIDE):
		for xi in range(0, X_CELLS, VIEWER_STRIDE):
			if dist[zi * X_CELLS + xi] >= 0:
				viewers.append(_world_of(Vector2i(xi, zi)))

	print("")
	print("=== DEAD SPACE: VISIBLE FROM ANYWHERE THE PLAYER CAN STAND? (%s, y=%.2f) ===" % [label, view_y])
	print("%d standing positions sampled (every %.1f m), dead ground every %.1f m" % [
		viewers.size(), VIEWER_STRIDE * STEP, TARGET_STRIDE * STEP,
	])

	var seen := PackedByteArray()
	seen.resize(free.size())
	var components := 0
	for start_index in range(free.size()):
		if seen[start_index] == 1 or free[start_index] == 0 or dist[start_index] >= 0:
			continue
		var start := Vector2i(start_index % X_CELLS, start_index / X_CELLS)
		if not _in_envelope(_world_of(start)):
			continue
		var cells: Array[Vector2i] = [start]
		seen[start_index] = 1
		var head := 0
		while head < cells.size():
			var cell: Vector2i = cells[head]
			head += 1
			for delta in NEIGHBORS:
				var next: Vector2i = cell + delta
				if next.x < 0 or next.x >= X_CELLS or next.y < 0 or next.y >= Z_CELLS:
					continue
				var next_index := _index(next)
				if seen[next_index] == 1 or free[next_index] == 0 or dist[next_index] >= 0:
					continue
				if not _in_envelope(_world_of(next)):
					continue
				seen[next_index] = 1
				cells.append(next)
		if cells.size() < 4:
			continue
		components += 1

		var exposed := 0
		var tested := 0
		var witness := ""
		for cell in cells:
			if cell.x % TARGET_STRIDE != 0 or cell.y % TARGET_STRIDE != 0:
				continue
			tested += 1
			var target_2d := _world_of(cell)
			var target := Vector3(target_2d.x, TARGET_Y, target_2d.y)
			for viewer_2d in viewers:
				var origin := Vector3(viewer_2d.x, view_y, viewer_2d.y)
				var to_target := target - origin
				var span := to_target.length()
				if span < 0.01:
					continue
				if _first_hit(origin, to_target / span)["dist"] >= span - 0.05:
					exposed += 1
					if witness == "":
						witness = "ground (%.1f, %.1f) seen from (%.1f, %.1f)" % [
							target_2d.x, target_2d.y, viewer_2d.x, viewer_2d.y,
						]
					break
		var verdict := "NOT VISIBLE" if exposed == 0 else "VISIBLE"
		print("  #%d  %6.1f m^2  %-12s %d of %d sampled cells%s" % [
			components, cells.size() * cell_area, verdict, exposed, tested,
			"" if witness == "" else "  -- e.g. " + witness,
		])
	if components == 0:
		print("  (no dead space)")


# ------------------------------------------ things you would walk head-first into --
# The mirror image of the invisible-wall check: not collision with nothing
# rendered on it, but something rendered where the player can stand. The
# world is full of decoration with no collider of its own -- creepers,
# bushes, treeline masses, the arch's own shoulders -- and none of it is
# constrained by anything except whoever typed its coordinates. A foliage
# sphere reaching 0.2 m through a wall costs nothing at runtime and looks
# like a bug; an arch shoulder standing in its own opening is one.


## Rendered geometry hanging at head height over ground the player can stand
## on. The band matters: only boxes whose BOTTOM sits between HEAD_MIN and
## HEAD_MAX count.
##
## Below HEAD_MIN and an axis-aligned box is a poor description of the thing
## anyway -- a tree's AABB is its whole canopy and starts at the ground, a
## tilted slide plank's AABB is several times the plank -- so ground-level
## objects would report constantly and mean nothing. Above HEAD_MAX the
## player walks underneath, which is what the home lintel and the garden
## arch's raised span are FOR, and flagging those would punish the fix this
## pass just made.
##
## What is left is exactly the defect class worth catching: something at
## the height of a child's head, standing where a child can stand.
func _report_geometry_in_walkable_space(dist: PackedInt32Array) -> void:
	const HEAD_MIN := 0.9
	const HEAD_MAX := 1.6
	var offenders := {}
	var hits := 0
	for i in range(dist.size()):
		if dist[i] < 0:
			continue
		var p := _world_of(Vector2i(i % X_CELLS, i / X_CELLS))
		for box_data in _occluders:
			var box: AABB = box_data["box"]
			if box.position.y < HEAD_MIN or box.position.y > HEAD_MAX:
				continue
			if p.x < box.position.x or p.x > box.end.x:
				continue
			if p.y < box.position.z or p.y > box.end.z:
				continue
			hits += 1
			var key: String = box_data["name"]
			if not offenders.has(key):
				offenders[key] = "at (%.1f, %.1f), box x[%.1f,%.1f] y[%.1f,%.1f] z[%.1f,%.1f]" % [
					p.x, p.y, box.position.x, box.end.x, box.position.y, box.end.y,
					box.position.z, box.end.z,
				]
	print("")
	print("=== THINGS YOU WOULD WALK HEAD-FIRST INTO (y %.1f-%.1f m) ===" % [HEAD_MIN, HEAD_MAX])
	if offenders.is_empty():
		print("  (none) -- nothing hangs at head height over ground the player can stand on")
		return
	print("  %d reachable cells sit under head-height geometry, across %d objects:" % [
		hits, offenders.size(),
	])
	for name in offenders:
		print("    %-22s %s" % [name, offenders[name]])
