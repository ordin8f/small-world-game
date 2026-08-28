extends SceneTree
const SCENE_PATH := "res://scenes/camera_rig.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/camera_rig.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/camera_rig.tscn -- Node3D pivot ->
## SpringArm3D -> Camera3D, matching camera_rig.gd's expected child paths
## ($SpringArm3D, $SpringArm3D/Camera3D).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_camera_rig_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "CameraRig"
	# NOTE: script is deliberately NOT attached here -- same load()-in-
	# --script-mode "Identifier not found: Game" issue as player.tscn's
	# generator (see _bootstrap_player_scene.gd for the full explanation).
	# Attached as a plain ExtResource text edit after this generator saves
	# the scene -- see godot/scenes/camera_rig.tscn.

	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 12.0  # THRESHOLD.distance -- sane default before the first physics tick
	arm.margin = 0.15
	root.add_child(arm)
	arm.owner = root

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 46.0  # THRESHOLD.fov -- avoids a visible pop from Godot's default 75
	cam.current = true
	arm.add_child(cam)
	cam.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/camera_rig.tscn")
	if err != OK:
		printerr("Failed to save camera_rig.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/camera_rig.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

