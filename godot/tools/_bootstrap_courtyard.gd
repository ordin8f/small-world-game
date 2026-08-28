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
##
## Detailed-vs-primitive toggle: a handful of "kinds" (tree, bush, bench,
## lamp, rock) are built through _kind(), which picks a vendored glTF/glb
## prop or today's primitive mesh per AssetMode.use_detailed() -- see
## scripts/logic/asset_mode.gd for how that's set and ASSET_CREDITS.md's
## "Detailed vs primitive assets" section for the full picture. Everything
## else in this file (courtyard shell, playground, walls, grass, puddles)
## is primitive-only in both modes, per ART_DIRECTION.md's "broad
## architectural planes... restrained materials" -- there is no detailed
## equivalent to toggle to, intentionally.

const ROUGHNESS := 0.92


func _init() -> void:
	var root := Node3D.new()
	root.name = "Courtyard"
	# M3.3 (70ddfef) attached prop_material_tuner.gd here so vendored glTF
	# props get bumped to the environment's >=0.78 matte roughness floor
	# live at _ready() (see _prop()'s doc comment for why that has to run
	# at runtime rather than be baked in here). A later regeneration of
	# this file dropped the attachment silently -- the exact "same class
	# of bug as M3.1's player.tscn" that M3.3's own commit message warned
	# about -- and courtyard.tscn has shipped without it since (confirmed:
	# no .tscn in the repo referenced prop_material_tuner.gd before this
	# line). Re-attached here, in the generator itself, so it survives the
	# next regeneration too. Safe to set directly (unlike player.gd/
	# ball.gd): prop_material_tuner.gd references no autoload, so it is
	# not affected by the "Game identifier not found" bare --script issue
	# those two scripts hit.
	root.set_script(load("res://scripts/prop_material_tuner.gd"))

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

	# A practical light in the garden pocket, over where the ball lands.
	#
	# docs/concept-art/extended/concept_06_garden_gap.png makes the ball the
	# BRIGHTEST thing in its frame -- glowing in golden light through the arch,
	# which is what makes the garden route something you want to take rather
	# than something the objective text sends you on.
	#
	# It also fixes a real gameplay problem the screenshot route surfaced: the
	# ball beat renders as a dark orange smear against near-black. FIND_BALL is
	# the lowest-comfort state in episode_director.gd's emotional_target(), so
	# perception.gd's lens modulation pulls exposure DOWN and fog IN during the
	# exact beat whose objective is "find a small object". Mood and playability
	# were pulling opposite ways. A local light resolves it without weakening the
	# mood: the world stays dim, the thing you are looking for does not.
	var pocket := OmniLight3D.new()
	pocket.name = "GardenPocketLight"
	# Kept LOW and tight. At y=2.6 with an 11 m range it uplit the tree canopy
	# above it into a glowing green blob -- a lamp under a tree, not a pool of
	# late sun on the ground. Sitting it near ground level with a fast falloff
	# keeps the light on the grass and the ball where the plate puts it.
	pocket.position = Vector3(8.6, 0.95, -6.6)
	pocket.light_color = Color(1.0, 0.84, 0.56)
	pocket.light_energy = 3.4
	pocket.omni_range = 7.0
	pocket.omni_attenuation = 2.0
	pocket.light_volumetric_fog_energy = 2.4
	pocket.shadow_enabled = false
	root.add_child(pocket)
	pocket.owner = root

	# Puddles, stepping stones, and bench.
	var puddle_color := Color(0.20, 0.32, 0.37, 0.65)
	for p in [
		[-1.5, 0.01, 3.2, 1.6, 0.04, 0.9],
		[2.1, 0.01, 0.8, 1.15, 0.04, 0.75],
		[6.8, 0.01, -4.2, 1.4, 0.04, 0.8],
	]:
		_mesh(root, "sphere", Vector3(p[0], p[1], p[2]), Vector3(p[3], p[4], p[5]), puddle_color)
	# NOTE: these 4 positions are also hardcoded in scripts/logic/
	# world_affordances.gd's stone_index_at() for the floor-is-lava
	# mechanic -- not touched here, and not moved by the toggle below.
	var stone_spots := [[6.1, -2.5, 0.45], [6.9, -3.2, 0.52], [7.7, -3.9, 0.48], [8.4, -4.7, 0.55]]
	for i in range(stone_spots.size()):
		var stone: Array = stone_spots[i]
		_add_rock(root, stone[0], stone[1], stone[2], i)
	# M3.2: real bench.gltf at the procedural bench's own position/footprint
	# (the primitive cube trio it replaces was itself at this spot; that
	# trio lives on as _primitive_bench(), the toggle's primitive-mode
	# fallback for this same spot).
	_kind(root, Vector3(-7.4, 0.0, -0.8), "res://assets/park/bench.gltf", 1.0, Callable(self, "_primitive_bench"), 1.0, 0.0, "Bench")

	_add_tree(root, -7.6, 1.7, 1.05, 0)
	_add_tree(root, 8.3, -8.2, 1.25, 1)
	_add_tree(root, 7.9, 6.2, 0.9, 2)


	# DEFERRED: the overhead canopy that frames the top of frame in
	# concept_03/06/07. First attempt hung foliage spheres at y 6-7.5 with no
	# trunk; from the play camera they read as floating discs, not a canopy.
	# Doing this properly means canopy attached to real trees at the frame
	# edges, sized against where the camera actually sits -- which is being
	# fixed right now. Same reason as the gateway below.

	# M3.2 gave ASSET_CREDITS.md's one featured bush_large.gltf to the
	# spot nearest the bench/tree cluster and left 5 more spheres as
	# "generic scattered shrubbery" with no detailed equivalent at all.
	# The detailed-assets toggle (M4) extends bush_large.gltf to all 6 of
	# today's positions instead -- still zero new placements, just the
	# same "kind" swapped in everywhere it already stood; primitive mode
	# renders all 6 as the original sphere via _primitive_bush().
	#
	# Bushes moved clear of the ball's rest spot (8.6, -6.6) on 2026-08-28. The
	# retuned low REVEAL camera framed the ball beat onto a bush sitting 0.64
	# units from where the ball lands, so the character and the ball both
	# vanished into it. Confirmed as prop placement rather than camera by
	# rendering the identical REVEAL numbers at a clean nearby position.
	var bush_spots := [
		[-8.7, -6.5, 1.0],  # ASSET_CREDITS.md's originally-credited spot
		[6.4, -4.4, 1.0], [6.2, -8.7, 0.8], [9.4, -3.0, 0.85], [-8.8, 7.5, 1.0], [8.8, 8.6, 0.9],
	]
	for i in range(bush_spots.size()):
		var bush: Array = bush_spots[i]
		var s: float = bush[2]
		_kind(root, Vector3(bush[0], 0.0, bush[1]), "res://assets/park/bush_large.gltf", s, Callable(self, "_primitive_bush"), s, 0.0, "Bush%d" % i)

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
## (1.05/1.25/0.9) game.mjs's addTree() used for size variety. The
## detailed-assets toggle (M4) revives that 3-primitive composition as
## _primitive_tree(), primitive mode's fallback for these same spots.
func _add_tree(root: Node3D, x: float, z: float, s: float, index: int) -> void:
	_kind(root, Vector3(x, 0.0, z), "res://assets/park/tree_large.gltf", s, Callable(self, "_primitive_tree"), s, 0.0, "Tree%d" % index)


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
## street_lantern.gltf goes through the toggle (_primitive_lamp() is its
## primitive-mode fallback); house.gltf does not -- it was never a
## registered "kind" (the brief's list is tree/bush/bench/lamp/rock) and
## has no primitive predecessor to fall back to (game.mjs's
## buildStaticWorld() never had a house at all -- see ASSET_CREDITS.md).
## It sits beyond WorldBounds' z<=12 walkable bound either way, so it
## never affects "iterate fast on mechanics", primitive mode's whole
## reason to exist.
func _add_props(root: Node3D) -> void:
	_kind(root, Vector3(4.5, 0.0, 9.2), "res://assets/park/street_lantern.gltf", 1.0, Callable(self, "_primitive_lamp"), 1.0, 0.0, "StreetLantern")
	_prop(root, "res://assets/house/house.gltf", Vector3(0.0, 0.0, 16.0))


