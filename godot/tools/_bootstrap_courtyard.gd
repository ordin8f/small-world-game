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

## The tower staircase's model (see _add_tower_stairs()). Kenney Fantasy Town
## Kit, CC0, already vendored alongside its shared Textures/colormap.png
## atlas -- tools/_check_asset_textures.gd is what guarantees that atlas
## actually resolves rather than the model importing pure white, which is how
## the roofs from this same kit shipped once.
const STAIR_MODEL := "res://assets/kenney_town/stairs-wood-handrail.glb"


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

## `node_name` is optional and almost always left empty -- these are hundreds
## of anonymous decorative shapes and naming them all would be noise. It
## exists for the few that something else has to find by name afterwards:
## today just the slide's bed, which tests/play/test_slide_ride_on_the_plank.gd
## looks up in the built scene to measure the ride against.
func _mesh(root: Node3D, kind: String, position: Vector3, scale: Vector3, color: Color, rotation_rad: Vector3 = Vector3.ZERO, emissive: float = 0.0, surface: String = "", node_name: String = "") -> void:
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
		"ring":
			# A unit ring lying flat in XZ, for the chalk circle. Authored
			# at ring radius 0.5 with a thin tube so a caller's `scale`
			# reads as diameter on X/Z; scale.y squashes the tube into the
			# flat mark chalk actually makes on stone.
			var tm := TorusMesh.new()
			tm.inner_radius = 0.47
			tm.outer_radius = 0.5
			tm.rings = 48
			tm.ring_segments = 6
			mesh = tm
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
	if node_name != "":
		instance.name = node_name
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
## Park pass (2026-08-30). The whole world used to stand on one uniform
## packed-earth plane -- 77% of everything the player walked on, measured
## (tools/_probe_reachability.gd's surface census). A park is legible
## because its surfaces are: mown grass, a bound path, a soft pit under the
## equipment, a planted bed. These are the missing four, and they are the
## cheapest large change available here because SURFACES already carries
## the textures; nothing was using them on the ground.
##
## Values stay inside ART_DIRECTION.md's muted band -- LAWN is barely more
## saturated than the GROUND it replaces, and reads as green only next to
## the paving, which is the point. MEADOW is the same green taken down and
## greyed: the ground BEYOND the park's boundary, so that what you see over
## the hedge reads as somewhere else rather than as more park.
## Both are authored one step SATURATED of where they should read, because
## _apply_surface() lerps every textured albedo 30% toward white to stop the
## texture and the palette multiplying into mud -- so a colour that looks
## right written down comes out of that as pale olive across 700 m^2 of lawn.
const LAWN := Color(0.26, 0.37, 0.15)
const MEADOW := Color(0.24, 0.28, 0.17)
const BARK := Color(0.35, 0.24, 0.15)
const CHALK := Color(0.78, 0.76, 0.62)
## Painted metalwork -- railings, the gate, the bin. Darker than
## SHADOW_STONE and slightly cooler, so a railing reads as ironwork against
## plaster rather than as more stone.
const IRONWORK := Color(0.17, 0.17, 0.16)

## Ground layers, top surface in metres -- ordered and spaced so no two are
## ever coplanar (z-fighting on a 45 m plane is visible from everywhere) and
## so the order they are drawn in cannot matter.
##
## The heights themselves now live in WorldAffordances, aliased here so
## every call site below reads the same as it always did. They moved
## because they are not a drawing decision: player.gd locks the child's Y
## to the walking plane, so a layer's height is the difference between
## standing ON the plaza and standing 5 cm inside it, and that has to be
## checkable by a test (tests/play/test_ground_under_the_childs_feet.gd)
## which cannot import a one-shot SceneTree tool. Their doc comment has the
## measurements and why they were re-spaced downward from 0.
const Y_LAWN := WorldAffordances.Y_LAWN
const Y_PAVING := WorldAffordances.Y_PAVING
const Y_BARK := WorldAffordances.Y_BARK
const Y_SOIL := WorldAffordances.Y_SOIL
const Y_CHALK := WorldAffordances.Y_CHALK
const Y_HAIR := WorldAffordances.SURFACE_HAIR


## 2026-08-28 world expansion: one cramped 20x24.5 m room -> four connected
## places (world_bounds.gd's own doc comment has the authoritative layout
## table; every position below either matches a WorldBounds/WorldAffordances
## constant directly or is derived from one, same discipline the single-room
## version held). Built to read as somewhere to choose a direction and go,
## not a diorama: HOME (porch/doorway) -> LANE (the new narrow passage,
## concept_02_path_discovery.png) -> THE PARK (open, the chalk circle/
## towers/slide/swing/sandbox) -> GARDEN POCKET through the wall gap
## (concept_06_garden_gap.png, relocated further out and enlarged). Kept
## sparse throughout, per ART_DIRECTION.md ("Avoid filling every space
## with props") -- bigger means more places, not more clutter in any one
## of them.
##
## 2026-08-30 park pass: the third of those four places widened from
## 32 x 16 m to 45 x 20 m and, more to the point, stopped being one
## uniform plane. It has surfaces, a path system, a legible boundary and
## furniture that belongs to the path -- _build_park_ground(),
## _build_park_boundary() and _build_park_furniture() below, each with its
## own doc block. The sparseness rule still holds: what filled the extra
## ground is lawn, trees and four benches, not more props per square metre.
func _build_static_world(root: Node3D) -> void:
	# The base plane, now grown to cover the park (x[-25,25] z[-26,18], with
	# the outermost wall faces at x=-23.6/22.6 and z=-24.6) and RESURFACED.
	# It used to be packed earth and it used to be the only thing under the
	# player's feet almost everywhere; it is now rough meadow, and it is
	# only ever seen OUTSIDE the boundary. Everything inside is laid over it
	# by _build_park_ground(). That inversion is the point: the ground the
	# player walks on and the ground beyond the hedge should not be the same
	# ground, or the boundary reads as an arbitrary stopping line across an
	# open field -- which is exactly what the developer was looking at.
	_mesh(root, "cube", Vector3(0, -0.28, -4), Vector3(50, 0.5, 44), MEADOW, Vector3.ZERO, 0.0, "grass")
	_build_park_ground(root)

	_build_home(root)
	_build_garden_bed(root)
	_build_lane(root)
	_build_playground(root)
	_build_garden_pocket(root)
	_build_park_boundary(root)
	_build_park_furniture(root)

	# Puddles, stepping stones, and bench. First two puddles sit in the
	# lane (unchanged from the single-room version -- its x[-3,3]/z[-4,8]
	# footprint already contained them); the third is the garden one,
	# relocated with the rest of that pocket. Positions mirror
	# WorldAffordances.PUDDLES/STONES exactly.
	# Y raised 0.01 -> 0.055 (park pass): the two lane puddles lie on laid
	# paving, and at the old height they were underneath it. They stand a
	# shallow 0.03 m proud of the flags, which is what a puddle on worn
	# stone looks like from a child's eye and is exactly the reading
	# concept_02/04 give them.
	#
	# Now written as an offset FROM the paving rather than as an absolute,
	# so that reading is what survives when the layer stack moves -- which
	# it just did. As an absolute 0.055 these would have been left standing
	# 6 cm proud of a plaza that had dropped to the child's feet. Unlike the
	# layers themselves these are deliberately ABOVE the walking plane: you
	# step into a puddle, and 2 cm of water over the sole of a shoe is the
	# whole point of the splash.
	const PUDDLE_PROUD := 0.005  ## centre offset; the flattened sphere adds 0.02 above that
	var puddle_color := Color(0.20, 0.32, 0.37, 0.65)
	for p in [
		[-1.5, 3.2, 1.6, 0.05, 0.9],
		[2.1, 0.8, 1.15, 0.05, 0.75],
		[12.4, -9.4, 1.4, 0.05, 0.8],
	]:
		_mesh(root, "sphere", Vector3(p[0], Y_PAVING + PUDDLE_PROUD, p[1]), Vector3(p[2], p[3], p[4]), puddle_color)
	# Stepping stones, likewise relative to the lawn they sit on rather than
	# absolute. They stand well proud of it on purpose -- they are stones to
	# hop between -- and with the player's Y locked the child crosses them
	# at ankle height rather than on top, which is a limitation of the
	# locked-Y walker that predates this pass and is not addressed here.
	for stone in [[11.7, -7.7, 0.45], [12.5, -8.4, 0.52], [13.3, -9.1, 0.48], [14.0, -9.9, 0.55]]:
		var s: float = stone[2]
		_mesh(root, "sphere", Vector3(stone[0], Y_LAWN + 0.07, stone[1]), Vector3(s, 0.16, s * 0.85), PATH, Vector3.ZERO, 0.0, "paving")
	# The bench that used to stand here (-7, -9.8, facing nowhere) is now one
	# of four in _build_park_furniture(), placed on the path and turned to
	# face what it looks at. Same position, so every probe landmark and
	# sightline measured against it still means the same thing.

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
	# Moved -2.5,-16.5 -> -3.0,-18.6 (park pass): its old spot is now inside
	# the plaza's paving, and a tree with no collider standing in the middle
	# of the play surface is something the player walks straight through.
	# From the circle beat's camera it still breaks the skyline over the
	# arcade behind, which is the whole reason it is there.
	_add_tree(root, -3.0, -18.6, 1.4)
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
	# Moved -8.7,-13.7 -> -11.0,-13.4 (park pass), off the plaza's paving and
	# onto the west lawn beside the perimeter path -- same reason as the
	# skyline tree above.
	_kind(root, Vector3(-11.0, Y_LAWN, -13.4), "res://assets/park/bush_large.gltf", 1.0, Callable(self, "_primitive_bush"), 1.0, 0.0, "BushFeature")

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

	# Tufts of longer grass on the lawn, where a mower would not reach: the
	# outer flanks and the strip along the boundary. Re-scattered for the
	# park pass -- the old band (|x| 5..15) is now mostly the plaza's own
	# paving, so two thirds of these tufts would have been growing out of
	# flagstones. Pushed out to |x| 10.5..21 and deepened to z -23..-5, so
	# they read as the untended edge of a mown lawn, which is where long
	# grass actually is in a park.
	#
	# Still deliberately NOT scattered into the lane or home (kept bare per
	# the brief: "bigger means more places, not more clutter"), and still
	# the same 48, the same heights, and the same _kind_of() path.
	for index in range(48):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z: float = -23.0 + fmod(index * 1.13, 18.0)
		var x: float = side * (10.5 + fmod(index * 2.17, 10.5))
		# The garden pocket is its own place with its own planting; keep the
		# park's rough edge out of it.
		if x > 10.5 and z > -16.0:
			x = -x
		var height: float = 0.32 + (index % 5) * 0.07
		_kind_of(root, "grass_tuft", Vector3(x, Y_LAWN, z), height, Callable(self, "_primitive_grass_blade"), fmod(absf(x * 3.7 + z * 5.1), TAU), "Grass", index)


