extends SceneTree
const SCENE_PATH := "res://scenes/ui/pause_menu.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/ui/pause_menu.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/ui/pause_menu.tscn (S8). See
## scripts/ui/pause_menu.gd's doc comment for behavior; this only builds
## the node tree its @onready paths expect.
##
## Script deliberately NOT attached here (to PauseMenu, or to the instanced
## SettingsPanel) -- same load()-in---script-mode issue as the other UI
## generators. Attached as a plain ExtResource text edit afterward.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_pause_menu_scene.gd

func _init() -> void:
	var root := CanvasLayer.new()
	root.name = "PauseMenu"
	root.layer = 20

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.02, 0.02, 0.02, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # blocks clicks from reaching the frozen world below
	root.add_child(backdrop)
	backdrop.owner = root

	var center := CenterContainer.new()
	center.name = "Root"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	center.owner = root

	var card := VBoxContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(360, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 16)
	center.add_child(card)
	card.owner = root

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Paused"
	heading.theme_type_variation = "ScreenHeading"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(heading)
	heading.owner = root

	var menu_buttons := VBoxContainer.new()
	menu_buttons.name = "MenuButtons"
	menu_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_buttons.add_theme_constant_override("separation", 6)
	card.add_child(menu_buttons)
	menu_buttons.owner = root

	for entry in [
		["ResumeButton", "Resume"],
		["RestartButton", "Restart the afternoon"],
		["SettingsButton", "Settings"],
		["QuitButton", "Quit"],
	]:
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

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/pause_menu.tscn")
	if err != OK:
		printerr("Failed to save pause_menu.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/pause_menu.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

