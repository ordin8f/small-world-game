extends SceneTree
## One-shot generator: builds scenes/ui/credits_screen.tscn (S7). Credit
## copy is condensed from ASSET_CREDITS.md -- keep both in sync by hand if
## that file changes; see scripts/ui/credits_screen.gd's doc comment.
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## issue as the other UI generators. Attached as a plain ExtResource text
## edit afterward.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_credits_screen_scene.gd

const ENTRIES := [
	["Kenney -- Mini Characters 1.0", "Player and playground children  ·  CC0 1.0"],
	["Tiny Treats -- Homely House 1.0", "The distant house  ·  CC0 1.0"],
	["Tiny Treats -- Pretty Park 1.0", "Trees, bench, bush, street lantern  ·  CC0 1.0"],
	["gdUnit4 (MikeSchulze)", "Test framework  ·  MIT"],
	["Godot Engine 4.7", "godotengine.org  ·  MIT"],
]


func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "CreditsScreen"
	root.layer = 11

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.02, 0.02, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	backdrop.owner = root

	var center := CenterContainer.new()
	center.name = "Root"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	center.owner = root

	var card := VBoxContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(560, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 16)
	center.add_child(card)
	card.owner = root

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Credits"
	heading.theme_type_variation = "ScreenHeading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(heading)
	heading.owner = root

	for i in range(ENTRIES.size()):
		var entry: Array = ENTRIES[i]
		var group := VBoxContainer.new()
		group.name = "Entry%d" % i
		group.add_theme_constant_override("separation", 2)
		card.add_child(group)
		group.owner = root

		var title := Label.new()
		title.name = "Title"
		title.text = entry[0]
		title.theme_type_variation = "BodyText"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(title)
		title.owner = root

		var sub := Label.new()
		sub.name = "Sub"
		sub.text = entry[1]
		sub.theme_type_variation = "MutedText"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		group.add_child(sub)
		sub.owner = root

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.custom_minimum_size = Vector2(0, 12)
	card.add_child(spacer)
	spacer.owner = root

	var return_button := Button.new()
	return_button.name = "ReturnButton"
	return_button.text = "Return to title"
	return_button.theme_type_variation = "PlainButton"
	return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(return_button)
	return_button.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/credits_screen.tscn")
	if err != OK:
		printerr("Failed to save credits_screen.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/credits_screen.tscn")
	quit()
