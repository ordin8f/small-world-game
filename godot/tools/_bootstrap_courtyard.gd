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


## 2026-08-28 world expansion: one cramped 20x24.5 m room -> four connected
## places (world_bounds.gd's own doc comment has the authoritative layout
## table; every position below either matches a WorldBounds/WorldAffordances
## constant directly or is derived from one, same discipline the single-room
## version held). Built to read as somewhere to choose a direction and go,
## not a diorama: HOME (porch/doorway) -> LANE (the new narrow passage,
## concept_02_path_discovery.png) -> PLAYGROUND (open, the chalk circle/
## towers/slide, room left for another agent's swing+sandbox) -> GARDEN
## POCKET through the wall gap (concept_06_garden_gap.png, relocated
## further out and enlarged). Kept sparse throughout, per ART_DIRECTION.md
## ("Avoid filling every space with props") -- bigger means more places,
## not more clutter in any one of them.
func _build_static_world(root: Node3D) -> void:
	# Ground, generous enough to cover all four rooms' combined extent
	# (x[-16.6,22.6], z[-20.3,16.3], world_bounds.gd's can_move_to envelope)
	# with margin. Worn path strip from the playground mouth through the
	# lane to the doorway (x +-3.2, z[-4,16]) -- the lane's own walkable
	# width, continued through home -- reads as the route the child has
	# already walked many times, per ART_DIRECTION.md's "wet footprints
	# near a puddle" style of small concrete detail.
	_mesh(root, "cube", Vector3(3, -0.28, -2), Vector3(42, 0.5, 40), GROUND)
	_mesh(root, "cube", Vector3(0, -0.01, 6.0), Vector3(6.4, 0.08, 20.0), PATH)

	_build_home(root)
	_build_lane(root)
	_build_playground(root)
	_build_garden_pocket(root)

	# Puddles, stepping stones, and bench. First two puddles sit in the
	# lane (unchanged from the single-room version -- its x[-3,3]/z[-4,8]
	# footprint already contained them); the third is the garden one,
	# relocated with the rest of that pocket. Positions mirror
	# WorldAffordances.PUDDLES/STONES exactly.
	var puddle_color := Color(0.20, 0.32, 0.37, 0.65)
	for p in [
		[-1.5, 0.01, 3.2, 1.6, 0.04, 0.9],
		[2.1, 0.01, 0.8, 1.15, 0.04, 0.75],
		[12.4, 0.01, -9.4, 1.4, 0.04, 0.8],
	]:
		_mesh(root, "sphere", Vector3(p[0], p[1], p[2]), Vector3(p[3], p[4], p[5]), puddle_color)
	for stone in [[11.7, -7.7, 0.45], [12.5, -8.4, 0.52], [13.3, -9.1, 0.48], [14.0, -9.9, 0.55]]:
		var s: float = stone[2]
		_mesh(root, "sphere", Vector3(stone[0], 0.05, stone[1]), Vector3(s, 0.14, s * 0.85), PATH)
	# M3.2: real bench.gltf, near the chalk circle -- same offset from
	# Group (0, -11) the single-room version held from its own Group.
	_kind(root, Vector3(-7.0, 0.0, -8.0), "res://assets/park/bench.gltf", 1.0, Callable(self, "_primitive_bench"), 1.0, 0.0, "Bench")

	# Trees flanking the lane's home-side mouth (concept_02's "narrow
	# passage... light at the far end" reads better with something framing
	# the near end too), plus the deep garden tree.
	_add_tree(root, -6.0, 9.5, 1.05)
	_add_tree(root, 6.0, 9.5, 0.9)
	_add_tree(root, 13.9, -13.4, 1.25)

	# DEFERRED: the overhead canopy that frames the top of frame in
	# concept_03/06/07. First attempt hung foliage spheres at y 6-7.5 with no
	# trunk; from the play camera they read as floating discs, not a canopy.
	# Doing this properly means canopy attached to real trees at the frame
	# edges, sized against where the camera actually sits. Unchanged by this
	# pass; still open.

	# M3.2: ASSET_CREDITS.md's one featured bush_large.gltf, near the bench/
	# tree cluster (west playground, same relative offset as the
	# single-room version held from its own Group).
	_kind(root, Vector3(-8.7, 0.0, -13.7), "res://assets/park/bush_large.gltf", 1.0, Callable(self, "_primitive_bush"), 1.0, 0.0, "BushFeature")

	# Generic scattered shrubbery -- garden-pocket cluster (relocated with
	# that pocket) plus the two flanking the home/lane mouth.
	for bush in [[12.0, -9.6, 1.0], [11.8, -13.9, 0.8], [15.0, -8.2, 0.85], [-5.5, 12.0, 1.0], [5.5, 12.5, 0.9]]:
		var s: float = bush[2]
		_mesh(root, "sphere", Vector3(bush[0], 0.55 * s, bush[1]), Vector3(1.3 * s, 1.0 * s, 1.1 * s), FOLIAGE)

	var flower_color := Color(0.85, 0.72, 0.42)
	for flower in [[11.8, -10.7], [12.3, -11.5], [14.4, -10.8], [14.6, -12.2], [-4.5, 10.5], [-4.5, 12.0]]:
		_mesh(root, "cylinder", Vector3(flower[0], 0.25, flower[1]), Vector3(0.035, 0.5, 0.035), FOLIAGE_LIGHT)
		_mesh(root, "sphere", Vector3(flower[0], 0.52, flower[1]), Vector3(0.14, 0.1, 0.14), flower_color, Vector3.ZERO, 0.15)

	# Sparse grass blades dress the playground's open flanks (x 5..15,
	# mirrored, avoiding the circle/tower cluster near the centreline) --
	# deliberately NOT scattered into the lane or home (kept bare per the
	# brief: "a bigger world that's empty reads worse than a small one
	# that's dense... bigger means more places, not more clutter").
	for index in range(48):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z: float = -19.0 + fmod(index * 0.83, 15.0)
		var x: float = side * (5.0 + fmod(index * 1.91, 10.0))
		var height: float = 0.32 + (index % 5) * 0.07
		var blade_color := FOLIAGE_LIGHT if index % 3 == 0 else FOLIAGE
		_mesh(root, "cone", Vector3(x, height * 0.48, z), Vector3(0.12, height, 0.12), blade_color)


