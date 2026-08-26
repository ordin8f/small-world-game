extends GdUnitTestSuite
## M2.5 play test: confirms perception.gd is actually running in the live
## scene, not just correct in isolation -- before this milestone, nothing
## ever called EmotionalLens.update(), so Game.lens.value sat frozen at
## its constructor default forever regardless of what state the episode
## was in. Drives the player far from the group during FIND_BALL and
## checks that comfort actually moved toward the (lower) target, and that
## WorldEnvironment's fog_depth_begin tracks get_visuals()["fog_near"].

const TOLERANCE := 0.05


func test_lens_and_environment_actually_update_over_real_physics_ticks() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let every node's _ready() run, including Perception's

	var player: Node3D = Game.player
	assert_object(player).is_not_null()

	Game.start_episode(0.0)
	var initial_comfort: float = Game.lens.value["comfort"]

	# Force FIND_BALL directly (bypassing the zone/timer chain -- this test
	# is about the lens/environment wiring, not the state machine, which
	# M2.1/M2.3 already cover) and move the player far from the group so
	# emotional_target()'s distance term pulls comfort down hard.
	Game.director.state = EpisodeDirector.State.FIND_BALL
	player.global_position = Vector3(8.6, 0.0, -6.6)  # ballEnd, far from groupPosition

	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(120):
		await tree.physics_frame

	var updated_comfort: float = Game.lens.value["comfort"]
	assert_float(updated_comfort).is_less(initial_comfort)

	var expected_fog_near: float = Game.lens.get_visuals()["fog_near"]
	var world_env: WorldEnvironment = runner.scene().find_child("WorldEnvironment", true, false)
	assert_object(world_env).is_not_null()
	var actual_fog_near: float = world_env.environment.fog_depth_begin
	assert_float(actual_fog_near).is_between(expected_fog_near - TOLERANCE, expected_fog_near + TOLERANCE)
