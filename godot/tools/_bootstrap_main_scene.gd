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

	# M2.2: interaction zones, one per game.mjs:170-188 trigger. Positions
	# match courtyard.tscn's own Marker3D key points exactly (see
	# _bootstrap_courtyard.gd); radii live in interaction_zone.gd's
	# ZONE_DATA, keyed by node .name -- same --script-mode script-compile
	# limitation as player/camera_rig above (see interaction_zone.gd's doc
	# comment for why this is a plain distance check, not an Area3D).
	var zones_container := Node3D.new()
	zones_container.name = "InteractionZones"
	root.add_child(zones_container)
	zones_container.owner = root

	var zone_packed: PackedScene = load("res://scenes/interaction_zone.tscn")
	_interaction_zone(zone_packed, zones_container, root, "Watch", 0.0, -1.2)
	_interaction_zone(zone_packed, zones_container, root, "BallEnd", 8.6, -6.6)
	_interaction_zone(zone_packed, zones_container, root, "Return", 0.0, -3.8)
	_interaction_zone(zone_packed, zones_container, root, "Join", 0.0, -3.1)
	_interaction_zone(zone_packed, zones_container, root, "Door", 0.0, 10.8)

	# M2.3: the real ball -- starts at ballStart (game.mjs:115), flies to
	# ballEnd on BALL_IN_FLIGHT, carried/rest-positioned by state changes.
	var ball_packed: PackedScene = load("res://scenes/ball.tscn")
	var ball: Node3D = ball_packed.instantiate()
	root.add_child(ball)
	ball.owner = root

	# M2.3: three placeholder NPC capsules at game.mjs:89-93's NPC_DEFS
	# positions/headings/tints. Real Kenney character assets + AnimationTree
	# land in M3.1; these are pure static geometry for now, no script.
	var npcs_container := Node3D.new()
	npcs_container.name = "NPCs"
	root.add_child(npcs_container)
	npcs_container.owner = root

	_npc(npcs_container, root, "Mina", -0.95, -3.8, 0.2, Color(0.945, 0.918, 0.863))
	_npc(npcs_container, root, "Arun", 0.35, -4.25, -0.1, Color(0.918, 0.851, 0.761))
	_npc(npcs_container, root, "Third", 1.45, -3.55, -0.4, Color(0.788, 0.827, 0.878))

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		printerr("Failed to save main.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/main.tscn with courtyard + player + camera rig + interaction zones + ball + NPCs")
	quit()


func _interaction_zone(zone_packed: PackedScene, parent: Node3D, scene_root: Node, zone_name: String, x: float, z: float) -> void:
	var zone: Node3D = zone_packed.instantiate()
	zone.name = zone_name
	parent.add_child(zone)
	zone.owner = scene_root
	zone.position = Vector3(x, 0.0, z)


func _npc(parent: Node3D, scene_root: Node, npc_name: String, x: float, z: float, heading: float, tint: Color) -> void:
	const NPC_HEIGHT := 1.0
	const NPC_RADIUS := 0.28

	var body := Node3D.new()
	body.name = npc_name
	parent.add_child(body)
	body.owner = scene_root
	body.position = Vector3(x, 0.0, z)
	body.rotation.y = heading + PI  # characters.mjs:126 -- kenney rig faces +Z, flipped to face -Z like the player

	var capsule := CapsuleMesh.new()
	capsule.radius = NPC_RADIUS
	capsule.height = NPC_HEIGHT

	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.75

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PlaceholderMesh"
	mesh_instance.mesh = capsule
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.position = Vector3(0.0, NPC_HEIGHT * 0.5, 0.0)
	body.add_child(mesh_instance)
	mesh_instance.owner = scene_root