## HOME: the porch and doorway passage, x[-7,7] z[8,16] -- already existed
## as a passage in the single-room version (docs/concept-art/extended/
## concept_07_circle.png: two heavy piers framing a dark threshold), just
## narrower now that it is its own room rather than one wall inside a
## 21 m-wide space. Side walls close z 8..14; the piers themselves (flush
## with those walls, no gap between) close z 14..16, leaving only the
## 2.4 m doorway opening through -- matches world_bounds.gd's COLLIDERS
## for this room exactly.
func _build_home(root: Node3D) -> void:
	_mesh(root, "cube", Vector3(-7.0, 4.0, 11.0), Vector3(1.1, 8.2, 6.0), PLASTER)
	_mesh(root, "cube", Vector3(7.0, 4.0, 11.0), Vector3(1.1, 8.2, 6.0), PLASTER_LIGHT)

	# The piers: heavy, tall, framing the doorway. Widened from the
	# single-room version's freestanding pair (which had open flanks either
	# side, x to +-10.7) to run flush out to the new x=+-7 side walls above.
	_mesh(root, "cube", Vector3(-4.1, 2.2, 15.0), Vector3(5.8, 4.7, 2.0), PLASTER)
	_mesh(root, "cube", Vector3(4.1, 2.2, 15.0), Vector3(5.8, 4.7, 2.0), PLASTER)
	# Lintel + roof slab: the dark ceiling that makes it read as a passage.
	_mesh(root, "cube", Vector3(0, 4.35, 15.0), Vector3(2.6, 1.2, 2.0), PLASTER)
	_mesh(root, "cube", Vector3(0, 3.95, 15.0), Vector3(2.5, 0.35, 2.2), SHADOW_STONE)
	# Back cap, just past the piers -- the world's true south edge here.
	_mesh(root, "cube", Vector3(0, 4.0, 16.3), Vector3(14.4, 8.2, 0.3), PLASTER)
	# The warm window/porch light -- the anchor ART_DIRECTION.md asks dusk to
	# resolve onto. Behind the player at the start, ahead of them at the end.
	_mesh(root, "cube", Vector3(0, 1.7, 15.95), Vector3(2.5, 3.5, 0.18), WARM_LIGHT, Vector3.ZERO, 0.9)

	# DEFERRED: the concept_07 framing gateway. It has to stand between the
	# camera and the player, so its position depends on where the camera
	# actually settles. Revisit once the retuned camera clamp (this pass)
	# has been screenshot-verified.

	# M3.2: ASSET_CREDITS.md's own "one distant house model", beyond the
	# world's true south edge (z=16.3) -- glimpsed through the doorway gap,
	# never reachable (can_move_to's z<=16.3 bound).
	_prop(root, "res://assets/house/house.gltf", Vector3(0.0, 0.0, 20.0))
	# Street lantern, beside the path near the doorway -- unmoved by this
	# pass, its old (4.5, 9.2) position already sits inside the new home
	# room clear of every wall and the camera's authored clamps.
	_kind(root, Vector3(4.5, 0.0, 9.2), "res://assets/park/street_lantern.gltf", 1.0, Callable(self, "_primitive_lamp"), 1.0, 0.0, "StreetLantern")