# ------------------------------------------------------------ park ground --
# Park pass (2026-08-30). The developer: "you should consider what such
# parks and playgrounds look like - to be able to implement something that
# looks natural."
#
# What they look like, before any prop is placed, is a set of SURFACES.
# Mown grass. A bound path that goes from the gate to the things worth
# stopping at, and curves, because a path that runs straight to the middle
# of a field is a runway. A soft pit under anything you can fall off. Beds
# with a kerb round them. That is most of what makes a photograph of a park
# legible as a park rather than as a field with equipment in it, and none of
# it existed here: the surface census in tools/_probe_reachability.gd
# measured 77% of all walkable ground as one packed-earth texture.
#
# Layered rather than tiled: every patch below is a flat slab laid over the
# base plane at its own authored height (Y_LAWN < Y_PAVING < Y_BARK <
# Y_SOIL < Y_CHALK), so patches may freely overlap and the later, more
# specific one simply wins. No seams to keep in sync, and no two coplanar
# faces anywhere.


## One flat ground patch. `top` is the surface height, so a caller writes
## the height it wants to see rather than a centre plus half a thickness.
##
## Every patch is NAMED (GroundPatch0, 1, ...) rather than left anonymous
## like the hundreds of other decorative meshes here. That is the whole
## mechanism behind tests/play/test_ground_under_the_childs_feet.gd: the
## invariant that matters is "no walkable surface top rises above the plane
## player.gd locks the child to", and checking it against the CONSTANTS
## would miss a call site that passed a literal `top`. Checking it against
## the built scene cannot, but only if the patches can be found in it.
var _ground_patch_count: int = 0

func _ground(root: Node3D, cx: float, cz: float, w: float, d: float, top: float, color: Color, surface: String, rot_y: float = 0.0) -> void:
	const THICK := 0.16
	_mesh(root, "cube", Vector3(cx, top - THICK * 0.5, cz), Vector3(w, THICK, d), color, Vector3(0.0, rot_y, 0.0), 0.0, surface, "GroundPatch%d" % _ground_patch_count)
	_ground_patch_count += 1


## A path laid between waypoints: one slab per segment, rotated to it, plus
## a square at each interior joint so the mitre does not show as a notch.
## Curves are polylines here -- the world is built from axis-aligned boxes
## and a real spline would need its own mesh; four short segments through an
## arc read as a curve at this scale and cost nothing.
func _path_run(root: Node3D, points: Array, width: float, color: Color = PATH, surface: String = "paving", top: float = Y_PAVING) -> void:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var mid := (a + b) * 0.5
		var span := b - a
		var length := span.length()
		if length < 0.01:
			continue
		# atan2(x, z): a slab's local +Z is its length, so this is the yaw
		# that points that length down the segment.
		_ground(root, mid.x, mid.y, width, length, top, color, surface, atan2(span.x, span.y))
	for i in range(1, points.size() - 1):
		var p: Vector2 = points[i]
		_ground(root, p.x, p.y, width, width, top, color, surface)


## A planted bed: soil, a low brick kerb on all four sides, and something
## growing in it. The kerb is what makes a bed read as deliberate rather
## than as a patch of bare dirt -- the same reading _build_garden_bed()'s
## own edging already carries by the home threshold, reused here so the
## park's beds and home's bed are visibly the same kind of object.
func _planting_bed(root: Node3D, cx: float, cz: float, w: float, d: float, seed_index: int) -> void:
	const KERB_H := 0.26
	const KERB_T := 0.24
	# BRICK straight is the home garden bed's own colour, authored for one
	# 2.8 m bed seen up close on a shaded porch. Ten beds of it along a
	# sunlit boundary came back as vivid terracotta stripes -- the loudest
	# thing in several survey frames, against ART_DIRECTION.md's muted band.
	# Taken most of the way to stone; still reads as a fired-clay edging,
	# no longer as the subject of the picture.
	var kerb := BRICK.lerp(SHADOW_STONE, 0.45)
	_ground(root, cx, cz, w, d, Y_SOIL, SOIL, "soil")
	_mesh(root, "cube", Vector3(cx, KERB_H * 0.5, cz + d * 0.5), Vector3(w + KERB_T * 2.0, KERB_H, KERB_T), kerb)
	_mesh(root, "cube", Vector3(cx, KERB_H * 0.5, cz - d * 0.5), Vector3(w + KERB_T * 2.0, KERB_H, KERB_T), kerb)
	_mesh(root, "cube", Vector3(cx + w * 0.5, KERB_H * 0.5, cz), Vector3(KERB_T, KERB_H, d), kerb)
	_mesh(root, "cube", Vector3(cx - w * 0.5, KERB_H * 0.5, cz), Vector3(KERB_T, KERB_H, d), kerb)

	# Planting, inset so nothing overhangs the kerb. Counts scale with the
	# bed rather than being fixed, so a long boundary bed is not as sparse
	# as a small one at the gate.
	var shrubs := maxi(1, int(w * d / 4.0))
	for i in range(shrubs):
		var t: float = (i + 0.5) / float(shrubs)
		var bx: float = cx + (t - 0.5) * (w - 1.2)
		var bz: float = cz + (fmod(absf(bx * 3.3 + seed_index * 1.7), 1.0) - 0.5) * maxf(d - 1.2, 0.0)
		_kind_of(root, "bush", Vector3(bx, Y_SOIL, bz), 0.85, Callable(self, "_primitive_bush"), fmod(absf(bx * 2.1 + bz), TAU), "BedBush", seed_index + i)
	for i in range(shrubs + 1):
		var t: float = (i + 0.25) / float(shrubs + 1)
		var fx: float = cx + (t - 0.5) * (w - 0.8)
		var fz: float = cz + (fmod(absf(fx * 5.9 + seed_index), 1.0) - 0.5) * maxf(d - 0.8, 0.0)
		_kind_of(root, "flower", Vector3(fx, Y_SOIL, fz), 0.6, Callable(self, "_primitive_flower"), fmod(absf(fx * 4.1 + fz * 2.7), TAU), "BedFlower", seed_index + i)


