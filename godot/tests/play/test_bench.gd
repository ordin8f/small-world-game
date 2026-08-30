extends GdUnitTestSuite
## Sitting on the bench (developer, 2026-08-30: "I can't sit on the bench and
## go right through it").
##
## Two separate defects and so two separate kinds of check here: the bench
## had no collider at all (a WorldBounds question, answered without a scene),
## and it had no affordance (a scripts/bench.gd question, answered by
## actually pressing interact through Game the way a player does).
##
## The thing this suite most has to protect is that sitting stays PLAY and
## never becomes a chore: leavable at any moment, by either the interact key
## or simply walking away, and incapable of touching story progress.


func test_the_bench_is_solid_and_you_cannot_walk_through_it() -> void:
	var bench := WorldAffordances.BENCH_POSITION
	# Dead centre of the bench is inside it now.
	assert_bool(WorldBounds.can_move_to(bench.x, bench.z)).is_false()
	# ...and so is standing where the seat is, from either side of it.
	var yaw := WorldAffordances.bench_yaw()
	for side in [-0.5, 0.5]:
		var probe: Vector3 = bench + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, side)
		assert_bool(WorldBounds.can_move_to(probe.x, probe.z)).is_false()
	# But you can still walk up to it -- a collider that sealed the approach
	# would trade one bug for another.
	var approach := WorldAffordances.bench_stand_position()
	assert_bool(WorldBounds.can_move_to(approach.x, approach.z)).is_true()
	assert_float(Vector2(approach.x - bench.x, approach.z - bench.z).length()) \
		.is_less(WorldAffordances.BENCH_SIT_RADIUS)


func test_walking_up_and_pressing_interact_sits_the_child_on_the_seat() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	assert_object(bench).is_not_null()

	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	assert_object(Game.active_free_interactable).is_same(bench)
	assert_bool(player.external_control).is_false()

	Game.interact()
	for _i in range(3):
		await tree.physics_frame

	assert_bool(bench.call("seated")).is_true()
	assert_bool(player.external_control).is_true()
	# On the seat's own top surface, not sunk into it or hovering over it.
	assert_vector(player.global_position).is_equal_approx(WorldAffordances.bench_sit_position(), Vector3.ONE * 0.01)
	assert_float(player.global_position.y).is_greater(WorldAffordances.BENCH_SEAT_TOP_Y)
	# Looking out over the seat (at the chalk circle), not at the backrest.
	var facing := -Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
	var to_circle := (WorldAffordances.BENCH_FACES - WorldAffordances.BENCH_POSITION).normalized()
	assert_float(facing.dot(to_circle)).is_greater(0.9)


func test_pressing_interact_again_gets_up() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(player.external_control).is_true()

	Game.interact()  # same button, no separate cancel input exists
	for _i in range(3):
		await tree.physics_frame

	assert_bool(bench.call("seated")).is_false()
	assert_bool(player.external_control).is_false()
	assert_float(player.global_position.y).is_equal_approx(player.locked_y, 0.01)
	# Stood up in FRONT of the bench, on ground they are allowed to stand on.
	assert_bool(WorldBounds.can_move_to(player.global_position.x, player.global_position.z)).is_true()


## The one that matters most: a player who has forgotten which key sat them
## down must still be able to leave by doing the obvious thing. Holding a
## movement key stands them up.
func test_trying_to_walk_away_gets_up_too() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(bench.call("seated")).is_true()

	runner.simulate_action_press("move_forward")
	for _i in range(10):
		await tree.physics_frame
	runner.simulate_action_release("move_forward")

	assert_bool(bench.call("seated")).is_false()
	assert_bool(player.external_control).is_false()


## ...but not INSTANTLY, if they were still holding the key they walked up
## with when they pressed interact. Sitting down and popping straight back
## up in the same breath is the failure this guards.
func test_sitting_down_mid_stride_does_not_pop_straight_back_up() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	runner.simulate_action_press("move_forward")  # still walking as they sit
	Game.interact()
	for _i in range(20):
		await tree.physics_frame
	assert_bool(bench.call("seated")).is_true()

	runner.simulate_action_release("move_forward")
	for _i in range(2):
		await tree.physics_frame
	runner.simulate_action_press("move_forward")  # a NEW press does leave
	for _i in range(6):
		await tree.physics_frame
	runner.simulate_action_release("move_forward")
	assert_bool(bench.call("seated")).is_false()


## Sitting is play, never a gate. Pressing interact on the bench must not
## advance, delay or otherwise touch the episode.
func test_sitting_never_moves_the_story() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	var state_before: String = Game.director.state
	Game.interact()
	for _i in range(30):
		await tree.physics_frame
	assert_str(Game.director.state).is_equal(state_before)
	Game.interact()
	for _i in range(10):
		await tree.physics_frame
	assert_str(Game.director.state).is_equal(state_before)


func test_a_fresh_run_mid_sit_hands_control_back() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(player.external_control).is_true()

	Game.start_episode(0.0)  # "Play again" mid-sit
	for _i in range(3):
		await tree.physics_frame

	assert_bool(bench.call("seated")).is_false()
	assert_bool(player.external_control).is_false()
