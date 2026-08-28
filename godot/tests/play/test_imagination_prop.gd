extends GdUnitTestSuite
## Gate 1 (mechanics agent) play test for scripts/imagination_prop.gd:
## walking up to a flagged prop and pressing interact should visibly
## transform it (overlay mesh actually grows, perception's imagination
## channel actually rises) and then revert on its own -- and a second
## press should end the cue early rather than only ever timing out.

const TIME_SCALE := 20.0


func after_test() -> void:
	Engine.time_scale = 1.0


func test_interacting_with_the_crate_grows_the_castle_overlay_and_drives_the_lens() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()
	var crate: Node = runner.scene().find_child("CrateProp", true, false)
	assert_object(crate).is_not_null()
	var perception: Node = runner.scene().find_child("Perception", true, false)
	assert_object(perception).is_not_null()

	Game.start_episode(0.0)
	player.global_position = crate.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	assert_object(Game.active_free_interactable).is_same(crate)

	var overlay: Node3D = crate.get("_overlay")
	assert_object(overlay).is_not_null()
	assert_bool(overlay.visible).is_false()
	assert_float(overlay.scale.x).is_equal_approx(0.0, 0.001)

	Game.interact()
	for _i in range(30):
		await tree.physics_frame

	assert_bool(overlay.visible).is_true()
	assert_float(overlay.scale.x).is_greater(0.5)
	assert_float(perception.call("imagination_strength")).is_greater(0.5)

	# "then reverts" -- accelerate the clock past REVERT_SECONDS rather than
	# waiting several real seconds.
	Engine.time_scale = TIME_SCALE
	for _i in range(240):
		await tree.physics_frame
	assert_bool(overlay.visible).is_false()
	assert_float(overlay.scale.x).is_equal_approx(0.0, 0.01)


func test_a_second_interact_ends_the_cue_early_instead_of_only_timing_out() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchProp", true, false)
	assert_object(bench).is_not_null()

	Game.start_episode(0.0)
	player.global_position = bench.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	Game.interact()
	for _i in range(20):
		await tree.physics_frame
	var overlay: Node3D = bench.get("_overlay")
	assert_bool(overlay.visible).is_true()
	assert_bool(bench.get("_imagined")).is_true()

	Game.interact()  # same button, ends it -- no separate "cancel" input exists
	for _i in range(5):
		await tree.physics_frame
	assert_bool(bench.get("_imagined")).is_false()


func test_props_never_write_an_authored_colour_onto_the_environment() -> void:
	# The brief's own guardrail: "It may modulate scalars only and must
	# never write an authored colour" -- same invariant
	# test_stepping_stones.gd's own colour test guards, checked here
	# against imagination_prop.gd specifically since it drives the same
	# shared channel from a different trigger.
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var crate: Node = runner.scene().find_child("CrateProp", true, false)
	var perception: Node = runner.scene().find_child("Perception", true, false)

	Game.start_episode(0.0)
	player.global_position = crate.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(60):
		await tree.physics_frame

	var base: Resource = perception.call("current_mood")
	var world_env: WorldEnvironment = runner.scene().find_child("WorldEnvironment", true, false)
	var env: Environment = world_env.environment
	assert_bool(env.fog_light_color.is_equal_approx(base.fog_color)).is_true()
	assert_bool(env.background_color.is_equal_approx(base.background_color)).is_true()
