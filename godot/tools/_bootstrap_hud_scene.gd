extends SceneTree
## One-shot generator: builds scenes/ui/hud.tscn -- verbatim-copy of
## index.html's #hud (lines 32-53): objective card, Sound/Reduce-motion
## toggles, dialogue card, interaction prompt.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_hud_scene.gd

func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "Hud"
	root.layer = 5
	# NOTE: script deliberately NOT attached here -- same reason as
	# player.tscn's generator (see its doc comment).

	var container := Control.new()
	container.name = "Root"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(container)
	container.owner = root

	_build_top(container, root)
	_build_dialogue_card(container, root)
	_build_prompt(container, root)

	var timer := Timer.new()
	timer.name = "DialogueTimer"
	timer.one_shot = true
	root.add_child(timer)
	timer.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/hud.tscn")
	if err != OK:
		printerr("Failed to save hud.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/hud.tscn")
	quit()


func _build_top(container: Control, root: Node) -> void:
	var top := HBoxContainer.new()
	top.name = "Top"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_top = 20
	top.offset_right = -24
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(top)
	top.owner = root

	var objective_card := VBoxContainer.new()
	objective_card.name = "ObjectiveCard"
	objective_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(objective_card)
	objective_card.owner = root

	var label := Label.new()
	label.name = "Label"
	label.text = "Right now"
	objective_card.add_child(label)
	label.owner = root

	var objective_text := Label.new()
	objective_text.name = "ObjectiveText"
	objective_text.text = "Look around."
	objective_text.add_theme_font_size_override("font_size", 20)
	objective_card.add_child(objective_text)
	objective_text.owner = root

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_child(buttons)
	buttons.owner = root

	var mute_button := Button.new()
	mute_button.name = "MuteButton"
	mute_button.text = "Sound on"
	mute_button.toggle_mode = true
	buttons.add_child(mute_button)
	mute_button.owner = root

	var motion_button := Button.new()
	motion_button.name = "MotionButton"
	motion_button.text = "Reduce motion"
	motion_button.toggle_mode = true
	buttons.add_child(motion_button)
	motion_button.owner = root


func _build_dialogue_card(container: Control, root: Node) -> void:
	var card := VBoxContainer.new()
	card.name = "DialogueCard"
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.offset_left = -260
	card.offset_right = 260
	card.offset_top = -140
	card.offset_bottom = -80
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(card)
	card.owner = root

	var speaker := Label.new()
	speaker.name = "Speaker"
	card.add_child(speaker)
	speaker.owner = root

	var text := Label.new()
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(text)
	text.owner = root


func _build_prompt(container: Control, root: Node) -> void:
	var prompt := HBoxContainer.new()
	prompt.name = "Prompt"
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -50
	prompt.offset_bottom = -20
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(prompt)
	prompt.owner = root

	var kbd := Label.new()
	kbd.name = "Kbd"
	kbd.text = "E"
	prompt.add_child(kbd)
	kbd.owner = root

	var prompt_text := Label.new()
	prompt_text.name = "PromptText"
	prompt_text.text = "Interact"
	prompt.add_child(prompt_text)
	prompt_text.owner = root