## The park's surfaces, laid outward from the thing the player walks on
## most. Coordinates are the room's own (world_bounds.gd's PARK block):
## x[-22.4, 21.65] for z[-23.4,-16], x[-22.4, 10.65] for z[-16,-4], and the
## slabs run a little past each wall's inner face so no join with a wall can
## leave a strip of base plane showing.
func _build_park_ground(root: Node3D) -> void:
	# --- lawn, the default everywhere inside the boundary -----------------
	_ground(root, -0.3, -20.0, 45.0, 8.6, Y_LAWN, LAWN, "grass")     # deep band
	_ground(root, -5.9, -9.9, 33.8, 12.6, Y_LAWN, LAWN, "grass")     # north band
	_ground(root, 16.5, -10.0, 11.4, 12.4, Y_LAWN, LAWN, "grass")    # garden pocket

	# --- the plaza: paving, and the reason the play area reads as a place --
	# concept_07_circle.png is the contract here and it is explicit: the
	# chalk circle and the children are on FLAGSTONES, bounded by a low wall
	# with a treeline over it, with planting hugging the piers either side.
	# Not on grass, and not on the same ground as everything else.
	const PLAZA_W := 17.0
	const PLAZA_D := 10.4
	const PLAZA_Z := -11.6
	_ground(root, 0.0, PLAZA_Z, PLAZA_W, PLAZA_D, Y_PAVING, PATH, "paving")
	# A darker stone band round its edge. This is the single detail that
	# makes a paved area read as LAID -- an edging course is how you can
	# tell a plaza from a light patch on the floor, and from above it is
	# the only thing that draws the plaza's outline at all. 0.6 m wide and a
	# hair proud of the paving, so it is a change of stone rather than a
	# step: nothing to walk into.
	#
	# That hair is Y_HAIR (half a layer step) rather than the 0.005 this was
	# authored with. 0.005 was chosen against the old widely-spaced stack;
	# once the stack compressed to sit under the child's feet it would have
	# landed exactly on Y_SOIL, which is the coplanarity the whole ordering
	# exists to avoid. Half a step can never collide with a layer.
	const EDGE_W := 0.6
	var edge_stone := SHADOW_STONE.lerp(PATH, 0.2)
	for side in [-1.0, 1.0]:
		_ground(root, 0.0, PLAZA_Z + side * (PLAZA_D * 0.5 - EDGE_W * 0.5), PLAZA_W, EDGE_W, Y_PAVING + Y_HAIR, edge_stone, "paving")
		_ground(root, side * (PLAZA_W * 0.5 - EDGE_W * 0.5), PLAZA_Z, EDGE_W, PLAZA_D, Y_PAVING + Y_HAIR, edge_stone, "paving")

	# --- home porch and the lane, both paved ------------------------------
	# The lane is narrower than its own walls, with a lawn verge either side
	# -- concept_02/04's weeds coming up where the flags meet the wall. It
	# used to be one 6.4 m strip running the full length of home AND lane,
	# which read as a road.
	_ground(root, 0.0, 12.15, 14.2, 8.5, Y_PAVING, PATH, "paving")
	_ground(root, 0.0, 2.0, 7.4, 12.4, Y_PAVING, PATH, "paving")
	for side in [-1.0, 1.0]:
		_ground(root, side * 4.2, 2.0, 1.1, 12.4, Y_LAWN, LAWN, "grass")

	# --- the path system --------------------------------------------------
	# A perimeter loop round the lawn off the plaza's west side, back along
	# the south boundary and up to a dead end at the south-east corner
	# (where a bench under a tree is the reason to walk it); an east link
	# closing the loop back to the plaza; short spurs to the gate, the
	# sandbox and the garden arch. Every leg goes somewhere.
	const PATH_W := 2.6
	_path_run(root, [Vector2(0.0, -3.6), Vector2(0.0, -6.2)], PATH_W)
	_path_run(root, [
		Vector2(-8.3, -7.5), Vector2(-13.0, -7.6), Vector2(-17.0, -9.0),
		Vector2(-19.8, -12.5), Vector2(-20.0, -17.5), Vector2(-17.5, -20.6),
		Vector2(-11.0, -21.8), Vector2(-2.0, -22.0), Vector2(7.0, -22.0),
		Vector2(14.0, -21.4), Vector2(19.0, -19.6), Vector2(20.4, -17.6),
	], PATH_W)
	_path_run(root, [Vector2(8.4, -16.0), Vector2(12.5, -18.2), Vector2(15.6, -20.6)], PATH_W)
	_path_run(root, [Vector2(8.4, -8.0), Vector2(11.4, -8.0)], 2.4)
	_path_run(root, [Vector2(-11.2, -7.6), Vector2(-10.5, -9.0)], 1.8)

	# --- soft surfaces under the things you can fall off ------------------
	_ground(root, 6.5, -8.7, 4.6, 4.6, Y_BARK, BARK, "earth")       # under the swing
	_ground(root, -10.5, -8.0, 5.6, 5.6, Y_BARK, BARK, "earth")     # round the sandbox

	# --- the chalk circle -------------------------------------------------
	# Never actually built before this pass, in a game whose objective text
	# says "Stand near the chalk circle and watch the game" and whose NPC
	# line is "It only counts if it stays inside the chalk". Three children
	# were standing around a mark that was not there.
	#
	# Radius 2.6 puts all three NPCs (main.tscn: -0.95/0.35/1.45 about x=0,
	# z=-11) and both the Join and Return zones inside it, which is the only
	# constraint on the size.
	#
	# Y is the mark's own TOP, matching what Y_CHALK means everywhere else
	# and what _ground()'s `top` means, so each mesh is dropped by half its
	# own thickness (_mesh() centres what it is given).
	#
	# And the marks got THIN. They were 0.09 and 0.06 tall, which is not a
	# chalk mark, it is a hoop: centred on the old Y_CHALK the main ring
	# spanned y 0.085..0.175, standing clear of the ground and passing
	# through the shins of every child in the circle, at the one spot the
	# objective text sends the player to. The height was there to keep it
	# clear of a paving layer that was itself too high; with the layers back
	# under the child's feet it is not needed, and the "ring" mesh kind's own
	# doc already says what these want to be -- "the flat mark chalk actually
	# makes on stone". A centimetre of thickness is a drawn line seen from
	# the play camera and nothing at all seen from the side, which is right.
	const CHALK_THICK := 0.012
	_mesh(root, "ring", Vector3(0.0, Y_CHALK - CHALK_THICK * 0.5, -11.0), Vector3(5.2, CHALK_THICK, 5.2), CHALK, Vector3.ZERO, 0.10)
	# A second, fainter ring and a scuffed line -- a mark that has been
	# redrawn, per ART_DIRECTION.md's own "signs of life" note. Kept thin
	# and low-contrast so the circle the dialogue means stays the readable one.
	# Their own 0.01/0.02 offsets below the main ring are kept: that is what
	# keeps three overlapping marks from fighting each other.
	_mesh(root, "ring", Vector3(0.15, Y_CHALK - 0.01 - CHALK_THICK * 0.5, -10.85), Vector3(6.6, CHALK_THICK, 6.6), CHALK.darkened(0.35), Vector3.ZERO, 0.04)
	for mark in [[-1.9, -13.4, 0.5], [2.2, -8.9, -0.7]]:
		_mesh(root, "cube", Vector3(mark[0], Y_CHALK - 0.02 - CHALK_THICK * 0.5, mark[1]), Vector3(0.9, CHALK_THICK, 0.09), CHALK.darkened(0.2), Vector3(0.0, mark[2], 0.0), 0.04)

	# --- beds -------------------------------------------------------------
	# Two flanking the gate (the first thing seen on entering, and what
	# stops the gateway reading as a hole in a wall), a run along the arcade
	# wall's base, and three down the west hedge. All well clear of the six
	# screenshot beats' camera positions -- a bed at head height in front of
	# a camera is the frame-occupancy failure this world has hit before.
	# Pushed out from x=+-3.6 to +-4.3 and narrowed 3.4 -> 2.6 (second look
	# at the frames): at the first size these two filled the bottom third of
	# both the watch and circle beats as a pair of dark troughs straddling
	# the way in. They belong tucked against the gate piers at x=+-5.15,
	# which is where a park actually plants them.
	_planting_bed(root, -4.3, -5.1, 2.6, 1.5, 1)
	_planting_bed(root, 4.3, -5.1, 2.6, 1.5, 2)
	var bed_index := 3
	for bed_x in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		_planting_bed(root, bed_x, -22.6, 5.2, 1.5, bed_index)
		bed_index += 1
	for bed_z in [-8.0, -13.5, -19.0]:
		_planting_bed(root, -21.4, bed_z, 1.5, 4.2, bed_index)
		bed_index += 1


