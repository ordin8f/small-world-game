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


# ------------------------------------------------------------------ surfaces --

## Surface textures. Until now every material in this world was a
## StandardMaterial3D with one flat albedo colour and nothing else -- a straight
## port artifact from the Three.js prototype, which also used flat colours. That
## is why the world read as a diagram rather than a place: nothing had surface.
##
## docs/ART_DIRECTION.md asks for exactly this and rules out only its excesses --
## "chalky plaster; matte painted wood; worn stone; soft fabric ... slightly
## imperfect painted playground surfaces", while avoiding "excessive gloss",
## "plastic-looking PBR" and "ultra-sharp high-frequency textures". Texture is
## wanted; photorealism is not.
##
## Triplanar, because this level is built from unwrapped primitives with no UVs --
## triplanar projects world-space and needs none, and keeps the scale consistent
## across boxes of wildly different sizes.
const SURFACE_DIR := "res://assets/surfaces/"
const SURFACES := {
	"plaster": {"file": "plaster_wall.png", "scale": 0.35, "rough": 0.94},
	"paving": {"file": "stone_paving.png", "scale": 0.28, "rough": 0.90},
	"earth": {"file": "packed_earth.png", "scale": 0.20, "rough": 0.96},
	"wood": {"file": "painted_wood.png", "scale": 0.55, "rough": 0.88},
	"grass": {"file": "grass_tufts.png", "scale": 0.30, "rough": 0.95},
	"soil": {"file": "garden_soil.png", "scale": 0.60, "rough": 0.97},
}

## `tint` keeps the palette authoritative: the texture supplies variation, the
## palette supplies hue. Pulled toward white so the two multiply to roughly the
## authored colour rather than doubling down into mud.
func _apply_surface(mat: StandardMaterial3D, surface: String, color: Color) -> bool:
	if surface == "cloth":
		mat.albedo_color = color
		mat.roughness = 0.98
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.55
		return true
	if surface == "" or not SURFACES.has(surface):
		return false
	var data: Dictionary = SURFACES[surface]
	var path: String = SURFACE_DIR + str(data["file"])
	if not ResourceLoader.exists(path):
		return false  # textures are optional; flat colour remains a valid fallback
	var tex: Texture2D = load(path)
	if tex == null:
		return false
	mat.albedo_texture = tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * float(data["scale"])
	mat.roughness = float(data["rough"])
	mat.albedo_color = color.lerp(Color(1, 1, 1), 0.30)
	return true


# ------------------------------------------------------------- visual mesh --

func _mesh(root: Node3D, kind: String, position: Vector3, scale: Vector3, color: Color, rotation_rad: Vector3 = Vector3.ZERO, emissive: float = 0.0, surface: String = "") -> void:
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
	var textured := _apply_surface(mat, surface, color)
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
	if textured and surface == "cloth":
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
## Ambience pass (2026-08-28): faded laundry cloth. The one deliberately
## cooler, slightly-more-separated note in an otherwise warm/neutral palette
## -- ART_DIRECTION.md's "child and key interactive elements can carry
## slightly clearer colour separation, but should still belong to the
## world" -- so a washing line reads as cloth against plaster instead of
## disappearing into it. Both still muted, not toy-box.
const CLOTH_PALE := Color(0.80, 0.76, 0.66)
const CLOTH_MUTED_BLUE := Color(0.44, 0.49, 0.54)
## Scale-diagnosis pass (2026-08-29): the home's garden bed and its low
## brick edging (_build_garden_bed()), and the house's primitive chimney
## (_primitive_house()). BRICK is warmer/redder than WOOD_LIGHT so a brick
## course still reads as masonry, not another timber rail.
const BRICK := Color(0.55, 0.26, 0.19)
const SOIL := Color(0.22, 0.15, 0.11)


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
	# lane to the doorway (x +-3.2, z[-4,16]) reads as the route the child
	# has already walked many times, per ART_DIRECTION.md's "wet footprints
	# near a puddle" style of small concrete detail. It used to be exactly
	# the lane's walkable width; since the openness pass widened the lane to
	# 8.76 m the path is narrower than the space it runs through, which is
	# what a worn path actually looks like -- kept at 6.4 for that reason
	# rather than widened to match.
	_mesh(root, "cube", Vector3(3, -0.28, -2), Vector3(42, 0.5, 40), GROUND, Vector3.ZERO, 0.0, "earth")
	_mesh(root, "cube", Vector3(0, -0.01, 6.0), Vector3(6.4, 0.08, 20.0), PATH, Vector3.ZERO, 0.0, "paving")

	_build_home(root)
	_build_garden_bed(root)
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
		_mesh(root, "sphere", Vector3(stone[0], 0.05, stone[1]), Vector3(s, 0.14, s * 0.85), PATH, Vector3.ZERO, 0.0, "paving")
	# M3.2: real bench.gltf, near the chalk circle -- same offset from
	# Group (0, -11) the single-room version held from its own Group.
	_kind(root, Vector3(-7.0, 0.0, -8.0), "res://assets/park/bench.gltf", 1.0, Callable(self, "_primitive_bench"), 1.0, 0.0, "Bench")

	# Trees flanking the lane's home-side mouth (concept_02's "narrow
	# passage... light at the far end" reads better with something framing
	# the near end too), the deep garden tree, and one new tree behind the
	# chalk circle. Scales bumped from the original expansion's 1.05/0.9/1.25
	# -- concept_03/06/07 all crop the top of frame with canopy mass. This
	# reuses the same _add_tree()/_kind() path every tree here already goes
	# through, so both AssetMode branches (tree_large.gltf, and
	# _primitive_tree's own trunk + two foliage tiers) get a real trunk for
	# free. The previous attempt at overhead framing hung bare foliage
	# spheres at y 6-7.5 with no trunk at all and read as floating discs from
	# the play camera -- a bespoke hack, not this path, which is why simply
	# adding/enlarging trees here doesn't repeat that failure.
	_add_tree(root, -6.0, 9.5, 1.25)
	_add_tree(root, 6.0, 9.5, 1.1)
	_add_tree(root, 13.9, -13.4, 1.35)
	# Behind and slightly off-centre from the circle (Group sits at x=0,
	# z=-11) so its trunk doesn't stand in the chalk circle itself and its
	# canopy doesn't smother the arcade's own centre arch (_build_playground)
	# -- concept_07's "one large tree breaking the skyline" over the watching
	# child and the group beyond.
	_add_tree(root, -2.5, -16.5, 1.4)
	# Lane-flank tree, camera-fix task round 3: matches world_bounds.gd's
	# new (9.5,4.5) camera-blocking collider exactly -- see that file's own
	# doc comment for why. Gives the REVEAL-zone camera something real to
	# settle in front of when a player near the garden-gap seam sends it
	# north into what was, until this round, an empty invisible flank.
	_add_tree(root, 9.5, 1.3, 1.6)

	# Gap 1 (ambience pass): a silhouette layer beyond the playable walls --
	# see _add_distant_layer()'s own doc comment.
	_add_distant_layer(root)

	# Gap 3 (ambience pass): thin things a low sun draws. concept_02/04's
	# ball-topped bollard, marking the lane mouth beside the path.
	_mesh(root, "cylinder", Vector3(-2.6, 0.45, 7.5), Vector3(0.10, 0.9, 0.10), SHADOW_STONE)
	_mesh(root, "sphere", Vector3(-2.6, 0.95, 7.5), Vector3(0.22, 0.22, 0.22), SHADOW_STONE)

	# A washing line across the home porch -- ART_DIRECTION.md's own example
	# of "signs of life" storytelling, anchored wall-to-wall (x=-7..7, the
	# HOME room's own side walls) rather than on new posts. One thin
	# cylinder rotated horizontal, plus three flat "cloth" panels that hang
	# just below it with a small stagger in position, colour and tilt so
	# they don't read as one rigid strip.
	_mesh(root, "cylinder", Vector3(0.0, 2.5, 10.3), Vector3(0.02, 14.0, 0.02), SHADOW_STONE, Vector3(0, 0, deg_to_rad(90.0)))
	for cloth in [[-3.4, CLOTH_PALE, 0.12], [-0.6, CLOTH_MUTED_BLUE, -0.16], [2.5, CLOTH_PALE, 0.10]]:
		_mesh(root, "cube", Vector3(cloth[0], 2.15, 10.3 + cloth[2]), Vector3(0.55, 0.6, 0.03), cloth[1], Vector3(0, 0, deg_to_rad(4.0)), 0.0, "cloth")

	# M3.2: ASSET_CREDITS.md's one featured bush_large.gltf, near the bench/
	# tree cluster (west playground, same relative offset as the
	# single-room version held from its own Group).
	_kind(root, Vector3(-8.7, 0.0, -13.7), "res://assets/park/bush_large.gltf", 1.0, Callable(self, "_primitive_bush"), 1.0, 0.0, "BushFeature")

	# Generic scattered shrubbery -- garden-pocket cluster (relocated with
	# that pocket) plus the two flanking the home/lane mouth. These five were
	# the last raw _mesh() spheres standing in for planting; they now go
	# through the same _kind_of() path as everything else, so the sphere
	# survives as _primitive_bush()'s fallback rather than as the only option.
	# Positions and scales are untouched -- PropLibrary normalises "bush" on
	# width to 1.3 m, which is exactly the X scale these spheres already had.
	var bush_index := 0
	for bush in [[12.0, -9.6, 1.0], [11.8, -13.9, 0.8], [15.0, -8.2, 0.85], [-5.5, 12.0, 1.0], [5.5, 12.5, 0.9]]:
		var bx: float = bush[0]
		var bz: float = bush[1]
		_kind_of(root, "bush", Vector3(bx, 0.0, bz), bush[2], Callable(self, "_primitive_bush"), fmod(absf(bx * 2.9 + bz * 1.3), TAU), "Bush", bush_index)
		bush_index += 1

	# The library's flowers come in three colours, so the detailed branch gets
	# the mixed planting the single-colour primitive could not. 0.6 m is the
	# primitive's own overall height (a 0.5 m stem with its head sitting at
	# 0.52), so both branches stand the same height out of the bed.
	var flower_index := 0
	for flower in [[11.8, -10.7], [12.3, -11.5], [14.4, -10.8], [14.6, -12.2], [-4.5, 10.5], [-4.5, 12.0]]:
		var fx: float = flower[0]
		var fz: float = flower[1]
		_kind_of(root, "flower", Vector3(fx, 0.0, fz), 0.6, Callable(self, "_primitive_flower"), fmod(absf(fx * 4.1 + fz * 2.7), TAU), "Flower", flower_index)
		flower_index += 1

	# Sparse grass blades dress the playground's open flanks (x 5..15,
	# mirrored, avoiding the circle/tower cluster near the centreline) --
	# deliberately NOT scattered into the lane or home (kept bare per the
	# brief: "a bigger world that's empty reads worse than a small one
	# that's dense... bigger means more places, not more clutter").
	# Same 48 positions and the same per-blade heights; a real grass tuft
	# (several bent blades) instead of one smooth cone each. Cones were the
	# most obviously placeholder thing at ground level -- at this size the eye
	# reads the perfect circular base immediately.
	for index in range(48):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z: float = -19.0 + fmod(index * 0.83, 15.0)
		var x: float = side * (5.0 + fmod(index * 1.91, 10.0))
		var height: float = 0.32 + (index % 5) * 0.07
		_kind_of(root, "grass_tuft", Vector3(x, 0.0, z), height, Callable(self, "_primitive_grass_blade"), fmod(absf(x * 3.7 + z * 5.1), TAU), "Grass", index)


