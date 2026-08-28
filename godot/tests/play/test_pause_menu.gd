extends GdUnitTestSuite
## Gate 0 frame play test (S8): Esc pauses/resumes during real gameplay,
## does nothing before Play, and Restart both unpauses and actually resets
## the episode. `runner.simulate_action_press/release("ui_cancel")` back to
## back with no frame in between mirrors test_playthrough.gd's own
## `_interact()` helper for "interact" -- the same proven pattern, applied
## to Godot's built-in ui_cancel action (Esc) instead.

func after_test() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0


func test_ui_cancel_does_nothing_before_play() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	_press_ui_cancel(runner)
	await runner.simulate_frames(2)

	assert_bool(get_tree().paused).is_false()

	var pause_menu: Node = runner.scene().get_node("PauseMenu")
	assert_bool(pause_menu.visible).is_false()


func test_ui_cancel_pauses_and_resumes_during_gameplay() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)
	await runner.simulate_frames(2)

	var pause_menu: Node = runner.scene().get_node("PauseMenu")
	assert_bool(pause_menu.visible).is_false()

	_press_ui_cancel(runner)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(20):  # past pause_menu.gd's own 0.2s fade_rise_in
		await tree.physics_frame
	assert_bool(get_tree().paused).is_true()
	assert_bool(pause_menu.visible).is_true()

	# Regression check (see test_title_sequence.gd's own doc comment on the
	# same bug class): actually opaque, not just "visible" while
	# fully transparent.
	var card: Control = pause_menu.get_node("Root/Card")
	assert_float(card.modulate.a).is_greater(0.95)

	_press_ui_cancel(runner)
	await runner.simulate_frames(2)
	assert_bool(get_tree().paused).is_false()
	assert_bool(pause_menu.visible).is_false()


func test_restart_unpauses_and_resets_to_arrive() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	Game.start_episode(0.0)
	await runner.simulate_frames(2)
	assert_bool(Game.dispatch("observe")).is_true()
	await runner.simulate_frames(2)
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.OBSERVED)

	var pause_menu: Node = runner.scene().get_node("PauseMenu")
	pause_menu.pause()
	await runner.simulate_frames(2)
	assert_bool(get_tree().paused).is_true()

	var restart_button: Button = pause_menu.get_node("Root/Card/MenuButtons/RestartButton")
	restart_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_bool(get_tree().paused).is_false()
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.ARRIVE)


func _press_ui_cancel(runner: GdUnitSceneRunner) -> void:
	runner.simulate_action_press("ui_cancel")
	runner.simulate_action_release("ui_cancel")
