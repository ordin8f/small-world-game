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
## Widened with the park (2026-08-30): the ground plane is now 50 x 44 m
## centred on (0,-4), and a grid that stopped at the old plane's edge would
## have measured the new park through a window cut to the old world's size.
const X_MIN := -25.0
const Z_MIN := -26.0
const X_CELLS := 101  # -25.0 .. 25.0
const Z_CELLS := 89  # -26.0 .. 18.0

## WorldBounds.can_move_to()'s loose outer envelope. Used only to classify
## the report (inside = the world's own bounding box, outside = backdrop
## space), never to decide walkability.
const ENV_X_MIN := -23.7
const ENV_X_MAX := 22.7
const ENV_Z_MIN := -24.7
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
	["Bench", -7.0, -9.8, 0.9],
	["BushFeature", -11.0, -13.4, 0.9],
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
	# The park's new corners (2026-08-30). Listed as targets, not just left
	# to the area total, because "the left and right hand areas are not
	# reachable" is the complaint this pass exists to answer, and an area
	# total can grow while a corner stays walled off.
	["ParkWestEdge", -21.0, -12.0, 0.75],
	["ParkNWCorner", -21.0, -5.0, 0.75],
	["ParkSWCorner", -21.0, -22.0, 0.75],
	["ParkSouthMid", 0.0, -22.0, 0.75],
	["ParkSECorner", 20.0, -22.0, 0.75],
	["ParkEastLawn", 17.0, -19.0, 0.75],
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
	# The park's long views (2026-08-30). "Enclosure only works if there is
	# somewhere it opens" -- these are the two places it is supposed to,
	# and they only mean anything if they are checked.
	# Aimed 0.4 m SHORT of the arcade's face: a blind niche's own surface is
	# the wall, so a line ending exactly on it reports as blocked by the
	# thing it is looking at.
	["Gate", 0.0, -5.0, "ArcadeCentreNiche", -0.5, -23.0],
	["ParkWestEdge", -20.0, -12.0, "GardenGapArch", 11.0, -8.0],
	["ParkNWCorner", -20.0, -6.0, "ParkSECorner", 19.0, -20.0],
	["ParkSECorner", 19.0, -20.0, "GardenPocket", 16.0, -10.0],
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
	# The park itself (2026-08-30). Every viewpoint above predates the park
	# pass and sits on the world's old north-south spine, so none of them
	# stands anywhere in the 45 x 20 m room the developer called
	# claustrophobic.
	["ParkWestLawn", -16.0, -12.0],
	["ParkSouthWalk", -2.0, -21.0],
	["ParkSECorner", 18.0, -20.0],
	["Gate", 0.0, -5.0],
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
var _all_boxes: Array = []


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
	_report_canopy_over_ground(dist, STEP * STEP)
	_report_open_ground_you_cannot_have(dist, STEP * STEP)
	_report_invisible_walls(courtyard, free, dist, STEP * STEP)
	_report_dead_space_visibility(free, dist, STEP * STEP, EYE_Y, "child eye")
	_report_dead_space_visibility(free, dist, STEP * STEP, CAMERA_Y, "REVEAL camera")
	_report_geometry_in_walkable_space(dist)
	_report_frame_occupancy()
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
		_all_boxes.append({
			"name": str(node.name), "box": box, "surface": _surface_of(node),
		})
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


