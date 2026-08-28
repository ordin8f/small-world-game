extends SceneTree
## One-shot generator: builds scenes/imagination_prop.tscn -- a bare Node3D
## template, same minimal pattern as _bootstrap_interaction_zone_scene.gd
## (config looked up by node .name at runtime, not baked per-instance here).
## scripts/imagination_prop.gd builds its own base mesh + imagined overlay
## procedurally in _ready(), keyed by PROP_DATA[name] -- there are only two
## kinds today (CrateProp -> castle, BenchProp -> boat) but any number of
## future flagged props can reuse this one template the same way
## character_visual.tscn is reused across three very different NPCs.
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## "Identifier not found: Game" issue every other generator in this folder
## already works around; attached as a plain ExtResource text edit after.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_imagination_prop_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "ImaginationProp"

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/imagination_prop.tscn")
	if err != OK:
		printerr("Failed to save imagination_prop.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/imagination_prop.tscn")
	quit()
