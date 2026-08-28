extends GdUnitTestSuite
## Gate 0 frame play test (S0/S1): the title is up over the live world at
## boot, and pressing Play ends with the title gone, the episode actually
## started, and the gameplay camera holding `current` -- title_camera.gd's
## glide has handed off cleanly rather than leaving two cameras fighting.

func after_test() -> void:
	Engine.time_scale = 1.0


func test_title_is_visible_at_boot_before_any_episode() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var title_card: Node = runner.scene().get_node("TitleCard")
	assert_bool(title_card.visible).is_true()
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.ARRIVE)

	var title_camera: Node = runner.scene().get_node("TitleCamera")
	assert_object(title_camera).is_same(Game.title_camera)
	assert_bool(title_camera.camera.current).is_true()


## Regression test for a real bug frame_shots_route.gd's screenshots caught
## that no earlier test did: UiMotion.fade_in/fade_rise_in used to infer
## their target alpha from the control's OWN current modulate.a, which
## every caller here had already zeroed for the pre-fade hidden state --
## so every fade animated 0 -> 0 and the wordmark/menu simply never
## appeared, invisibly, with every boolean-only assertion (.visible,
## director.state) still passing. Checking actual rendered alpha, not just
## .visible, is the only way this class of bug gets caught by a test
## rather than a screenshot.
func test_wordmark_and_menu_actually_reach_visible_alpha() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var title_card: Node = runner.scene().get_node("TitleCard")
	await _wait_seconds(2.2)  # past the full boot sequence (see title_card.gd's own timing doc)

	var wordmark: Label = title_card.get_node("MenuRoot/Card/Wordmark")
	var menu_buttons: Control = title_card.get_node("MenuRoot/Card/MenuButtons")
	assert_float(wordmark.modulate.a).is_greater(0.95)
	assert_float(menu_buttons.modulate.a).is_greater(0.95)


func test_play_hides_title_starts_episode_and_hands_off_the_camera() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var title_card: Node = runner.scene().get_node("TitleCard")
	# Past the boot hold + wordmark/menu fade-in (title_card.gd's
	# _play_boot_sequence) so the button is actually there to press.
	await _wait_seconds(1.6)

	var play_button: Button = title_card.get_node("MenuRoot/Card/MenuButtons/PlayButton")
	play_button.pressed.emit()

	# Past title_camera.gd's GLIDE_DURATION plus the menu fade-outs.
	await _wait_seconds(3.0)

	assert_bool(title_card.visible).is_false()
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.ARRIVE)
	assert_bool(is_instance_valid(Game.camera)).is_true()
	assert_bool(Game.camera.current).is_true()

	var title_camera: Node = runner.scene().get_node("TitleCamera")
	assert_bool(title_camera.camera.current).is_false()


func _wait_seconds(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ticks := int(seconds * 60.0)
	for _i in range(ticks):
		await tree.physics_frame