## The name of the surface texture a mesh is dressed in ("grass", "paving",
## "bark"...), read off its own material -- _bootstrap_courtyard.gd's
## SURFACES registry keys are the texture filenames, so the filename IS the
## surface name. "flat" means an untextured albedo colour. Used by the
## ground census: "how many different surfaces does this park have" is a
## question about materials, and asking it of the material is the only way
## to get an answer that a renamed node cannot fake.
func _surface_of(node: Node) -> String:
	var mat: Material = null
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mat = mi.get_surface_override_material(0)
		if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0)
	if not (mat is BaseMaterial3D):
		return "flat"
	var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture
	if tex == null or tex.resource_path == "":
		return "flat"
	return tex.resource_path.get_file().get_basename()


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
	print("%-18s -> %-18s %8s %8s %8s  %s" % [
		"from", "to", "range", "clear", "see-thru", "first blocker",
	])
	print("-".repeat(84))
	var clear_count := 0
	var low_clear_count := 0
	for line in SIGHTLINES:
		var from := Vector3(line[1], EYE_Y, line[2])
		var to := Vector3(line[4], EYE_Y, line[5])
		var span := from.distance_to(to)
		var dir := (to - from).normalized()
		var hit := _first_hit(from, dir)
		var clear: bool = hit["dist"] >= span - 0.05
		if clear:
			clear_count += 1
		# Second verdict against WALL-SCALE geometry only. A Kenney tree is
		# one mesh, so its AABB runs ground-to-crown at full crown width and
		# blocks every line that passes anywhere near it -- but a crown at
		# 3-11 m does not stop a 1.2 m child seeing the next place, only the
		# trunk does. Without this column, planting canopy reads here as
		# closing the world down. See _report_enclosure_and_cover().
		var through := _see_through(from, to)
		if through["share"] >= 0.5:
			low_clear_count += 1
		var blocker: String = hit["name"] if not clear else ""
		if through["share"] < 1.0 and through["name"] != "":
			blocker = "%s / low: %s" % [blocker if blocker != "" else "--", through["name"]]
		print("%-18s -> %-18s %7.1fm %8s %7.0f%%  %s" % [
			line[0], line[3], span, "YES" if clear else "no",
			100.0 * float(through["share"]),
			"--" if blocker == "" else blocker,
		])
	print("clear: %d / %d   >=50%% see-through at wall scale: %d / %d" % [
		clear_count, SIGHTLINES.size(), low_clear_count, SIGHTLINES.size(),
	])

	print("")
	print("=== OPENNESS FAN (%d rays) ===" % FAN_RAYS)
	print("median dist = how far you see along the ground; horizon = how high")
	print("the tallest thing in each direction rises; open = share of the 360")
	print("where that stays under %.0f deg. Openness is the horizon columns." % OPEN_HORIZON_DEG)
	print("READ THE 'low' COLUMNS FOR ENCLOSURE, not these -- see the")
	print("LOW_MAX doc comment. These two count a tree canopy as a wall.")
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

	_report_enclosure_and_cover()


# ------------------------------------------- enclosure vs. cover --
# The fan above cannot answer the question the developer actually asked
# ("the park seems a bit claustrophobic"), and would answer it backwards.
#
# It classifies an occluder by whether its AABB spans eye height. A Kenney
# tree imports as ONE mesh, so its box runs from the ground to the top of
# the crown and is as wide as the crown -- a 10 m tree with a bare trunk
# and its foliage starting at 3 m scores identically to a 10 m solid slab
# of the same footprint. Planting canopy trees, which is the single
# strongest thing you can do to make a space feel bigger, would therefore
# show up in that table as a large REGRESSION in both columns. A metric
# that punishes the fix is worse than no metric.
#
# So this splits occluders by height and reports the two halves apart:
#
#   LOW  (top below LOW_MAX) -- walls, hedges, railings, kerbs, benches,
#        the things that stop your eye at your own scale. THIS is
#        enclosure, and this is the number to drive down.
#   TALL (top above LOW_MAX) -- tree crowns, the lane's monumental walls,
#        rooflines. These are cover and landmark. Reported as a share of
#        the 360, and MORE of it is generally better: a park with nothing
#        above head height is a field.
#
# The split is a height band, not a name check, so it cannot drift when
# something is renamed -- but be honest about what it costs: the arcade
# wall (4.6 m) lands in TALL even though it does enclose the park's south
# side, and a very low tree would land in LOW. Both are the right call at
# the sizes this world actually uses; neither is free of judgement.

## Above this, a thing reads as something you are under or look past
## rather than something hemming you in. 3.4 m clears every wall in the
## park (the tallest boundary is the garden pocket's 2.4 m) and sits below
## the crown of any tree planted as canopy.
const LOW_MAX := 3.4
## Ground cells count as "under canopy" when something rendered sits at
## least this far above them -- high enough to walk under without ducking,
## low enough that a tree crown at 3-8 m counts and a distant roofline
## across the world does not (footprint containment, so nothing counts
## unless it is literally overhead).
const CANOPY_MIN_Y := 2.4
## A crown counts as cover when it is this close and rises this far above
## the eye -- 12 m and 30 degrees is roughly "the edge of its shade falls
## within a few strides of you", which is what walking under a tree means.
const COVER_RANGE := 12.0
const COVER_DEG := 30.0


