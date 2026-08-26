extends SceneTree
## One-shot generator: builds scenes/ball.tscn -- Node3D with a sphere
## mesh (r 0.42, game.mjs's ball radius) in WorldBounds.PALETTE.ball's
## tone, emission enabled but at zero energy by default (ball.gd raises
## it only during FIND_BALL).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_ball_scene.gd

const RADIUS := 0.42
const BALL_COLOR := Color(0.83, 0.53, 0.18)


func _init() -> void:
	var root := Node3D.new()
	root.name = "Ball"
	# NOTE: script deliberately NOT attached here -- same load()-in-
	# --script-mode "Identifier not found: Game" issue as player.tscn's
	# generator. Attached as a plain ExtResource text edit afterward.

	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = BALL_COLOR
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = BALL_COLOR
	mat.emission_energy_multiplier = 0.0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = sphere
	mesh_instance.set_surface_override_material(0, mat)
	root.add_child(mesh_instance)
	mesh_instance.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/ball.tscn")
	if err != OK:
		printerr("Failed to save ball.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/ball.tscn")
	quit()
