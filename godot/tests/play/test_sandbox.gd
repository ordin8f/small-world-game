extends GdUnitTestSuite
## Gate 1 (mechanics agent) play test for scripts/sandbox.gd: "a sandcastle
## that stays built." Guards mounds actually appearing as real child nodes
## (not just a counter incrementing), the castle surviving ordinary idle
## time, the flag only appearing once the pit is full, and everything
## clearing on a fresh "Play again" -- docs/PRODUCT_CONTRACT.md's session-
## only save scope, same reset contract as the ball/player/pocket treasures.

func test_interacting_inside_the_pit_spawns_a_real_mound_node() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()
	var sandbox: Node = runner.scene().find_child("Sandbox", true, false)
	assert_object(sandbox).is_not_null()

	Game.start_episode(0.0)
	player.global_position = sandbox.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	assert_object(Game.active_free_interactable).is_same(sandbox)
	var mounds: Node = sandbox.get("_mounds_container")
	assert_object(mounds).is_not_null()
	assert_int(mounds.get_child_count()).is_equal(0)

	Game.interact()
	for _i in range(15):
		await tree.physics_frame

	assert_int(mounds.get_child_count()).is_equal(1)
	assert_int(sandbox.get("_mound_count")).is_equal(1)


func test_mounds_land_near_wherever_the_player_was_standing_not_a_fixed_spot() -> void:
	# "Where you stand is a real, if small, creative choice" -- two mounds
	# placed from two different standing spots inside the pit must not
	# collapse onto the same authored point.
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var sandbox: Node = runner.scene().find_child("Sandbox", true, false)
	Game.start_episode(0.0)
	var tree := Engine.get_main_loop() as SceneTree

	player.global_position = sandbox.global_position + Vector3(0.9, 0.0, 0.0)
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(15):
		await tree.physics_frame

	player.global_position = sandbox.global_position + Vector3(-0.9, 0.0, 0.6)
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(15):
		await tree.physics_frame

	var mounds: Node = sandbox.get("_mounds_container")
	assert_int(mounds.get_child_count()).is_equal(2)
	var first: Node3D = mounds.get_child(0)
	var second: Node3D = mounds.get_child(1)
	assert_float(first.position.distance_to(second.position)).is_greater(0.5)


func test_filling_the_pit_plants_a_flag_and_further_interacts_are_a_no_op() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var sandbox: Node = runner.scene().find_child("Sandbox", true, false)
	Game.start_episode(0.0)
	player.global_position = sandbox.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	const MAX_MOUNDS := 5  ## mirrors sandbox.gd's own const -- consts aren't reachable through Object.get()
	for _i in range(MAX_MOUNDS):
		Game.interact()
		for _t in range(10):
			await tree.physics_frame

	assert_bool(sandbox.get("_flag_planted")).is_true()
	var mounds: Node = sandbox.get("_mounds_container")
	var count_at_cap := mounds.get_child_count()

	Game.interact()  # pit is full -- must not add anything else
	for _i in range(10):
		await tree.physics_frame
	assert_int(mounds.get_child_count()).is_equal(count_at_cap)


func test_a_finished_castle_survives_ordinary_idle_time() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var sandbox: Node = runner.scene().find_child("Sandbox", true, false)
	Game.start_episode(0.0)
	player.global_position = sandbox.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	Game.interact()
	for _i in range(15):
		await tree.physics_frame
	var mounds: Node = sandbox.get("_mounds_container")
	assert_int(mounds.get_child_count()).is_equal(1)

	# Walk away and let a few seconds pass -- nothing about this mechanic
	# should be time-limited or fade on its own.
	player.global_position = Vector3(0.0, 0.0, 6.5)
	for _i in range(180):
		await tree.physics_frame
	assert_int(mounds.get_child_count()).is_equal(1)


func test_a_fresh_run_clears_the_castle_back_to_an_empty_pit() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var sandbox: Node = runner.scene().find_child("Sandbox", true, false)
	Game.start_episode(0.0)
	player.global_position = sandbox.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	Game.interact()
	for _i in range(15):
		await tree.physics_frame
	var mounds: Node = sandbox.get("_mounds_container")
	assert_int(mounds.get_child_count()).is_equal(1)

	Game.start_episode(0.0)  # "Play again"
	for _i in range(3):
		await tree.physics_frame
	assert_int(mounds.get_child_count()).is_equal(0)
	assert_int(sandbox.get("_mound_count")).is_equal(0)


func test_sandbox_prompt_never_shows_a_piece_count() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var sandbox: Node = runner.scene().find_child("Sandbox", true, false)
	var label: String = sandbox.get("label")
	assert_str(label).not_contains("/")
	for digit in range(10):
		assert_str(label).not_contains(str(digit))
