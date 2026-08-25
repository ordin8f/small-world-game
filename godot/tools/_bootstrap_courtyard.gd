extends SceneTree
## One-shot generator: builds scenes/courtyard.tscn from the exact numbers in
## src/scene.mjs's buildStaticWorld() (visual shapes), src/world.mjs's
## COLLIDERS (physical walls), and src/game.mjs's lighting/fog (lines 41-59)
## and interaction key points (lines 114-116, 170-188).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_courtyard.gd
## Re-run any time the shape list below changes, then re-run --import.
##
## Materials are matte StandardMaterial3D (roughness 0.92, metalness 0,
## palette colors as plain 0..1 floats -- no hex round-trip needed, unlike
## the JS source, since Godot's Color already takes 0..1 components).

const ROUGHNESS := 0.92


func _init() -> void:
	var root := Node3D.new()
	root.name = "Courtyard"

	_add_lighting(root)
	_build_static_world(root)
	_add_wall_colliders(root)
	_add_key_point_markers(root)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/courtyard.tscn")
	if err != OK:
		printerr("Failed to save courtyard.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/courtyard.tscn (%d children)" % root.get_child_count())
	quit()


# ---------------------------------------------------------------- lighting --

func _add_lighting(root: Node3D) -> void:
	# game.mjs:41 -- scene.fog = new THREE.Fog(0x4f6070, 10, 27)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0x4f / 255.0, 0x60 / 255.0, 0x70 / 255.0)
	env.fog_enabled = true
	env.fog_light_color = Color(0x4f / 255.0, 0x60 / 255.0, 0x70 / 255.0)
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 27.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# game.mjs:45 -- HemisphereLight(sky 0x9fb0c0, ground 0x4a4030, 1.6). Godot's
	# Environment ambient is a single color, not sky/ground -- use the sky tone
	# and let the ground bounce be approximated by the directional sun's fill.
	env.ambient_light_color = Color(0x9f / 255.0, 0xb0 / 255.0, 0xc0 / 255.0)
	env.ambient_light_energy = 1.6

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)
	world_env.owner = root

	# game.mjs:48-58 -- DirectionalLight(0xffd59a, 2.4) at (5.5, 10, 3.5), shadows on.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(0xff / 255.0, 0xd5 / 255.0, 0x9a / 255.0)
	sun.light_energy = 2.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	# Orient the light so it shines FROM (5.5, 10, 3.5) TOWARD the origin, matching
	# the JS DirectionalLight's implicit target-at-origin behavior. Node3D.look_at()
	# requires the node to already be inside the SceneTree (not true for a
	# generator script building an unparented scene in memory) -- use
	# look_at_from_position(), which computes the same basis without that
	# requirement, then add the node with its transform already set.
	sun.transform = Transform3D.IDENTITY
	sun.look_at_from_position(Vector3(5.5, 10.0, 3.5), Vector3.ZERO, Vector3.UP)
	root.add_child(sun)
	sun.owner = root


# ------------------------------------------------------------- visual mesh --

func _mesh(root: Node3D, kind: String, position: Vector3, scale: Vector3, color: Color, rotation_rad: Vector3 = Vector3.ZERO, emissive: float = 0.0) -> void:
	var mesh: Mesh
	match kind:
		"cube":
			mesh = BoxMesh.new()
			mesh.size = Vector3.ONE
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 20
			sm.rings = 16
			mesh = sm
		"cylinder":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.5
			cm.height = 1.0
			cm.radial_segments = 16
			mesh = cm
		"cone":
			var co := CylinderMesh.new()
			co.top_radius = 0.0
			co.bottom_radius = 0.5
			co.height = 1.0
			co.radial_segments = 16
			mesh = co
		_:
			push_error("Unknown shape kind: %s" % kind)
			return

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = ROUGHNESS
	mat.metallic = 0.0
	if emissive > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emissive
	mesh.surface_set_material(0, mat)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	root.add_child(instance)
	instance.owner = root
	instance.position = position
	instance.scale = scale
	instance.rotation = rotation_rad
	instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC


# Palette (src/world.mjs) as Color(0..1) -- no hex round-trip needed.
const PLASTER := Color(0.68, 0.62, 0.52)
const PLASTER_LIGHT := Color(0.78, 0.71, 0.58)
const GROUND := Color(0.36, 0.37, 0.29)
const PATH := Color(0.66, 0.57, 0.40)
const WOOD := Color(0.34, 0.20, 0.12)
const WOOD_LIGHT := Color(0.62, 0.38, 0.20)
const FOLIAGE := Color(0.18, 0.34, 0.22)
const FOLIAGE_LIGHT := Color(0.34, 0.50, 0.28)
const SLIDE := Color(0.80, 0.30, 0.16)
const WARM_LIGHT := Color(1.0, 0.66, 0.28)