# ---------------------------------------------------------- park boundary --
# "The boundary is a thing you can see: railings, a hedge, a low wall, a
# treeline, a fence with a gate. Where the player cannot go should LOOK like
# somewhere you would not go."
#
# The park's own measurement of this (tools/_probe_reachability.gd's OPEN
# GROUND pass) is only half the story, because it can be satisfied by a
# 5 m slab. What a real park boundary does is bound the space while staying
# LOOK-OVER-ABLE -- concept_03 and concept_09 both show a wall the eye
# clears easily with treetops and haze above it. So: a low wall or hedge at
# eye level or below, and mass ABOVE and BEYOND it. The hedge stops you; the
# treeline says the world continues; you never mistake either for floor.
#
# All of this is visual. Collision stays exclusively world_bounds.gd's, and
# every hedge below sits inside the footprint of the collider it dresses --
# decoration that overhangs the face a camera can reach is a mistake this
# world has already made twice (see _build_playground's creepers).


## A hedge along a straight run: overlapping blocks with a deterministic
## height and length wobble, plus a crown of flattened spheres, so it reads
## as clipped planting rather than as a green wall. `axis` is "x" or "z".
func _hedge_run(root: Node3D, axis: String, fixed: float, from: float, to: float, thickness: float, height: float) -> void:
	var span := to - from
	var count := maxi(1, int(round(absf(span) / 2.4)))
	var step := span / float(count)
	for i in range(count):
		var t: float = from + step * (i + 0.5)
		var wobble: float = fmod(absf(t * 3.7 + fixed * 1.9), 1.0)
		var h: float = height * (0.88 + wobble * 0.22)
		var length: float = absf(step) * 1.08
		var pos := Vector3(fixed, h * 0.5, t) if axis == "z" else Vector3(t, h * 0.5, fixed)
		var size := Vector3(thickness, h, length) if axis == "z" else Vector3(length, h, thickness)
		_mesh(root, "cube", pos, size, FOLIAGE)
		# Crown: two squashed spheres per block, alternating side, so the
		# top edge is broken rather than ruled. FOLIAGE_LIGHT catches the
		# low sun the way a clipped hedge's top actually does.
		for j in range(2):
			var ct: float = t + step * (j - 0.5) * 0.45
			var lift: float = h + thickness * 0.10
			var cpos := Vector3(fixed, lift, ct) if axis == "z" else Vector3(ct, lift, fixed)
			var csize := Vector3(thickness * 1.05, thickness * 0.62, absf(step) * 0.62)
			if axis == "x":
				csize = Vector3(absf(step) * 0.62, thickness * 0.62, thickness * 1.05)
			_mesh(root, "sphere", cpos, csize, FOLIAGE_LIGHT if j == 0 else FOLIAGE)


## A run of park railing standing on top of something -- posts, a top rail
## and a mid rail. Thin, vertical and regular: the reason to use ironwork on
## the entrance rather than more hedge is that a rhythm of thin uprights
## reads as "boundary, deliberate, municipal" from much further away than a
## soft mass does, and the low sun draws it (ART_DIRECTION.md's own note
## about thin things a low sun draws).
func _railing_run(root: Node3D, x_from: float, x_to: float, z: float, base_y: float, height: float) -> void:
	const POST_SPACING := 0.42
	var span := x_to - x_from
	var posts := maxi(2, int(round(absf(span) / POST_SPACING)))
	for i in range(posts + 1):
		var x: float = x_from + span * i / float(posts)
		_mesh(root, "cube", Vector3(x, base_y + height * 0.5, z), Vector3(0.05, height, 0.05), IRONWORK)
	_mesh(root, "cube", Vector3((x_from + x_to) * 0.5, base_y + height, z), Vector3(absf(span), 0.07, 0.09), IRONWORK)
	_mesh(root, "cube", Vector3((x_from + x_to) * 0.5, base_y + height * 0.45, z), Vector3(absf(span), 0.05, 0.06), IRONWORK)


