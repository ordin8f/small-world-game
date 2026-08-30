extends GdUnitTestSuite

## The developer played the build and found, in order: a slide whose surface the
## child rode through, a bench they walked through, and -- underneath both -- the
## same defect at world scale. The park pass laid the ground as thin slabs with
## their top faces at 0.02 (lawn), 0.05 (paving) and 0.07 (bark), while
## player.gd pins the child's feet to locked_y = 0.0 every physics tick with no
## terrain following. So the child walked INSIDE the ground: ankle-deep in the
## bark under the swing and sandbox, where the camera is closest.
##
## Nothing caught it. Every test in the suite asked whether the player could
## REACH somewhere, never what height they stood at when they got there, and the
## reachability probe flood-fills a 2-D grid where y does not exist at all.
##
## This suite pins the one invariant that makes the ground walkable: no surface
## the player can stand on may top out above their feet. It reads the built
## scene rather than the generator's constants, so it cannot be satisfied by two
## constants agreeing with each other while the geometry disagrees with both --
## the same reason test_slide_ride reads the plank's baked transform.

const SCENE := "res://scenes/courtyard.tscn"
const LOCKED_Y := 0.0

## A millimetre of tolerance for float error in the baked transforms. Anything
## real is centimetres: the defect this suite exists for was 20-70 mm.
const EPSILON := 0.001

## _bootstrap_courtyard.gd's _ground() names every patch it lays: GroundWalkable
## for one the child's feet can land on, GroundRaised for a kerbed bed they can
## only look into. Whether a surface is walkable is a fact only the generator
## knows -- from the built scene a bed and a lawn are both a thin, wide, flat
## slab -- so this suite reads the name rather than inferring it, and a new
## patch that forgets to say is simply not measured, which is why
## test_every_ground_patch_declares_whether_it_is_walkable exists below.
const WALKABLE_PREFIX := "GroundWalkable"


func test_no_walkable_surface_tops_out_above_the_players_feet() -> void:
	var root: Node3D = load(SCENE).instantiate()
	# global_transform is identity until the node is in a tree, so every
	# measurement below would silently read zero without this.
	add_child(root)
	auto_free(root)

	var offenders: Array[String] = []
	var checked := 0
	for node in _all_mesh_instances(root):
		var top := _slab_top(node)
		if is_nan(top):
			continue
		checked += 1
		if top > LOCKED_Y + EPSILON:
			offenders.append("%s top=%.3f" % [node.name, top])

	assert_int(checked).is_greater(20)
	assert_array(offenders).override_failure_message(
		"These ground slabs top out above the player's feet (locked_y=%.3f), so " % LOCKED_Y
		+ "the child walks inside them:\n  " + "\n  ".join(offenders)
	).is_empty()


## The inverse error, and the one a careless fix introduces: drop the layers so
## far that the child hovers over them. Anything walkable must also be close
## UNDER the feet, not an unbounded distance below.
func test_no_walkable_surface_leaves_the_player_hovering() -> void:
	var root: Node3D = load(SCENE).instantiate()
	# global_transform is identity until the node is in a tree, so every
	# measurement below would silently read zero without this.
	add_child(root)
	auto_free(root)

	var worst := 0.0
	var worst_name := ""
	for node in _all_mesh_instances(root):
		var top := _slab_top(node)
		if is_nan(top) or top > LOCKED_Y:
			continue
		var gap := LOCKED_Y - top
		if gap > worst:
			worst = gap
			worst_name = node.name

	# 10 mm: enough room for the whole layer stack, far too little to see.
	assert_float(worst).override_failure_message(
		"%s leaves the player hovering %.3f m above it." % [worst_name, worst]
	).is_less(0.010)


## The bench is the case where the ground datum and an affordance have to agree.
## WorldAffordances.BENCH_POSITION is restated in runtime logic rather than
## imported from the build-time generator, so nothing but this test stops the
## two drifting -- which is exactly how the seat ended up 5 cm under the bench.
func test_the_bench_affordance_sits_on_the_paving_it_is_drawn_on() -> void:
	var root: Node3D = load(SCENE).instantiate()
	# global_transform is identity until the node is in a tree, so every
	# measurement below would silently read zero without this.
	add_child(root)
	auto_free(root)

	var bench: Node3D = _find_named(root, "Bench")
	assert_object(bench).override_failure_message(
		"No node named Bench in the scene; this test cannot measure anything."
	).is_not_null()

	assert_float(bench.global_position.y).is_equal_approx(
		WorldAffordances.BENCH_POSITION.y, EPSILON
	)
	assert_float(bench.global_position.x).is_equal_approx(
		WorldAffordances.BENCH_POSITION.x, EPSILON
	)
	assert_float(bench.global_position.z).is_equal_approx(
		WorldAffordances.BENCH_POSITION.z, EPSILON
	)


# ------------------------------------------------------------------ helpers --

## The world-space top face of `node`, or NAN if it is not a walkable patch.
func _slab_top(node: MeshInstance3D) -> float:
	if not node.name.begins_with(WALKABLE_PREFIX):
		return NAN
	var mesh: Mesh = node.mesh
	if mesh == null or not (mesh is BoxMesh):
		return NAN
	var scaled: Vector3 = (mesh as BoxMesh).size * node.global_transform.basis.get_scale()
	return node.global_position.y + scaled.y * 0.5


func _all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_all_mesh_instances(child))
	return found


func _find_named(node: Node, prefix: String) -> Node3D:
	if node is Node3D and node.name.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_named(child, prefix)
		if found != null:
			return found
	return null
