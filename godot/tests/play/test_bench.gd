extends GdUnitTestSuite
## Sitting on the bench (developer, 2026-08-30: "I can't sit on the bench and
## go right through it").
##
## Two separate defects and so two separate kinds of check here: the bench
## had no collider at all (a WorldBounds question, answered without a scene),
## and it had no affordance (a scripts/bench.gd question, answered by
## actually pressing interact through Game the way a player does).
##
## The thing this suite most has to protect is that sitting stays PLAY and
## never becomes a chore: leavable at any moment, by either the interact key
## or simply walking away, and incapable of touching story progress.


## The seat height, measured against the bench MESH as it actually stands in
## the built courtyard.
##
## Replaces two assertions that looked like they checked this and did not.
## One compared the player's position to bench_sit_position() -- the same
## function that had just placed them there, so it only ever caught "bench.gd
## forgot to call it". The other compared a WORLD y against BENCH_SEAT_TOP_Y,
## which is a MODEL-LOCAL measurement (0.5 above the bench's own origin);
## that happened to be equivalent while the bench stood at y=0 and stopped
## meaning anything the moment the park pass raised it onto the paving. Set
## BENCH_POSITION.y to 0.5 and the bench floats half a metre while the old
## assertion still passed.
##
## This one cannot: it reads where the mesh's feet actually are and requires
## the sit point to be exactly the seat plus the rider lift above them, so
## the model, the constant and the seat can be checked against each other
## instead of asserted to agree. That drift -- visible bench on the paving,
## collider and seat 5 cm below it -- is what the park/playground merge
## produced, and it is the slide defect again at a smaller scale.
func test_the_sit_point_is_on_the_seat_of_the_bench_that_got_built() -> void:
	var courtyard: Node3D = auto_free(load("res://scenes/courtyard.tscn").instantiate())
	add_child(courtyard)
	var bench: Node3D = courtyard.find_child("SittableBench", true, false)
	assert_object(bench).is_not_null()

	var bounds := _mesh_bounds(bench)
	# The model's origin is at its base, so the AABB's floor is where the
	# bench actually stands. Two separate things to check about it.
	#
	# First: it stands where the constant says. This is the drift the merge
	# produced -- generator on the paving, constant on the base plane.
	assert_float(bounds.position.y).is_equal_approx(WorldAffordances.BENCH_POSITION.y, 0.01)
	# Second, and NOT implied by the first: its feet are on the ground the
	# child walks on. The generator places the mesh from BENCH_POSITION too,
	# so raising that constant moves model and seat together and every
	# check between them still agrees -- only a check against the walking
	# plane notices a bench floating half a metre in the air.
	assert_float(bounds.position.y).is_less_equal(WorldAffordances.WALK_PLANE_Y + 0.001)
	assert_float(bounds.position.y).is_greater(WorldAffordances.WALK_PLANE_Y - 0.02)
	# ...and BENCH_SEAT_TOP_Y has to be a height the bench really has,
	# somewhere between its feet and the top of its backrest.
	assert_float(WorldAffordances.BENCH_SEAT_TOP_Y).is_greater(0.0)
	assert_float(WorldAffordances.BENCH_SEAT_TOP_Y).is_less(bounds.size.y)

	var expected := bounds.position.y + WorldAffordances.BENCH_SEAT_TOP_Y + WorldAffordances.SEATED_RIDER_LIFT
	assert_float(WorldAffordances.bench_sit_position().y) \
		.override_failure_message("sit point is %.3f m off the seat of the bench as built (bench base %.3f, seat %.3f, lift %.3f)" % [
			WorldAffordances.bench_sit_position().y - expected,
			bounds.position.y, WorldAffordances.BENCH_SEAT_TOP_Y, WorldAffordances.SEATED_RIDER_LIFT,
		]) \
		.is_equal_approx(expected, 0.001)


## Which way bench.gltf faces, measured off its own vertices rather than
## believed from a comment. Everything that places a bench depends on this
## one fact, and _bootstrap_courtyard.gd carried a comment asserting the
## opposite of it for a while: had anyone authored a bench from that claim,
## it would have faced a wall. A re-export or a swapped model breaks this
## silently otherwise.
func test_the_bench_model_faces_its_own_local_positive_z() -> void:
	var packed: PackedScene = load("res://assets/park/bench.gltf")
	var model: Node3D = auto_free(packed.instantiate())
	add_child(model)

	var backrest_z := 0.0
	var backrest_count := 0
	for mesh_instance in _mesh_instances(model):
		var mesh: Mesh = mesh_instance.mesh
		for surface in range(mesh.get_surface_count()):
			for v in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				if v.y < 0.85:
					continue  # seat, legs and apron -- only the backrest answers this
				backrest_z += v.z
				backrest_count += 1
	assert_int(backrest_count).is_greater(0)
	# Backrest behind the sitter means the sitter looks the other way: +Z.
	assert_float(backrest_z / float(backrest_count)).is_less(0.0)


