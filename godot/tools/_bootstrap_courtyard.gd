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
	_add_props(root)

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
	# The Environment and Sun are created BARE here and authored at runtime by
	# scripts/perception.gd from resources/moods/*.tres.
	#
	# Lighting values deliberately do NOT live in this file any more. The previous
	# version hardcoded a fog colour, fog range, and an ambient_light_energy of 1.6
	# (a literal port of src/game.mjs:45's HemisphereLight) which flooded every
	# shadow flat -- and perception.gd overwrote all of it every physics frame
	# anyway. See the architecture note at the top of perception.gd.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ssao_enabled = true
	env.adjustment_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)
	world_env.owner = root

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	# A sane default placement so an isolated scene (e.g. a scene-only test with no
	# Perception node) is not pitch black. The mood presets override colour,
	# energy and angle every physics frame in the real game.
	sun.transform = Transform3D.IDENTITY
	sun.look_at_from_position(Vector3(18.0, 8.0, 10.0), Vector3(0.0, 1.2, -2.0), Vector3.UP)
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
## Deep stone for passage ceilings and undersides. ART_DIRECTION.md wants "warm
## natural light with deep but readable shadow"; the pale plaster dissolves into
## the fog at distance, so surfaces meant to read as dark need their own value.
const SHADOW_STONE := Color(0.24, 0.21, 0.19)


