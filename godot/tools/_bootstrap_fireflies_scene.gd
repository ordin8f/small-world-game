extends SceneTree
const SCENE_PATH := "res://scenes/fireflies.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/fireflies.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/fireflies.tscn -- a bare Node3D
## template for fireflies.gd (builds its own 12 sphere children in
## _ready()).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_fireflies_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "Fireflies"
	# NOTE: script deliberately NOT attached here -- same reason as
	# perception.tscn's generator.

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/fireflies.tscn")
	if err != OK:
		printerr("Failed to save fireflies.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/fireflies.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

