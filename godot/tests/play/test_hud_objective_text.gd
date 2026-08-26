extends GdUnitTestSuite
## M2.4 play test (GODOT_REBUILD_PLAN.md's literal accept criterion):
## "playthrough asserts objective text == STATE_COPY[state].objective
## after each transition." Drives dispatch() directly (the objective-text
## wiring only cares that state_changed fired, not how) through several
## real transitions and reads the actual Hud node's rendered Label text
## after each one.

func after_test() -> void:
	Engine.time_scale = 1.0


func test_objective_text_matches_state_copy_after_every_transition() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let every node's _ready() run, including Hud's

	var hud: Node = runner.scene().get_node("Hud")
	var objective_label: Label = hud.get_node("Root/Top/ObjectiveCard/ObjectiveText")

	Game.start_episode(0.0)
	await runner.simulate_frames(1)
	_assert_objective_matches(objective_label, EpisodeDirector.State.ARRIVE)
	assert_bool(hud.visible).is_true()

	for event_and_state in [
		["observe", EpisodeDirector.State.OBSERVED],
		["ball_kicked", EpisodeDirector.State.BALL_IN_FLIGHT],
		["ball_landed", EpisodeDirector.State.FIND_BALL],
		["ball_picked_up", EpisodeDirector.State.RETURN_BALL],
		["ball_returned", EpisodeDirector.State.INVITED],
		["joined", EpisodeDirector.State.GO_HOME],
		["entered_home", EpisodeDirector.State.COMPLETE],
	]:
		var event: String = event_and_state[0]
		var expected_state: String = event_and_state[1]
		assert_bool(Game.dispatch(event)).is_true()
		await runner.simulate_frames(1)
		assert_str(Game.director.state).is_equal(expected_state)
		_assert_objective_matches(objective_label, expected_state)

	# COMPLETE's dispatch() also schedules episode_complete (1.9s) which
	# hides the Hud (mirrors game.mjs's showEnding()) -- confirm that too.
	Engine.time_scale = 20.0
	var tree := Engine.get_main_loop() as SceneTree
	var waited := 0
	while hud.visible and waited < 300:
		await tree.physics_frame
		waited += 1
	assert_bool(hud.visible).is_false()


func _assert_objective_matches(objective_label: Label, state: String) -> void:
	var expected: String = EpisodeDirector.STATE_COPY[state]["objective"]
	assert_str(objective_label.text).is_equal(expected)
