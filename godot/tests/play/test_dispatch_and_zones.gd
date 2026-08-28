extends GdUnitTestSuite
## M2.2 play test (GODOT_REBUILD_PLAN.md): drives the real Player into the
## real Watch InteractionZone via simulated WASD input, presses "interact",
## and asserts Game.dispatch() actually ran the state machine forward --
## then accelerates Engine.time_scale to confirm the OBSERVED -> ball_kicked
## timer (game.mjs:206's 2.6s schedule) fires on its own. This stops at
## BALL_IN_FLIGHT: the next real transition (ball_landed) is dispatched by
## ball.gd's flight-tween completion, which doesn't exist until M2.3 --
## the full 7-event playthrough test lives there once it does.

const TIME_SCALE := 20.0
const MAX_WAIT_TICKS := 300  # 5s of real ticks at 20x -> 100s covered, generous


func after_test() -> void:
	# Engine.time_scale is process-global -- always restore it, pass or
	# fail, or every test that runs after this one in the same run
	# inherits a scaled clock and its own timing assumptions break.
	Engine.time_scale = 1.0


func test_interact_at_watch_zone_dispatches_observe_and_auto_advances_to_ball_in_flight() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let every node's _ready() run (Player, CameraRig, zones)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()

	Game.start_episode(0.0)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.ARRIVE)

	var ticks := await DriveRoute.run(runner, player, [[0.0, -1.2]], func() -> void: pass)  # Watch marker
	assert_int(ticks).is_greater(0)

	assert_object(Game.active_zone).is_not_null()
	assert_str(Game.active_zone.event_name).is_equal("observe")

	runner.simulate_action_press("interact")
	await runner.simulate_frames(1)
	runner.simulate_action_release("interact")
	await runner.simulate_frames(1)

	assert_str(Game.director.state).is_equal(EpisodeDirector.State.OBSERVED)

	# Accelerate the clock so the 2.6s ball_kicked schedule() fires without
	# the test itself waiting 2.6 real seconds.
	Engine.time_scale = TIME_SCALE
	var tree := Engine.get_main_loop() as SceneTree
	var waited := 0
	while Game.director.state == EpisodeDirector.State.OBSERVED and waited < MAX_WAIT_TICKS:
		await tree.physics_frame
		waited += 1

	assert_str(Game.director.state).is_equal(EpisodeDirector.State.BALL_IN_FLIGHT)