## What share of a small bundle of rays from `from` to `to` gets past
## WALL-SCALE geometry, and the name of the first thing that stops any of
## them.
##
## A bundle and not one ray, because the thing this pass added is
## PERMEABLE boundaries, and a single ray cannot tell a railing from a
## wall: the posts are 0.05 m wide at 0.42 m centres, so whether one ray
## clears them is decided by where the two endpoints happen to sit. Five
## rays spread across a metre of lateral offset answers the question a
## player is actually asking -- can I see the garden from here -- and a
## railing scores ~80% where a wall scores 0%.
##
## Deliberately NOT applied to the raw `clear` column beside it, which
## stays exactly the single ray it has always been.
func _see_through(from: Vector3, to: Vector3) -> Dictionary:
	const RAYS := 5
	const SPREAD := 0.5  # metres either side
	var span := from.distance_to(to)
	var dir := (to - from).normalized()
	var lat := dir.cross(Vector3.UP).normalized()
	var through := 0
	var name := ""
	for i in range(RAYS):
		var offset: float = SPREAD * (2.0 * i / float(RAYS - 1) - 1.0)
		var a := from + lat * offset
		var b := to + lat * offset
		var d := (b - a).normalized()
		var best := SIGHT_MAX
		var who := ""
		for entry in _low_boxes():
			var box: AABB = entry["box"]
			if box.has_point(a):
				continue
			if box.position.y > EYE_Y or box.end.y < EYE_Y:
				continue
			var t := _ray_box(a, d, box)
			if t >= 0.0 and t < best:
				best = t
				who = entry["name"]
		if best >= span - 0.05:
			through += 1
		elif name == "":
			name = "%s at %.1fm" % [who, best]
	return {"share": float(through) / RAYS, "name": name}


## Wall-scale boxes: everything that stops the eye at the player's own
## height. Cached because both the sightline table and the enclosure fan
## want it. See _report_enclosure_and_cover()'s doc comment for the split.
var _low_cache: Array = []

func _low_boxes() -> Array:
	if not _low_cache.is_empty():
		return _low_cache
	for entry in _all_boxes:
		var box: AABB = entry["box"]
		if box.end.y > EYE_Y and box.end.y <= LOW_MAX:
			_low_cache.append(entry)
	return _low_cache


func _report_enclosure_and_cover() -> void:
	var low: Array = _low_boxes()
	var unused: Array = []
	var tall: Array = []
	for entry in _all_boxes:
		var box: AABB = entry["box"]
		if box.end.y > LOW_MAX:
			tall.append(entry)

	print("")
	print("=== ENCLOSURE (things under %.1f m) vs COVER (things above it) ===" % LOW_MAX)
	print("low dist/horizon = how close and how high the WALL-SCALE stuff is;")
	print("this is the claustrophobia number and lower/further is better.")
	print("cover = share of the 360 with a crown or roof within %.0f m rising" % COVER_RANGE)
	print("past %.0f deg -- i.e. actually over you. More is better." % COVER_DEG)
	print("%-18s %10s %12s %9s %8s" % [
		"viewpoint", "low med dist", "low med horiz", "low open", "cover",
	])
	print("-".repeat(64))
	for point in VIEWPOINTS:
		var origin := Vector3(point[1], EYE_Y, point[2])
		var distances: Array[float] = []
		var horizons: Array[float] = []
		var open_rays := 0
		var cover_rays := 0
		for i in range(FAN_RAYS):
			var angle := TAU * float(i) / float(FAN_RAYS)
			var dir := Vector3(sin(angle), 0.0, cos(angle))
			distances.append(_nearest_in(origin, dir, low))
			var horizon := _horizon_in(origin, dir, low)
			horizons.append(horizon)
			if horizon < OPEN_HORIZON_DEG:
				open_rays += 1
			# Overhead, not merely present: a treeline on the far boundary
			# is tall and in that direction and does nothing for the
			# feeling of being under something. Near AND high.
			if _horizon_in(origin, dir, tall, COVER_RANGE) >= COVER_DEG:
				cover_rays += 1
		distances.sort()
		horizons.sort()
		print("%-18s %9.1fm %11.1fd %8d%% %7d%%" % [
			point[0], distances[FAN_RAYS / 2], horizons[FAN_RAYS / 2],
			round(100.0 * open_rays / FAN_RAYS), round(100.0 * cover_rays / FAN_RAYS),
		])


