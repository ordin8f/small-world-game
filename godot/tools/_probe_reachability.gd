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

var _space: PhysicsDirectSpaceState3D
var _params: PhysicsShapeQueryParameters3D
var _capsule_y := 0.54
var _occluders: Array = []


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
		if box.position.y > EYE_Y or box.end.y < EYE_Y:
			continue
		_occluders.append({"name": str(node.name), "box": box})
	print("")
	print("occluders spanning eye height (y=%.2f): %d" % [EYE_Y, _occluders.size()])


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
	print("=== OPENNESS FAN (%d rays, capped at %.0f m) ===" % [FAN_RAYS, SIGHT_MAX])
	print("%-18s %10s %10s %10s %10s" % ["viewpoint", "median", "mean", "max", ">15m rays"])
	print("-".repeat(64))
	for point in VIEWPOINTS:
		var origin := Vector3(point[1], EYE_Y, point[2])
		var distances: Array[float] = []
		var long_rays := 0
		for i in range(FAN_RAYS):
			var angle := TAU * float(i) / float(FAN_RAYS)
			var d := _first_hit(origin, Vector3(sin(angle), 0.0, cos(angle)))["dist"] as float
			distances.append(d)
			if d > 15.0:
				long_rays += 1
		distances.sort()
		var total := 0.0
		for d in distances:
			total += d
		print("%-18s %9.1fm %9.1fm %9.1fm %10d" % [
			point[0], distances[FAN_RAYS / 2], total / FAN_RAYS, distances[FAN_RAYS - 1], long_rays,
		])