## HOME: the porch and doorway passage, x[-7,7] z[8,16] -- already existed
## as a passage in the single-room version (docs/concept-art/extended/
## concept_07_circle.png: two heavy piers framing a dark threshold), just
## narrower now that it is its own room rather than one wall inside a
## 21 m-wide space. Side walls close z 8..14; the piers themselves (flush
## with those walls, no gap between) close z 14..16, leaving only the
## 2.4 m doorway opening through -- matches world_bounds.gd's COLLIDERS
## for this room exactly.
func _build_home(root: Node3D) -> void:
	# Side walls dropped from 5.5 m to 4.0 m (openness pass, 2026-08-29).
	# Home is 12.8 m wide between them, so at 5.5 the walls were nearly half
	# the room's own width and there was no angle from inside the porch that
	# put anything but plaster above the horizon. 4.0 is still far too tall
	# to see over from inside (the eye would have to be 15 m back), so the
	# dead ground beyond home stays hidden exactly as before -- what changes
	# is how much sky the frame gets.
	_mesh(root, "cube", Vector3(-7.0, 2.0, 11.0), Vector3(1.1, 4.0, 6.0), PLASTER, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(7.0, 2.0, 11.0), Vector3(1.1, 4.0, 6.0), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")

	# The piers: heavy, tall, framing the doorway. Widened from the
	# single-room version's freestanding pair (which had open flanks either
	# side, x to +-10.7) to run flush out to the new x=+-7 side walls above.
	# The opening between them is 3.6 m as of the openness pass, up from
	# 2.4 -- see world_bounds.gd's matching colliders for why.
	_mesh(root, "cube", Vector3(-4.4, 2.2, 15.0), Vector3(5.2, 4.7, 2.0), PLASTER, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(4.4, 2.2, 15.0), Vector3(5.2, 4.7, 2.0), PLASTER, Vector3.ZERO, 0.0, "plaster")
	# Lintel + roof slab: the dark ceiling that makes it read as a passage.
	# Both widened with the opening so they still span it corner to corner.
	_mesh(root, "cube", Vector3(0, 4.35, 15.0), Vector3(3.8, 1.2, 2.0), PLASTER, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(0, 3.95, 15.0), Vector3(3.7, 0.35, 2.2), SHADOW_STONE)
	# Back cap, just past the piers -- the world's true south edge here.
	# Kept as a plain backdrop slab: _build_house() below stands in front of
	# it and is the real facade now, but the slab still shows past the
	# house's own width (it spans the room's full x[-7,7]; the house is
	# narrower) so there is never a gap in the world's true boundary. Only
	# lightly lowered (5.5 -> 4.6, less than the side walls above): it has
	# to stay taller than the house it backs or the house gets a halo of
	# sky where the slab used to be.
	_mesh(root, "cube", Vector3(0, 2.3, 16.3), Vector3(14.4, 4.6, 0.3), PLASTER, Vector3.ZERO, 0.0, "plaster")

	# Shoulders at the home/lane seam (openness pass), matching
	# world_bounds.gd's own new colliders there. Home is 12.8 m wide and the
	# lane below is 10 m, and until this pass that 1.4 m step per side was
	# part of the lane's wide INVISIBLE flank -- a player walking south
	# along home's east side simply stopped, on open rendered ground, at
	# nothing. Drawing the step is the fix; the collision was always there.
	for shoulder_x in [-6.0, 6.0]:
		_mesh(root, "cube", Vector3(shoulder_x, 2.0, 8.0), Vector3(2.6, 4.0, 0.7), PLASTER, Vector3.ZERO, 0.0, "plaster")

	# DEFERRED: the concept_07 framing gateway. It has to stand between the
	# camera and the player, so its position depends on where the camera
	# actually settles. Revisit once the retuned camera clamp (this pass)
	# has been screenshot-verified.

	_build_house(root)

	# Street lantern, beside the path near the doorway -- unmoved by this
	# pass, its old (4.5, 9.2) position already sits inside the new home
	# room clear of every wall and the camera's authored clamps.
	_kind(root, Vector3(4.5, 0.0, 9.2), "res://assets/park/street_lantern.gltf", 1.0, Callable(self, "_primitive_lamp"), 1.0, 0.0, "StreetLantern")


## Scale diagnosis (DEMO_PLAN.md, 2026-08-29): "There is no house.
## house.gltf sits at z=20, outside the walkable bound and behind an
## 8.2 m wall, so 'home' is a blank wall with a hole in it." This builds a
## real, approachable facade at the world's true south edge (z=16.3 -- the
## same world_bounds.gd collider as before, UNCHANGED; only what stands
## visually beyond it changes): a door, windows, a roof, a chimney, a
## porch, matching concept_05_return_safety.png's dusk composition -- a
## lit window as the single warm anchor, a small porch light over the
## door, steps, a pot. Works in both AssetMode states via the same
## _kind() detailed/primitive split every other prop in this file uses.
## The window/porch dressing below is universal (added regardless of
## AssetMode): neither house.gltf nor its primitive fallback models a
## window, so this file's own hand-placed emissive panel remains, in both
## modes, the dusk anchor the brief asks to keep -- exactly the role the
## panel it replaces already had.
func _build_house(root: Node3D) -> void:
	# house.gltf's own front (the door sits toward its +Z face, per its own
	# node translations) has to face the player, who approaches from -Z --
	# rotated 180 degrees about Y. A yaw about the origin doesn't by itself
	# keep any particular face flush with a given plane, so the DETAILED
	# branch's anchor is pushed out in Z by the model's own (unscaled) +Z
	# reach, 4.325 m (ASSET_CREDITS.md's Tiny Treats "Homely House"), at
	# HOUSE_SCALE, so the rotated front face lands right at the walkable
	# boundary. NOT routed through _kind() (unlike every other detailed/
	# primitive prop in this file): _kind() hands both branches the SAME
	# position, which is correct for every symmetric prop it already
	# serves (a tree, a bench) but wrong here, since only the detailed
	# branch needs that offset -- _primitive_house() builds forward from
	# `position` as its own front wall face and would otherwise land its
	# entire body 4.76 m further from the doorway than intended.
	const HOUSE_SCALE := 1.1
	const HOUSE_PATH := "res://assets/house/house.gltf"
	if AssetMode.resolve_detailed(HOUSE_PATH):
		const HOUSE_FRONT_REACH := 4.325 * HOUSE_SCALE
		_prop(root, HOUSE_PATH, Vector3(0.0, 0.0, 16.3 + HOUSE_FRONT_REACH), HOUSE_SCALE, PI, "House")
	else:
		if AssetMode.use_detailed():
			push_warning("Detailed asset missing, using primitive fallback: %s" % HOUSE_PATH)
		_primitive_house(root, Vector3(0.0, 0.0, 16.3), 1.0, 0.0)

	# The warm window, a porch sconce, and a second supporting window --
	# concept_05's "single warm anchor" and its plural "windows" -- and the
	# door/step/pot below all sit as close to z=16.3 (the true walkable
	# boundary, and where both AssetMode branches above put the house's own
	# front wall) as camera_rig.gd's own THRESHOLD/APPROACH clamp allows.
	#
	# That clamp is a hard constraint, not a margin to eyeball: this zone's
	# camera can sit at z up to 15.9 (camera_rig.gd's own `desired_z :=
	# clampf(raw_z, -19.0, 15.9)`, tuned and screenshot-verified against
	# this room by the camera-fix task) -- confirmed empirically here too
	# (tools/shots.ps1's "threshold" beat logs camera=(0.30, 1.28, 15.90)
	# at the game's literal opening frame, player still at START_POSITION).
	# The FIRST version of this dressing sat at z~16.0, inside SpringArm3D's
	# camera-height range (y 1.2-2.6) and within centimetres of that 15.9
	# ceiling -- close enough that the camera's own near-clip plane ended
	# up inside the window mesh, filling the entire opening frame with one
	# giant flat surface. Every tall (y > ~0.5) element below therefore
	# keeps its nearest face at z <= 16.05, a minimum 0.15 m clear of 15.9 --
	# camera_rig.gd is out of bounds for this pass (another agent's file),
	# so the fix has to be entirely on this side. Ground-level things
	# (the step, the pot) never enter that camera height range regardless
	# of z and keep their original, more "proud" placement.
	_mesh(root, "cube", Vector3(0.0, 1.75, 16.13), Vector3(1.1, 1.35, 0.14), WARM_LIGHT, Vector3.ZERO, 0.85)
	_mesh(root, "cube", Vector3(0.0, 1.75, 16.045), Vector3(0.05, 1.35, 0.05), SHADOW_STONE)
	_mesh(root, "cube", Vector3(0.0, 1.42, 16.045), Vector3(1.1, 0.05, 0.05), SHADOW_STONE)

	# A second, dimmer window off to one side -- ART_DIRECTION.md's plural
	# "windows", supporting rather than competing with the anchor above
	# (per docs/EMOTIONAL_LENS.md's own "a lit window is the single warm
	# anchor" framing of this beat).
	_mesh(root, "cube", Vector3(-2.6, 1.55, 16.13), Vector3(0.8, 1.0, 0.14), WARM_LIGHT, Vector3.ZERO, 0.4)
	_mesh(root, "cube", Vector3(-2.6, 1.55, 16.045), Vector3(0.05, 1.0, 0.05), SHADOW_STONE)

	# A small warm sconce near the entrance -- concept_05's porch light.
	# Off-centre (x=0.85), where the THRESHOLD/APPROACH camera's own small
	# lateral offset is unlikely to sit exactly, on top of the same z clamp.
	_mesh(root, "cylinder", Vector3(0.85, 2.35, 16.1), Vector3(0.05, 0.14, 0.05), SHADOW_STONE)
	_mesh(root, "sphere", Vector3(0.85, 2.28, 16.15), Vector3(0.14, 0.14, 0.14), WARM_LIGHT, Vector3.ZERO, 1.2)

	# A low porch step -- wide enough to read as the threshold regardless
	# of exactly which x a door mesh lands at in either AssetMode. Ground
	# level (top at y=0.14), well under the camera's height range, so it
	# can sit proud of the wall toward the player without the clearance
	# concern above.
	_mesh(root, "cube", Vector3(0.0, 0.07, 15.85), Vector3(3.4, 0.14, 0.9), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")

	# A potted plant beside the step -- concept_01/05's flanking planters. The
	# POT is a model now; the plant in it stays the same FOLIAGE sphere in both
	# modes, because pot_small.glb is an empty pot and this pot is meant to
	# have something growing in it. Sized to the primitive cylinder it replaces
	# (0.44 m across, top at 0.36) so the sphere still sits in its mouth.
	_kind_of(root, "flowerpot", Vector3(1.9, 0.0, 15.75), 0.44, Callable(self, "_primitive_flowerpot"), 0.0, "PorchPot")
	_mesh(root, "sphere", Vector3(1.9, 0.44, 15.75), Vector3(0.32, 0.28, 0.32), FOLIAGE)


## A symmetric gable roof from two slabs meeting at a ridge -- the same
## "box as a tilted plank, rotated about the perpendicular horizontal
## axis" construction _slide_plank() uses, just rotated about Z (height
## varying across local X) instead of X (height varying across local Z).
## `center` is the midpoint of the eave line at the wall's own top (x =
## center.x, y = eave height, z = center.z); the roof spans +-half_width
## in X from there, rising `rise` metres to a ridge directly above
## center.x.
func _gable_roof(root: Node3D, center: Vector3, half_width: float, rise: float, depth: float, thickness: float, color: Color) -> void:
	var run_len := sqrt(half_width * half_width + rise * rise)
	var theta := atan2(rise, half_width)
	for side in [-1.0, 1.0]:
		var mid := Vector3(center.x + side * half_width * 0.5, center.y + rise * 0.5, center.z)
		_mesh(root, "cube", mid, Vector3(run_len, thickness, depth), color, Vector3(0.0, 0.0, -side * theta))


## Primitive-mode fallback for _build_house(): walls, a gabled roof, a
## chimney and a door, in the same PLASTER/WOOD/SHADOW_STONE-ish palette
## every other primitive fallback in this file already uses. Anchored at
## its own front-wall-at-ground-level point like every other _kind() spot
## in this file (_add_tree, the bench, the lamp) -- unlike house.gltf's
## own asymmetric bounding box, a primitive box needs no offset trick:
## its front wall face is simply `position.z`, so this ignores
## `_rotation_y` the same way _primitive_tree() does (always built facing
## -Z, since it is only ever placed the one way).
func _primitive_house(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	var half_width := 3.2 * scale
	var wall_height := 3.6 * scale
	var rise := 2.6 * scale
	var depth := 5.0 * scale
	_mesh(root, "cube", position + Vector3(0.0, wall_height * 0.5, depth * 0.5), Vector3(half_width * 2.0, wall_height, depth), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	_gable_roof(root, position + Vector3(0.0, wall_height, depth * 0.5), half_width, rise, depth + 0.6 * scale, 0.18 * scale, SHADOW_STONE)

	# Chimney, off-centre, based part-way up the near roof slope so it
	# reads as growing out of the roof rather than floating above it.
	var chimney_x := 1.8 * scale
	var roof_h_here: float = wall_height + rise * (1.0 - chimney_x / half_width)
	_mesh(root, "cube", position + Vector3(chimney_x, roof_h_here + 0.3 * scale, depth * 0.35), Vector3(0.5, 1.3, 0.5) * scale, BRICK)

	# Door, offset from centre -- the universal window dressing in
	# _build_house() owns the doorway's own centreline.
	_mesh(root, "cube", position + Vector3(1.8 * scale, 1.075 * scale, -0.05 * scale), Vector3(1.1, 2.15, 0.12) * scale, WOOD_LIGHT, Vector3.ZERO, 0.0, "wood")


## GARDEN BED (home west flank): outer footprint x[-6.3,-3.5], z[10.45,
## 13.65] -- a low brick-edged planting bed by the home threshold, where
## the balance verb now lives (moved off the tall playground/garden-pocket
## boundary wall, world_affordances.gd's own doc comment has the
## developer's own words on why). Same "pit + four borders" construction
## tools/_bootstrap_sandbox_scene.gd already uses for the sandbox, just
## soil and brick instead of sand and timber, and built here directly
## (world-space, like every other courtyard prop) rather than as its own
## sub-scene, since this is dressing for one specific spot, not a
## droppable kit piece.
##
## Placement clears the HOME west wall collider (x<=-6.4), the near-home
## tree's own collider at (-6.0,9.5) (half 0.65, so it reaches z=10.15),
## and the doorway piers (z>=14) -- 0.1-0.35 m margins throughout, tight
## by this file's usual standard because the flank itself is only ~3 m
## wide, but the tree and the piers are real colliders that already stop
## a player from reaching the tightest of those margins on foot.
##
## Only the EAST border (facing the path, WorldAffordances.EDGING_X) is
## the mountable edge -- the other three sides are dressing without their
## own collider, the same "collision simpler than render" allowance
## _build_arcade_wall() already relies on for its blind niches. A player
## would have to leave the path and squeeze past the tree specifically to
## walk through the far side of a small planting bed; accepted rather
## than spending a new WorldBounds collider on it (world_bounds.gd's
## footprints are settled for this pass).
func _build_garden_bed(root: Node3D) -> void:
	var soil_color := SOIL
	_mesh(root, "cube", Vector3(-4.9, 0.05, 12.05), Vector3(2.2, 0.1, 2.6), soil_color)

	# Borders: east (the mount edge, EDGING_X=-3.7) and west fit the soil's
	# own depth; north and south run the full outer width to cover the
	# corners -- exactly the sandbox's own BorderNorth/South/East/West
	# shape, see that generator's doc comment.
	_mesh(root, "cube", Vector3(WorldAffordances.EDGING_X, WorldAffordances.EDGING_TOP_Y * 0.5, 12.05), Vector3(0.3, WorldAffordances.EDGING_TOP_Y, 3.2), BRICK)
	_mesh(root, "cube", Vector3(-6.15, WorldAffordances.EDGING_TOP_Y * 0.5, 12.05), Vector3(0.3, WorldAffordances.EDGING_TOP_Y, 3.2), BRICK)
	_mesh(root, "cube", Vector3(-4.9, WorldAffordances.EDGING_TOP_Y * 0.5, 10.6), Vector3(2.8, WorldAffordances.EDGING_TOP_Y, 0.3), BRICK)
	_mesh(root, "cube", Vector3(-4.9, WorldAffordances.EDGING_TOP_Y * 0.5, 13.5), Vector3(2.8, WorldAffordances.EDGING_TOP_Y, 0.3), BRICK)

	# A couple of blooms in the soil -- reuses _build_static_world()'s own
	# flower construction (stem + emissive bloom) so this bed reads as
	# planted rather than just an empty dirt box.
	var bed_flower_color := Color(0.85, 0.72, 0.42)
	for flower in [[-4.4, 11.5], [-5.4, 12.6]]:
		_mesh(root, "cylinder", Vector3(flower[0], 0.25, flower[1]), Vector3(0.035, 0.5, 0.035), FOLIAGE_LIGHT)
		_mesh(root, "sphere", Vector3(flower[0], 0.52, flower[1]), Vector3(0.14, 0.1, 0.14), bed_flower_color, Vector3.ZERO, 0.15)


## LANE: the walled passage, x[-5,5] z[-4,8] -- concept_02_path_
## discovery.png, and the piece GODOT_REBUILD_PLAN.md's successor task
## found completely missing: "a narrow passage between tall walls, reading
## as a canyon, light at the far end". Rendered walls are a thin pair right
## at the walkable edge (x=+-5); the much wider invisible collider flanking
## each one (world_bounds.gd) is what actually prevents walking around the
## outside of them.
##
## Openness pass (2026-08-29): +-3 -> +-5 and 9.5 m -> 7.0 m tall. The
## original went taller rather than wider on the reasoning that "a canyon
## read needs the height/width ratio" -- true, but it was pushed to 2.0
## (9.5 over a 4.76 m walkable width) for a passage the player spends a
## quarter of the demo walking down, and it measured as the most enclosed
## spot in the game. 7.0 over 8.76 m is 0.80: still unmistakably a walled
## passage with light at the far end, no longer a slot the player has to
## thread. The plate itself is a SHORT passage opening into light, and
## home's own doorway piers (with their lintel and dark ceiling, see
## _build_home) already carry that beat at the scale the plate shows it.
func _build_lane(root: Node3D) -> void:
	# Each wall is split into a dark plinth (y 0..0.4) and the tall plaster
	# above it, in place of one flat cube -- Gap 4 of the ambience pass
	# ("ground that isn't one plane"). The 39x37m world sits on a single flat
	# ground plane and player.gd's Y is locked at 0 with no terrain-follow at
	# all, so real height relief across a walkable path isn't available
	# here; this is the safe substitute, a shadow-catching base that grounds
	# the wall instead of leaving it looking like it floats on the flat
	# plane. Zero risk to the locked-Y character: it sits flush with the
	# wall's own existing footprint (world_bounds.gd's LANE colliders,
	# unchanged), and the player's own 0.32m collision radius can never
	# bring their rendered body closer to it than the wall face itself.
	_mesh(root, "cube", Vector3(-5.0, 0.2, 2.0), Vector3(0.5, 0.4, 12.4), SHADOW_STONE)
	_mesh(root, "cube", Vector3(-5.0, 3.7, 2.0), Vector3(0.5, 6.6, 12.4), PLASTER, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(5.0, 0.2, 2.0), Vector3(0.5, 0.4, 12.4), SHADOW_STONE)
	_mesh(root, "cube", Vector3(5.0, 3.7, 2.0), Vector3(0.5, 6.6, 12.4), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
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
	# Side walls dropped 4.2 -> 3.2 m (openness pass, 2026-08-29).
	# concept_03_playground_scale.png and concept_09_overall.png both bound
	# this space with a wall the eye clears easily -- treetops, haze and
	# rooflines above it, which is the entire reason _add_distant_layer()
	# exists. At 4.2 the wall's top edge sat above the horizon from
	# everywhere in the playground and hid the layer built to be seen.
	_mesh(root, "cube", Vector3(-16.0, 1.6, -12.0), Vector3(1.1, 3.2, 16.0), PLASTER, Vector3.ZERO, 0.0, "plaster")
	# East wall only for the deep end (z -20..-16); south of that the garden
	# wall (x=11, _build_garden_pocket) is the real boundary, and rendering
	# a second wall out at x=16 alongside it there would look like a second,
	# redundant room. Deliberately absent for z > -16 for that reason.
	_mesh(root, "cube", Vector3(16.0, 1.6, -18.0), Vector3(1.1, 3.2, 4.0), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	# South wall, as a blind arcade instead of one flat cube -- Gap 2 of the
	# ambience pass. concept_03_playground_scale.png is literally a row of
	# arches in a weathered wall; before this the build had exactly one arch
	# anywhere (the garden gap). See _build_arcade_wall()'s own doc comment
	# for why these are blind niches, not punch-throughs.
	#
	# 8.2 -> 4.6 m (openness pass). This is the backdrop of the watch and
	# circle beats -- the wall behind the children -- and at 8.2 it was
	# taller than the house and filled the upper half of every frame shot
	# from the chalk circle. The niches are 2.8 m tall (ARCH_SPRING_Y plus
	# the arch radius), so 4.6 still leaves a 1.8 m parapet band above
	# them, keeping the plate's "arches partway up a taller wall" reading
	# with roughly the plate's own proportion.
	_build_arcade_wall(root, 0.0, -20.0, 33.0, 1.1, 4.6, [-10.0, 0.0, 10.0])

	# North boundary (openness pass). The playground's own north edge, at
	# the lane/playground seam z=-4, had NO rendered geometry at all for
	# the 22 m either side of the lane mouth: collision came from the lane's
	# wide invisible flanks (world_bounds.gd), and the ground plane is a
	# single 42x40 m slab that runs on regardless. So a player standing
	# anywhere along the playground's north edge saw open ground continuing
	# north and walked into nothing -- 41 m of the walkable perimeter
	# measured as invisible wall (tools/_probe_reachability.gd). That is
	# the "all places are not reachable" complaint in its literal form:
	# not an unreachable ROOM, an unreachable-looking floor.
	#
	# Deliberately LOW (1.6 m) rather than matching the side walls. Two
	# reasons. It has to be seen over -- the point of the openness pass is
	# that this edge reads as a garden wall with a world beyond it, as in
	# concept_06_garden_gap.png, not as another slab. And no collider is
	# added with it (the flank already collides), so the camera can pass
	# over it; at 1.6 m it is below REVEAL's own 2.6 m camera height, so
	# that pass reads as looking over a low wall rather than clipping
	# through a tall one. Its SOUTH face lands exactly on z=-4 so the wall
	# sits entirely inside the existing collider's footprint and never
	# pokes into walkable ground.
	#
	# Two runs, skipping the lane mouth (x -5..5, where the lane's own walls
	# take over) and ending at x=11.5, overlapping the garden pocket's own
	# wall on that line so the two read as one continuous boundary out to
	# x=22. Centred at z=-3.6 with 0.8 depth, so the face the player sees
	# lands exactly on z=-4, the flank collider's own edge, and no part of
	# the wall stands on ground the player can still walk on.
	for run in [[-10.9, 11.2], [8.25, 6.5]]:
		_mesh(root, "cube", Vector3(run[0], 0.8, -3.6), Vector3(run[1], 1.6, 0.8), PLASTER, Vector3.ZERO, 0.0, "plaster")
	# Creepers along its top, the same trick the garden arch already uses to
	# keep a low wall from reading as a bare kerb. Kept strictly INSIDE the
	# wall's own z footprint (z -3.75..-3.25 against the wall's -4.0..-3.2)
	# rather than straddling it: the first version was 0.9 deep and centred
	# on the wall, so it hung 0.05 m past the south face -- into exactly the
	# sliver of air where the REVEAL spring arm parks when it stops against
	# this wall. The "gap" screenshot beat came back with the camera
	# literally inside the creeper at x=10.4, seeing the frame from within a
	# bush. Decoration on a wall must not overhang the face the camera can
	# reach.
	for creeper_x in [-14.5, -9.0, -6.2, 7.0, 10.4]:
		_mesh(root, "sphere", Vector3(creeper_x, 1.7, -3.5), Vector3(1.5, 0.5, 0.5), FOLIAGE)

	for x in [-3.4, 3.4]:
		_mesh(root, "cube", Vector3(x, 1.25, -12.8), Vector3(2.3, 2.4, 2.3), WOOD_LIGHT, Vector3.ZERO, 0.0, "wood")
		_mesh(root, "cube", Vector3(x, 2.75, -12.8), Vector3(2.7, 0.25, 2.7), WOOD, Vector3.ZERO, 0.0, "wood")
		# The tower roof. A bare CylinderMesh cone was the most obviously
		# placeholder thing left in this frame once the planting had real
		# models beside it -- a smooth untextured funnel where the rest of the
		# world had grown surface. roof-high-point.glb occupies the SAME volume
		# (2.0 m across, 1.82 m tall against the cone's 1.8) and, because the
		# model's origin is at its base while a CylinderMesh's is at its
		# centre, sits at the cone's base rather than its centre: y 4.0 - 1.8/2.
		_kind_of(root, "roof_point", Vector3(x, 3.1, -12.8), 2.0, Callable(self, "_primitive_tower_roof"), 0.0, "TowerRoof")
		for dx in [-0.8, 0.8]:
			for dz in [-0.8, 0.8]:
				_mesh(root, "cylinder", Vector3(x + dx, 0.5, -12.8 + dz), Vector3(0.16, 3.8, 0.16), WOOD, Vector3.ZERO, 0.0, "wood")
	_mesh(root, "cube", Vector3(0, 2.3, -12.8), Vector3(4.8, 0.25, 1.15), WOOD, Vector3.ZERO, 0.0, "wood")

	# The slide. Scale diagnosis (DEMO_PLAN.md, 2026-08-29): the previous
	# plank (a bare Vector3(-0.54,0,0)-tilted box) ran from ~2.3 m down to
	# -0.4 m -- authored backwards (its high end sat further from the tower
	# than its low end) and ending below the ground plane, so it never
	# visually connected deck to ground from any angle. Rebuilt from the
	# SAME two authored points WorldAffordances/player.gd already use for
	# the scripted ride -- the tower deck's own south face (its top, at the
	# footprint's edge) down to SLIDE_END (where the ride's launch hop
	# lands) -- via _slide_plank() below, so the visual and the ride can
	# never drift apart again: change PLATFORM_TOP_Y or SLIDE_END and this
	# geometry follows.
	var slide_top := Vector3(WorldAffordances.TOWER_X, WorldAffordances.PLATFORM_TOP_Y - 0.025, WorldAffordances.TOWER_Z + WorldAffordances.TOWER_FOOTPRINT_HALF)
	var slide_bottom := Vector3(WorldAffordances.SLIDE_END.x, 0.05, WorldAffordances.SLIDE_END.z)
	_slide_plank(root, slide_top, slide_bottom, 1.25, 0.18)

	# Side rails. The developer has called the slide out twice as "not properly
	# oriented"; the geometry was fixed to derive from the two authored points
	# above, but a bare 1.25 m plank still reads as an orange SLAB from the
	# play camera, with nothing to say which way it runs or which face you go
	# down. Rails are what make a slide legible as a slide.
	#
	# No CC0 slide model exists (kenney.nl and quaternius.com both checked in
	# full), so these are primitives -- but primitives built from the SAME two
	# points as the bed, through the same _slide_plank(), so they cannot drift
	# from it or from the ride. See _slide_rail() for why the offset has to be
	# taken along the plank's own local up rather than straight up in world Y.
	for side in [-1.0, 1.0]:
		_slide_rail(root, slide_top, slide_bottom, side * 0.60, 0.16, 0.12, 0.34)
	# A kicker at the foot, where SLIDE_END's launch hop lands -- the small
	# upturned lip a real slide finishes with, and a full-width visual full
	# stop at the bottom end so the run reads as having a direction.
	_mesh(root, "cube", slide_bottom + Vector3(0.0, 0.10, 0.28), Vector3(1.25, 0.30, 0.14), SLIDE, Vector3(deg_to_rad(-18.0), 0.0, 0.0), 0.0, "wood")


## A plank parallel to the from->to run, shifted `lateral` metres sideways and
## `up` metres clear of it. Delegates to _slide_plank() with shifted endpoints,
## so a rail can never end up at a different angle from the bed it guards.
##
## `up` is measured along the PLANK's own local up, not world Y. The run is
## tilted about X by theta, so its local up is (0, cos theta, sin theta);
## offsetting straight up in world Y instead would slide the rail along the
## bed's length as well as away from it, leaving it proud at the top and sunk
## at the bottom. `lateral` needs no such correction -- X is the rotation axis,
## so world X and the plank's local X are the same direction.
func _slide_rail(root: Node3D, from: Vector3, to: Vector3, lateral: float, up: float, width: float, thickness: float) -> void:
	var theta := atan2(-(to.y - from.y), to.z - from.z)
	var offset := Vector3(lateral, cos(theta) * up, sin(theta) * up)
	_slide_plank(root, from + offset, to + offset, width, thickness)


## A plank between two world points that share an X (so the box's local Z
## is the only axis that needs rotating away from world Z), tilted about
## local X. `width` runs along local X, unrotated -- the slide's sideways
## width; `thickness` is local Y before rotation, same parameter shapes
## _mesh() itself uses. Verified against the ORIGINAL (broken) slide: this
## formula, fed that plank's own two endpoints, reproduces its authored
## Vector3(-0.54,0,0) rotation exactly -- so the fix here is purely the
## two input points (deck edge to SLIDE_END, not two arbitrary floating
## numbers), not a new rotation trick.
##
## Textured, unlike the version before this pass. The slide was the ONLY large
## surface in the playground still carrying a bare palette colour -- the towers
## are "wood", the walls and piers "plaster" -- and a 3.7 x 1.25 m field of flat
## SLIDE orange is exactly what read as untextured cardboard beside the
## vegetation once that had real models. It is painted wood like everything
## else the children climb on, so it takes the same surface.
func _slide_plank(root: Node3D, from: Vector3, to: Vector3, width: float, thickness: float, surface: String = "wood") -> void:
	var dy := to.y - from.y
	var dz := to.z - from.z
	var run_len := sqrt(dy * dy + dz * dz)
	var theta := atan2(-dy, dz)
	var mid := (from + to) * 0.5
	_mesh(root, "cube", mid, Vector3(width, thickness, run_len), SLIDE, Vector3(theta, 0.0, 0.0), 0.0, surface)


## GARDEN POCKET, through the wall gap: x[11,22] z[-16,-4] --
## concept_06_garden_gap.png, relocated from the single-room version's
## x[5.4,10.7] strip and enlarged now that it is its own room rather than
## a slice of the one shared room. Same "wall with one discoverable
## opening, built as an arch" construction, just relocated and, unlike the
## single-room version, now fully enclosed on its own three remaining
## sides (world_bounds.gd's own doc comment: "the garden gap must still be
## the only way through").
func _build_garden_pocket(root: Node3D) -> void:
	# West wall (shared with the playground), two segments with the 3.4 m
	# gap between them. (No longer the balance-verb wall -- that affordance
	# now lives on the garden-bed edging in _build_garden_bed(); this stays
	# a plain boundary, matching WorldBounds.COLLIDERS exactly as before.)
	# Segment z-spans follow world_bounds.gd's widened gap (3.4 m, was 2.0).
	_mesh(root, "cube", Vector3(11.0, 0.55, -12.85), Vector3(0.6, 1.2, 6.3), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(11.0, 0.55, -5.15), Vector3(0.6, 1.2, 2.3), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	# North/south/east walls seal the rest of the pocket. 3.0 -> 2.4 m
	# (openness pass): concept_06_garden_gap.png's own wall is barely over
	# an adult's head with trees and light plainly visible above it, and
	# this pocket is only 11 m across, so 3.0 closed the sky out of the one
	# beat whose whole subject is warm light coming from somewhere else.
	_mesh(root, "cube", Vector3(16.5, 1.2, -16.0), Vector3(11.0, 2.4, 0.7), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	# The z=-4 side goes lower still, to 1.6 -- it is no longer this
	# pocket's own wall in isolation. _build_playground()'s new north
	# boundary runs the same line from x=-16.5 to x=11.5, so from x=11 out
	# to x=22 this simply continues it, and the two should be one wall
	# rather than a 1.6 m run that steps up to 2.4 partway along.
	#
	# It also fixes the "gap" screenshot beat directly. With the camera
	# collision added along z=-4 the REVEAL spring arm now stops INSIDE the
	# playground (z=-4.0 rather than sailing to z=+0.8), which is right,
	# but that parks it about half a metre west of this wall's own end --
	# so at 2.4 m the wall stood taller than the camera and filled the
	# right of frame edge-on. At 1.6 m the camera looks over it into the
	# pocket, which is the shot that beat is for.
	_mesh(root, "cube", Vector3(16.5, 0.8, -4.0), Vector3(11.0, 1.6, 0.7), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(22.0, 1.2, -10.0), Vector3(0.7, 2.4, 12.0), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	# Creepers carried along the lowered run, matching the playground
	# boundary's own so the join between them does not read as a seam --
	# including its "stay inside the wall's own footprint" rule, for the
	# same reason (see _build_playground()).
	for creeper_x in [13.0, 17.5, 20.5]:
		_mesh(root, "sphere", Vector3(creeper_x, 1.7, -3.95), Vector3(1.5, 0.5, 0.5), FOLIAGE)

	# The span over the opening, plus shoulders stepping down to it -- a
	# coarse arch, in keeping with ART_DIRECTION.md's "broad architectural
	# planes, modest geometric detail". Centred on the gap's own midpoint
	# (z=-8, unchanged -- it is halfway between the widened -9.7/-6.3
	# segment edges exactly as it was between the old -9/-7 pair, so every
	# authored route and test waypoint through the gap still lands in open
	# ground).
	#
	# RAISED (openness pass): the span used to sit at y 1.15-1.95, so the
	# opening was 1.15 m of clear height and the lintel crossed the eyeline
	# of a 1.2 m child dead centre. tools/_probe_reachability.gd measured
	# every sightline into this pocket -- from the playground, the swing,
	# the lane mouth -- as blocked by this one box. It is now at y 2.1-2.6:
	# 2.1 m clear, so the arch frames the view through it the way
	# concept_06_garden_gap.png does instead of guillotining it. Still
	# unmistakably an arch to duck through, still the only way in.
	_mesh(root, "cube", Vector3(11.0, 2.35, -8.0), Vector3(0.72, 0.5, 3.6), PLASTER, Vector3.ZERO, 0.0, "plaster")
	# Shoulders bridge wall-top (1.15) to span-bottom (2.1), buttressing up
	# to the span. They sit on the WALL SEGMENTS (z <= -9.7 and z >= -6.3),
	# NOT at the opening's edges: a first version centred them on -9.35 and
	# -6.65, which put them inside the opening itself, and since the
	# traversable band through a 3.4 m gap is z[-9.38, -6.62] once the
	# player's radius is taken off, the player could walk head-first into
	# them. Caught by tools/_probe_reachability.gd's head-height check, not
	# by looking -- from outside the gap they looked exactly right.
	_mesh(root, "cube", Vector3(11.0, 1.63, -10.05), Vector3(0.66, 0.95, 0.7), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(11.0, 1.63, -5.95), Vector3(0.66, 0.95, 0.7), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	# Vegetation swallowing the arch, as in the plate -- carried up onto the
	# raised span so it still reads as overgrown, and kept clear of the
	# opening itself so it cannot re-block what raising the span just
	# opened.
	for creeper in [[-9.6, 0.62], [-8.0, 0.5], [-6.4, 0.58]]:
		_mesh(root, "sphere", Vector3(11.0, 2.75, creeper[0]), Vector3(1.05, 0.55, creeper[1] * 1.6), FOLIAGE)

	# Gap 4 (ambience pass): a shallow sill at the arch's own threshold --
	# ground relief the locked-Y player (player.gd) can still walk over
	# convincingly, the same scale as the stepping stones already shipped
	# elsewhere in this world (~0.1m poke-up, already walked over there).
	# Unlike the lane's plinth above, this one IS crossed underfoot -- kept
	# to that same shallow precedent rather than a real riser for that
	# reason.
	_mesh(root, "cube", Vector3(11.0, 0.04, -8.0), Vector3(0.8, 0.08, 3.4), SHADOW_STONE)

	# A low garden fence along the pocket's bare south wall (x[13,19],
	# z=-4.6) -- Gap 3, thin things a low sun draws. Kept well clear of the
	# gap->ball sightline (the player's route from the arch at x=11 to
	# BallEnd at x=14,z=-12) so it doesn't compete with GardenPocketLight's
	# carefully-tuned "ball is the brightest thing in frame" below.
	#
	# A whole RUN, so unlike every other prop here the fallback is the run and
	# not a per-item swap -- going through _kind_of() panel by panel would have
	# had to move the primitive posts onto the panel centres to line them up,
	# and these seven posts' own x[13,19] is the thing worth preserving. The
	# library's fence model carries its posts AND rail in one 1 m panel; five
	# of them at scale 1.2 span exactly 13.0 to 19.0, and stand 0.42 m instead
	# of the primitive's 0.56 m -- still a low garden border, still the same
	# silhouette along the same sightline.
	var fence_panel := PropLibrary.path_for("fence_post")
	if fence_panel != "":
		for panel_x in [13.6, 14.8, 16.0, 17.2, 18.4]:
			_prop(root, fence_panel, Vector3(panel_x, 0.0, -4.6), PropLibrary.scale_for("fence_post", 1.2), 0.0, "GardenFence")
	else:
		for fx in range(13, 20):
			_mesh(root, "cylinder", Vector3(float(fx), 0.28, -4.6), Vector3(0.05, 0.56, 0.05), WOOD, Vector3.ZERO, 0.0, "wood")
		_mesh(root, "cube", Vector3(16.0, 0.54, -4.6), Vector3(7.4, 0.06, 0.06), WOOD_LIGHT, Vector3.ZERO, 0.0, "wood")

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


# --------------------------------------------------------- ambience pass --
# 2026-08-28: five gaps closed against docs/concept-art/extended/ and
# docs/ART_DIRECTION.md's "beauty from light, proportion, atmosphere and
# silence rather than asset density" -- a depth layer beyond the walls, a
# blind arcade, a handful of thin light-catching things, two safe forms of
# ground relief, and the overhead canopy the trees above now carry. Every
# shape below is either plain MeshInstance3D (via _mesh(), no new collider --
# WorldBounds.COLLIDERS is untouched by this whole pass) or CSG with
# use_collision = false, so none of it can change what world_bounds.gd's
# 2-D circle-vs-box check allows a player to reach.


## Gap 1: a silhouette layer OUTSIDE the playable envelope (world_bounds.gd's
## can_move_to: x[-16.6,22.6] z[-20.3,16.3]). Every plate in
## docs/concept-art/extended/ recedes -- distant rooftops, a treeline, haze --
## and this world stopped at a flat plaster wall with nothing behind it,
## which is also why volumetric fog (fog_end 42-60m across the three moods,
## mood_preset.gd) had nothing at a second distance to separate from the
## near walls. Purely visual and well clear of the envelope, so none of it
## can ever be walked into or change test_camera_never_in_geometry.gd's
## result (that raycast only checks physics layer 2, and nothing here joins
## any physics layer at all).
func _add_distant_layer(root: Node3D) -> void:
	# South, beyond the playground's far wall (z=-20) -- the backdrop the
	# watch/circle beats already look toward, past the chalk circle and the
	# new arcade.
	_roofline(root, -11.0, -29.0, 5.5, 10.0)
	_roofline(root, 1.0, -32.0, 7.0, 12.5)
	_roofline(root, 10.5, -28.5, 5.0, 9.0)
	_treeline_mass(root, -6.0, -27.0, 6.5, 8.5)
	_treeline_mass(root, 6.5, -30.0, 7.5, 9.5)

	# West, beyond the playground's side wall (x=-16.6).
	_roofline(root, -24.0, -11.0, 6.0, 10.5)
	_treeline_mass(root, -25.5, -16.0, 7.0, 8.0)

	# East, beyond the garden pocket's far wall (x=22.6) -- visible past the
	# gap/ball beats, the "something beyond the wall" the garden light
	# already promises up close.
	_roofline(root, 29.0, -9.0, 5.5, 10.0)
	_treeline_mass(root, 30.0, -14.5, 6.5, 8.5)

	# The lane's own flanks and the ground beside home (openness pass,
	# 2026-08-29). Unlike everything above, this band is INSIDE the
	# can_move_to envelope -- but it is not inside the walkable world, and
	# that is the point.
	#
	# The playground's new north boundary is deliberately only 1.6 m so it
	# can be seen over. Measuring what that exposes (see
	# tools/_probe_reachability.gd's dead-space visibility pass, run at
	# REVEAL's 2.6 m camera height rather than the child's 1.2 m eye) found
	# 194 m2 of unreachable ground fully visible from the playground: a
	# grazing ray clears the wall top by ~0.1 m and then runs 16 m up the
	# bare ground plane beside home. That is exactly "space the player can
	# see but never stand in", and the honest fix is not to raise the wall
	# back up -- it is to give what you see over the wall something to be.
	# Foliage and rooftops read as a world continuing; bare dirt reads as a
	# level that ran out.
	#
	# All of it is _mesh()/_treeline_mass()/_roofline() output: no collider,
	# no physics layer, so none of it changes where anyone can walk. But
	# "no collider" is not the same as "out of the way": a first pass put
	# these closer in and the offset second sphere _treeline_mass() builds
	# reached 0.2 m THROUGH the lane's west wall, showing up in the
	# threshold shot as a flat green disc stuck on the plaster. Each mass
	# below is placed so its full reach -- centre + 0.66 * width, which is
	# where that offset sphere's far edge lands -- clears the lane walls'
	# outer faces (x=+-5.25) and home's side walls (x=+-7.55, z 8..14).
	# tools/_probe_reachability.gd's "geometry standing in walkable space"
	# check now fails on this class of mistake rather than leaving it to
	# whoever looks at the next screenshot.
	for mass in [
		[-10.5, 0.5, 6.0, 7.5], [-14.0, 4.0, 7.0, 8.5], [-12.5, 7.5, 6.5, 8.0],
		[13.0, 0.5, 6.0, 7.5], [18.5, 4.0, 6.5, 8.0], [11.0, 7.0, 6.0, 7.5],
		# Near-east: without this one a viewer at (6, -6) still had a clear
		# line over the boundary wall to unreachable ground at (8, 9).
		# Placed north of the lane-flank tree at (9.5, 1.3) rather than on
		# top of it -- that tree is a camera fix's own composition anchor.
		[8.5, 4.5, 5.0, 7.0],
	]:
		_treeline_mass(root, mass[0], mass[1], mass[2], mass[3])
	# Rooftops on the ground beside home itself (x beyond +-7.5, z 8.5..16),
	# the two largest unreachable pockets -- so the porch reads as backing
	# onto neighbouring houses rather than onto nothing.
	_roofline(root, -12.5, 11.5, 5.5, 8.5)
	_roofline(root, 13.0, 12.0, 6.0, 9.0)
	_roofline(root, 19.0, 10.5, 5.0, 7.5)


## One roofline mass: a plain block plus a shallow cone roof. SHADOW_STONE
## reads as near-silhouette against the sky at this distance, and fog begins
## swallowing detail past ~12-14m (mood_preset.gd's fog_begin) long before
## these are reached -- this only has to be a correct SHAPE, not a correct
## building, per ART_DIRECTION.md's "modest geometric detail".
func _roofline(root: Node3D, x: float, z: float, width: float, height: float) -> void:
	var wall_h: float = height * 0.6
	_mesh(root, "cube", Vector3(x, wall_h * 0.5, z), Vector3(width, wall_h, width * 0.8), SHADOW_STONE)
	var roof_h: float = height - wall_h
	_mesh(root, "cone", Vector3(x, wall_h + roof_h * 0.5, z), Vector3(width * 1.15, roof_h, width * 0.95), SHADOW_STONE)


## One treeline mass: two overlapping flattened spheres standing in for a
## distant stand of trees -- the same FOLIAGE the near trees use, just
## bigger and coarser, since nothing here is meant to survive a close look.
func _treeline_mass(root: Node3D, x: float, z: float, width: float, height: float) -> void:
	_mesh(root, "sphere", Vector3(x, height * 0.5, z), Vector3(width, height, width), FOLIAGE)
	_mesh(root, "sphere", Vector3(x + width * 0.32, height * 0.42, z + width * 0.18), Vector3(width * 0.68, height * 0.76, width * 0.68), FOLIAGE)


## Gap 2: concept_03_playground_scale.png's row of arches in a weathered
## wall. Blind niches, not punch-throughs: cut only partway into the wall's
## own thickness, so there is always a shadowed stone backing visible inside
## each opening. A THROUGH arch here would visually promise a route that
## isn't one -- unlike the garden gap, this wall is the world's true south
## edge, and world_bounds.gd's collider for it (unchanged, still one solid
## box the full span) would stop a player who tried to walk into what looked
## like an opening.
##
## `length` runs along local/world X, `thickness` along local/world Z --
## matches this wall's own orientation (its long axis is X). CSGBox3D for
## the pier mass, then a CSGBox3D+CSGCylinder3D pair per arch as SUBTRACTION
## children (a rectangular lower half union a round top -- the standard
## two-primitive round-arch cut). use_collision = false throughout: the real
## collider for this wall is world_bounds.gd's own flat box, untouched.
func _build_arcade_wall(root: Node3D, center_x: float, center_z: float, length: float, thickness: float, wall_height: float, arch_xs: Array) -> void:
	var combiner := CSGCombiner3D.new()
	combiner.name = "ArcadeWall"
	root.add_child(combiner)
	combiner.owner = root
	combiner.position = Vector3(center_x, 0.0, center_z)

	var pier := CSGBox3D.new()
	pier.size = Vector3(length, wall_height, thickness)
	pier.position = Vector3(0.0, wall_height * 0.5, 0.0)
	pier.operation = CSGShape3D.OPERATION_UNION
	pier.material = _csg_material(PLASTER)
	pier.use_collision = false
	combiner.add_child(pier)
	pier.owner = root

	# +Z is this wall's playground-facing side (world z=-20+thickness/2) --
	# confirmed sun-facing in all three moods (mood_preset.gd's sun_from/
	# sun_target all point predominantly toward -X/-Z, so a +Z-facing
	# surface catches it), which is the whole point: something for the low
	# sun to rake across and into.
	var near_face: float = thickness * 0.5
	for ax in arch_xs:
		_arch_niche(combiner, root, float(ax), near_face)


const ARCH_WIDTH := 1.6
const ARCH_SPRING_Y := 2.0
const ARCH_DEPTH := 0.8

## One blind arch niche. `local_x` is the arch's centre along the wall's own
## run; `near_face` is the local Z of the wall's sun-facing surface, so the
## cut always starts flush with it regardless of wall thickness. Total niche
## height (ARCH_SPRING_Y + radius = 2.8m) leaves most of `wall_height` above
## it as a solid parapet band -- the arches are a feature partway up a
## taller wall, matching the plate, not the wall's full height.
func _arch_niche(combiner: CSGCombiner3D, root: Node3D, local_x: float, near_face: float) -> void:
	var radius: float = ARCH_WIDTH * 0.5
	var cut_material := _csg_material(SHADOW_STONE)
	# 0.05 past the face, both cutters -- clean boolean, no coplanar
	# z-fighting at the opening's own front edge.
	var cut_z: float = near_face - ARCH_DEPTH * 0.5 + 0.05

	var lower := CSGBox3D.new()
	lower.size = Vector3(ARCH_WIDTH, ARCH_SPRING_Y, ARCH_DEPTH)
	lower.position = Vector3(local_x, ARCH_SPRING_Y * 0.5, cut_z)
	lower.operation = CSGShape3D.OPERATION_SUBTRACTION
	lower.material = cut_material
	lower.use_collision = false
	combiner.add_child(lower)
	lower.owner = root

	var top := CSGCylinder3D.new()
	top.radius = radius
	top.height = ARCH_DEPTH
	top.sides = 16
	top.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)  # local Y axis (default) -> world Z
	top.position = Vector3(local_x, ARCH_SPRING_Y, cut_z)
	top.operation = CSGShape3D.OPERATION_SUBTRACTION
	top.material = cut_material
	top.use_collision = false
	combiner.add_child(top)
	top.owner = root


## Shared material setup for CSG shapes -- same values _mesh() uses for
## every MeshInstance3D, so the arcade matches the rest of the palette.
func _csg_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = ROUGHNESS
	mat.metallic = 0.0
	return mat


## A tree. Positions and per-tree scale factors are UNCHANGED from M3.2; what
## changed is that "a tree" is now one of PropLibrary's six species rather
## than tree_large.gltf five times over. Five identical trees was the single
## most artificial thing left in the world -- real planting is never a clone
## stamp, and the eye reads the repeat long before it reads the shape.
##
## Species cycles through the library in call order rather than hashing x/z.
## Both are deterministic (this generator must produce the same scene every
## run), but with only five trees a hash collides: the first attempt here put
## tree_default at BOTH lane-mouth trees and tree_plateau at two more, which
## is three species doing the work of five. A counter cannot collide until
## the sixth tree. Yaw stays position-derived -- it wants to look arbitrary,
## and it is what stops two trees of the same species reading as a pair.
var _tree_count := 0

func _add_tree(root: Node3D, x: float, z: float, s: float) -> void:
	var variant := _tree_count
	_tree_count += 1
	var yaw := fmod(absf(x * 1.7 + z * 2.3), TAU)
	_kind_of(root, "tree", Vector3(x, 0.0, z), s, Callable(self, "_primitive_tree"), yaw, "Tree", variant)


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


## _kind() by KIND rather than by file path -- the same detailed/primitive
## split, with scripts/prop_library.gd choosing the file and working out the
## scale that makes it come out `scale` metres on its kind's own axis.
##
## Prefer this over _kind() for anything the library knows about. Two things
## it buys that a hardcoded path cannot: a kind can have several models and
## vary by `variant` (six tree species where there was one repeated
## tree_large.gltf), and the size correction _add_rock() had to spell out by
## hand as `s / ROCK_NATIVE_WIDTH` becomes the library's job for every kind.
##
## `scale` means the same thing in BOTH branches here -- unlike _kind(),
## whose two scale parameters differ precisely because the caller was left to
## do that correction itself. PropLibrary.scale_for() has already done it.
func _kind_of(root: Node3D, kind: String, position: Vector3, scale: float, primitive_fallback: Callable, rotation_y: float = 0.0, name_hint: String = "", variant: int = 0) -> void:
	var path := PropLibrary.path_for(kind, variant)
	if path != "":
		_prop(root, path, position, PropLibrary.scale_for(kind, scale, variant), rotation_y, name_hint)
		return
	# Silent when models are simply switched off; loud when they were wanted
	# and the file is not there -- same split _kind() makes above, and the
	# reason PropLibrary separates models_enabled() from path_for().
	if PropLibrary.models_enabled() and PropLibrary.variant_count(kind) > 0:
		push_warning("Detailed asset missing for kind '%s', using primitive fallback" % kind)
	primitive_fallback.call(root, position, scale, rotation_y)


## Primitive-mode fallback for _add_tree(): the 3-primitive trunk+foliage
## composition M3.2's tree_large.gltf replaced, restored here as the
## toggle's "today's boxes" side. Not a precise match to tree_large.gltf's
## silhouette (~2.75m wide x ~5m tall) -- close enough in scale (WOOD
## trunk + two FOLIAGE tiers, apex ~4.65m at scale 1.0) to read as the
## same kind of thing standing in the same spot.
func _primitive_tree(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	_mesh(root, "cylinder", position + Vector3(0.0, 1.5 * scale, 0.0), Vector3(0.22, 3.0, 0.22) * scale, WOOD, Vector3.ZERO, 0.0, "wood")
	_mesh(root, "sphere", position + Vector3(0.0, 3.2 * scale, 0.0), Vector3(1.6, 1.4, 1.6) * scale, FOLIAGE)
	_mesh(root, "sphere", position + Vector3(0.0, 4.1 * scale, 0.0), Vector3(1.1, 1.1, 1.1) * scale, FOLIAGE_LIGHT)


## Primitive-mode fallback for every bush_spots entry in
## _build_static_world() -- identical to the sphere formula the 5
## always-primitive bushes used before M4, now shared by all 6.
func _primitive_bush(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	_mesh(root, "sphere", position + Vector3(0.0, 0.55 * scale, 0.0), Vector3(1.3, 1.0, 1.1) * scale, FOLIAGE)


## Primitive-mode fallback for the garden flowers: exactly the stem-plus-head
## pair this file used before, with `scale` as the flower's overall height so
## it matches what the "flower" kind's target of 1.0 means on the model side.
func _primitive_flower(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	var stem := scale / 0.6  # the old numbers were authored at a 0.6 m flower
	_mesh(root, "cylinder", position + Vector3(0.0, 0.25 * stem, 0.0), Vector3(0.035, 0.5, 0.035) * stem, FOLIAGE_LIGHT)
	_mesh(root, "sphere", position + Vector3(0.0, 0.52 * stem, 0.0), Vector3(0.14, 0.1, 0.14) * stem, Color(0.85, 0.72, 0.42), Vector3.ZERO, 0.15)


## Primitive-mode fallback for the play towers' roofs: the bare CylinderMesh
## cone they had before. `position` is the roof's BASE (the model's own origin
## convention), so the cone -- which a CylinderMesh centres -- is lifted half
## its height to occupy the same volume. Height tracks `scale` at the authored
## 2.0-wide / 1.8-tall proportion rather than being a second loose constant.
func _primitive_tower_roof(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	var height := scale * 0.9
	_mesh(root, "cone", position + Vector3(0.0, height * 0.5, 0.0), Vector3(scale, height, scale), WOOD_LIGHT, Vector3.ZERO, 0.0, "wood")


## Primitive-mode fallback for the porch pot: the plain WOOD cylinder this
## file used before, with `scale` as the pot's width so it matches what the
## "flowerpot" kind's target of 1.0 means on the model side.
func _primitive_flowerpot(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	_mesh(root, "cylinder", position + Vector3(0.0, 0.18, 0.0), Vector3(scale * 0.5, 0.36, scale * 0.5), WOOD, Vector3.ZERO, 0.0, "wood")


## Primitive-mode fallback for the scattered grass: one cone, as before.
## The two-tone FOLIAGE/FOLIAGE_LIGHT alternation the loop used to do by
## `index % 3` is derived from position here instead -- _kind_of() hands a
## fallback only (root, position, scale, rotation), and position is the one
## input that keeps this deterministic without threading an index through
## every caller for the sake of one colour.
func _primitive_grass_blade(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	var lighter := int(absf(position.x * 2.0 + position.z * 3.0)) % 3 == 0
	_mesh(root, "cone", position + Vector3(0.0, scale * 0.48, 0.0), Vector3(0.12, scale, 0.12), FOLIAGE_LIGHT if lighter else FOLIAGE)


## Primitive-mode fallback for the bench spot: the "cube trio" bench.gltf
## replaced in M3.2 (seat + backrest + a single plinth standing in for
## two legs), in the playground's existing WOOD/WOOD_LIGHT tones.
func _primitive_bench(root: Node3D, position: Vector3, scale: float, rotation_y: float) -> void:
	var rot := Vector3(0.0, rotation_y, 0.0)
	_mesh(root, "cube", position + Vector3(0.0, 0.20 * scale, 0.0), Vector3(1.5, 0.4, 0.45) * scale, WOOD, rot, 0.0, "wood")
	_mesh(root, "cube", position + Vector3(0.0, 0.46 * scale, 0.0), Vector3(1.7, 0.12, 0.55) * scale, WOOD_LIGHT, rot, 0.0, "wood")
	_mesh(root, "cube", position + Vector3(0.0, 0.80 * scale, -0.20 * scale), Vector3(1.7, 0.55, 0.12) * scale, WOOD_LIGHT, rot, 0.0, "wood")


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
	_mesh(root, "sphere", position + Vector3(0.0, 0.05, 0.0), Vector3(scale, 0.14, scale * 0.85), PATH, Vector3.ZERO, 0.0, "paving")


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