## Instances a glTF PackedScene as a purely visual prop -- WorldBounds'
## own box colliders remain the sole source of collision, untouched here.
## `name_hint`, if given, becomes the instance's node name (Godot
## otherwise names repeated instances of the same source file "@Node3D@N"
## once the first copy claims "<filename>2" -- harmless, since nothing
## looks these mesh nodes up by name, but confusing to read in the
## editor once a kind like bush_large.gltf is instanced 6 times).
func _prop(root: Node3D, path: String, position: Vector3, scale: float = 1.0, rotation_y: float = 0.0, name_hint: String = "") -> void:
	var packed: PackedScene = load(path)
	var inst: Node3D = packed.instantiate()
	if name_hint != "":
		inst.name = name_hint
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


# --------------------------------------------------- detailed/primitive kinds --

## Builds one registered "kind" of prop at `position`: the vendored
## glTF/glb at `detailed_path` (instanced at `detailed_scale`) when
## AssetMode.resolve_detailed() says so, otherwise `primitive_fallback` --
## a Callable shaped like _primitive_tree()/_primitive_bush()/
## _primitive_bench()/_primitive_lamp()/_primitive_rock(): fn(root,
## position, scale, rotation_y). `detailed_scale` and `primitive_scale`
## are separate parameters, not one shared value, because a vendored
## mesh's native size does not always match the primitive's own
## scale-as-metres convention (see _add_rock()); everywhere else they are
## simply the same number passed twice.
func _kind(root: Node3D, position: Vector3, detailed_path: String, detailed_scale: float, primitive_fallback: Callable, primitive_scale: float, rotation_y: float = 0.0, name_hint: String = "") -> void:
	if AssetMode.resolve_detailed(detailed_path):
		_prop(root, detailed_path, position, detailed_scale, rotation_y, name_hint)
		return
	if AssetMode.use_detailed():
		push_warning("Detailed asset missing, using primitive fallback: %s" % detailed_path)
	primitive_fallback.call(root, position, primitive_scale, rotation_y)


