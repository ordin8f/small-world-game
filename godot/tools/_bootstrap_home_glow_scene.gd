extends SceneTree
const SCENE_PATH := "res://scenes/home_glow.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/home_glow.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/home_glow.tscn -- a MeshInstance3D
## (PlaneMesh, positioned/rotated to stand upright at the home threshold,
## game.mjs:230) for home_glow.gd, which builds its own material in
## _ready().
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_home_glow_scene.gd

func _init() -> void:
	var root := MeshInstance3D.new()
	root.name = "HomeGlow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 3.0)
	root.mesh = plane
	root.position = Vector3(0.0, 1.7, 11.82)
	root.rotation.x = PI / 2.0  # PlaneMesh lies flat (XZ) by default; stand it upright to face the player
	# NOTE: script deliberately NOT attached here -- same reason as
	# perception.tscn's generator.

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/home_glow.tscn")
	if err != OK:
		printerr("Failed to save home_glow.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/home_glow.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

