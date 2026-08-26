class_name DriveRoute
extends RefCounted
## Steers a live CharacterBody3D toward a sequence of world-space waypoints
## using simulated discrete WASD-style input (never teleportation) via a
## gdUnit4 SceneRunner -- an actual input-driven playthrough, matching the
## plan's working agreement (real input, not a debug-command shortcut).
##
## Key insight: CameraProfile.input_direction(x, z, yaw) is its own inverse.
## Its 2x2 matrix M = [[cos,-sin],[-sin,-cos]] squares to the identity
## (verified algebraically: M*M's off-diagonal terms cancel, diagonal terms
## reduce to sin^2+cos^2=1). So to find the input that produces a desired
## *world*-space unit direction, call input_direction() again with that
## world direction as the input -- the same function that maps input->world
## also maps world->input.

const ARRIVE_RADIUS := 0.5
const MAX_TICKS_PER_LEG := 600  # 10s @ 60Hz -- generous ceiling per leg; a
	# leg that never arrives is a real bug, not something to loop forever on.

const ACTIONS := ["move_right", "move_left", "move_forward", "move_back"]


static func _keys_for(world_dir: Vector2, yaw: float) -> Dictionary:
	if world_dir.length() < 1e-6:
		return {"x": 0, "z": 0}
	var n := world_dir.normalized()
	var raw: Dictionary = CameraProfile.input_direction(n.x, n.y, yaw)
	var rx: float = raw["x"]
	var rz: float = raw["z"]
	var kx := 0
	var kz := 0
	if rx > 0.3:
		kx = 1
	elif rx < -0.3:
		kx = -1
	if rz > 0.3:
		kz = 1
	elif rz < -0.3:
		kz = -1
	return {"x": kx, "z": kz}


static func _set_key(runner: GdUnitSceneRunner, held: Dictionary, action: String, want_pressed: bool) -> void:
	if held[action] == want_pressed:
		return
	if want_pressed:
		runner.simulate_action_press(action)
	else:
		runner.simulate_action_release(action)
	held[action] = want_pressed


## Drives `player` through each [x, z] pair in `waypoints` in order. Calls
## `on_tick` (Callable, no args) once per elapsed physics tick so the
## caller can assert per-tick invariants (camera raycast, height, clamps).
## Returns the total number of physics ticks driven.
static func run(runner: GdUnitSceneRunner, player: Node3D, waypoints: Array, on_tick: Callable) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var held := {"move_right": false, "move_left": false, "move_forward": false, "move_back": false}
	var total_ticks := 0

	for wp in waypoints:
		var wx: float = wp[0]
		var wz: float = wp[1]
		var target := Vector2(wx, wz)
		var ticks := 0
		while ticks < MAX_TICKS_PER_LEG:
			var pos := player.global_position
			var to_target := target - Vector2(pos.x, pos.z)
			if to_target.length() <= ARRIVE_RADIUS:
				break

			var profile := CameraProfile.profile(pos.z)
			var yaw: float = profile["authored_yaw"]
			var keys := _keys_for(to_target, yaw)
			var kx: int = keys["x"]
			var kz: int = keys["z"]

			_set_key(runner, held, "move_right", kx == 1)
			_set_key(runner, held, "move_left", kx == -1)
			_set_key(runner, held, "move_forward", kz == 1)
			_set_key(runner, held, "move_back", kz == -1)

			await tree.physics_frame
			on_tick.call()
			ticks += 1
			total_ticks += 1

		if ticks >= MAX_TICKS_PER_LEG:
			push_error("DriveRoute: leg toward (%s, %s) did not arrive within %d ticks (stuck at %s)" % [wx, wz, MAX_TICKS_PER_LEG, player.global_position])

	for action in ACTIONS:
		_set_key(runner, held, action, false)

	return total_ticks