func test_the_bench_is_solid_and_you_cannot_walk_through_it() -> void:
	var bench := WorldAffordances.BENCH_POSITION
	# Dead centre of the bench is inside it now.
	assert_bool(WorldBounds.can_move_to(bench.x, bench.z)).is_false()
	# ...and so is standing where the seat is, from either side of it.
	var yaw := WorldAffordances.bench_yaw()
	for side in [-0.5, 0.5]:
		var probe: Vector3 = bench + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, side)
		assert_bool(WorldBounds.can_move_to(probe.x, probe.z)).is_false()
	# But you can still walk up to it -- a collider that sealed the approach
	# would trade one bug for another.
	var approach := WorldAffordances.bench_stand_position()
	assert_bool(WorldBounds.can_move_to(approach.x, approach.z)).is_true()
	assert_float(Vector2(approach.x - bench.x, approach.z - bench.z).length()) \
		.is_less(WorldAffordances.BENCH_SIT_RADIUS)


func test_walking_up_and_pressing_interact_sits_the_child_on_the_seat() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	assert_object(bench).is_not_null()

	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	assert_object(Game.active_free_interactable).is_same(bench)
	assert_bool(player.external_control).is_false()

	Game.interact()
	for _i in range(3):
		await tree.physics_frame

	assert_bool(bench.call("seated")).is_true()
	assert_bool(player.external_control).is_true()
	assert_vector(player.global_position).is_equal_approx(WorldAffordances.bench_sit_position(), Vector3.ONE * 0.01)
	# Looking out over the seat (at the chalk circle), not at the backrest.
	var facing := -Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
	var to_circle := (WorldAffordances.BENCH_FACES - WorldAffordances.BENCH_POSITION).normalized()
	assert_float(facing.dot(to_circle)).is_greater(0.9)


func test_pressing_interact_again_gets_up() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(player.external_control).is_true()

	Game.interact()  # same button, no separate cancel input exists
	for _i in range(3):
		await tree.physics_frame

	assert_bool(bench.call("seated")).is_false()
	assert_bool(player.external_control).is_false()
	assert_float(player.global_position.y).is_equal_approx(player.locked_y, 0.01)
	# Stood up in FRONT of the bench, on ground they are allowed to stand on.
	assert_bool(WorldBounds.can_move_to(player.global_position.x, player.global_position.z)).is_true()


## The one that matters most: a player who has forgotten which key sat them
## down must still be able to leave by doing the obvious thing. Holding a
## movement key stands them up.
func test_trying_to_walk_away_gets_up_too() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(bench.call("seated")).is_true()

	runner.simulate_action_press("move_forward")
	for _i in range(10):
		await tree.physics_frame
	runner.simulate_action_release("move_forward")

	assert_bool(bench.call("seated")).is_false()
	assert_bool(player.external_control).is_false()


## ...but not INSTANTLY, if they were still holding the key they walked up
## with when they pressed interact. Sitting down and popping straight back
## up in the same breath is the failure this guards.
func test_sitting_down_mid_stride_does_not_pop_straight_back_up() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	runner.simulate_action_press("move_forward")  # still walking as they sit
	Game.interact()
	for _i in range(20):
		await tree.physics_frame
	assert_bool(bench.call("seated")).is_true()

	runner.simulate_action_release("move_forward")
	for _i in range(2):
		await tree.physics_frame
	runner.simulate_action_press("move_forward")  # a NEW press does leave
	for _i in range(6):
		await tree.physics_frame
	runner.simulate_action_release("move_forward")
	assert_bool(bench.call("seated")).is_false()


## Sitting is play, never a gate. Pressing interact on the bench must not
## advance, delay or otherwise touch the episode.
func test_sitting_never_moves_the_story() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame

	var state_before: String = Game.director.state
	Game.interact()
	for _i in range(30):
		await tree.physics_frame
	assert_str(Game.director.state).is_equal(state_before)
	Game.interact()
	for _i in range(10):
		await tree.physics_frame
	assert_str(Game.director.state).is_equal(state_before)


func test_a_fresh_run_mid_sit_hands_control_back() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var bench: Node = runner.scene().find_child("BenchSeat", true, false)
	Game.start_episode(0.0)
	player.global_position = WorldAffordances.bench_stand_position()
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(5):
		await tree.physics_frame
	Game.interact()
	for _i in range(3):
		await tree.physics_frame
	assert_bool(player.external_control).is_true()

	Game.start_episode(0.0)  # "Play again" mid-sit
	for _i in range(3):
		await tree.physics_frame

	assert_bool(bench.call("seated")).is_false()
	assert_bool(player.external_control).is_false()


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_mesh_instances(child))
	return out


## World-space AABB of every mesh under `node`.
func _mesh_bounds(node: Node) -> AABB:
	var total := AABB()
	var first := true
	for mesh_instance in _mesh_instances(node):
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		if first:
			total = box
			first = false
		else:
			total = total.merge(box)
	return total
