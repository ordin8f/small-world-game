extends SceneTree
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
	quit()
