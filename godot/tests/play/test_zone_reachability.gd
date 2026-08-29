extends GdUnitTestSuite
## Openness pass (2026-08-29): every interaction zone must be reachable on
## foot from the player's spawn, through the real physics world.
##
## The regression this guards is a specific and easy one to cause: the four
## rooms are joined by three openings (the home doorway, the lane, the
## garden gap), each of them a deliberate gap left between two collider
## boxes in WorldBounds.COLLIDERS. Nothing in that data structure says the
## gaps are gaps. Widening a wall segment by half a metre, or nudging one
## in z, closes one without any other test noticing -- test_world_bounds.gd
## checks the garden gap's own three points and nothing else, and the play
## tests drive authored routes that would simply time out with a
## push_error rather than fail an assertion.
##
## This floods the walkable plane instead: a breadth-first search on a
## 0.5 m grid from wherever the player actually stands on frame 2 (player.gd
## puts itself at its own START_POSITION in _ready(), so this is the spawn
## without hardcoding it), using the player's own collision
## shape and the real StaticBody3D set, with every step confirmed by a
## swept shape cast rather than by sampling the two endpoints (two free
## cells 0.5 m apart can still have a wall corner between them). A zone
## counts as reached when any reachable cell falls inside its own trigger
## radius -- the same radius interaction_zone.gd polls with, so this asserts
## exactly what the game asks of the player and not a stricter proxy.
##
## Zones are read from Game.zones rather than listed here, so a zone added
## to the world is covered by this test without anyone remembering to.
##
## tools/_probe_reachability.gd is the interactive version of the same
## walk, and reports far more (walk distances, dead space, sightlines,
## invisible walls). This is only the assertion.

const STEP := 0.5
const X_MIN := -18.0
const Z_MIN := -22.0
const X_CELLS := 85
const Z_CELLS := 81
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _space: PhysicsDirectSpaceState3D
var _params: PhysicsShapeQueryParameters3D
var _shape_y := 0.54


func test_every_interaction_zone_is_reachable_on_foot_from_spawn() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let Player, CameraRig and every zone _ready() run

	var player: CharacterBody3D = Game.player
	assert_object(player).is_not_null()
	assert_array(Game.zones).is_not_empty()

	_prepare_query(player)

	var start := player.global_position
	var free := _free_grid()
	var spawn := _cell_of(start.x, start.z)
	assert_bool(free[_index(spawn)] == 1).override_failure_message(
		"The spawn cell %s is itself inside geometry -- the player starts stuck." % start
	).is_true()

	var reached := _flood(free, spawn)

	for zone in Game.zones:
		var here: Vector3 = zone.global_position
		assert_bool(_any_reachable_within(reached, here.x, here.z, zone.radius)) \
			.override_failure_message(
				"Zone '%s' at (%.2f, %.2f) r=%.2f cannot be walked to from spawn %s. "
				% [zone.name, here.x, here.z, zone.radius, start]
				+ "Some wall segment has closed one of the three openings between the "
				+ "four rooms (home doorway / lane / garden gap). Run "
				+ "tools/_probe_reachability.gd for the full walk."
			).is_true()


func _prepare_query(player: CharacterBody3D) -> void:
	var shape: Shape3D = null
	for child in player.get_children():
		if child is CollisionShape3D:
			shape = (child as CollisionShape3D).shape
			_shape_y = (child as CollisionShape3D).position.y
			break
	assert_object(shape).override_failure_message(
		"No CollisionShape3D on the player -- this test cannot measure a body it can't find."
	).is_not_null()

	_space = player.get_world_3d().direct_space_state
	_params = PhysicsShapeQueryParameters3D.new()
	_params.shape = shape
	_params.collision_mask = 1  # movement layer, the one player.gd's own body collides on
	_params.collide_with_areas = false
	_params.exclude = [player.get_rid()]


func _index(cell: Vector2i) -> int:
	return cell.y * X_CELLS + cell.x


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(round((x - X_MIN) / STEP)), int(round((z - Z_MIN) / STEP)))


func _world_of(cell: Vector2i) -> Vector2:
	return Vector2(X_MIN + cell.x * STEP, Z_MIN + cell.y * STEP)


func _free_grid() -> PackedByteArray:
	var free := PackedByteArray()
	free.resize(X_CELLS * Z_CELLS)
	for zi in range(Z_CELLS):
		for xi in range(X_CELLS):
			var p := _world_of(Vector2i(xi, zi))
			_params.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, _shape_y, p.y))
			_params.motion = Vector3.ZERO
			free[zi * X_CELLS + xi] = 1 if _space.intersect_shape(_params, 1).is_empty() else 0
	return free


func _flood(free: PackedByteArray, start: Vector2i) -> PackedByteArray:
	var reached := PackedByteArray()
	reached.resize(free.size())
	reached[_index(start)] = 1

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
			if reached[next_index] == 1 or free[next_index] == 0:
				continue
			_params.transform = Transform3D(Basis.IDENTITY, Vector3(here.x, _shape_y, here.y))
			_params.motion = Vector3(delta.x * STEP, 0.0, delta.y * STEP)
			var cast: PackedFloat32Array = _space.cast_motion(_params)
			if cast.size() < 1 or cast[0] < 0.999:
				continue  # a wall corner sits between these two free cells
			reached[next_index] = 1
			queue.append(next)
	return reached


func _any_reachable_within(reached: PackedByteArray, x: float, z: float, radius: float) -> bool:
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
			if reached[_index(cell)] == 1:
				return true
	return false
