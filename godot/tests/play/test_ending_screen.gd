extends GdUnitTestSuite
## Gate 0 frame play test (S6): the held-shot ending appears on the real
## episode_complete signal (driven through the actual state machine, same
## sequence test_playthrough.gd proves, just without walking the player --
## dispatch() doesn't care where the player physically is, only interact()
## does), marks Game.completed_once, and the sill renders 0..3 treasures
## correctly regardless of whether the (not-yet-built) pickup mechanic has
## ever run -- "the shot must work either way" (DEMO_PLAN.md S6).

const TIME_SCALE := 8.0
const MAX_WAIT_TICKS := 300


func after_test() -> void:
	Engine.time_scale = 1.0
	Game.completed_once = false
	Game.treasures_found = 0
	var abs_path := ProjectSettings.globalize_path(Game.SAVE_PATH)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func test_sill_shows_the_right_treasure_count_for_zero_through_three() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var ending: Node = runner.scene().get_node("EndingScreen")
	for count in [0, 1, 2, 3]:
		Game.set_treasures_found(count)
		ending._update_sill()
		var visible_count := 0
		for icon in ending.treasures:
			if icon.visible:
				visible_count += 1
		assert_int(visible_count).is_equal(count)


func test_episode_complete_shows_the_ending_and_marks_completed_once() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var ending: Node = runner.scene().get_node("EndingScreen")
	assert_bool(ending.visible).is_false()
	assert_bool(Game.completed_once).is_false()

	Game.start_episode(0.0)
	Engine.time_scale = TIME_SCALE
	var tree := Engine.get_main_loop() as SceneTree

	Game.dispatch("observe")
	await _wait_until_state_changes(tree, EpisodeDirector.State.OBSERVED)         # auto ball_kicked (2.6s)
	await _wait_until_state_changes(tree, EpisodeDirector.State.BALL_IN_FLIGHT)   # auto ball_landed (1.8s tween)
	assert_bool(Game.dispatch("ball_picked_up")).is_true()
	assert_bool(Game.dispatch("ball_returned")).is_true()
	assert_bool(Game.dispatch("joined")).is_true()
	assert_bool(Game.dispatch("entered_home")).is_true()
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.COMPLETE)

	# COMPLETE schedules episode_complete.emit() 1.9s later (game.gd).
	var waited := 0
	while not ending.visible and waited < MAX_WAIT_TICKS:
		await tree.physics_frame
		waited += 1

	assert_bool(ending.visible).is_true()
	assert_bool(Game.completed_once).is_true()

	# Regression check (see test_title_sequence.gd's own doc comment on the
	# same bug class): the frame overlay must actually become opaque, not
	# just "the CanvasLayer is visible" -- ending_screen.gd's own reveal
	# sequence takes ~0.9s (frame fade + a beat) before the frame itself is
	# fully in; give it real time (still at 8x scale) before checking.
	Engine.time_scale = TIME_SCALE
	for _i in range(120):
		await tree.physics_frame
	Engine.time_scale = 1.0
	var frame: Control = ending.get_node("Frame")
	assert_float(frame.modulate.a).is_greater(0.95)


func _wait_until_state_changes(tree: SceneTree, from_state: String) -> void:
	var waited := 0
	while Game.director.state == from_state and waited < MAX_WAIT_TICKS:
		await tree.physics_frame
		waited += 1
