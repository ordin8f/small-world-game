extends SceneTree
const SCENE_PATH := "res://scenes/player.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/player.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/player.tscn -- CharacterBody3D with
## player.gd attached, CapsuleShape3D r0.32 matching WorldBounds' player
## radius (world.mjs's default canMoveTo radius), and a CharacterVisual
## child (M3.1) named "Player" for character_visual.gd's CHARACTER_DATA
## lookup, carrying the real Kenney character model.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_player_scene.gd

const RADIUS := 0.32
const HEIGHT := 1.08


func _init() -> void:
	var root := CharacterBody3D.new()
	root.name = "Player"
	# NOTE: script is deliberately NOT attached here. Loading/compiling
	# player.gd via load() at this point in --script mode's lifecycle fails
	# with "Identifier not found: Game" -- the Game/DebugBridge/DebugOverlay
	# autoloads aren't yet registered as global GDScript identifiers this
	# early in a bare --script run (confirmed this is specific to that
	# context: `tools/import.sh`, the real compile path used by the editor,
	# export, and the running game, compiles player.gd with Game resolving
	# fine). The script is attached as a plain ExtResource text edit after
	# this generator saves the scene -- see godot/scenes/player.tscn.
	root.collision_layer = 1
	root.collision_mask = 1

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	root.add_child(shape)
	shape.owner = root

	# M3.1: the real Kenney character model. Named "Player" (not
	# "CharacterVisual") for character_visual.gd's CHARACTER_DATA[name]
	# lookup -- see that script's doc comment for why config can't be set
	# here via @export instead. Not script-loaded via load() here, same
	# reason as this generator not loading player.gd itself.
	var visual_packed: PackedScene = load("res://scenes/character_visual.tscn")
	var visual: Node3D = visual_packed.instantiate()
	visual.name = "Player"
	root.add_child(visual)
	visual.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/player.tscn")
	if err != OK:
		printerr("Failed to save player.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/player.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