## LANE: the new narrow passage, x[-3,3] z[-4,8] -- concept_02_path_
## discovery.png, and the piece GODOT_REBUILD_PLAN.md's successor task
## found completely missing: "a narrow passage between tall walls, reading
## as a canyon, light at the far end". Rendered walls are a thin pair right
## at the walkable edge (x=+-3); the much wider invisible collider flanking
## each one (world_bounds.gd) is what actually prevents walking around the
## outside of them. Taller than the other rooms' walls (9.5 m vs 8.2 m) --
## the only place in this pass that goes taller rather than wider, since a
## canyon read needs the height/width ratio, not just enclosure.
func _build_lane(root: Node3D) -> void:
	_mesh(root, "cube", Vector3(-3.0, 4.75, 2.0), Vector3(0.5, 9.5, 12.4), PLASTER)
	_mesh(root, "cube", Vector3(3.0, 4.75, 2.0), Vector3(0.5, 9.5, 12.4), PLASTER_LIGHT)
	# Deliberately nothing else in here -- ART_DIRECTION.md's "avoid filling
	# every space with props" and the brief's own "keep it sparse": the two
	# puddles already at x[-1.5,2.1] (see caller) are the lane's only detail,
	# the same restraint concept_02's plate itself shows.


## PLAYGROUND: open ground, x[-16,16] z[-20,-4] (stepping in to x[-16,11]
## for z in [-16,-4], where the garden pocket sits alongside it -- see
## world_bounds.gd's own doc comment). Chalk circle, towers, and slide
## stay clustered near the centreline as before, just relocated deeper
## (z -5.6 -> -12.8) to sit near the new Group position; the wide flanks
## either side (x 5..16 roughly) are left open and ungrouped -- room for
## another agent's swing and sandbox, per the brief.
func _build_playground(root: Node3D) -> void:
	_mesh(root, "cube", Vector3(-16.0, 4.0, -12.0), Vector3(1.1, 8.2, 16.0), PLASTER)
	# East wall only for the deep end (z -20..-16); south of that the garden
	# wall (x=11, _build_garden_pocket) is the real boundary, and rendering
	# a second wall out at x=16 alongside it there would look like a second,
	# redundant room. Deliberately absent for z > -16 for that reason.
	_mesh(root, "cube", Vector3(16.0, 4.0, -18.0), Vector3(1.1, 8.2, 4.0), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(0, 4.0, -20.0), Vector3(33.0, 8.2, 1.1), PLASTER)

	for x in [-3.4, 3.4]:
		_mesh(root, "cube", Vector3(x, 1.25, -12.8), Vector3(2.3, 2.4, 2.3), WOOD_LIGHT)
		_mesh(root, "cube", Vector3(x, 2.75, -12.8), Vector3(2.7, 0.25, 2.7), WOOD)
		_mesh(root, "cone", Vector3(x, 4.0, -12.8), Vector3(2.0, 1.8, 2.0), WOOD_LIGHT)
		for dx in [-0.8, 0.8]:
			for dz in [-0.8, 0.8]:
				_mesh(root, "cylinder", Vector3(x + dx, 0.5, -12.8 + dz), Vector3(0.16, 3.8, 0.16), WOOD)
	_mesh(root, "cube", Vector3(0, 2.3, -12.8), Vector3(4.8, 0.25, 1.15), WOOD)
	_mesh(root, "cube", Vector3(-3.4, 0.95, -10.1), Vector3(1.25, 0.18, 5.2), SLIDE, Vector3(-0.54, 0, 0))


