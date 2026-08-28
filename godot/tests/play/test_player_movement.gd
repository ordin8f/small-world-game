extends GdUnitTestSuite
## M1.3 play test (GODOT_REBUILD_PLAN.md): drives the real Player scene with
## simulated input via gdUnit4's SceneRunner -- an actual input-driven
## playthrough test, not a screenshot of an isolated debug harness. This is
## the exact test class the plan calls out as guarding the Saturday
## Afternoon failure mode (a builder/critic loop that judged static
## screenshots and shipped an unplayable walk speed).
##
## Timing note: simulate_frames() awaits SceneTree.process_frame (idle/
## render frames), not physics ticks. In this headless sandbox idle frames
## fire far faster than the fixed 60Hz physics rate, so N simulate_frames()
## calls do NOT correspond to N/60 physics-seconds -- physics still runs
## correctly at a real, fixed 60Hz underneath, it's just that 120 idle-frame
## awaits elapse in well under 120 physics ticks' worth of wall-clock time.
## Confirmed empirically: 120 simulate_frames() took 838ms wall-clock,
## during which Engine.get_physics_frames() only advanced by ~50, not 120.
## Fix: measure the ACTUAL elapsed physics ticks via Engine.get_physics_frames()
## and derive the expected distance from that real count, rather than
## assuming frames == seconds*60.

const WALK_SPEED := 2.65
const RUN_SPEED := 4.1
const TOLERANCE := 0.15  # ±15%, per the plan's acceptance criterion
const FRAMES := 180      # generous idle-frame budget so enough real physics ticks land
const MIN_PHYSICS_TICKS := 30  # sanity floor: must be enough ticks for a meaningful sample


func test_hold_move_forward_walks_at_walk_speed() -> void:
	var runner := scene_runner("res://scenes/player.tscn")
	var player: Node3D = runner.scene()
	var start_z: float = player.global_position.z
	var ticks_before := Engine.get_physics_frames()

	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(FRAMES)
	runner.simulate_action_release("move_forward")

	var ticks_elapsed := Engine.get_physics_frames() - ticks_before
	assert_int(ticks_elapsed).is_greater_equal(MIN_PHYSICS_TICKS)

	var delta_z: float = player.global_position.z - start_z
	var expected: float = -WALK_SPEED * (ticks_elapsed / 60.0)
	assert_float(delta_z).is_between(expected * (1.0 + TOLERANCE), expected * (1.0 - TOLERANCE))


func test_hold_move_forward_and_run_walks_at_run_speed() -> void:
	var runner := scene_runner("res://scenes/player.tscn")
	var player: Node3D = runner.scene()
	var start_z: float = player.global_position.z
	var ticks_before := Engine.get_physics_frames()

	runner.simulate_action_press("move_forward")
	runner.simulate_action_press("run")
	await runner.simulate_frames(FRAMES)
	runner.simulate_action_release("move_forward")
	runner.simulate_action_release("run")

	var ticks_elapsed := Engine.get_physics_frames() - ticks_before
	assert_int(ticks_elapsed).is_greater_equal(MIN_PHYSICS_TICKS)

	var delta_z: float = player.global_position.z - start_z
	var expected: float = -RUN_SPEED * (ticks_elapsed / 60.0)
	assert_float(delta_z).is_between(expected * (1.0 + TOLERANCE), expected * (1.0 - TOLERANCE))


func test_zero_input_gives_zero_velocity() -> void:
	var runner := scene_runner("res://scenes/player.tscn")
	var player: CharacterBody3D = runner.scene()
	var start_pos: Vector3 = player.global_position

	await runner.simulate_frames(30)

	assert_vector(player.velocity).is_equal_approx(Vector3.ZERO, Vector3(0.001, 0.001, 0.001))
	assert_vector(player.global_position).is_equal_approx(start_pos, Vector3(0.001, 0.001, 0.001))