## First hit along `dir` among `boxes` only. Same slab test and the same
## "you are not blocked by what you stand inside" rule as _first_hit().
func _nearest_in(origin: Vector3, dir: Vector3, boxes: Array) -> float:
	var best := SIGHT_MAX
	for entry in boxes:
		var box: AABB = entry["box"]
		if box.has_point(origin):
			continue
		if box.position.y > EYE_Y or box.end.y < EYE_Y:
			continue  # not in the way AT eye height, whatever else it does
		var t := _ray_box(origin, dir, box)
		if t >= 0.0 and t < best:
			best = t
	return best


## Highest angle above the horizontal reached by anything in `boxes` along
## `dir` -- _horizon_deg()'s maths against a chosen subset, optionally
## capped to things nearer than `range_m`.
func _horizon_in(origin: Vector3, dir: Vector3, boxes: Array, range_m: float = SIGHT_MAX) -> float:
	var highest := 0.0
	for entry in boxes:
		var box: AABB = entry["box"]
		if box.has_point(origin):
			continue
		var t := _ray_box(origin, dir, box)
		if t < 0.0 or t > range_m:
			continue
		var angle := rad_to_deg(atan2(box.end.y - EYE_Y, maxf(t, 0.01)))
		if angle > highest:
			highest = angle
	return highest


## How much of the park has something over it. Unambiguous where the fan is
## not: footprint containment against reachable ground, so a wall cannot
## score (its own footprint is not walkable) and a distant treeline cannot
## score (it is not overhead). 0% means every square metre of this world is
## open sky, which is what a car park looks like.
func _report_canopy_over_ground(dist: PackedInt32Array, cell_area: float) -> void:
	var covered := PackedByteArray()
	covered.resize(dist.size())
	for entry in _all_boxes:
		var box: AABB = entry["box"]
		# TOP above the bar, not bottom. An earlier version of this line
		# required box.position.y >= CANOPY_MIN_Y -- "the thing starts
		# above head height" -- which sounds right and is unsatisfiable:
		# every vendored tree imports as a single mesh whose AABB runs from
		# the ground to the top of the crown, so no tree in this world has
		# ever had a bottom above 2.4 m. It read 1% before eight canopy
		# trees were planted and 1% after.
		#
		# Using the top instead does not let walls in, because the filter
		# that matters is below: a cell only counts if the PLAYER CAN STAND
		# in it, and no wall's own footprint is walkable. What is left is
		# exactly what was wanted -- crowns, arches and lintels over ground
		# you can walk on.
		if box.end.y < CANOPY_MIN_Y:
			continue
		var x0 := maxi(0, int(ceil((box.position.x - X_MIN) / STEP)))
		var x1 := mini(X_CELLS - 1, int(floor((box.end.x - X_MIN) / STEP)))
		var z0 := maxi(0, int(ceil((box.position.z - Z_MIN) / STEP)))
		var z1 := mini(Z_CELLS - 1, int(floor((box.end.z - Z_MIN) / STEP)))
		for zi in range(z0, z1 + 1):
			for xi in range(x0, x1 + 1):
				covered[zi * X_CELLS + xi] = 1

	var reachable := 0
	var under := 0
	for i in range(dist.size()):
		if dist[i] < 0:
			continue
		reachable += 1
		if covered[i] == 1:
			under += 1
	print("")
	print("=== CANOPY OVER GROUND YOU CAN WALK ON (anything above %.1f m) ===" % CANOPY_MIN_Y)
	print("%.1f m^2 of %.1f m^2 is under something: %.0f%%" % [
		under * cell_area, reachable * cell_area,
		100.0 * under / maxi(reachable, 1),
	])


