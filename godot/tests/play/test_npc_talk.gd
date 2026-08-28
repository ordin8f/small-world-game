extends GdUnitTestSuite
## Gate 1 (mechanics agent) play test for character_visual.gd's interact-
## driven NPC conversations. Mina/Arun/Priya were animated statues that
## played "idle" once and never moved again; this guards that each of the
## brief's three named reactions actually DOES something measurable --
## Mina's own rotation changing to face the player, Arun's position
## actually closing the distance while following, Priya's position
## actually advancing toward the slide -- not just a flag flipping or a
## line of text appearing.

func after_test() -> void:
	Engine.time_scale = 1.0


func test_talking_to_mina_turns_her_to_face_the_player() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()
	var mina: Node3D = runner.scene().find_child("Mina", true, false)
	assert_object(mina).is_not_null()

	Game.start_episode(0.0)
	# Stand well off Mina's current facing so a turn is unambiguous, but
	# still inside her own INTERACT_RADIUS (1.7).
	player.global_position = mina.global_position + Vector3(-1.0, 0.0, 0.8)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	assert_object(Game.active_free_interactable).is_same(mina)
	var heading_before: float = mina.rotation.y
	var lines_before: int = mina.get("_line_index")

	Game.interact()
	for _i in range(60):
		await tree.physics_frame

	assert_int(mina.get("_line_index")).is_greater(lines_before)
	assert_float(absf(mina.rotation.y - heading_before)).is_greater(0.1)
	# She turns and stays -- she must not have wandered off her mark.
	assert_float(mina.global_position.distance_to(Vector3(-0.95, 0.0, -11.0))).is_less(0.1)


func test_talking_to_arun_makes_him_actually_follow_the_moving_player() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var arun: Node3D = runner.scene().find_child("Arun", true, false)
	assert_object(arun).is_not_null()

	Game.start_episode(0.0)
	# South of Arun, not east -- east (+x) is only ~0.8m from Priya's own
	# spawn (1.45,-3.55), whose INTERACT_RADIUS (1.7) would then be NEARER
	# than Arun's own offset, and Game.interact() would talk to her instead.
	player.global_position = arun.global_position + Vector3(0.0, 0.0, -1.3)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	assert_object(Game.active_free_interactable).is_same(arun)

	Game.interact()
	var start_pos: Vector3 = arun.global_position
	# Lead him somewhere new -- a real follow must close in on a MOVING
	# target, not just walk to where the player happened to be at t=0.
	# North, away from the towers either side (x=+-3.4) -- open ground, so
	# this is purely testing the follow logic, not also grazing a collider.
	player.global_position = start_pos + Vector3(0.0, 0.0, 3.0)
	for _i in range(120):
		await tree.physics_frame

	var moved: float = arun.global_position.distance_to(start_pos)
	assert_float(moved).is_greater(0.5)
	var distance_to_player: float = arun.global_position.distance_to(player.global_position)
	assert_float(distance_to_player).is_less(start_pos.distance_to(player.global_position))


func test_talking_to_priya_sends_her_walking_toward_the_slide() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var priya: Node3D = runner.scene().find_child("Priya", true, false)
	assert_object(priya).is_not_null()

	Game.start_episode(0.0)
	player.global_position = priya.global_position + Vector3(1.5, 0.0, 0.0)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	var start_pos: Vector3 = priya.global_position
	var start_dist_to_slide: float = start_pos.distance_to(WorldAffordances.CLIMB_TRIGGER)

	Game.interact()
	for _i in range(180):
		await tree.physics_frame

	var moved: float = priya.global_position.distance_to(start_pos)
	assert_float(moved).is_greater(0.5)
	assert_float(priya.global_position.distance_to(WorldAffordances.CLIMB_TRIGGER)).is_less(start_dist_to_slide)


func test_repeated_interacts_cycle_through_different_lines() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var mina: Node3D = runner.scene().find_child("Mina", true, false)
	Game.start_episode(0.0)
	player.global_position = mina.global_position + Vector3(-1.0, 0.0, 0.5)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	Game.interact()
	await tree.physics_frame
	var first_index: int = mina.get("_line_index")
	Game.interact()
	await tree.physics_frame
	var second_index: int = mina.get("_line_index")

	assert_int(second_index).is_greater(first_index)


func test_a_fresh_run_stops_a_mid_follow_npc_instead_of_leaving_it_stuck_moving() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var arun: Node3D = runner.scene().find_child("Arun", true, false)
	Game.start_episode(0.0)
	# South of Arun, not east -- see test_talking_to_arun_makes_him_
	# actually_follow_the_moving_player's own comment on why (Priya's
	# radius overlaps the east side).
	player.global_position = arun.global_position + Vector3(0.0, 0.0, -1.3)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	assert_object(Game.active_free_interactable).is_same(arun)

	Game.interact()
	for _i in range(10):
		await tree.physics_frame
	assert_bool(arun.get("_talking")).is_true()

	Game.start_episode(0.0)  # "Play again" mid-follow
	for _i in range(3):
		await tree.physics_frame
	assert_bool(arun.get("_talking")).is_false()
