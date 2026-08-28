extends SceneTree
## One-shot generator: builds scenes/ui/title_card.tscn -- verbatim-copy of
## index.html's #start-screen (lines 16-30).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_title_card_scene.gd

func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "TitleCard"
	root.layer = 10
	# NOTE: script deliberately NOT attached here -- same load()-in-
	# --script-mode "Identifier not found: Game" issue as player.tscn's
	# generator. Attached as a plain ExtResource text edit afterward.

	var center := CenterContainer.new()
	center.name = "Root"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	center.owner = root

	var card := VBoxContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_constant_override("separation", 14)
	center.add_child(card)
	card.owner = root

	var eyebrow := Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "Small World · Playtest Episode"
	card.add_child(eyebrow)
	eyebrow.owner = root

	var title := Label.new()
	title.name = "Title"
	title.text = "The Lost Ball"
	title.add_theme_font_size_override("font_size", 48)
	card.add_child(title)
	title.owner = root

	var lede := Label.new()
	lede.name = "Lede"
	lede.text = "You know the playground now. The other children know your face. But you are not quite part of their game—yet."
	lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(lede)
	lede.owner = root

	var begin_button := Button.new()
	begin_button.name = "BeginButton"
	begin_button.text = "Begin the afternoon"
	card.add_child(begin_button)
	begin_button.owner = root

	var controls := Label.new()
	controls.name = "ControlsSummary"
	controls.text = "Move: WASD / arrows · Interact: E or Space · Run: Shift"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(controls)
	controls.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/title_card.tscn")
	if err != OK:
		printerr("Failed to save title_card.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/title_card.tscn")
	quit()