# ------------------------------------ open ground you cannot have --
# Every other measure in this file classifies cells INSIDE
# WorldBounds.can_move_to()'s envelope, so the envelope's own edge is
# treated as legitimate boundary by construction. That is why they can all
# come back clean while the developer, standing in the world, says the left
# and right of the park are not reachable: they are answering "is the
# authored shape internally consistent", and the complaint is about the
# authored shape itself.
#
# This measure deliberately ignores the envelope. It asks the player's
# question instead: standing where I can stand, how much ground can I SEE
# that looks like ground I could walk on, and cannot? Ground the player can
# see is every cell of the rendered ground plane, envelope or not.
#
# Two columns, because they are two different defects with two different
# fixes:
#   SCREENED -- there is something rendered and at least MARKER_Y tall
#               between the viewer and that ground. You are looking over a
#               wall, a hedge, a railing, into somewhere that is plainly
#               not this park. Some of this is wanted; a bounded world with
#               nothing visible past its edge reads as a diorama.
#   OPEN     -- nothing at all stands between the viewer and it. This is
#               the felt defect verbatim: floor that continues, reads as
#               walkable, and stops you with nothing. Drive this to zero
#               either by letting the player walk there or by putting a
#               boundary they can see on the line where they are stopped.
#
# Note what this does NOT do: it never consults the collider envelope, so
# it cannot be satisfied by redefining where the world is supposed to end.
# The only two things that move it are geometry the player can see and
# ground the player can reach.

## How tall something has to stand to read as a boundary rather than as
## texture on the floor. Roughly knee height on this world's 1.08 m child:
## below it you step over, above it you walk around, and either way you can
## see it is there.
const MARKER_Y := 0.5
## Ray target height over the far ground -- low, because the thing that
## looks wrong is seeing FLOOR you cannot have, not the air above it.
const GROUND_TARGET_Y := 0.3
## Anything whose top is below this cannot be ground you stand on (it is a
## kerb, a paving slab, a stepping stone). Anything above it is a thing.
const GROUND_TOP_MAX := 0.4


