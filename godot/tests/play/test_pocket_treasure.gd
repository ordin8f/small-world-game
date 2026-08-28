extends GdUnitTestSuite
## Gate 1 (mechanics agent) play test for scripts/pocket_treasure.gd.
## docs/PRODUCT_CONTRACT.md bans collectibles/scoring, so this deliberately
## does NOT assert on any UI tally (there isn't one) -- it guards the real
## contract instead: picking one up increments Game.treasures_found (which
## scripts/ui/ending_screen.gd renders on the sill), the object actually
## disappears so it can't be found twice in the same run, and a fresh
## "Play again" makes all three findable again.

func test_picking_up_a_treasure_increments_the_ending_screen_count_and_removes_it() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()
	var marble: Node3D = runner.scene().find_child("Marble", true, false)
	assert_object(marble).is_not_null()

	Game.start_episode(0.0)
	assert_int(Game.treasures_found).is_equal(0)

	player.global_position = marble.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	assert_object(Game.active_free_interactable).is_same(marble)
	Game.interact()
	for _i in range(2):
		await tree.physics_frame

	assert_int(Game.treasures_found).is_equal(1)
	assert_bool(marble.visible).is_false()
	# Removed from the interactable pool -- pressing interact again at the
	# same spot (nothing else nearby) must not double-count it.
	assert_object(Game.active_free_interactable).is_null()
	Game.interact()
	for _i in range(2):
		await tree.physics_frame
	assert_int(Game.treasures_found).is_equal(1)


func test_finding_all_three_reaches_the_ending_screens_own_cap() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	Game.start_episode(0.0)

	var tree := Engine.get_main_loop() as SceneTree
	for treasure_name in ["Marble", "Stone", "Feather"]:
		var treasure: Node3D = runner.scene().find_child(treasure_name, true, false)
		assert_object(treasure).is_not_null()
		player.global_position = treasure.global_position
		for _i in range(5):
			await tree.physics_frame
		Game.interact()
		for _i in range(2):
			await tree.physics_frame

	assert_int(Game.treasures_found).is_equal(3)


func test_a_fresh_run_makes_every_treasure_findable_again() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var marble: Node3D = runner.scene().find_child("Marble", true, false)

	Game.start_episode(0.0)
	player.global_position = marble.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(2):
		await tree.physics_frame
	assert_int(Game.treasures_found).is_equal(1)
	assert_bool(marble.visible).is_false()

	# "Play again" -- game.gd's start_episode() resets the count, and each
	# treasure's own ARRIVE handler must restore its own visibility to match.
	Game.start_episode(0.0)
	for _i in range(2):
		await tree.physics_frame
	assert_int(Game.treasures_found).is_equal(0)
	assert_bool(marble.visible).is_true()

	player.global_position = marble.global_position
	for _i in range(5):
		await tree.physics_frame
	assert_object(Game.active_free_interactable).is_same(marble)


func test_pocket_treasures_are_never_mentioned_in_hud_prompt_text_as_a_count() -> void:
	# Cheap guardrail against the exact failure mode the brief calls out:
	# "if you find yourself adding a '2/3' anywhere, stop." Labels are
	# small, fixed strings -- none of them may contain digits.
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	for treasure_name in ["Marble", "Stone", "Feather"]:
		var treasure: Node = runner.scene().find_child(treasure_name, true, false)
		var label: String = treasure.get("label")
		assert_str(label).not_contains("/")
		for digit in range(10):
			assert_str(label).not_contains(str(digit))