func _build_static_world(root: Node3D) -> void:
	# Courtyard shell: deliberately tall, sparse, and child-scaled.
	_mesh(root, "cube", Vector3(0, -0.28, -1), Vector3(22, 0.5, 27), GROUND)
	_mesh(root, "cube", Vector3(0, -0.01, 3.8), Vector3(7.2, 0.08, 14.5), PATH)
	_mesh(root, "cube", Vector3(-10.7, 3.8, -1), Vector3(1.1, 8.2, 29), PLASTER)
	_mesh(root, "cube", Vector3(10.7, 3.8, -1), Vector3(1.1, 8.2, 29), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(0, 4, -13.3), Vector3(23, 8.5, 1.1), PLASTER)

	# Home threshold, built as a PASSAGE rather than a flat wall.
	#
	# docs/concept-art/extended/concept_07_circle.png carries the episode's
	# premise architecturally: the child stands inside a dark threshold, framed
	# by two heavy piers, looking out into a sunlit courtyard where the other
	# three play in the chalk circle. Outside the group and outside the light
	# are the same fact, said by the framing rather than by dialogue.
	#
	# The piers and lintel already existed here as a thin z=12.0 wall; the player
	# simply started 5.5 m in front of them facing away, so the opening was never
	# in shot. Deepening them to a 2 m passage and starting the player under it
	# (player.gd START_POSITION) is what puts the composition on screen.
	#
	# Opening widened from 0.9 m to 2.4 m so the child and the camera both fit
	# through it. No collider changes: WorldBounds has no box here at all, the
	# player is stopped by the z=12.3 bound, and the piers sit either side of the
	# walked centre line.
	_mesh(root, "cube", Vector3(-4.18, 2.2, 11.6), Vector3(5.95, 4.7, 2.0), PLASTER)
	_mesh(root, "cube", Vector3(4.18, 2.2, 11.6), Vector3(5.95, 4.7, 2.0), PLASTER)
	# Lintel + roof slab: the dark ceiling that makes it read as a passage.
	_mesh(root, "cube", Vector3(0, 4.35, 11.6), Vector3(2.6, 1.2, 2.0), PLASTER)
	_mesh(root, "cube", Vector3(0, 3.95, 11.6), Vector3(2.5, 0.35, 2.2), SHADOW_STONE)
	# The warm window/porch light -- the anchor ART_DIRECTION.md asks dusk to
	# resolve onto. Behind the player at the start, ahead of them at the end.
	_mesh(root, "cube", Vector3(0, 1.7, 12.55), Vector3(2.5, 3.5, 0.18), WARM_LIGHT, Vector3.ZERO, 0.9)


	# DEFERRED: the concept_07 framing gateway. It has to stand between the
	# camera and the player, so its position depends on where the camera
	# actually settles -- and camera_rig.gd's z clamp is being fixed right now
	# (it currently pins the camera near z=11.05 for the whole route, so real
	# camera-to-player distance swings 0.7 m to 16 m against an authored 12-16).
	# Placing a framing device against a camera that is known-wrong would bake
	# the bug into the level. Revisit once the clamp lands.

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

	# Garden wall with one discoverable opening, built as an ARCH.
	#
	# concept_06_garden_gap.png: the way through is not a slot between two wall
	# segments, it is a low overgrown arched opening the child ducks through,
	# with the ball glowing in golden light on the far side. Spanning the gap
	# turns "a hole in a wall" into something to look through -- and gives the
	# volumetric fog an edge to shaft against, which an open slot does not.
	#
	# Purely visual. The two wall colliders either side of the gap
	# (world_bounds.gd:30-31) are untouched and the opening is unchanged in
	# plan, so test_garden_gap.gd still guards the same route.
	_mesh(root, "cube", Vector3(5.4, 0.55, -5.9), Vector3(0.6, 1.2, 4.2), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(5.4, 0.55, -1.1), Vector3(0.6, 1.2, 1.4), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(8.1, 0.55, -0.8), Vector3(4.7, 1.2, 0.6), PLASTER_LIGHT)
	# The span over the opening, plus shoulders stepping down to it -- a coarse
	# arch, in keeping with ART_DIRECTION.md's "broad architectural planes,
	# modest geometric detail".
	_mesh(root, "cube", Vector3(5.4, 1.55, -2.8), Vector3(0.72, 0.8, 2.4), PLASTER)
	_mesh(root, "cube", Vector3(5.4, 1.12, -3.55), Vector3(0.66, 0.5, 0.75), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(5.4, 1.12, -2.05), Vector3(0.66, 0.5, 0.75), PLASTER_LIGHT)
	# Vegetation swallowing the arch, as in the plate.
	for creeper in [[-3.9, 0.62], [-2.9, 0.5], [-1.9, 0.58]]:
		_mesh(root, "sphere", Vector3(5.4, 1.9, creeper[0]), Vector3(1.05, 0.55, creeper[1] * 1.6), FOLIAGE)

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
	# M3.2: real bench.gltf at the procedural bench's own position/footprint
	# (the primitive cube trio it replaces was itself at this spot).
	_prop(root, "res://assets/park/bench.gltf", Vector3(-7.4, 0.0, -0.8))

	_add_tree(root, -7.6, 1.7, 1.05)
	_add_tree(root, 8.3, -8.2, 1.25)
	_add_tree(root, 7.9, 6.2, 0.9)


	# DEFERRED: the overhead canopy that frames the top of frame in
	# concept_03/06/07. First attempt hung foliage spheres at y 6-7.5 with no
	# trunk; from the play camera they read as floating discs, not a canopy.
	# Doing this properly means canopy attached to real trees at the frame
	# edges, sized against where the camera actually sits -- which is being
	# fixed right now. Same reason as the gateway below.

	# M3.2: ASSET_CREDITS.md's one featured bush_large.gltf, at the
	# procedural bush-sphere spot nearest the bench/tree cluster (the other
	# 5 procedural spheres stay as generic scattered shrubbery -- the credit
	# describes one specific bush, not six).
	_prop(root, "res://assets/park/bush_large.gltf", Vector3(-8.7, 0.0, -6.5))

	for bush in [[8.2, -6.1, 1.0], [7.0, -7.3, 0.8], [9.1, -3.2, 0.85], [-8.8, 7.5, 1.0], [8.8, 8.6, 0.9]]:
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


## M3.2: real tree_large.gltf, replacing the 3-primitive trunk+foliage
## composition -- same positions and the same per-tree scale factors
## (1.05/1.25/0.9) game.mjs's addTree() used for size variety.
func _add_tree(root: Node3D, x: float, z: float, s: float) -> void:
	_prop(root, "res://assets/park/tree_large.gltf", Vector3(x, 0.0, z), s)


## M3.2: the two ASSET_CREDITS.md props with no equivalent in game.mjs's
## (entirely-procedural) buildStaticWorld() -- placements chosen here, not
## extracted from the source, since nothing in scene.mjs positions a
## street lantern or a house:
## - street_lantern.gltf: beside the path approaching the home threshold,
##   an unclaimed spot that reads as "lighting the way home." Moved off
##   to the path's edge (M3.4): its original x=2.2 sat almost exactly
##   where CameraProfile's authored z clamp (game.mjs:399-400) rests the
##   camera for the watch/circle beats (x~0.6-1.3, z~11.05), so the lamp
##   loomed in the immediate foreground instead of reading as scenery --
##   found shooting M3.4's "watch" reference frame.
## - house.gltf: ASSET_CREDITS.md's own "one distant house model" -- placed
##   just beyond the home threshold's z=12 wall (WorldBounds' z<=12 bound
##   means the player can never reach it), glimpsed through the doorway
##   gap rather than standing inside the walkable courtyard.
func _add_props(root: Node3D) -> void:
	_prop(root, "res://assets/park/street_lantern.gltf", Vector3(4.5, 0.0, 9.2))
	_prop(root, "res://assets/house/house.gltf", Vector3(0.0, 0.0, 16.0))