## GARDEN POCKET, through the wall gap: x[11,22] z[-16,-4] --
## concept_06_garden_gap.png, relocated from the single-room version's
## x[5.4,10.7] strip and enlarged now that it is its own room rather than
## a slice of the one shared room. Same "wall with one discoverable
## opening, built as an arch" construction, just relocated and, unlike the
## single-room version, now fully enclosed on its own three remaining
## sides (world_bounds.gd's own doc comment: "the garden gap must still be
## the only way through").
func _build_garden_pocket(root: Node3D) -> void:
	# West wall (shared with the playground), two segments with the 2 m
	# gap between them -- matches WorldAffordances.WALL_SEGMENTS exactly.
	_mesh(root, "cube", Vector3(11.0, 0.55, -12.5), Vector3(0.6, 1.2, 7.0), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(11.0, 0.55, -5.5), Vector3(0.6, 1.2, 3.0), PLASTER_LIGHT)
	# North/south/east walls seal the rest of the pocket.
	_mesh(root, "cube", Vector3(16.5, 3.5, -16.0), Vector3(11.0, 7.0, 0.7), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(16.5, 3.5, -4.0), Vector3(11.0, 7.0, 0.7), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(22.0, 3.5, -10.0), Vector3(0.7, 7.0, 12.0), PLASTER_LIGHT)

	# The span over the opening, plus shoulders stepping down to it -- a
	# coarse arch, in keeping with ART_DIRECTION.md's "broad architectural
	# planes, modest geometric detail". Centred on the gap's own midpoint
	# (z=-8, halfway between the -9/-7 segment edges).
	_mesh(root, "cube", Vector3(11.0, 1.55, -8.0), Vector3(0.72, 0.8, 2.4), PLASTER)
	_mesh(root, "cube", Vector3(11.0, 1.12, -8.75), Vector3(0.66, 0.5, 0.75), PLASTER_LIGHT)
	_mesh(root, "cube", Vector3(11.0, 1.12, -7.25), Vector3(0.66, 0.5, 0.75), PLASTER_LIGHT)
	# Vegetation swallowing the arch, as in the plate.
	for creeper in [[-9.1, 0.62], [-8.1, 0.5], [-7.1, 0.58]]:
		_mesh(root, "sphere", Vector3(11.0, 1.9, creeper[0]), Vector3(1.05, 0.55, creeper[1] * 1.6), FOLIAGE)

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
	pocket.position = Vector3(14.0, 0.95, -12.0)
	pocket.light_color = Color(1.0, 0.84, 0.56)
	pocket.light_energy = 3.4
	pocket.omni_range = 7.0
	pocket.omni_attenuation = 2.0
	pocket.light_volumetric_fog_energy = 2.4
	pocket.shadow_enabled = false
	root.add_child(pocket)
	pocket.owner = root


