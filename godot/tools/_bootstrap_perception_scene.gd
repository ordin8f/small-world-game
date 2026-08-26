extends SceneTree
## One-shot generator: builds scenes/perception.tscn -- a bare Node
## template for perception.gd (finds WorldEnvironment/Sun via find_child()
## at runtime, needs no scene structure of its own).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_perception_scene.gd

func _init() -> void:
	var root := Node.new()
	root.name = "Perception"
	# NOTE: script deliberately NOT attached here -- same load()-in-
	# --script-mode "Identifier not found: Game" issue as player.tscn's
	# generator. Attached as a plain ExtResource text edit afterward.

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/perception.tscn")
	if err != OK:
		printerr("Failed to save perception.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/perception.tscn")
	quit()
