extends GdUnitTestSuite
## M2.3 play test (GODOT_REBUILD_PLAN.md): the test that gates every later
## milestone. Drives the real player through the full authored route with
## simulated WASD input, pressing "interact" at each zone and waiting for
## the auto-timers (ball_kicked, ball_landed) to fire on their own,
## asserting the full 7-event sequence completes: ARRIVE -> OBSERVED ->
## BALL_IN_FLIGHT -> FIND_BALL -> RETURN_BALL -> INVITED -> GO_HOME ->
## COMPLETE, with history size 8 (matching tests/logic.test.mjs's own
## 7-event assertion, M2.1's own port of which never exercised the real
## ball/zone/timer wiring -- this is that same claim, now against the
## actually-running game). Also spot-checks the ball never leaves a sane
## height envelope during its flight arc.

const TIME_SCALE := 8.0
const MAX_WAIT_TICKS := 600  # 10s of real ticks -- generous per auto-timer wait

const ROUTE_TO_WATCH := [[0.0, -1.2]]
# Both legs funnel through the garden-wall gap (matches
# test_camera_never_in_geometry.gd's route) -- a straight line from Watch
# to BallEnd, or BallEnd back to Group, cuts through the wall itself
# otherwise; a real player has to walk through the same opening both ways.
const ROUTE_TO_BALL := [[6.5, -3.0], [8.6, -6.6]]
const ROUTE_TO_GROUP := [[6.5, -3.0], [0.0, -3.8]]
const ROUTE_TO_JOIN := [[0.0, -3.1]]
const ROUTE_TO_DOOR := [[0.0, 10.8]]


func after_test() -> void:
	# Engine.time_scale is process-global -- always restore it, pass or
	# fail, so later suites in the same run don't inherit a scaled clock.
	Engine.time_scale = 1.0


func test_full_episode_reaches_complete_through_the_authored_route() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let every node's _ready() run

	var player: Node3D = Game.player
	var ball: Node3D = runner.scene().get_node("Ball")
	assert_object(player).is_not_null()
	assert_object(ball).is_not_null()

	Game.start_episode(0.0)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.ARRIVE)

	Engine.time_scale = TIME_SCALE
	var tree := Engine.get_main_loop() as SceneTree
	var stats := {"ball_min_y": INF, "ball_max_y": -INF}
	var track_ball := func() -> void:
		var y: float = ball.global_position.y
		stats["ball_min_y"] = minf(stats["ball_min_y"], y)
		stats["ball_max_y"] = maxf(stats["ball_max_y"], y)

	# 1. Watch -> observe -> OBSERVED
	await DriveRoute.run(runner, player, ROUTE_TO_WATCH, track_ball)
	_interact(runner)
	await _await_frames(2)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.OBSERVED)

	# 2. auto: OBSERVED -> ball_kicked -> BALL_IN_FLIGHT (2.6s timer)
	await _wait_until_state_changes(tree, track_ball, EpisodeDirector.State.OBSERVED)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.BALL_IN_FLIGHT)

	# 3. auto: ball flight tween completes -> ball_landed -> FIND_BALL (1.8s)
	await _wait_until_state_changes(tree, track_ball, EpisodeDirector.State.BALL_IN_FLIGHT)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.FIND_BALL)

	# The ball's flight arc (game.mjs:363's sin(t*PI)*2.1) just finished --
	# spot-check it stayed in a sane envelope: never below its "never
	# below 0.45" floor, never absurdly above the sin-arc's own ceiling
	# (start/end y 0.45 + arc height 2.1 + a little slack).
	assert_float(stats["ball_min_y"]).is_greater_equal(0.44)
	assert_float(stats["ball_max_y"]).is_less_equal(2.6)

	# 4. BallEnd -> ball_picked_up -> RETURN_BALL
	await DriveRoute.run(runner, player, ROUTE_TO_BALL, track_ball)
	_interact(runner)
	await _await_frames(2)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.RETURN_BALL)

	# 5. Group -> ball_returned -> INVITED
	await DriveRoute.run(runner, player, ROUTE_TO_GROUP, track_ball)
	_interact(runner)
	await _await_frames(2)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.INVITED)

	# 6. Join -> joined -> GO_HOME
	await DriveRoute.run(runner, player, ROUTE_TO_JOIN, track_ball)
	_interact(runner)
	await _await_frames(2)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.GO_HOME)

	# 7. Door -> entered_home -> COMPLETE
	await DriveRoute.run(runner, player, ROUTE_TO_DOOR, track_ball)
	_interact(runner)
	await _await_frames(2)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.COMPLETE)

	assert_int(Game.director.history.size()).is_equal(8)


func _interact(runner: GdUnitSceneRunner) -> void:
	runner.simulate_action_press("interact")
	runner.simulate_action_release("interact")


func _await_frames(n: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(n):
		await tree.physics_frame


func _wait_until_state_changes(tree: SceneTree, on_tick: Callable, from_state: String) -> void:
	var waited := 0
	while Game.director.state == from_state and waited < MAX_WAIT_TICKS:
		await tree.physics_frame
		on_tick.call()
		waited += 1
