extends SceneTree
const SCENE_PATH := "res://scenes/interaction_zone.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/interaction_zone.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/interaction_zone.tscn -- a bare
## Node3D template. Deliberately NOT an Area3D/CollisionShape3D: see
## interaction_zone.gd's doc comment for why (a physics trigger volume
## version reliably produced orphan-node warnings and an intermittent
## hang; game.mjs's own nearestInteraction() is a plain distance check
## anyway, so this is the more faithful port too).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_interaction_zone_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "InteractionZone"
	# NOTE: script deliberately NOT attached here -- same load()-in-
	# --script-mode "Identifier not found: Game" issue as player.tscn's
	# generator. Attached as a plain ExtResource text edit afterward.

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/interaction_zone.tscn")
	if err != OK:
		printerr("Failed to save interaction_zone.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/interaction_zone.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

