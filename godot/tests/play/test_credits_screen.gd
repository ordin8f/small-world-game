extends GdUnitTestSuite
## Gate 0 frame play test (S7): credits show real ASSET_CREDITS.md sources
## and returning to the title actually shows the title again.

func test_credits_show_key_sources_and_return_to_title() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var credits: Node = runner.scene().get_node("CreditsScreen")
	var title_card: Node = runner.scene().get_node("TitleCard")

	# Mirrors title_card.gd's own _on_credits_pressed(): hide title, then
	# show credits -- so "return to title" below is actually exercising a
	# false -> true transition, not asserting a value that was never false.
	title_card.visible = false
	credits.show_credits()

	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(30):  # past CreditsScreen's own 0.3s fade_rise_in
		await tree.physics_frame
	assert_bool(credits.visible).is_true()
	assert_bool(title_card.visible).is_false()

	# Regression check (see test_title_sequence.gd's own doc comment on the
	# same bug class): the card must actually be opaque AND centered, not
	# just "visible" -- a fade animating 0 -> 0, or a Container child left
	# at a stale (0, 0) position, would both still pass a bare .visible
	# check.
	var card: Control = credits.get_node("Root/Card")
	var root: Control = credits.get_node("Root")
	assert_float(card.modulate.a).is_greater(0.95)
	var expected_x := (root.size.x - card.size.x) / 2.0
	var expected_y := (root.size.y - card.size.y) / 2.0
	assert_float(card.position.x).is_between(expected_x - 2.0, expected_x + 2.0)
	assert_float(card.position.y).is_between(expected_y - 2.0, expected_y + 2.0)

	var full_text := _all_label_text(credits)
	assert_bool(full_text.findn("Kenney") != -1).is_true()
	assert_bool(full_text.findn("Tiny Treats") != -1).is_true()
	assert_bool(full_text.findn("gdUnit4") != -1).is_true()

	var return_button: Button = credits.get_node("Root/Card/ReturnButton")
	return_button.pressed.emit()

	for _i in range(30):
		await tree.physics_frame

	assert_bool(credits.visible).is_false()
	assert_bool(title_card.visible).is_true()


func _all_label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	for child in node.get_children():
		text += _all_label_text(child)
	return text