func _report_open_ground_you_cannot_have(dist: PackedInt32Array, cell_area: float) -> void:
	const VIEWER_STRIDE := 4  # standing positions every 2 m
	const TARGET_STRIDE := 1  # every ground cell, 0.5 m

	# Per-cell ground height and per-cell "something is standing here",
	# both read straight off the rendered meshes -- no name or type
	# heuristics, same discipline as _collect_occluders().
	var ground_top := PackedFloat32Array()
	ground_top.resize(dist.size())
	ground_top.fill(-INF)
	var ground_surface := PackedStringArray()
	ground_surface.resize(dist.size())
	ground_surface.fill("")
	var marker := PackedByteArray()
	marker.resize(dist.size())
	# The same cells, but with each boundary's footprint grown by the
	# player's own radius -- the band along a wall where the capsule cannot
	# fit even though the wall's face is still half a metre away. Those
	# cells are unreachable and have nothing standing on them, so without
	# this they read as the defect; they are quantisation. Exactly the
	# correction _report_invisible_walls() already makes for the same
	# reason, applied to the same kind of test.
	var fringe := PackedByteArray()
	fringe.resize(dist.size())
	var radius: float = (_params.shape as CapsuleShape3D).radius
	for entry in _all_boxes:
		var box: AABB = entry["box"]
		var is_ground: bool = box.end.y <= GROUND_TOP_MAX
		var is_marker: bool = box.end.y >= MARKER_Y and box.position.y <= MARKER_Y
		if not is_ground and not is_marker:
			continue
		var pad: float = 0.0 if is_ground else radius
		var x0 := maxi(0, int(ceil((box.position.x - pad - X_MIN) / STEP)))
		var x1 := mini(X_CELLS - 1, int(floor((box.end.x + pad - X_MIN) / STEP)))
		var z0 := maxi(0, int(ceil((box.position.z - pad - Z_MIN) / STEP)))
		var z1 := mini(Z_CELLS - 1, int(floor((box.end.z + pad - Z_MIN) / STEP)))
		if x1 < x0 or z1 < z0:
			continue
		for zi in range(z0, z1 + 1):
			for xi in range(x0, x1 + 1):
				var i := zi * X_CELLS + xi
				var p := _world_of(Vector2i(xi, zi))
				if is_ground:
					if box.end.y > ground_top[i]:
						ground_top[i] = box.end.y
						ground_surface[i] = str(entry["surface"])
					continue
				fringe[i] = 1
				if p.x >= box.position.x and p.x <= box.end.x \
						and p.y >= box.position.z and p.y <= box.end.z:
					marker[i] = 1

	var viewers: Array[Vector2i] = []
	for zi in range(0, Z_CELLS, VIEWER_STRIDE):
		for xi in range(0, X_CELLS, VIEWER_STRIDE):
			if dist[zi * X_CELLS + xi] >= 0:
				viewers.append(Vector2i(xi, zi))

	var blockers: Array[AABB] = []
	for entry in _all_boxes:
		var b: AABB = entry["box"]
		if b.end.y > GROUND_TARGET_Y + 0.05:
			blockers.append(b)

	var open_cells := PackedByteArray()
	open_cells.resize(dist.size())
	var open_total := 0
	var screened_total := 0
	var reachable_total := 0
	var ground_total := 0
	var worst := ""
	var worst_span := 0.0
	var walked_surfaces := {}

	for i in range(dist.size()):
		if ground_top[i] == -INF:
			continue  # nothing rendered to stand on: not ground, not a defect
		ground_total += 1
		if dist[i] >= 0:
			reachable_total += 1
			var key: String = ground_surface[i]
			walked_surfaces[key] = walked_surfaces.get(key, 0) + 1
			continue
		if fringe[i] == 1:
			continue  # something visibly stands here, or the capsule merely
			          # cannot squeeze against it -- see `fringe` above
		var cell := Vector2i(i % X_CELLS, i / X_CELLS)
		var p := _world_of(cell)
		var target := Vector3(p.x, ground_top[i] + GROUND_TARGET_Y, p.y)
		if cell.x % TARGET_STRIDE != 0 or cell.y % TARGET_STRIDE != 0:
			continue
		var seen_open := false
		var seen_screened := false
		for viewer_cell in viewers:
			var v := _world_of(viewer_cell)
			var origin := Vector3(v.x, CAMERA_Y, v.y)
			var to_target := target - origin
			var span := to_target.length()
			if span < 0.01:
				continue
			if _blocked(origin, to_target / span, span, blockers):
				continue
			# Visible. Now: was there anything to SEE on the way, at any
			# height? Walked on the grid rather than raycast, because a
			# railing you look straight over still marks the edge.
			if _crosses_marker(marker, viewer_cell, cell):
				seen_screened = true
				continue
			seen_open = true
			if span > worst_span:
				worst_span = span
				worst = "ground (%.1f, %.1f) seen from (%.1f, %.1f), %.1f m away" % [
					p.x, p.y, v.x, v.y, span,
				]
			break
		if seen_open:
			open_cells[i] = 1
			open_total += 1
		elif seen_screened:
			screened_total += 1

	print("")
	print("=== OPEN GROUND YOU CANNOT HAVE (whole ground plane, envelope ignored) ===")
	print("%d standing positions sampled every %.1f m, at REVEAL camera height y=%.2f" % [
		viewers.size(), VIEWER_STRIDE * STEP, CAMERA_Y,
	])
	print("rendered ground:        %8.1f m^2" % (ground_total * cell_area))
	print("  reachable:            %8.1f m^2  (%.0f%% of it)" % [
		reachable_total * cell_area, 100.0 * reachable_total / maxi(ground_total, 1),
	])
	print("  OPEN and unreachable: %8.1f m^2  <- floor you see, read as walkable, walk into nothing" % (open_total * cell_area))
	print("  screened, unreachable:%8.1f m^2  (a boundary stands between you and it)" % (screened_total * cell_area))
	if worst != "":
		print("  furthest: %s" % worst)
	_print_components(open_cells, cell_area, "OPEN unreachable ground")

	# The other half of "does this read as a park". A park is legible
	# because its surfaces are: mown grass, a bound path, bark under the
	# equipment, a planted bed. One surface everywhere is a floor, not a
	# place -- and no ray test can see that, because a uniform plane and a
	# laid-out park have identical geometry. Read off the ground meshes'
	# own materials, so it cannot be satisfied by renaming a node.
	print("")
	print("=== WHAT THE PLAYER WALKS ON (surfaces under reachable ground) ===")
	var ranked: Array = []
	for key in walked_surfaces:
		ranked.append([key, walked_surfaces[key]])
	ranked.sort_custom(func(a, b): return a[1] > b[1])
	for row in ranked:
		print("  %-18s %8.1f m^2  %5.1f%%" % [
			"(untextured)" if row[0] == "flat" else row[0],
			row[1] * cell_area, 100.0 * float(row[1]) / maxi(reachable_total, 1),
		])
	print("  %d distinct surface(s) underfoot" % ranked.size())


