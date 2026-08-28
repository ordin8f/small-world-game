extends SceneTree
## One-shot generator: builds scenes/pocket_treasure.tscn -- a bare Node3D
## template, same minimal pattern as _bootstrap_interaction_zone_scene.gd.
## scripts/pocket_treasure.gd builds its own mesh procedurally in _ready(),
## keyed by KIND_DATA[name] (three kinds today: Marble/Stone/Feather),
## exactly the way character_visual.tscn is reused across NPCs.
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## "Identifier not found: Game" issue every other generator in this folder
## already works around; attached as a plain ExtResource text edit after.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_pocket_treasure_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "PocketTreasure"

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/pocket_treasure.tscn")
	if err != OK:
		printerr("Failed to save pocket_treasure.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/pocket_treasure.tscn")
	quit()
