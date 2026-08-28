extends SceneTree
const SCENE_PATH := "res://scenes/character_visual.tscn"
const SCENE_SCRIPT_PATH := "res://scripts/character_visual.gd"
const _BOOTSTRAP_SCENE_BINDER := preload("res://tools/scene_script_binder.gd")
## One-shot generator: builds scenes/character_visual.tscn -- a bare
## Node3D template for character_visual.gd, which loads its own glTF
## child and builds its own AnimationPlayer wiring in _ready() (config
## looked up via CHARACTER_DATA[name] -- see the script's doc comment).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_character_visual_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "CharacterVisual"
	# NOTE: script deliberately NOT attached here -- same reason as
	# interaction_zone.tscn's generator (see its doc comment).

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/character_visual.tscn")
	if err != OK:
		printerr("Failed to save character_visual.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/character_visual.tscn")
	if not _BOOTSTRAP_SCENE_BINDER.bind_root_script(SCENE_PATH, SCENE_SCRIPT_PATH):
		printerr("bootstrap scene script binding failed for ", SCENE_PATH)
		quit(1)
		return
	quit()