## True when anything in `boxes` sits across the segment origin -> origin +
## dir * span. Boxes containing the origin are skipped for the same reason
## _first_hit() skips them: you are not blocked by what you stand inside.
func _blocked(origin: Vector3, dir: Vector3, span: float, boxes: Array[AABB]) -> bool:
	for box in boxes:
		if box.has_point(origin):
			continue
		var t := _ray_box(origin, dir, box)
		if t >= 0.0 and t < span - 0.05:
			return true
	return false


## Whether the straight ground-plane line from `from` to `to` passes over
## any cell with something MARKER_Y tall standing on it. Deliberately a 2-D
## walk and not a ray: a 0.9 m railing between you and the field beyond is
## a boundary you can see even though your eye passes clean over it, and a
## height-aware test would score it as no boundary at all.
func _crosses_marker(marker: PackedByteArray, from: Vector2i, to: Vector2i) -> bool:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		return false
	for s in range(1, steps):
		var xi := from.x + int(round(float(delta.x) * s / steps))
		var zi := from.y + int(round(float(delta.y) * s / steps))
		if marker[zi * X_CELLS + xi] == 1:
			return true
	return false


## Connected components of a cell mask, largest first -- a number you
## cannot locate is a number you cannot act on.
func _print_components(mask: PackedByteArray, cell_area: float, label: String) -> void:
	var seen := PackedByteArray()
	seen.resize(mask.size())
	var found: Array = []
	for start_index in range(mask.size()):
		if mask[start_index] == 0 or seen[start_index] == 1:
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
			for d in NEIGHBORS:
				var next: Vector2i = cell + d
				if next.x < 0 or next.x >= X_CELLS or next.y < 0 or next.y >= Z_CELLS:
					continue
				var next_index := _index(next)
				if mask[next_index] == 0 or seen[next_index] == 1:
					continue
				seen[next_index] = 1
				queue.append(next)
		if count < 4:
			continue
		found.append([count, min_p, max_p])
	found.sort_custom(func(a, b): return a[0] > b[0])
	if found.is_empty():
		print("  (no %s)" % label)
		return
	for i in range(mini(6, found.size())):
		print("  #%d  %6.1f m^2   x[%.1f, %.1f]  z[%.1f, %.1f]" % [
			i + 1, found[i][0] * cell_area, found[i][1].x, found[i][2].x,
			found[i][1].y, found[i][2].y,
		])
	if found.size() > 6:
		print("  ... and %d more" % (found.size() - 6))


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


# ------------------------------------------------- what fills the frame --
# A sightline test asks "does a ray from A reach B". It says nothing about
# how much of the SCREEN the thing beside the ray takes up, so a beat can
# score as perfectly clear while 40% of the picture is one flat wall face
# at two metres. That is not a hypothetical: it is what the gap beat did,
# through two rounds of this pass, while every ray-based number here said
# it was fine. This is the metric that catches it.
#
# Camera and player positions below are RECORDED, not simulated -- they are
# what scripts/screenshot_route.gd itself printed on its last run, because
# where the camera actually ends up depends on SpringArm3D collision that
# this headless probe does not reproduce. Refresh them with:
#   godot --path godot --script res://scripts/screenshot_route.gd
# and paste the camera=/player= pairs it prints. A stale row here measures
# a frame nobody is shooting, so the numbers are only as current as this
# list.