## A permeable boundary: a low kerb wall with railing standing on it, along
## `axis` ("x" or "z") at `fixed`, from `a` to `b`. Total height is
## `kerb_h + rail_h`, and everything above the kerb is see-through.
##
## The point of the shape: the kerb gives the boundary a base that reads as
## built and catches a shadow, and the railing gives it height without
## giving it mass. Containment is not this mesh's job at all -- every
## collider in this world comes from world_bounds.gd -- so a boundary can
## be as transparent as it likes without a player being able to cross it.
## X-run only, matching _railing_run() which this delegates the railing to.
func _railing_on_kerb(root: Node3D, z: float, x_from: float, x_to: float, kerb_h: float, rail_h: float) -> void:
	_mesh(root, "cube", Vector3((x_from + x_to) * 0.5, kerb_h * 0.5, z), Vector3(absf(x_to - x_from), kerb_h, 0.7), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	_railing_run(root, x_from, x_to, z, kerb_h, rail_h)
	# End piers, so the run reads as finished rather than sawn off.
	for end_x in [x_from, x_to]:
		_mesh(root, "cube", Vector3(end_x, (kerb_h + rail_h) * 0.5, z), Vector3(0.42, kerb_h + rail_h, 0.78), PLASTER, Vector3.ZERO, 0.0, "plaster")


## A gateway pier: plinth, shaft, cap, ball finial. Straight off
## concept_04_journey_child_height.png and concept_09_overall.png, both of
## which put exactly this object -- a squat stone pier with a ball on top --
## at the edge of the path in the foreground.
func _gate_pier(root: Node3D, x: float, z: float) -> void:
	const H := 2.35
	_mesh(root, "cube", Vector3(x, 0.14, z), Vector3(1.02, 0.28, 1.02), SHADOW_STONE)
	_mesh(root, "cube", Vector3(x, H * 0.5 + 0.14, z), Vector3(0.82, H, 0.82), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(x, H + 0.24, z), Vector3(1.0, 0.18, 1.0), PLASTER)
	_mesh(root, "sphere", Vector3(x, H + 0.58, z), Vector3(0.52, 0.56, 0.52), SHADOW_STONE)


## Everything that says "this is the edge of the park".
func _build_park_boundary(root: Node3D) -> void:
	# --- west: hedge on the wall, treeline beyond it ----------------------
	# The wall collider runs x[-23.6,-22.4]; the hedge sits inside that
	# footprint exactly, so it can never stand on ground the player can
	# still reach. 1.9 m: over a 1.08 m child's head, under REVEAL's 2.6 m
	# camera, so the shot looks over it into the trees while the child
	# standing at it cannot see through.
	_hedge_run(root, "z", -23.2, -23.4, -4.0, 0.8, 2.1)
	# No hedge on the east: that edge is a 2.4 m plaster wall the whole way
	# from z=-4 to z=-24 (_build_playground and _build_garden_pocket), which
	# already reads as boundary on its own. Doubling it with a hedge would
	# only make the one side of the park you approach the ball from feel
	# narrower than it is.
	# --- north: hedge BEHIND the low wall, on the unreachable side --------
	# The wall here is deliberately only 1.6 m so it can be seen over
	# (_build_playground). What you saw over it was bare ground. This is
	# what it should have been seeing all along. Deliberately stopping at
	# x=8.5: the "gap" beat parks its camera at (10.4, -4.0), hard against
	# this wall's own south face, and this world has twice put foliage
	# exactly there and shot a frame from inside it.
	_hedge_run(root, "x", -2.9, -23.0, -6.0, 1.1, 1.7)
	_hedge_run(root, "x", -2.9, 5.6, 8.5, 1.1, 1.7)

	# --- the gate ---------------------------------------------------------
	# Where the lane's 7 m walls stop and the park starts. Piers sit exactly
	# on the lane walls' own inner faces (x=+-4.7) so nothing overhangs the
	# opening the player walks through; railings run outward from them along
	# the top of the park's north wall (top at 1.6), stopping well short of
	# the gap beat's camera on the east side for the same reason as above.
	for side in [-1.0, 1.0]:
		_gate_pier(root, side * 5.15, -3.8)
	# West side: the whole run is railed by _build_playground now that the
	# wall under it came down to 1.0 m, so only the east side needs its own
	# short length here (that run is still 1.6 m -- see its own comment).
	_railing_run(root, 5.6, 8.4, -3.6, 1.6, 0.82)

	# --- banks ------------------------------------------------------------
	# "Break the flat plane. Even 0.5 m of change reads as landscape rather
	# than floor." Correct, and mostly not available here: player.gd locks
	# global_position.y to 0 every physics tick (three call sites, no
	# gravity, no terrain-follow), so any ground the player can reach must
	# be dead level or they walk through it. That file is frozen and is
	# another agent's.
	#
	# What IS available is everything OUTSIDE the walkable line, which is
	# where a park's landform mostly is anyway -- boundaries are banked,
	# lawns are not. These are earth banks running behind each boundary,
	# rising 0.8-1.4 m, with the hedge and the treeline standing on top of
	# them instead of on the same plane as the player. From inside the park
	# the boundary planting now steps UP away from you, which is the read
	# the brief is asking for, and it costs no collider and no risk to a
	# locked-Y character because none of it is reachable.
	#
	# Stepped in two courses rather than one box: a single tall slab is
	# another wall. Two courses with the outer one taller and set back read
	# as a slope at this distance, in the same "broad planes, modest
	# geometric detail" register as the arcade.
	for bank in [
		# West, behind the hedge (wall outer face x=-23.6).
		[-24.3, -14.0, 1.4, 20.0, 0.85], [-25.4, -14.0, 1.6, 20.0, 1.35],
		# South, behind the arcade (wall outer face z=-24.6).
		[-0.5, -25.4, 47.0, 1.5, 0.9], [-0.5, -26.6, 47.0, 1.6, 1.4],
		# East, behind the boundary wall (outer face x=22.35).
		[23.1, -19.0, 1.3, 11.0, 0.8], [24.1, -19.0, 1.5, 11.0, 1.25],
		# North, behind the low wall and its hedge -- the bank the park's
		# own north edge steps up to before the treeline beyond it.
		[-14.0, -2.0, 19.0, 1.3, 0.75], [-14.0, -0.9, 19.0, 1.4, 1.2],
	]:
		_mesh(root, "cube", Vector3(bank[0], bank[4] * 0.5, bank[1]), Vector3(bank[2], bank[4], bank[3]), MEADOW, Vector3.ZERO, 0.0, "grass")

	# --- treelines --------------------------------------------------------
	# Real trees (PropLibrary species, trunks and all), OUTSIDE every wall,
	# so none of them can be walked into and none needs a collider. This is
	# the mass concept_03/07/09 put above the boundary in every plate; the
	# existing _add_distant_layer() silhouettes stay where they are, much
	# further out, as the layer behind THIS one.
	for z in [-5.5, -10.0, -14.5, -19.0, -23.0]:
		_add_tree(root, -24.6, z, 1.4)
	for x in [-18.0, -10.0, -2.0, 6.0, 14.0, 20.5]:
		_add_tree(root, x, -25.8, 1.5)
	for z in [-17.5, -21.0]:
		_add_tree(root, 23.6, z, 1.4)

	# --- canopy ------------------------------------------------------------
	# Claustrophobia pass (2026-08-30). The developer: "the park also seems
	# a bit claustrophobic - maybe just reducing the height of the internal
	# walls can help."
	#
	# Measured first (tools/_probe_reachability.gd's new ENCLOSURE vs COVER
	# fan), the walls turned out NOT to be the main cause: wall-scale
	# geometry already sat 8-45 m away with a 0-7 degree median horizon
	# almost everywhere in the park. What the probe found instead was that
	# 1% of walkable ground -- 13 m^2 out of 913 -- had anything at all
	# above it. The entire world happened between 0 and 3 m. That is what a
	# car park is, and it is why a 45 m wide space could still feel like a
	# box: the eye had nothing near to measure the far things against.
	#
	# So: real canopy. Scales 2.0-2.6 make these 10-13 m trees against the
	# 5-8 m ones the park had, with the crown starting above head height, so
	# the player walks UNDER them along the path instead of past them. Each
	# is placed 1.5-3 m off a path centreline, which is the offset that puts
	# the crown over the path rather than over empty lawn.
	#
	# Colliders (world_bounds.gd's PARK TREES block) stay trunk-sized, NOT
	# crown-sized: 0.5-0.7 m half-extents on a tree whose crown is 5 m
	# across. A canopy you cannot walk under is just a wall with leaves.
	# SIX, thinned from eight after looking at the frames. The first attempt
	# put a canopy tree at (-15.6,-11.4) and (-18.2,-15.2) alongside the two
	# lawn trees already at (-16.5,-6) and (-17.5,-15) -- the last pair only
	# 0.7 m apart -- and the west side came back as a thicket: six crowns
	# inside ten metres, the west lawn in total shade with a trunk filling
	# the middle of the frame. Canopy makes a space feel bigger by giving
	# the eye something near AND something far; a closed roof of foliage
	# takes the far half away and makes it a wood, which is smaller than a
	# park, not bigger. Spacing is the whole discipline here: 6-10 m apart
	# along a route, never two crowns overlapping.
	for spot in [
		# Over the gate, so the first thing the player does on entering the
		# park is walk under a tree.
		[-7.0, -5.8, 2.3],
		# Down the west perimeter path, an avenue rather than a stand.
		[-12.8, -6.4, 2.2], [-17.6, -13.4, 2.3],
		# Over the south walk, framing the gate -> arcade axis rather than
		# standing in it (see the bench note in _build_park_furniture).
		[-5.0, -20.2, 2.2], [4.6, -20.4, 2.1],
		# Reaching over the plaza's open east corner, so the play area
		# itself gets shade instead of only the lawn around it.
		[9.6, -14.6, 2.2],
	]:
		_add_tree(root, spot[0], spot[1], spot[2])

	# --- trees inside the park -------------------------------------------
	# Shade over the lawn, and the thing that stops a 45 m wide park reading
	# as a field. These DO get colliders (see world_bounds.gd's PARK TREES
	# block) because they stand where the player walks; the boundary trees
	# above do not, because nobody can reach them.
	#
	# Three, down from six: (-16.5,-6), (-17.5,-15) and (-8.0,-19.4) were
	# all within a few metres of a canopy tree above and were what turned
	# the west and south into a thicket. 17.5,-17.6 moved to 16.2,-19.4 as
	# well, off the south-east corner's own view into the garden pocket --
	# it still shades the corner bench 3.9 m away.
	for spot in [
		[-13.5, -19.0, 1.7], [16.2, -19.4, 1.8], [20.5, -21.5, 1.5],
	]:
		_add_tree(root, spot[0], spot[1], spot[2])


# --------------------------------------------------------- park furniture --

## A park bin: a tapered body on a small plinth with a rim. Primitives
## rather than a model -- neither vendored Kenney kit (nature, town) has
## one, and the shape is two cylinders.
func _park_bin(root: Node3D, x: float, z: float) -> void:
	_mesh(root, "cylinder", Vector3(x, 0.04, z), Vector3(0.52, 0.08, 0.52), SHADOW_STONE)
	_mesh(root, "cylinder", Vector3(x, 0.40, z), Vector3(0.44, 0.66, 0.44), IRONWORK)
	_mesh(root, "cylinder", Vector3(x, 0.75, z), Vector3(0.50, 0.06, 0.50), SHADOW_STONE)


## The park noticeboard by the gate -- two posts and a board with a pitched
## top. "Signs of life" the same way the washing line on the home porch is:
## an object that only exists because someone runs this place.
func _park_noticeboard(root: Node3D, x: float, z: float, yaw: float) -> void:
	var rot := Vector3(0.0, yaw, 0.0)
	for side in [-0.62, 0.62]:
		var off := Vector3(cos(yaw) * side, 0.0, -sin(yaw) * side)
		_mesh(root, "cube", Vector3(x + off.x, 0.55, z + off.z), Vector3(0.11, 1.1, 0.11), WOOD, rot)
	_mesh(root, "cube", Vector3(x, 1.34, z), Vector3(1.5, 0.92, 0.08), WOOD_LIGHT, rot, 0.0, "wood")
	_mesh(root, "cube", Vector3(x, 1.82, z), Vector3(1.66, 0.12, 0.26), WOOD, rot, 0.0, "wood")


## Benches, bins, lamps and the noticeboard -- all ON the path or on the
## plaza edge, all facing something. "Park furniture belongs to the path":
## the previous build had one bench standing in open ground and one lantern
## by the house, and furniture floating on a lawn is one of the clearest
## tells that a space was assembled rather than laid out.
func _build_park_furniture(root: Node3D) -> void:
	# yaw points the bench's FRONT: bench.gltf faces its own local +Z.
	#
	# This comment used to say the opposite ("yaw is the direction the
	# bench's back is turned... its front faces local -Z") and it was wrong.
	# Measured on the mesh (tools/_probe_prop_bounds.gd): every vertex band
	# above 0.85 -- the backrest -- lies at z -0.72..-0.14, while the seat
	# slab runs z -0.40..+0.60. Backrest at -Z, so the sitter faces +Z.
	#
	# The three yaws below were NOT wrong; only the comment was. Checked one
	# by one against the target each of their own notes names, reading +Z as
	# the front: the circle (dot 1.000), the plaza (0.960), west across the
	# park (0.903). Under the comment's claim all three would have been 180
	# degrees out and facing walls, which is what made it worth checking
	# rather than believing. They are left exactly as authored -- they were
	# tuned against the sightline probe and re-deriving them from landmark
	# points would have silently rotated two of the three by 16 and 25
	# degrees. tests/play/test_bench.gd pins the model's facing itself, which
	# is the fact all four benches actually depend on.
	#
	# The one bench you can actually sit on. Position and yaw come from
	# WorldAffordances, not from the list below: it carries a COLLIDERS entry
	# and scripts/bench.gd's sit verb, and a hand-written angle here would
	# silently disagree with them. bench_yaw() derives ~99.7 degrees from the
	# bench toward the chalk circle; the 90.0 this entry used to carry was
	# close enough to look right and wrong enough to miss what it faces.
	# Named apart from the other three: tests/play/test_bench.gd measures the
	# seat against this mesh's own placement, and "Bench" x4 in one scene
	# leaves it matching whichever Godot happened to auto-rename first.
	_kind(root, WorldAffordances.BENCH_POSITION, "res://assets/park/bench.gltf", 1.0, Callable(self, "_primitive_bench"), 1.0, WorldAffordances.bench_yaw(), "SittableBench")

	for bench in [
		# South-east of the circle, facing back across it. Third position
		# for this bench and the first that measures clean on both passes.
		# (9.0, -6.6) took 27% of the "gap" beat's whole picture from 1.5 m;
		# (3.8, -6.2) fixed that but landed square in the lane mouth's own
		# sightlines to BOTH the swing and the garden arch -- the two views
		# that tell a player arriving in the park where the next thing is.
		# The openness pass moved this same bench for this exact reason
		# once already ("a prop standing in a sightline is a placement
		# problem, not a fact"); here it is 11 m from the gap camera and
		# clear of every line in _probe_reachability.gd's SIGHTLINES.
		[7.4, -14.8, -63.0],
		# On the south loop, facing back up at the plaza -- moved x=0 -> 2.6
		# (claustrophobia pass). At x=0 it stood square in the middle of the
		# gate -> arcade-centre-niche axis, the one full-length view this
		# world has, and the probe's own sightline table found it there:
		# "Gate -> ArcadeCentreNiche 18.4m no, bench at 15.0m".
		[2.6, -20.5, 0.0],
		# The dead end at the south-east corner, under its own tree: the
		# reason to walk the far side of the loop at all. Turned to face
		# WEST, back across the park -- at 125 degrees it faced the east
		# wall two metres away, which is not a view.
		[19.6, -17.0, -100.0],
	]:
		_kind(root, Vector3(bench[0], Y_PAVING, bench[1]), "res://assets/park/bench.gltf", 1.0, Callable(self, "_primitive_bench"), 1.0, deg_to_rad(bench[2]), "Bench")

	for bin_spot in [[-5.6, -9.9], [4.3, -20.6], [-6.0, -4.8], [18.6, -18.0]]:
		_park_bin(root, bin_spot[0], bin_spot[1])

	# Lamps down the path, at the gate and at the two junctions -- the
	# spacing a park actually lights a route at, not one per landmark.
	# Four, not five. street_lantern.gltf's slate-blue post is the coolest
	# note in an otherwise warm palette; one is a nice accent at a gate and
	# a survey frame with three of them in it reads as municipal lighting
	# stock. Kept at the gate and at the three points on the loop where a
	# path actually changes direction.
	for lamp in [[-6.1, -5.0], [-12.2, -6.6], [-19.4, -19.4], [13.2, -19.8]]:
		_kind(root, Vector3(lamp[0], 0.0, lamp[1]), "res://assets/park/street_lantern.gltf", 1.0, Callable(self, "_primitive_lamp"), 1.0, 0.0, "ParkLamp")

	# West of the gate against the boundary wall, not east of it: at
	# (6.2, -5.6) the board stood on the lane mouth's own sightline to the
	# garden arch, the same defect the bench above had.
	_park_noticeboard(root, -9.4, -4.7, deg_to_rad(150.0))

	# Things on the lawn a child would use without anyone calling them
	# equipment: a ring of sawn stumps to jump between, a felled log to
	# balance along, and a group of boulders. Every real park of this size
	# has some of this, and it is what stops 45 m of mown grass reading as
	# a pitch. All three kinds were already in PropLibrary and unused.
	var log_index := 0
	for angle_step in range(6):
		var a: float = TAU * angle_step / 6.0
		_kind_of(root, "stump", Vector3(-14.5 + cos(a) * 2.3, Y_LAWN, -12.5 + sin(a) * 2.3), 0.95, Callable(self, "_primitive_stump"), a, "Stump", log_index)
		log_index += 1
	for fallen in [[-15.8, -15.6, 0.5], [-13.1, -16.4, -0.25]]:
		_kind_of(root, "log", Vector3(fallen[0], Y_LAWN, fallen[1]), 1.15, Callable(self, "_primitive_log"), fallen[2], "Log", log_index)
		log_index += 1
	for rock in [[11.5, -20.2, 1.1], [10.2, -21.3, 0.75], [12.9, -21.9, 0.9]]:
		_add_rock(root, rock[0], rock[1], rock[2], log_index)
		log_index += 1

	# Planters flanking the gate, on the paving where the path leaves it.
	for side in [-1.0, 1.0]:
		_kind_of(root, "planter", Vector3(side * 2.1, Y_PAVING, -4.4), 0.9, Callable(self, "_primitive_flowerpot"), 0.0, "GatePlanter")


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
	# clampf(raw_z, -23.0, 15.9)`, tuned and screenshot-verified against
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
	# ("ground that isn't one plane"). The 50x44m world sits on a single flat
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


## THE PARK: open ground, x[-23,22] z[-24,-16] stepping in to x[-23,11]
## for z in [-16,-4], where the garden pocket sits alongside it -- see
## world_bounds.gd's own PARK doc block. This function builds only the
## room's WALLS; its surfaces (lawn, plaza, paths, beds), boundary
## (hedges, gate, treeline) and furniture are _build_park_ground(),
## _build_park_boundary() and _build_park_furniture() above.
##
## Chalk circle, towers and slide stay clustered near the centreline
## exactly where the 2026-08-28 expansion put them; the park pass widened
## the room around them rather than moving anything the episode depends on.
func _build_playground(root: Node3D) -> void:
	# Side walls dropped 4.2 -> 3.2 m (openness pass, 2026-08-29).
	# concept_03_playground_scale.png and concept_09_overall.png both bound
	# this space with a wall the eye clears easily -- treetops, haze and
	# rooflines above it, which is the entire reason _add_distant_layer()
	# exists. At 4.2 the wall's top edge sat above the horizon from
	# everywhere in the playground and hid the layer built to be seen.
	# Park pass (2026-08-30): the west boundary is no longer a 3.2 m plaster
	# slab at x=-16. It is a 1.25 m garden wall at x=-23 with a hedge
	# standing behind it and a line of real trees behind that
	# (_build_park_boundary), which is what the west side of a park looks
	# like and, more to the point, is legible AS a boundary from across the
	# lawn -- a pale flat plane 16 m away dissolves into the fog and reads
	# as haze, which is precisely the thing the developer walked into.
	# Wall and hedge both sit inside the collider's own x[-23.6,-22.4]
	# footprint.
	_mesh(root, "cube", Vector3(-22.8, 0.62, -14.0), Vector3(0.8, 1.25, 20.0), PLASTER, Vector3.ZERO, 0.0, "plaster")
	# East wall for the deep end (z -24..-16); north of that the garden
	# wall (x=11, _build_garden_pocket) is the real boundary. Height and
	# colour match the garden pocket's own east wall at the same x, so from
	# inside the park the east edge reads as one continuous 2.4 m wall from
	# z=-4 all the way to z=-24 rather than as two rooms' walls meeting.
	# Dropped 2.4 -> 1.5 m (claustrophobia pass). This is the third side of
	# the south-east corner's box; the two trees standing behind it
	# (_build_park_boundary) now do the screening a taller wall was doing,
	# which is the trade the whole pass is built on -- mass ABOVE the
	# boundary rather than mass AT it.
	_mesh(root, "cube", Vector3(22.0, 0.75, -20.0), Vector3(0.7, 1.5, 8.0), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
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
	# Moved out with the park (z -20 -> -24) and lengthened 33 -> 46.2 m to
	# span the widened room, with five niches instead of three at the same
	# ~8 m rhythm the three had. Still the south boundary and still blind
	# niches, for the reason its own doc comment gives.
	_build_arcade_wall(root, -0.5, -24.0, 46.2, 1.2, 4.6, [-16.0, -8.0, 0.0, 8.0, 16.0])

	# North boundary (openness pass). The playground's own north edge, at
	# the lane/playground seam z=-4, had NO rendered geometry at all for
	# the 22 m either side of the lane mouth: collision came from the lane's
	# wide invisible flanks (world_bounds.gd), and the ground plane is a
	# single 50x44 m slab that runs on regardless. So a player standing
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
	# West run lengthened 11.2 -> 18.3 m with the park (park pass), so it
	# still meets the new west wall's outer face at x=-23.6; both runs
	# continue to match world_bounds.gd's colliders for this line exactly.
	# Claustrophobia pass: the long west run is now 1.0 m of solid wall with
	# railing above it rather than 1.6 m of solid. 1.6 m is above a 1.08 m
	# child's eye, so for 18 m of the park's north side the boundary was
	# something you looked AT; at 1.0 m with railing over it, it is
	# something you look THROUGH while being contained by exactly the same
	# collider. The hedge planted behind it on the unreachable side (z=-2.9)
	# still screens the ground beyond, so nothing that pass fixed regresses.
	#
	# The short east run keeps its 1.6 m: it is the piece the "gap" beat's
	# camera parks against at (10.4, -4.0), and this world has twice broken
	# that frame by changing something on this line.
	_mesh(root, "cube", Vector3(-14.45, 0.5, -3.6), Vector3(18.3, 1.0, 0.8), PLASTER, Vector3.ZERO, 0.0, "plaster")
	_railing_run(root, -23.2, -5.6, -3.6, 1.0, 0.82)
	_mesh(root, "cube", Vector3(8.25, 0.8, -3.6), Vector3(6.5, 1.6, 0.8), PLASTER, Vector3.ZERO, 0.0, "plaster")
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
	for creeper_x in [-21.0, -17.5, -14.5, -9.0, -6.2, 7.0, 10.4]:
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

	_add_tower_stairs(root)

	# The slide, built from WorldAffordances' single authored definition of
	# where its TOP SURFACE is (slide_surface_point(), which has the full
	# history). The previous version of this comment claimed the visual and
	# the ride "can never drift apart again" because both derived from the
	# same constants. They did not: the plank ran deck-edge -> SLIDE_END at
	# 50.0 degrees while the ride ran PLATFORM_STAND -> SLIDE_END at 46.8,
	# starting 0.35 m up-slope of the plank and crossing through it on the
	# way down -- and _slide_plank() centred the box on the line it was
	# given, so the "surface" was another 0.09 m above it again. The
	# developer caught all of it by playing.
	#
	# The fix is that there is now ONE line and both things hang off it:
	# _slide_plank() takes the top FACE and drops the box below it, and
	# player.gd rides slide_ride_position(), which is the same face plus the
	# seat lift. Nothing here re-derives an endpoint.
	var slide_top := WorldAffordances.slide_surface_point(0.0)
	var slide_bottom := WorldAffordances.slide_surface_point(1.0)
	_slide_plank(root, slide_top, slide_bottom, WorldAffordances.SLIDE_WIDTH, 0.18, "wood", "SlidePlank")

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


## The left tower's staircase -- real, built access to the deck, so the slide
## stops being the only visible way up (developer, 2026-08-30). Three flights
## of Kenney's stairs-wood-handrail.glb up the tower's west flank; every
## number comes from WorldAffordances' STAIR_* block, which has the
## reasoning, so the meshes stand exactly where player.gd walks.
##
## There is no primitive fallback branch here, unlike the props that go
## through _kind(). A staircase whose whole job is to be visibly climbable
## cannot degrade to "three boxes"; if the model is switched off the ramp
## below still gives the ascent something solid to be on, which is the part
## that must not silently vanish.
func _add_tower_stairs(root: Node3D) -> void:
	var scale := WorldAffordances.STAIR_MODULE
	for index in range(WorldAffordances.STAIR_FLIGHTS):
		var origin := WorldAffordances.stair_flight_origin(index)
		if AssetMode.resolve_detailed(STAIR_MODEL):
			_prop(root, STAIR_MODEL, origin, scale, 0.0, "TowerStair%d" % index)
		else:
			# Primitive fallback: the flight's own wedge, as a stack of
			# treads on the same 1x1 module the model occupies.
			for step in range(4):
				var t := (float(step) + 0.5) / 4.0
				_mesh(root, "cube",
					origin + Vector3((t - 0.5) * scale, t * scale * 0.5, 0.0),
					Vector3(scale * 0.25, t * scale, scale * 0.5),
					WOOD_LIGHT, Vector3.ZERO, 0.0, "wood")

	# A stringer under the whole run: one continuous plank from the bottom
	# step to the deck, along the same line stair_surface_y_at_x() ramps up.
	# Without it three separate flights read as three floating objects from
	# the side, which is exactly the angle the player approaches from.
	var foot := Vector3(WorldAffordances.STAIR_FOOT_X, 0.0, WorldAffordances.STAIR_Z)
	var head := Vector3(WorldAffordances.STAIR_TOP_X, WorldAffordances.PLATFORM_TOP_Y, WorldAffordances.STAIR_Z)
	for side in [-1.0, 1.0]:
		var offset := Vector3(0.0, 0.0, side * (WorldAffordances.STAIR_HALF_WIDTH - 0.06))
		_stringer(root, foot + offset, head + offset, 0.1, 0.26)


## A plank between two points that share a Z (the mirror of _slide_plank(),
## whose two points share an X): the staircase runs along world X, so the
## rotation that lines a box up with it is about Z rather than about X.
func _stringer(root: Node3D, from: Vector3, to: Vector3, width: float, thickness: float) -> void:
	var dy := to.y - from.y
	var dx := to.x - from.x
	var run_len := sqrt(dy * dy + dx * dx)
	var theta := atan2(dy, dx)
	var mid := (from + to) * 0.5 - Vector3(0.0, cos(theta) * thickness * 0.5, 0.0)
	_mesh(root, "cube", mid, Vector3(run_len, thickness, width), WOOD, Vector3(0.0, 0.0, theta), 0.0, "wood")


## A plank parallel to the from->to run, shifted `lateral` metres sideways and
## standing `up` metres proud of it. Delegates to _slide_plank() with shifted
## endpoints, so a rail can never end up at a different angle from the bed it
## guards.
##
## `up` is measured along the PLANK's own local up, not world Y. The run is
## tilted about X by theta, so its local up is (0, cos theta, sin theta);
## offsetting straight up in world Y instead would slide the rail along the
## bed's length as well as away from it, leaving it proud at the top and sunk
## at the bottom. `lateral` needs no such correction -- X is the rotation axis,
## so world X and the plank's local X are the same direction.
##
## Since _slide_plank() now takes a top FACE rather than a centreline, `up`
## reads as "how far the rail stands above the bed you slide on", and a rail
## `thickness` deeper than `up` hangs down alongside the bed's own underside
## -- which is what the authored 0.16/0.34 pair does.
func _slide_rail(root: Node3D, from: Vector3, to: Vector3, lateral: float, up: float, width: float, thickness: float) -> void:
	var theta := atan2(-(to.y - from.y), to.z - from.z)
	var offset := Vector3(lateral, cos(theta) * up, sin(theta) * up)
	_slide_plank(root, from + offset, to + offset, width, thickness)


## A plank hanging below the line from->to, both of which share an X (so the
## box's local Z is the only axis that needs rotating away from world Z),
## tilted about local X. `width` runs along local X, unrotated -- the slide's
## sideways width; `thickness` is local Y before rotation, same parameter
## shapes _mesh() itself uses.
##
## from->to is the plank's TOP FACE, not its centreline. That distinction is
## the third of the three offsets that had the slide's rider inside the plank
## instead of on it: a box centred on the line puts half its thickness above
## it, so the surface the eye sees was 0.09 m above the surface the ride
## used. Hanging the box below the line instead means "the line" and "the
## thing you sit on" are the same place, which is what lets
## WorldAffordances.slide_ride_position() be that line plus a seat lift and
## nothing else.
##
## Textured, unlike the version before this pass. The slide was the ONLY large
## surface in the playground still carrying a bare palette colour -- the towers
## are "wood", the walls and piers "plaster" -- and a 3.7 x 1.25 m field of flat
## SLIDE orange is exactly what read as untextured cardboard beside the
## vegetation once that had real models. It is painted wood like everything
## else the children climb on, so it takes the same surface.
func _slide_plank(root: Node3D, from: Vector3, to: Vector3, width: float, thickness: float, surface: String = "wood", node_name: String = "") -> void:
	var dy := to.y - from.y
	var dz := to.z - from.z
	var run_len := sqrt(dy * dy + dz * dz)
	var theta := atan2(-dy, dz)
	# Local up for a box rotated by theta about X, so the drop below the top
	# face is taken perpendicular to the plank rather than straight down.
	var local_up := Vector3(0.0, cos(theta), sin(theta))
	var mid := (from + to) * 0.5 - local_up * (thickness * 0.5)
	_mesh(root, "cube", mid, Vector3(width, thickness, run_len), SLIDE, Vector3(theta, 0.0, 0.0), 0.0, surface, node_name)


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
	# Claustrophobia pass (2026-08-30): kerb and railing, not a 2.4 m slab.
	# This is the one wall in the world that is genuinely INTERNAL -- park
	# on one side, garden on the other, both places the player goes -- and
	# the probe found it: the park's south-east corner measured 4.5 m to
	# the nearest wall-scale geometry with a 14.1 degree median horizon and
	# only 53% of its 360 open, by far the most hemmed-in spot in the park
	# and more than twice as enclosed as anywhere else in it.
	#
	# A permeable boundary contains the player exactly as well, because
	# containment is world_bounds.gd's collider and not this mesh -- which
	# is UNCHANGED, so the garden gap is still the only way through and the
	# camera still stops in exactly the same place. What changes is that
	# the eye now crosses here: standing in the south-east corner you can
	# see into the garden pocket, and standing in the pocket you can see
	# the park. Parks essentially never use solid internal walls; this one
	# was inherited from the single-room courtyard prototype.
	_railing_on_kerb(root, -16.0, 11.0, 22.0, 0.55, 0.95)
	# The z=-4 side goes lower still, to 1.6 -- it is no longer this
	# pocket's own wall in isolation. _build_playground()'s new north
	# boundary runs the same line from x=-23.6 to x=11.5, so from x=11 out
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
	_mesh(root, "cube", Vector3(11.0, 2.05, -8.0), Vector3(0.72, 0.4, 3.6), PLASTER, Vector3.ZERO, 0.0, "plaster")
	# Corbels carrying the span's ends, on the WALL SEGMENTS (z <= -9.7 and
	# z >= -6.3) rather than at the opening's edges: a version centred on
	# -9.35 and -6.65 put them inside the opening itself, and since the
	# traversable band through a 3.4 m gap is z[-9.38, -6.62] once the
	# player's radius comes off, the player could walk head-first into them.
	# Caught by _probe_reachability.gd's head-height check, not by looking.
	#
	# Small brackets, not piers. They were 0.95 m tall and 0.7 m deep,
	# bridging the whole wall-top-to-span gap, and the frame-occupancy pass
	# measured the south one alone at 13% of the gap beat's picture from
	# 1.6 m away -- stacked with the wall below and the span above, one dark
	# 26% column with the player half behind it. That is the "sightline is
	# clear but the frame is a wall" case, invisible to every ray test here.
	# Dropping the span to 1.85-2.25 and shrinking these to 0.3 x 0.4 takes
	# about 80% off that column (measured 13.2% -> 3.3%) while keeping
	# 1.85 m of headroom and the same corbelled arch reading.
	_mesh(root, "cube", Vector3(11.0, 1.70, -10.0), Vector3(0.66, 0.3, 0.4), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	_mesh(root, "cube", Vector3(11.0, 1.70, -6.0), Vector3(0.66, 0.3, 0.4), PLASTER_LIGHT, Vector3.ZERO, 0.0, "plaster")
	# Vegetation swallowing the arch, as in the plate -- carried up onto the
	# raised span so it still reads as overgrown, and kept clear of the
	# opening itself so it cannot re-block what raising the span just
	# opened.
	# Kept inboard of the span's own ends (z -9.8..-6.2). At -9.6/-6.4 the
	# outer two overhung the wall segments either side, and the southern one
	# measured 6% of the gap beat's frame from 1.9 m -- a dark mass hanging
	# directly over where the camera parks against the boundary. Same rule
	# as the boundary wall's own creepers: decoration stays inside the
	# footprint of the thing it decorates.
	for creeper in [[-8.8, 0.62], [-8.0, 0.5], [-7.2, 0.58]]:
		_mesh(root, "sphere", Vector3(11.0, 2.4, creeper[0]), Vector3(1.05, 0.55, creeper[1] * 1.6), FOLIAGE)

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
	# South, beyond the park's far wall (z=-24) -- the backdrop the
	# watch/circle beats already look toward, past the chalk circle and the
	# new arcade.
	_roofline(root, -11.0, -29.0, 5.5, 10.0)
	_roofline(root, 1.0, -32.0, 7.0, 12.5)
	_roofline(root, 10.5, -28.5, 5.0, 9.0)
	_treeline_mass(root, -6.0, -27.0, 6.5, 8.5)
	_treeline_mass(root, 6.5, -30.0, 7.5, 9.5)

	# West, beyond the park's side wall (x=-23.6).
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
		[-10.5, 0.5, 6.0, 5.5], [-14.0, 4.0, 7.0, 6.0], [-12.5, 7.5, 6.5, 5.5],
		[13.0, 0.5, 6.0, 5.5], [18.5, 4.0, 6.5, 6.0], [11.0, 7.0, 6.0, 5.5],
		# Near-east: without this one a viewer at (6, -6) still had a clear
		# line over the boundary wall to unreachable ground at (8, 9).
		# Placed north of the lane-flank tree at (9.5, 1.3) rather than on
		# top of it -- that tree is a camera fix's own composition anchor.
		[8.5, 4.5, 5.0, 5.0],
	]:
		_treeline_mass(root, mass[0], mass[1], mass[2], mass[3])
	# Further west again (park pass, 2026-08-30). Standing at the park's new
	# west edge (-21, -12) and looking north, a REVEAL-height camera clears
	# the 1.6 m boundary wall and runs 20 m up the bare ground beside home
	# -- the same grazing-ray case this block already exists for, simply at
	# a distance the old x=-16 wall could never produce. Reach (centre +
	# 0.66 * width) still clears home's own side wall at x=-7.55.
	for mass in [[-18.0, 1.5, 6.5, 6.0], [-20.5, 6.0, 7.0, 6.5], [-16.5, 10.5, 6.0, 5.5]]:
		_treeline_mass(root, mass[0], mass[1], mass[2], mass[3])
	_roofline(root, -20.0, 13.5, 6.0, 9.0)

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

	# +Z is this wall's park-facing side (world z=-24+thickness/2) --
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
## A sawn stump: a short wide cylinder with a paler cut face on top.
func _primitive_stump(root: Node3D, position: Vector3, scale: float, _rotation_y: float) -> void:
	var h: float = 0.42 * scale
	_mesh(root, "cylinder", position + Vector3(0.0, h * 0.5, 0.0), Vector3(0.34 * scale, h, 0.34 * scale), WOOD, Vector3.ZERO, 0.0, "wood")
	_mesh(root, "cylinder", position + Vector3(0.0, h + 0.01, 0.0), Vector3(0.34 * scale, 0.03, 0.34 * scale), WOOD_LIGHT)


## A felled log: a cylinder laid on its side along local X.
func _primitive_log(root: Node3D, position: Vector3, scale: float, rotation_y: float) -> void:
	_mesh(root, "cylinder", position + Vector3(0.0, 0.16 * scale, 0.0), Vector3(0.32 * scale, 1.6 * scale, 0.32 * scale), WOOD, Vector3(0.0, rotation_y, deg_to_rad(90.0)), 0.0, "wood")


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

