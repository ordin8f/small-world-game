extends SceneTree
const SCENE_PATH := "res://scenes/ui/settings_panel.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/ui/settings_panel.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/ui/settings_panel.tscn -- the shared
## Sound/Reduce-motion block instanced by both title_card.tscn (S1) and
## pause_menu.tscn (S8). See scripts/ui/settings_panel.gd's doc comment.
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## issue as the other UI generators. Attached as a plain ExtResource text
## edit afterward.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_settings_panel_scene.gd

func _init() -> void:
	var root := VBoxContainer.new()
	root.name = "SettingsPanel"
	root.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "SETTINGS"
	heading.theme_type_variation = "Eyebrow"
	root.add_child(heading)
	heading.owner = root

	var mute_button := Button.new()
	mute_button.name = "MuteButton"
	mute_button.toggle_mode = true
	mute_button.text = "Sound on"
	mute_button.theme_type_variation = "PlainButton"
	root.add_child(mute_button)
	mute_button.owner = root

	var motion_button := Button.new()
	motion_button.name = "MotionButton"
	motion_button.toggle_mode = true
	motion_button.text = "Reduce motion"
	motion_button.theme_type_variation = "PlainButton"
	root.add_child(motion_button)
	motion_button.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ui/settings_panel.tscn")
	if err != OK:
		printerr("Failed to save settings_panel.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ui/settings_panel.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