func _build_static_world(root: Node3D) -> void:
	# Courtyard shell: deliberately tall, sparse, and child-scaled.
	_mesh(root, "cube", Vector3(0, -0.28, -1), Vector3(22, 0.5, 27), GROUND)
	_mesh(root, "cube", Vector3(0, -0.01, 3.8), Vector3(7.2, 0.08, 14.5), PATH)
	_mesh(root, "cube", Vector3(-10.7, 3.8, -1), Vector3(1.1, 8.2, 29), PLASTER)
	_mesh(root, "cube", Vector3(10.7, 3.8, -1), Vector3(1.1, 8.2, 29), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(0, 4, -13.3), Vector3(23, 8.5, 1.1), PLASTER)

	# Home threshold.
	_mesh(root, "cube", Vector3(-3.8, 2.2, 12.0), Vector3(6.7, 4.7, 0.8), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(3.8, 2.2, 12.0), Vector3(6.7, 4.7, 0.8), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(0, 4.35, 12.0), Vector3(1.2, 1.2, 0.8), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(0, 1.7, 12.15), Vector3(2.5, 3.5, 0.18), WARM_LIGHT, Vector3.ZERO, 0.9)

	# Playground towers, bridge, and slide.
	for x in [-3.4, 3.4]:
		_mesh(root, "cube", Vector3(x, 1.25, -5.6), Vector3(2.3, 2.4, 2.3), WOOD_LIGHT)
		_mesh(root, "cube", Vector3(x, 2.75, -5.6), Vector3(2.7, 0.25, 2.7), WOOD)
		_mesh(root, "cone", Vector3(x, 4.0, -5.6), Vector3(2.0, 1.8, 2.0), WOOD_LIGHT)
		for dx in [-0.8, 0.8]:
			for dz in [-0.8, 0.8]:
				_mesh(root, "cylinder", Vector3(x + dx, 0.5, -5.6 + dz), Vector3(0.16, 3.8, 0.16), WOOD)
	_mesh(root, "cube", Vector3(0, 2.3, -5.6), Vector3(4.8, 0.25, 1.15), WOOD)
	_mesh(root, "cube", Vector3(-3.4, 0.95, -2.9), Vector3(1.25, 0.18, 5.2), SLIDE, Vector3(-0.54, 0, 0))

	# Garden wall with one discoverable opening.
	_mesh(root, "cube", Vector3(5.4, 0.55, -5.9), Vector3(0.6, 1.2, 4.2), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(5.4, 0.55, -1.1), Vector3(0.6, 1.2, 1.4), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(8.1, 0.55, -0.8), Vector3(4.7, 1.2, 0.6), PLASTER_LIGHT)

	# Puddles, stepping stones, and bench.
	var puddle_color := Color(0.20, 0.32, 0.37, 0.65)
	for p in [
		[-1.5, 0.01, 3.2, 1.6, 0.04, 0.9],
		[2.1, 0.01, 0.8, 1.15, 0.04, 0.75],
		[6.8, 0.01, -4.2, 1.4, 0.04, 0.8],
	]:
		_mesh(root, "sphere", Vector3(p[0], p[1], p[2]), Vector3(p[3], p[4], p[5]), puddle_color)
	for stone in [[6.1, -2.5, 0.45], [6.9, -3.2, 0.52], [7.7, -3.9, 0.48], [8.4, -4.7, 0.55]]:
		var s: float = stone[2]
		_mesh(root, "sphere", Vector3(stone[0], 0.05, stone[1]), Vector3(s, 0.14, s * 0.85), PATH)
	_mesh(root, "cube", Vector3(-7.4, 0.7, -0.8), Vector3(3.1, 0.25, 0.8), WOOD_LIGHT)
	_mesh(root, "cube", Vector3(-8.5, 0.35, -0.8), Vector3(0.18, 1.2, 0.65), WOOD)
	_mesh(root, "cube", Vector3(-6.3, 0.35, -0.8), Vector3(0.18, 1.2, 0.65), WOOD)

	_add_tree(root, -7.6, 1.7, 1.05)
	_add_tree(root, 8.3, -8.2, 1.25)
	_add_tree(root, 7.9, 6.2, 0.9)

	for bush in [[8.2, -6.1, 1.0], [7.0, -7.3, 0.8], [9.1, -3.2, 0.85], [-8.7, -6.5, 0.9], [-8.8, 7.5, 1.0], [8.8, 8.6, 0.9]]:
		var s: float = bush[2]
		_mesh(root, "sphere", Vector3(bush[0], 0.55 * s, bush[1]), Vector3(1.3 * s, 1.0 * s, 1.1 * s), FOLIAGE)

	var flower_color := Color(0.85, 0.72, 0.42)
	for flower in [[6.2, -5.5], [6.7, -6.3], [8.8, -5.6], [9.0, -7.0], [-8.4, 4.2], [-9.0, 5.0]]:
		_mesh(root, "cylinder", Vector3(flower[0], 0.25, flower[1]), Vector3(0.035, 0.5, 0.035), FOLIAGE_LIGHT)
		_mesh(root, "sphere", Vector3(flower[0], 0.52, flower[1]), Vector3(0.14, 0.1, 0.14), flower_color, Vector3.ZERO, 0.15)

	# Sparse grass blades soften the route without filling the scene with clutter.
	for index in range(34):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z: float = -10.5 + fmod(index * 0.67, 20.0)
		var x: float = side * (4.3 + fmod(index * 1.91, 4.4))
		var height: float = 0.32 + (index % 5) * 0.07
		var blade_color := FOLIAGE_LIGHT if index % 3 == 0 else FOLIAGE
		_mesh(root, "cone", Vector3(x, height * 0.48, z), Vector3(0.12, height, 0.12), blade_color)


