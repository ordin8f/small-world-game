extends GdUnitTestSuite
## Camera sweep regression (camera-fix task, round 4, 2026-08-30).
##
## Every position below came out of tools/_probe_camera_sweep.gd's ranked
## worst-offenders table, not from a beat list. They are the places where a
## camera-blocking wall stands within a couple of metres BEHIND the player,
## which before this round meant SpringArm3D shortened the whole shot --
## direction preserved, length lost -- so the camera's height collapsed in
## proportion with its distance and it ended up at the child's own head
## height, at arm's length, with the child partly outside the frame.
## Measured on the shipped build at the time: 1.30 m at (14,-5), 1.48 m at
## (16,-17), and 306 of 3610 walkable positions with some part of the child
## outside the camera frustum.
##
## WHY THESE ASSERTIONS AND NOT A DISTANCE FLOOR ALONE. The suite already
## has a distance-ratio floor (test_camera_never_in_geometry.gd) and it
## passed straight through all of this: a ratio is relative to the zone's
## authored distance, so a shot that is SUPPOSED to be short is
## indistinguishable from one that has collapsed, and neither number knows
## whether the child is in shot at all. These check the two things that
## actually broke -- the shot keeps the height it was authored with, and
## the whole child is inside the frame -- at the exact coordinates where
## they broke.

## x, z. All five are cells the probe's own reachability flood reached, so
## the child can really stand in each of them.
const PINNED := [
	[-9.5, -6.0],    # park's north edge, west of the lane mouth
	[-16.5, -4.5],   # same wall, far west
	[14.0, -5.0],    # inside the garden pocket, against its north wall
	[16.0, -17.0],   # south-east lawn, against the pocket's south wall
	[21.0, -17.0],   # the same strip, in the corner
]

## Feet / waist / head, matching the sweep's own three body samples -- one
## head point alone calls the shot good when the child is framed from the
## neck up.
const BODY_SAMPLES := [0.25, 0.85, 1.45]
const HEAD_HEIGHT := 1.5

## camera_rig.gd damps with lambda 7.3, so 90 physics ticks (1.5 s) is well
## past convergence. tree.physics_frame rather than simulate_frames(), for
## the reason test_camera_never_in_geometry.gd's own settle records: idle
## frames do not drive a fixed number of physics ticks in this headless
## sandbox, and this test needs the SAME fully-settled state every run.
const SETTLE_TICKS := 90

## Measured after the fix: 4.11, 4.05, 2.16, 3.22 and 3.19 m at the five
## positions above; measured before it: 2.40, 1.21, 1.30, 1.48 and 1.60.
## 2.0 sits in the gap with room on both sides.
const MIN_SEPARATION := 2.0

## The shot may be pulled in, but it must not lose its HEIGHT while doing
## so -- that is the specific mechanism this round fixed. Slack absorbs the
## fov/position damping still settling and the zone blend's own gradient.
const HEIGHT_SLACK := 0.15


func _settle(runner: GdUnitSceneRunner, player: Node3D, x: float, z: float) -> void:
	# player.gd does nothing at all while external_control is set: no input,
	# no move_and_slide, no proximity verbs. Without it, standing next to
	# the tower stairs starts a climb and the test measures a camera
	# following a child up a staircase.
	player.external_control = true
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(x, player.locked_y, z)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(SETTLE_TICKS):
		await tree.physics_frame


func test_the_shot_keeps_its_height_and_its_distance_where_the_wall_is_close_behind() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var camera: Camera3D = Game.camera
	assert_object(player).is_not_null()
	assert_object(camera).is_not_null()

	var space_state := player.get_world_3d().direct_space_state
	var exclude := [player.get_rid()]

	for spot in PINNED:
		await _settle(runner, player, spot[0], spot[1])
		var p := player.global_position
		var eye := camera.global_position

		assert_float(eye.distance_to(p)) \
			.override_failure_message("camera collapsed onto the child at (%.1f, %.1f): %.2f m" % [
				spot[0], spot[1], eye.distance_to(p)]) \
			.is_greater_equal(MIN_SEPARATION)

		# The authored height for THIS z, read from the profile rather than
		# written down, so a deliberate re-tune of camera_profile.gd moves
		# this bar with it instead of failing spuriously.
		var authored_height: float = CameraProfile.profile(p.z)["height"]
		assert_float(eye.y) \
			.override_failure_message("shot lost its height at (%.1f, %.1f): camera y %.2f, zone authors %.2f" % [
				spot[0], spot[1], eye.y, authored_height]) \
			.is_greater_equal(authored_height - HEIGHT_SLACK)

		# ...and none of the above may be bought by putting the camera
		# somewhere it could never render from. Same layer-2 query
		# test_camera_never_in_geometry.gd uses.
		var query := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, HEAD_HEIGHT, 0.0), eye)
		query.exclude = exclude
		query.collision_mask = 2
		assert_dict(space_state.intersect_ray(query)) \
			.override_failure_message("camera is through a wall at (%.1f, %.1f)" % [spot[0], spot[1]]) \
			.is_empty()


func test_the_whole_child_stays_inside_the_frame_at_those_places() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var camera: Camera3D = Game.camera
	assert_object(player).is_not_null()
	assert_object(camera).is_not_null()

	for spot in PINNED:
		await _settle(runner, player, spot[0], spot[1])
		var p := player.global_position
		for h in BODY_SAMPLES:
			assert_bool(camera.is_position_in_frustum(p + Vector3(0.0, h, 0.0))) \
				.override_failure_message("child is out of frame at (%.1f, %.1f): the point %.2f m up their body is outside the camera frustum" % [
					spot[0], spot[1], h]) \
				.is_true()
