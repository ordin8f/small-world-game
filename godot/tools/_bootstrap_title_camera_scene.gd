extends SceneTree
const SCENE_PATH := "res://scenes/title_camera.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/title_camera.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/title_camera.tscn -- the S0/S1
## cinematic camera (see scripts/title_camera.gd's doc comment).
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## "Identifier not found: Game" issue as player.tscn/camera_rig.tscn's own
## generators. Attached as a plain ExtResource text edit afterward.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_title_camera_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "TitleCamera"

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	camera.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/title_camera.tscn")
	if err != OK:
		printerr("Failed to save title_camera.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/title_camera.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

