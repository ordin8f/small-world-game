extends GdUnitTestSuite
## Gate 0 play test for scripts/puddles.gd: walking into a puddle should
## fire exactly one splash per entry (not once per tick spent standing in
## it), and leaving then returning splashes again.

func test_entering_a_puddle_splashes_once_per_entry() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()
	var puddles: Node = runner.scene().find_child("Puddles", true, false)
	assert_object(puddles).is_not_null()
	Game.start_episode(0.0)  # AudioDirector.start() -- play_splash() no-ops before this

	var tree := Engine.get_main_loop() as SceneTree
	var first_puddle: Dictionary = WorldAffordances.PUDDLES[0]

	# Dry ground first.
	player.global_position = Vector3(0.0, 0.0, 6.5)
	for _i in range(5):
		await tree.physics_frame
	assert_int(puddles.splash_count).is_equal(0)

	# Step into the puddle and linger -- one splash, not several.
	player.global_position = Vector3(first_puddle["x"], 0.0, first_puddle["z"])
	for _i in range(30):
		await tree.physics_frame
	assert_int(puddles.splash_count).is_equal(1)

	# Step out, then back in -- a fresh splash.
	player.global_position = Vector3(0.0, 0.0, 6.5)
	for _i in range(5):
		await tree.physics_frame
	player.global_position = Vector3(first_puddle["x"], 0.0, first_puddle["z"])
	for _i in range(5):
		await tree.physics_frame
	assert_int(puddles.splash_count).is_equal(2)


func test_dry_ground_never_splashes() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var puddles: Node = runner.scene().find_child("Puddles", true, false)
	Game.start_episode(0.0)

	var tree := Engine.get_main_loop() as SceneTree
	for wp in [[0.0, 6.5], [0.0, -3.8], [8.6, -6.6]]:
		player.global_position = Vector3(wp[0], 0.0, wp[1])
		for _i in range(10):
			await tree.physics_frame
	assert_int(puddles.splash_count).is_equal(0)