## Instances a glTF PackedScene as a purely visual prop -- WorldBounds'
## own box colliders remain the sole source of collision, untouched here.
func _prop(root: Node3D, path: String, position: Vector3, scale: float = 1.0, rotation_y: float = 0.0) -> void:
	var packed: PackedScene = load(path)
	var inst: Node3D = packed.instantiate()
	root.add_child(inst)
	inst.owner = root
	inst.position = position
	inst.scale = Vector3.ONE * scale
	inst.rotation.y = rotation_y
	# M3.3: the Tiny Treats glTF props ship with roughness 0.5, shinier
	# than the >=0.78 matte floor the rest of the environment holds to.
	# NOT fixed here -- reassigning a nested instance child's owner to
	# `root` so PackedScene.pack() would keep the override (the same
	# trick M1.2/M3.1 needed for other nested-instance overrides) makes
	# these specific nodes come back as orphans on every instantiate(),
	# and that leak reliably hangs gdUnit4's SceneRunner on the very next
	# suite after a long-running one (confirmed by bisection: reverting
	# just this override made the hang disappear). Applied instead at
	# runtime by prop_material_tuner.gd, attached to this scene's root --
	# the same live-tree approach character_visual.gd already uses
	# successfully for the same >=0.78 floor.


# ------------------------------------------------------------ wall colliders --

func _add_wall_colliders(root: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "WallColliders"
	root.add_child(walls)
	walls.owner = root

	# WorldBounds.COLLIDERS' first 3 entries are the courtyard's actual
	# perimeter (left wall, right wall, back wall) -- the boundary
	# M1.4's camera rig exists to guard (GODOT_REBUILD_PLAN.md: "the exact
	# regression guard for Saturday Afternoon's follow camera ending up
	# outside the starting room's walls"). Everything after that is a
	# small in-courtyard obstacle (garden wall nub, tree trunk, bench
	# footprint) sized only for player movement -- see below.
	for i in range(WorldBounds.COLLIDERS.size()):
		var box: Dictionary = WorldBounds.COLLIDERS[i]
		_wall_collider(walls, box["x"], box["z"], box["half_x"], box["half_z"], i < 3)

	# Plan 1.2: "plus an invisible bound at z=12.3" -- the upper z bound
	# (can_move_to rejects z > 12) as a real thin wall so the camera/player
	# can't clip past the home threshold's z edge. Also a perimeter bound.
	_wall_collider(walls, 0.0, 12.3, 11.5, 0.05, true)


## M3.4: `camera_blocks` puts a wall on a second physics layer (bit 2) that
## camera_rig.tscn's SpringArm3D exclusively watches, in addition to the
## default layer 1 every wall stays on for player movement. Without this
## split, the spring arm collided with EVERY WorldBounds box, including
## small in-courtyard obstacles never meant to represent a camera-height
## wall (e.g. the {x:8.1,z:-0.8} garden wall is 1.2m tall in the source,
## scene.mjs:74, but every collider here uses a uniform 2.4m height --
## intentionally simpler than render geometry, per ART_DIRECTION.md, and
## fine for player movement, but tall enough to collapse the spring arm
## in the REVEAL zone). Found while shooting M3.4's "gap"/"ball" frames:
## the camera was landing ~1.3m from the pivot instead of the ~14-16m
## CameraProfile authored, because SpringArm3D was shortening against
## this collider on every frame, not just transiently.
func _wall_collider(parent: Node3D, x: float, z: float, half_x: float, half_z: float, camera_blocks: bool = false) -> void:
	const HEIGHT := 2.4
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.owner = parent.owner if parent.owner else parent
	body.position = Vector3(x, HEIGHT * 0.5, z)
	if camera_blocks:
		body.collision_layer = 0b11  # layer 1 (movement) + layer 2 (camera)

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