## M3.2: real tree_large.gltf, replacing the 3-primitive trunk+foliage
## composition -- same positions and the same per-tree scale factors
## (1.05/1.25/0.9) game.mjs's addTree() used for size variety.
func _add_tree(root: Node3D, x: float, z: float, s: float) -> void:
	_kind(root, Vector3(x, 0.0, z), "res://assets/park/tree_large.gltf", s, Callable(self, "_primitive_tree"), s, 0.0, "Tree")


## Instances a glTF PackedScene as a purely visual prop -- WorldBounds'
## own box colliders remain the sole source of collision, untouched here.
func _prop(root: Node3D, path: String, position: Vector3, scale: float = 1.0, rotation_y: float = 0.0, name_hint: String = "") -> void:
	# A stable name when the caller supplies one; Godot otherwise auto-names
	# repeated instances @Node3D@N, which is unreadable once a kind has six.
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


# ------------------------------------------------------------ wall colliders --

func _add_wall_colliders(root: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "WallColliders"
	root.add_child(walls)
	walls.owner = root

	# Each WorldBounds.COLLIDERS entry now carries its own "camera_blocks"
	# flag (that file's own doc comment) rather than relying on an index
	# cutoff -- the courtyard is a four-room shape, not one box with a
	# handful of small obstacles in it, so "the first N entries are the
	# perimeter" stopped being a safe assumption once rooms/walls could be
	# reordered or inserted.
	for box in WorldBounds.COLLIDERS:
		_wall_collider(walls, box["x"], box["z"], box["half_x"], box["half_z"], box.get("camera_blocks", false))


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
	# 2.4 for ordinary (player-only) obstacles -- unchanged, matches every
	# render height in the courtyard comfortably.
	#
	# camera_blocks ones go to 5.0 instead, as of the 2026-08-28 world
	# expansion: REVEAL's own authored camera height is 2.6 (camera_
	# profile.gd), and with a 2.4 collider a REVEAL-zone spring-arm cast
	# aimed at a nearby wall can graze just OVER its top edge instead of
	# being caught by it -- found empirically shooting this pass's own
	# screenshots (tools/shots.ps1's "gap"/"ball" beats): with the garden
	# pocket's south wall (x[11,22], z=-4) at the standard height, a REVEAL
	# camera trailing behind a player deep in the pocket (e.g. BallEnd,
	# z=-12) could end up on the LANE side of that wall entirely, so the
	# head->camera raycast test_camera_never_in_geometry.gd runs crossed
	# straight through it. 5.0 clears REVEAL's 2.6 with real margin without
	# touching any camera_profile.gd number.
	var height := 5.0 if camera_blocks else 2.4
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.owner = parent.owner if parent.owner else parent
	body.position = Vector3(x, height * 0.5, z)
	if camera_blocks:
		body.collision_layer = 0b11  # layer 1 (movement) + layer 2 (camera)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half_x * 2.0, height, half_z * 2.0)
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

	# Player start (player.gd START_POSITION), group/ball, interaction radii
	# -- relocated for the 2026-08-28 world expansion (world_bounds.gd's own
	# doc comment has the four-room layout). Group moved from (0,-3.8) to
	# (0,-11), deep in the relocated playground; every other marker here
	# keeps its old offset FROM Group, just applied at the new position.
	_marker(markers, root, "Start", 0.0, 10.0, 0.0)
	_marker(markers, root, "Group", 0.0, -11.0, 0.0)
	_marker(markers, root, "Watch", 0.0, -8.0, 2.3)
	_marker(markers, root, "BallEnd", 14.0, -12.0, 1.45)
	_marker(markers, root, "Return", 0.0, -11.0, 2.1)  # same position as Group, own radius
	_marker(markers, root, "Join", 0.0, -10.3, 2.2)
	_marker(markers, root, "Door", 0.0, 13.0, 1.8)


# AssetMode.resolve_detailed() says so, otherwise `primitive_fallback` --
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

