extends SceneTree
## One-shot generator: wires scenes/courtyard.tscn, scenes/player.tscn, and
## scenes/camera_rig.tscn into scenes/main.tscn -- the real M1.4 play
## camera, replacing the M1.2/M1.3 temporary static overview Camera3D.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_main_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "Main"

	var courtyard_packed: PackedScene = load("res://scenes/courtyard.tscn")
	var courtyard: Node = courtyard_packed.instantiate()
	root.add_child(courtyard)
	courtyard.owner = root

	# M1.3: the real player, positioned at the courtyard's "Start" key point
	# (game.mjs line 80's player.position = [0, 0, 6.5]). Not script-loaded
	# via load() here -- same reason as player.tscn's own generator: `Game`
	# autoload isn't registered this early in a bare --script run. Since
	# player.tscn already carries its own script reference (attached as a
	# plain ExtResource text edit after generation), instantiating the
	# PackedScene picks that up without needing to load the script here too.
	var player_packed: PackedScene = load("res://scenes/player.tscn")
	var player: Node3D = player_packed.instantiate()
	root.add_child(player)
	player.owner = root
	player.position = Vector3(0.0, 0.0, 6.5)

	# M1.4: the real play camera -- pivot -> SpringArm3D -> Camera3D, driven
	# every physics tick by CameraProfile.profile(player.z). Not script-
	# loaded via load() here, same reason as player.tscn's generator.
	var camera_rig_packed: PackedScene = load("res://scenes/camera_rig.tscn")
	var camera_rig: Node3D = camera_rig_packed.instantiate()
	root.add_child(camera_rig)
	camera_rig.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		printerr("Failed to save main.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/main.tscn with courtyard + temp overview camera")
	quit()
