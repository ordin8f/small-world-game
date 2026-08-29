extends SceneTree
const SCENE_PATH := "res://scenes/home_glow.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/home_glow.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/home_glow.tscn -- an OmniLight3D at
## the porch for home_glow.gd, which sets its own light properties in _ready().
## Was a translucent PlaneMesh at z=11.82 until the world expansion left it
## adrift mid-courtyard and walkable-through -- see home_glow.gd.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_home_glow_scene.gd

func _init() -> void:
	var root := OmniLight3D.new()
	root.name = "HomeGlow"
	root.position = Vector3(0.0, 2.05, 15.55)
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