func _add_tree(root: Node3D, x: float, z: float, s: float) -> void:
	_mesh(root, "cylinder", Vector3(x, 1.25 * s, z), Vector3(0.42 * s, 2.5 * s, 0.42 * s), WOOD)
	_mesh(root, "sphere", Vector3(x, 3.15 * s, z), Vector3(2.4 * s, 2.1 * s, 2.3 * s), FOLIAGE)
	_mesh(root, "sphere", Vector3(x - 0.8 * s, 3.4 * s, z + 0.2 * s), Vector3(1.5 * s, 1.3 * s, 1.5 * s), FOLIAGE_LIGHT)


# ------------------------------------------------------------ wall colliders --

func _add_wall_colliders(root: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "WallColliders"
	root.add_child(walls)
	walls.owner = root

	for box in WorldBounds.COLLIDERS:
		_wall_collider(walls, box["x"], box["z"], box["half_x"], box["half_z"])

	# Plan 1.2: "plus an invisible bound at z=12.3" -- the upper z bound
	# (can_move_to rejects z > 12) as a real thin wall so the camera/player
	# can't clip past the home threshold's z edge.
	_wall_collider(walls, 0.0, 12.3, 11.5, 0.05)


func _wall_collider(parent: Node3D, x: float, z: float, half_x: float, half_z: float) -> void:
	const HEIGHT := 2.4
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.owner = parent.owner if parent.owner else parent
	body.position = Vector3(x, HEIGHT * 0.5, z)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half_x * 2.0, HEIGHT, half_z * 2.0)
	shape.shape = box
	body.add_child(shape)
	shape.owner = parent.owner if parent.owner else parent


# --------------------------------------------------------- key point markers --

## `parent` is where the marker is added (e.g. the "KeyPoints" container);
## `scene_root` is the TRUE PackedScene root -- every node's .owner must be
## this exact node (not just any ancestor) or pack() silently drops it.
func _marker(parent: Node3D, scene_root: Node, marker_name: String, x: float, z: float, radius: float) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	parent.add_child(marker)
	marker.owner = scene_root
	marker.position = Vector3(x, 0.0, z)
	marker.set_meta("radius", radius)


func _add_key_point_markers(root: Node3D) -> void:
	var markers := Node3D.new()
	markers.name = "KeyPoints"
	root.add_child(markers)
	markers.owner = root

	# game.mjs: player start (line 80), group/ball (114-116), interaction
	# radii (170-188).
	_marker(markers, root, "Start", 0.0, 6.5, 0.0)
	_marker(markers, root, "Group", 0.0, -3.8, 0.0)
	_marker(markers, root, "Watch", 0.0, -1.2, 2.3)
	_marker(markers, root, "BallEnd", 8.6, -6.6, 1.45)
	_marker(markers, root, "Return", 0.0, -3.8, 2.1)  # same position as Group, own radius
	_marker(markers, root, "Join", 0.0, -3.1, 2.2)
	_marker(markers, root, "Door", 0.0, 10.8, 1.8)
