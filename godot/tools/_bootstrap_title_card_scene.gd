extends SceneTree
const SCENE_PATH := "res://scenes/ui/title_card.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/ui/title_card.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: rebuilds scenes/ui/title_card.tscn for the Gate 0
## frame (S0 boot + S1 title-over-live-world + relocated feedback surface).
## See scripts/ui/title_card.gd's doc comment for the behavior; this only
## builds the node tree its @onready paths expect.
##
## Script deliberately NOT attached here (to TitleCard, or to the instanced
## SettingsPanel) -- same load()-in---script-mode issue as the other UI
## generators. Attached as a plain ExtResource text edit afterward.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_title_card_scene.gd

func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "TitleCard"
	root.layer = 10

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 1)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	backdrop.owner = root

	var menu_root := CenterContainer.new()
	menu_root.name = "MenuRoot"
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu_root)
	menu_root.owner = root

	var card := VBoxContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(640, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 18)
	menu_root.add_child(card)
	card.owner = root

	var eyebrow := Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "CAREFREE"
	eyebrow.theme_type_variation = "Eyebrow"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(eyebrow)
	eyebrow.owner = root

	var wordmark := Label.new()
	wordmark.name = "Wordmark"
	wordmark.text = "The Lost Ball"
	wordmark.theme_type_variation = "Wordmark"
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(wordmark)
	wordmark.owner = root

	var menu_buttons := VBoxContainer.new()
	menu_buttons.name = "MenuButtons"
	menu_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_buttons.add_theme_constant_override("separation", 6)
	card.add_child(menu_buttons)
	menu_buttons.owner = root

	for entry in [["PlayButton", "Play"], ["SettingsButton", "Settings"], ["CreditsButton", "Credits"]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.theme_type_variation = "PlainButton"
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		menu_buttons.add_child(button)
		button.owner = root

	var settings_panel_packed: PackedScene = load("res://scenes/ui/settings_panel.tscn")
	var settings_panel: Control = settings_panel_packed.instantiate()
	settings_panel.name = "SettingsPanel"
	settings_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(settings_panel)
	settings_panel.owner = root

	var settings_back := Button.new()
	settings_back.name = "SettingsBack"
	settings_back.text = "Back"
	settings_back.theme_type_variation = "PlainButton"
	settings_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(settings_back)
	settings_back.owner = root

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Move: WASD / arrows  ·  Interact: E or Space  ·  Run: Shift"
	hint.theme_type_variation = "MutedText"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(hint)
	hint.owner = root

	# ---- feedback (relocated from the old end-card survey) -----------------
	var feedback_corner := Control.new()
	feedback_corner.name = "FeedbackCorner"
	feedback_corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	feedback_corner.offset_left = -220
	feedback_corner.offset_top = -48
	feedback_corner.offset_right = -20
	feedback_corner.offset_bottom = -16
	root.add_child(feedback_corner)
	feedback_corner.owner = root

	var feedback_button := Button.new()
	feedback_button.name = "FeedbackButton"
	feedback_button.text = "Playtest feedback"
	feedback_button.theme_type_variation = "PlainButton"
	feedback_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	feedback_corner.add_child(feedback_button)
	feedback_button.owner = root

	var feedback_popup := CenterContainer.new()
	feedback_popup.name = "FeedbackPopup"
	feedback_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(feedback_popup)
	feedback_popup.owner = root

	var feedback_card := PanelContainer.new()
	feedback_card.name = "FeedbackCard"
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = Color(0.05, 0.055, 0.05, 0.88)
	card_box.set_border_width_all(1)
	card_box.border_color = Color(1.0, 0.66, 0.28, 0.3)
	card_box.set_corner_radius_all(4)
	card_box.content_margin_left = 28
	card_box.content_margin_right = 28
	card_box.content_margin_top = 24
	card_box.content_margin_bottom = 24
	feedback_card.add_theme_stylebox_override("panel", card_box)
	feedback_popup.add_child(feedback_card)
	feedback_card.owner = root

	var fields := VBoxContainer.new()
	fields.name = "Fields"
	fields.custom_minimum_size = Vector2(560, 0)
	fields.add_theme_constant_override("separation", 10)
	feedback_card.add_child(fields)
	fields.owner = root

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Playtest feedback"
	heading.theme_type_variation = "ScreenHeading"
	fields.add_child(heading)
	heading.owner = root

	_question(fields, root, "ScaleGroup", "Did the world feel large from the child's height?", ["Yes", "Partly", "No"])
	_question(fields, root, "EmotionGroup", "How noticeable was the emotional shift?", ["TooSubtle:Too subtle", "AboutRight:About right", "TooStrong:Too strong"])
	_question(fields, root, "ContinueGroup", "Would you play another afternoon?", ["Yes", "Maybe", "No"])

	var notes_label := Label.new()
	notes_label.name = "NotesLabel"
	notes_label.text = "What did you notice or feel?"
	notes_label.theme_type_variation = "BodyText"
	fields.add_child(notes_label)
	notes_label.owner = root

	var notes := TextEdit.new()
	notes.name = "Notes"
	notes.custom_minimum_size = Vector2(0, 80)
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	fields.add_child(notes)
	notes.owner = root

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", 12)
	fields.add_child(actions)
	actions.owner = root

	var copy_button := Button.new()
	copy_button.name = "CopyButton"
	copy_button.text = "Copy playtest notes"
	copy_button.theme_type_variation = "PlainButton"
	actions.add_child(copy_button)
	copy_button.owner = root

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.theme_type_variation = "PlainButton"
	actions.add_child(close_button)
	close_button.owner = root

	var copy_status := Label.new()
	copy_status.name = "CopyStatus"
	copy_status.theme_type_variation = "MutedText"
	fields.add_child(copy_status)
	copy_status.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/title_card.tscn")
	if err != OK:
		printerr("Failed to save title_card.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/title_card.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()


## `labels` entries are either a plain name (button text == node name) or
## "NodeName:Button text" when they need to differ (CheckBox node names
## must match end_card.gd's original Yes/Partly/No-style short names so
## title_card.gd's exclusive-group wiring and _selected_value() ordering
## still lines up).
func _question(parent: VBoxContainer, scene_root: Node, group_name: String, legend_text: String, labels: Array) -> void:
	var legend := Label.new()
	legend.name = group_name + "Legend"
	legend.text = legend_text
	legend.theme_type_variation = "BodyText"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(legend)
	legend.owner = scene_root

	var group := HBoxContainer.new()
	group.name = group_name
	group.add_theme_constant_override("separation", 16)
	parent.add_child(group)
	group.owner = scene_root

	for entry in labels:
		var entry_str: String = entry
		var node_name: String = entry_str
		var text: String = entry_str
		if ":" in entry_str:
			var parts: PackedStringArray = entry_str.split(":", true, 1)
			node_name = parts[0]
			text = parts[1]
		var box := CheckBox.new()
		box.name = node_name
		box.text = text
		group.add_child(box)
		box.owner = scene_root