## Primitive-mode fallback for _add_tree(): the 3-primitive trunk+foliage
## composition M3.2's tree_large.gltf replaced, restored here as the
## toggle's "today's boxes" side. Not a precise match to tree_large.gltf's
## silhouette (~2.75m wide x ~5m tall) -- close enough in scale (WOOD
## trunk + two FOLIAGE tiers, apex ~4.65m at scale 1.0) to read as the
## same kind of thing standing in the same spot.
func _primitive_tree(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	_mesh(root, "cylinder", position + Vector3(0.0, 1.5 * scale, 0.0), Vector3(0.22, 3.0, 0.22) * scale, WOOD)
	_mesh(root, "sphere", position + Vector3(0.0, 3.2 * scale, 0.0), Vector3(1.6, 1.4, 1.6) * scale, FOLIAGE)
	_mesh(root, "sphere", position + Vector3(0.0, 4.1 * scale, 0.0), Vector3(1.1, 1.1, 1.1) * scale, FOLIAGE_LIGHT)


## Primitive-mode fallback for every bush_spots entry in
## _build_static_world() -- identical to the sphere formula the 5
## always-primitive bushes used before M4, now shared by all 6.
func _primitive_bush(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	_mesh(root, "sphere", position + Vector3(0.0, 0.55 * scale, 0.0), Vector3(1.3, 1.0, 1.1) * scale, FOLIAGE)


## Primitive-mode fallback for the bench spot: the "cube trio" bench.gltf
## replaced in M3.2 (seat + backrest + a single plinth standing in for
## two legs), in the playground's existing WOOD/WOOD_LIGHT tones.
func _primitive_bench(root: Node3D, position: Vector3, scale: float, rotation_y: float) -> void:
	var rot := Vector3(0.0, rotation_y, 0.0)
	_mesh(root, "cube", position + Vector3(0.0, 0.20 * scale, 0.0), Vector3(1.5, 0.4, 0.45) * scale, WOOD, rot)
	_mesh(root, "cube", position + Vector3(0.0, 0.46 * scale, 0.0), Vector3(1.7, 0.12, 0.55) * scale, WOOD_LIGHT, rot)
	_mesh(root, "cube", position + Vector3(0.0, 0.80 * scale, -0.20 * scale), Vector3(1.7, 0.55, 0.12) * scale, WOOD_LIGHT, rot)


## Primitive-mode fallback for the street lantern: a dark pole plus a
## small emissive WARM_LIGHT head, echoing the same warm-glow-as-anchor
## treatment _build_static_world() already uses for the home threshold's
## porch light. Sized to street_lantern.gltf's own ~4.5m height.
func _primitive_lamp(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	_mesh(root, "cylinder", position + Vector3(0.0, 2.0 * scale, 0.0), Vector3(0.08, 4.0, 0.08) * scale, SHADOW_STONE)
	_mesh(root, "sphere", position + Vector3(0.0, 4.15 * scale, 0.0), Vector3(0.28, 0.28, 0.28) * scale, WARM_LIGHT, Vector3.ZERO, 1.2)


## Primitive-mode fallback for the stepping stones: exactly today's
## flattened PATH-colored sphere, unchanged and unmoved (positions are
## shared with world_affordances.gd -- see the NOTE above stone_spots in
## _build_static_world()).
func _primitive_rock(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	_mesh(root, "sphere", position + Vector3(0.0, 0.05, 0.0), Vector3(scale, 0.14, scale * 0.85), PATH)


## Kenney Nature Kit's CC0 flat rocks (ASSET_CREDITS.md), re-materialed
## to this project's own PATH/FOLIAGE palette before vendoring (stock
## colors were an unrelated bright teal-green "grass" placeholder --
## see ASSET_CREDITS.md). ~0.48m wide at scale 1.0 in GLTF format, so the
## detailed path gets its own correction factor to land on the same
## ground footprint `s` already gives the primitive sphere fallback
## (diameter == s metres); the primitive path uses `s` directly, as it
## always has.
const ROCK_VARIANTS := [
	"res://assets/nature/rock_smallFlatA.glb",
	"res://assets/nature/rock_smallFlatB.glb",
	"res://assets/nature/rock_smallFlatC.glb",
]
const ROCK_NATIVE_WIDTH := 0.48

func _add_rock(root: Node3D, x: float, z: float, s: float, variant_index: int) -> void:
	var path: String = ROCK_VARIANTS[variant_index % ROCK_VARIANTS.size()]
	_kind(root, Vector3(x, 0.0, z), path, s / ROCK_NATIVE_WIDTH, Callable(self, "_primitive_rock"), s, float(variant_index) * 0.9, "Rock%d" % variant_index)


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
