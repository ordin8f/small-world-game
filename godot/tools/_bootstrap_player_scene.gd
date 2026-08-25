extends SceneTree
## One-shot generator: builds scenes/player.tscn -- CharacterBody3D with
## player.gd attached, CapsuleShape3D r0.32 matching WorldBounds' player
## radius (world.mjs's default canMoveTo radius), placeholder capsule mesh
## at the source's eventual character scale (1.08 m, game.mjs:100).
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

	var mesh_capsule := CapsuleMesh.new()
	mesh_capsule.radius = RADIUS
	mesh_capsule.height = HEIGHT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.83, 0.53, 0.18)  # WorldBounds.PALETTE.ball tone -- placeholder only
	mat.roughness = 0.7
	mesh_capsule.surface_set_material(0, mat)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PlaceholderMesh"
	mesh_instance.mesh = mesh_capsule
	mesh_instance.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	root.add_child(mesh_instance)
	mesh_instance.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/player.tscn")
	if err != OK:
		printerr("Failed to save player.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/player.tscn")
	quit()
