extends GdUnitTestSuite
## No walkable surface may rise above the plane the child's feet are locked
## to. The park is something you stand ON, not something you stand IN.
##
## player.gd has no gravity and no terrain-follow: it hard-sets
## global_position.y = locked_y every tick. So a ground patch laid at any
## height above that plane is not a step up, it is the child sinking into
## it -- and because the park's surfaces are LAYERED (lawn < paving < bark
## < soil < chalk, each overlapping the last so the more specific one wins)
## the sink differed per surface, which is worse than a uniform offset: the
## child waded 2 cm on the lawn, 5 cm on the plaza and 7 cm in the bark pit
## under the swing and sandbox, where the camera is closest.
##
## Measured against the BUILT courtyard, not against WorldAffordances' own
## constants, for the same reason as tests/play/test_slide_ride_on_the_plank.gd:
## the constants agreeing with each other proves nothing. A _ground() call
## that passed a literal `top`, or an offset from a layer that outgrew it
## (the plaza's edging course was authored at +0.005, which was fine against
## the old stack and lands on another layer against the new one), is invisible
## to a constants-only check and plain here.
##
## Mutation-checked: raising ONE patch -- the plaza slab, Y_PAVING ->
## Y_PAVING + 0.05, regenerated -- fails
## test_no_ground_patch_rises_above_the_walking_plane by 0.050 m on
## GroundPatch10, and leaves the other 60-odd patches passing.

## The patches are flat slabs; anything within a tenth of a millimetre of
## the plane is the plane.
const TOLERANCE := 0.0001

var _courtyard: Node3D = null
var _patches: Array[MeshInstance3D] = []


func before_test() -> void:
	_courtyard = auto_free(load("res://scenes/courtyard.tscn").instantiate())
	add_child(_courtyard)
	_patches = []
	for child in _courtyard.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("GroundPatch"):
			_patches.append(child as MeshInstance3D)


## Guards the vacuous pass. Every assertion below is a loop over _patches,
## so a rename or a dropped node_name argument would empty the list and turn
## the whole suite green while measuring nothing -- which is precisely the
## failure mode this repo keeps producing.
func test_the_built_scene_actually_contains_the_ground_patches() -> void:
	assert_int(_patches.size()).is_greater(20)


func test_no_ground_patch_rises_above_the_walking_plane() -> void:
	var plane := _walking_plane()
	var worst := -INF
	var worst_name := ""
	for patch in _patches:
		var top: float = (patch.global_transform * patch.get_aabb()).end.y
		if top > worst:
			worst = top
			worst_name = str(patch.name)
	assert_float(worst) \
		.override_failure_message("%s's top face is %.4f m above the child's feet (walking plane %.4f, tolerance %.4f)" % [worst_name, worst - plane, plane, TOLERANCE]) \
		.is_less_equal(plane + TOLERANCE)


## ...and not so far below it that the child walks on air. The whole stack
## has to fit inside a centimetre, or "compressed downward" would just be
## the same defect pointing the other way.
func test_no_ground_patch_sinks_far_below_the_walking_plane() -> void:
	var plane := _walking_plane()
	for patch in _patches:
		var top: float = (patch.global_transform * patch.get_aabb()).end.y
		assert_float(top).is_greater(plane - 0.02)


## The layering only works if no two heights coincide -- overlapping
## coplanar slabs z-fight across a 45 m plane and the flicker is visible
## from everywhere. Checked on the distinct heights actually built, so an
## offset-from-a-layer that happens to land on another layer is caught even
## though neither constant changed.
func test_no_two_ground_heights_are_coplanar() -> void:
	var heights: Array[float] = []
	for patch in _patches:
		var top: float = (patch.global_transform * patch.get_aabb()).end.y
		var seen := false
		for h in heights:
			if absf(h - top) < TOLERANCE:
				seen = true
				break
			assert_float(absf(h - top)) \
				.override_failure_message("two ground layers only %.5f m apart -- too close to survive depth precision" % absf(h - top)) \
				.is_greater(0.0005)
		if not seen:
			heights.append(top)
	assert_int(heights.size()).is_greater(1)


## The plane itself, read off the player scene rather than off the constant
## the generator used -- that pairing is the thing under test.
func _walking_plane() -> float:
	var player: Node3D = auto_free(load("res://scenes/player.tscn").instantiate())
	return player.get("locked_y")