## name, camera x/y/z, player x/z, vertical fov (camera_profile.gd's own
## value for that beat's z, after the THRESHOLD/APPROACH/REVEAL blend).
const FRAMES := [
	["01_threshold", 0.30, 1.28, 15.90, 0.00, 10.00, 50.0],
	["02_watch", -0.42, 2.56, 2.83, -0.19, -7.55, 58.0],
	["03_gap", 10.40, 1.79, -4.03, 10.46, -7.97, 58.0],
	["04_ball", 13.63, 2.17, -4.37, 13.81, -11.54, 58.0],
	["05_circle", 0.16, 2.60, 0.39, 0.45, -10.11, 58.0],
	["06_door", 0.25, 1.20, 15.90, 0.16, 12.56, 50.0],
]

const FRAME_COLS := 64
const FRAME_ROWS := 36
const ASPECT := 1280.0 / 720.0
## Anything closer than this is "in your face" rather than "in the scene".
const NEAR_M := 6.0
## camera_rig.gd aims at the player's target_height, not their feet.
const AIM_Y := 1.1


func _report_frame_occupancy() -> void:
	print("")
	print("=== WHAT FILLS THE FRAME (%dx%d ray grid, recorded camera positions) ===" % [
		FRAME_COLS, FRAME_ROWS,
	])
	print("near%% = share of the picture taken by geometry within %.0f m of the camera." % NEAR_M)
	print("A single object over ~25%% is a slab in the way, however clear the sightline is.")
	print("%-14s %8s %8s   %s" % ["beat", "near%", "top obj", "largest contributors"])
	print("-".repeat(78))

	for frame in FRAMES:
		var eye := Vector3(frame[1], frame[2], frame[3])
		var aim := Vector3(frame[4], AIM_Y, frame[5])
		var forward := (aim - eye).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var up := right.cross(forward).normalized()
		var half_v: float = tan(deg_to_rad(float(frame[6]) * 0.5))
		var half_h: float = half_v * ASPECT

		var near_hits := 0
		var shares := {}
		var nearest := {}
		for row in range(FRAME_ROWS):
			# +0.5 samples each cell's centre rather than its corner.
			var v: float = (2.0 * (row + 0.5) / FRAME_ROWS - 1.0) * half_v
			for col in range(FRAME_COLS):
				var h: float = (2.0 * (col + 0.5) / FRAME_COLS - 1.0) * half_h
				var dir := (forward + right * h + up * v).normalized()
				var best := INF
				var who := ""
				for entry in _all_boxes:
					var t := _ray_box(eye, dir, entry["box"])
					if t >= 0.0 and t < best:
						best = t
						who = entry["name"]
				if best > NEAR_M:
					continue
				near_hits += 1
				shares[who] = shares.get(who, 0) + 1
				if not nearest.has(who) or best < nearest[who]:
					nearest[who] = best

		var total := FRAME_COLS * FRAME_ROWS
		var ranked: Array = []
		for key in shares:
			ranked.append([key, shares[key]])
		ranked.sort_custom(func(a, b): return a[1] > b[1])
		var top_share: float = 0.0 if ranked.is_empty() else 100.0 * float(ranked[0][1]) / total
		print("%-14s %7.0f%% %7.0f%%" % [frame[0], 100.0 * near_hits / total, top_share])
		for i in range(mini(5, ranked.size())):
			var key: String = ranked[i][0]
			var pct: float = 100.0 * float(ranked[i][1]) / total
			if pct < 2.0:
				break
			var box := AABB()
			for entry in _all_boxes:
				if entry["name"] == key:
					box = entry["box"]
					break
			print("                 %5.1f%%  %-20s %4.1f m  y[%.1f,%.1f] x[%.1f,%.1f] z[%.1f,%.1f]" % [
				pct, key, nearest[key], box.position.y, box.end.y,
				box.position.x, box.end.x, box.position.z, box.end.z,
			])
