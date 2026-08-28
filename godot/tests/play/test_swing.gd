extends GdUnitTestSuite
## Gate 1 (mechanics agent) play test for scripts/swing.gd. Guards the
## thing that actually matters here per the brief ("real arc and momentum,
## worth doing twice"): sustained pump input must measurably build swing
## amplitude, not just flip a "riding" flag -- scripts/logic/swing_math.gd
## already has its own pure-math unit tests, so this is specifically the
## INTEGRATION: input -> player.external_control -> Pivot rotation -> the
## player's own world position actually following the seat.

func after_test() -> void:
	Engine.time_scale = 1.0


func test_mounting_hands_the_player_to_the_swing_and_sitting_reads_as_riding() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()
	var swing: Node = runner.scene().find_child("Swing", true, false)
	assert_object(swing).is_not_null()

	Game.start_episode(0.0)
	player.global_position = swing.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	assert_object(Game.active_free_interactable).is_same(swing)
	assert_bool(player.external_control).is_false()

	Game.interact()
	for _i in range(3):
		await tree.physics_frame

	assert_bool(player.external_control).is_true()
	assert_bool(swing.get("_riding")).is_true()
	# The player's world position must actually be at the seat, not just a
	# flag having flipped -- within arm's reach of the swing's own origin.
	assert_float(player.global_position.distance_to(swing.global_position)).is_less(3.0)


func test_sustained_pumping_builds_real_amplitude_and_moves_the_seated_player() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var swing: Node = runner.scene().find_child("Swing", true, false)
	Game.start_episode(0.0)

	player.global_position = swing.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame

	var pos_at_rest: Vector3 = player.global_position

	runner.simulate_action_press("move_forward")
	for _i in range(90):
		await tree.physics_frame
	runner.simulate_action_release("move_forward")

	var theta: float = swing.get("_theta")
	assert_float(absf(theta)).is_greater(0.05)
	# The player's own tracked position must have moved off the rest point
	# by a real amount, not a rounding-error's worth.
	assert_float(player.global_position.distance_to(pos_at_rest)).is_greater(0.05)


func test_interacting_again_hops_off_and_returns_control_to_the_player() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var swing: Node = runner.scene().find_child("Swing", true, false)
	Game.start_episode(0.0)

	player.global_position = swing.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(player.external_control).is_true()

	Game.interact()  # same button hops off -- no separate "cancel" input exists
	for _i in range(3):
		await tree.physics_frame

	assert_bool(player.external_control).is_false()
	assert_bool(swing.get("_riding")).is_false()
	assert_float(player.global_position.y).is_equal_approx(player.locked_y, 0.01)


func test_a_fresh_run_mid_ride_hands_control_back_instead_of_leaving_the_player_stuck() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var swing: Node = runner.scene().find_child("Swing", true, false)
	Game.start_episode(0.0)

	player.global_position = swing.global_position
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(player.external_control).is_true()

	Game.start_episode(0.0)  # "Play again" mid-ride
	for _i in range(3):
		await tree.physics_frame

	assert_bool(player.external_control).is_false()
	assert_bool(swing.get("_riding")).is_false()
