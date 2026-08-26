extends SceneTree
## One-shot generator: builds scenes/ui/end_card.tscn -- verbatim-copy of
## index.html's #end-screen (lines 59-93): summary, three playtest
## questions, notes, "Copy playtest notes", "Play again".
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_end_card_scene.gd

func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "EndCard"
	root.layer = 10
	# NOTE: script deliberately NOT attached here -- same reason as
	# player.tscn's generator (see its doc comment).

	var center := CenterContainer.new()
	center.name = "Root"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	center.owner = root

	var card := VBoxContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(620, 0)
	card.add_theme_constant_override("separation", 12)
	center.add_child(card)
	card.owner = root

	var title := Label.new()
	title.name = "Title"
	title.text = "Episode complete"
	title.add_theme_font_size_override("font_size", 32)
	card.add_child(title)
	title.owner = root

	var summary := Label.new()
	summary.name = "Summary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(summary)
	summary.owner = root

	_question_group(card, root, "ScaleGroup", "Did the world feel large from the child's height?",
		["Yes", "Partly", "No"], ["Yes", "Partly", "No"])
	_question_group(card, root, "EmotionGroup", "How noticeable was the emotional shift?",
		["TooSubtle", "AboutRight", "TooStrong"], ["Too subtle", "About right", "Too strong"])
	_question_group(card, root, "ContinueGroup", "Would you play another afternoon?",
		["Yes", "Maybe", "No"], ["Yes", "Maybe", "No"])

	var notes_label := Label.new()
	notes_label.name = "NotesLabel"
	notes_label.text = "What did you notice or feel?"
	card.add_child(notes_label)
	notes_label.owner = root

	var notes := TextEdit.new()
	notes.name = "Notes"
	notes.custom_minimum_size = Vector2(0, 90)
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	card.add_child(notes)
	notes.owner = root

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	card.add_child(actions)
	actions.owner = root

	var copy_button := Button.new()
	copy_button.name = "CopyButton"
	copy_button.text = "Copy playtest notes"
	actions.add_child(copy_button)
	copy_button.owner = root

	var restart_button := Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "Play again"
	actions.add_child(restart_button)
	restart_button.owner = root

	var copy_status := Label.new()
	copy_status.name = "CopyStatus"
	card.add_child(copy_status)
	copy_status.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/end_card.tscn")
	if err != OK:
		printerr("Failed to save end_card.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/end_card.tscn")
	quit()


func _question_group(card: VBoxContainer, root: Node, group_name: String, legend: String, node_names: Array, labels: Array) -> void:
	var legend_label := Label.new()
	legend_label.name = group_name + "Legend"
	legend_label.text = legend
	legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(legend_label)
	legend_label.owner = root

	var group := HBoxContainer.new()
	group.name = group_name
	card.add_child(group)
	group.owner = root

	for i in range(node_names.size()):
		var box := CheckBox.new()
		box.name = node_names[i]
		box.text = labels[i]
		group.add_child(box)
		box.owner = root
