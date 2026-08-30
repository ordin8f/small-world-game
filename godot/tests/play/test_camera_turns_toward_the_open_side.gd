extends GdUnitTestSuite
## Camera-orbit regression (camera-orbit task, 2026-08-30).
##
## The fault this covers, in the developer's words after playing round 5:
## "the only time it is struggling is that the default position of the
## camera looking is the same as the one facing wall. It might be worth
## considering moving it around a bit."
##
## Round 5 (test_camera_where_the_room_runs_out.gd) fixed the camera
## COLLAPSING when a wall stood behind the player -- the shot kept its
## height instead of losing it in proportion with its distance. What it did
## not do, and could not, is change WHICH WAY the shot points: the camera
## only ever moved along the one authored axis, shorter and higher, so
## wherever that axis was a bad one there was nothing left to try.
## camera_rig.gd's orbit block scores candidate angles either side of the
## authored one and slides the shot toward whichever measures better.
##
## THE THREE THINGS THAT MUST ALL HOLD, and why one alone is not enough:
##   - it TURNS where the authored angle is bad. Without this the feature
##     does nothing.
##   - it DOES NOT TURN where the authored angle is fine. Without this it is
##     a permanent 30 deg tax on docs/ART_DIRECTION.md's authored framing,
##     paid everywhere to fix somewhere -- and the open park is most of the
##     world.
##   - it EASES. A camera that finds a better angle by snapping to it is
##     worse than one that stays put, and neither of the two assertions
##     above can see the difference: both read a settled state.

const SETTLE_TICKS := 150

## Where the authored angle is already the best available. Read out of
## tools/_probe_camera_sweep.gd's own `orbit` column: each of these settles
## at EXACTLY zero, because camera_rig.gd's ORBIT_ENGAGE_MIN makes the orbit
## a hard zero below its margin rather than a small number. 1.0 deg is
## therefore a tight bound with real slack in it, not a hopeful one.
##
## Chosen from the sweep, not picked by eye, and one candidate was thrown
## out for it: (-8,-17) looks like open lawn on the map and turns 26 deg,
## because the left tower and its staircase sit right behind it. These three
## are also where the game's story actually happens -- (0,-10) is the chalk
## circle and the Group beat -- so this is not an abstract control. It is
## the assertion that the authored shot docs/ART_DIRECTION.md calls part of
## the visual identity is what the player gets for the bulk of the game.
const OPEN_GROUND := [
	[0.0, -10.0],
	[0.0, -14.0],
	[-10.0, -11.0],
]
const OPEN_GROUND_LIMIT_DEG := 1.0

## Beside the left tower's staircase. On the pre-orbit build the shot here
## is thrown straight north into the back of the staircase and the tower:
## the rendered frame has the child completely hidden behind the treads,
## with one blue shoe visible through them. It is the single clearest case
## in the world of an authored angle that cannot work, and the sweep agrees
## -- the staircase stood between camera and child at 27 cells before this
## round and at none after.
const PINNED_BEHIND_THE_STAIRCASE := Vector2(-6.0, -15.0)

## Hard against the park's west wall, and here the right answer is NOT to
## turn. An earlier build turned this one 18.8 deg, which bought the full
## authored distance and a normal follow angle in exchange for pointing the
## frame into the corner -- window openness 0.45 -> 0.28 -- and the render
## came back with no child in it anywhere. camera_rig.gd's
## ORBIT_VIEW_TOLERANCE is what stops it; this is the guard on that guard.
##
## Not a duplicate of the open-ground test above, and the difference is the
## point: there the orbit stays put because nothing better exists, here it
## stays put because the better-scoring angle is a worse SHOT. Only the
## second one goes red if the frame constraint is removed.
const COSTS_MORE_THAN_IT_BUYS := [
	[-22.0, -14.0],
	[-22.0, -13.5],
]
const COSTS_MORE_LIMIT_DEG := 8.0

## The garden gap (world_bounds.gd's x=11 wall, opening z in [-9,-7]).
## Excluded from the orbit on purpose, and this is the guard on that
## exclusion rather than a hope: round 3 of the camera work established with
## measurements that swinging the camera from a player standing in this gap
## puts the arm through the corner at (11,-9) or (11,-7) in one direction or
## the other, in every one of five variants tried. camera_rig.gd's
## ORBIT_SEAM_X/Z fade the orbit's authority to zero across it.
const IN_THE_GARDEN_GAP := [
	[11.3, -8.0],
	[12.0, -8.0],
	[10.5, -8.5],
]
## Measured 0.37, 0.00 and 0.00 deg at the three positions above.
const SEAM_LIMIT_DEG := 2.0


func _settle(player: Node3D, x: float, z: float, ticks: int = SETTLE_TICKS) -> void:
	# player.gd does nothing at all while external_control is set -- no
	# input, no move_and_slide, no proximity verbs -- so nothing here can
	# turn into a tower climb halfway through a measurement.
	player.external_control = true
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(x, player.locked_y, z)
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(ticks):
		await tree.physics_frame


## Degrees the camera sits off the zone's authored dead-behind direction --
## the same quantity test_camera_never_in_geometry.gd bounds at 45, measured
## the same way, so the two tests are talking about one number.
func _angle_off_authored(player: Node3D, camera: Camera3D) -> float:
	var p := player.global_position
	var eye := camera.global_position
	var authored_yaw: float = CameraProfile.profile(p.z)["authored_yaw"]
	var back := Vector2(sin(authored_yaw), cos(authored_yaw))
	var offset := Vector2(eye.x - p.x, eye.z - p.z)
	if offset.length() <= 0.05:
		return 0.0
	return absf(rad_to_deg(back.angle_to(offset)))


func test_the_authored_angle_is_left_alone_in_open_ground() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var rig: Node3D = Game.camera.get_parent().get_parent()
	assert_object(player).is_not_null()

	for spot in OPEN_GROUND:
		await _settle(player, spot[0], spot[1])
		assert_float(rad_to_deg(rig._orbit_yaw)) \
			.override_failure_message("the shot was turned off its authored angle in open ground at (%.1f, %.1f): %.2f deg, and there was nothing there worth turning for" % [
				spot[0], spot[1], rad_to_deg(rig._orbit_yaw)]) \
			.is_between(-OPEN_GROUND_LIMIT_DEG, OPEN_GROUND_LIMIT_DEG)


func test_the_shot_turns_off_the_thing_it_was_pinned_behind() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var camera: Camera3D = Game.camera
	assert_object(player).is_not_null()
	assert_object(camera).is_not_null()

	await _settle(player, PINNED_BEHIND_THE_STAIRCASE.x, PINNED_BEHIND_THE_STAIRCASE.y)
	var p := player.global_position
	var eye := camera.global_position

	# It turned at all. 8 deg, not something tighter: the shipped build
	# settles at 28.5 deg off authored here, and the pre-orbit build at 4.5.
	assert_float(_angle_off_authored(player, camera)) \
		.override_failure_message("the shot stayed on the axis that put the staircase between camera and child: %.2f deg off authored" % [
			_angle_off_authored(player, camera)]) \
		.is_greater(8.0)

	# ...and turning bought the two things it was turned for, both of which
	# the pre-orbit build failed here and neither of which follows from the
	# angle alone. A shot can be turned 20 deg and still be jammed.
	#
	# Separation: the authored angle here does reach its full 8.17 m -- what
	# it cannot do is see past the staircase -- so this is a guard against a
	# turn that buys the angle by collapsing the shot, not a claim that the
	# turn bought the distance.
	assert_float(eye.distance_to(p)) \
		.override_failure_message("the turn collapsed the shot: %.2f m" % eye.distance_to(p)) \
		.is_greater(6.0)

	# ...and it did not buy the angle by parking on a wall face instead.
	# The same arithmetic camera_rig.gd's own _clearance_score() uses,
	# against world_bounds.gd's own boxes. Measured 4.66 m here.
	var clearance := INF
	for box in WorldBounds.COLLIDERS:
		if not box.get("camera_blocks", false):
			continue
		var dx: float = maxf(absf(eye.x - box["x"]) - box["half_x"], 0.0)
		var dz: float = maxf(absf(eye.z - box["z"]) - box["half_z"], 0.0)
		clearance = minf(clearance, sqrt(dx * dx + dz * dz))
	assert_float(clearance) \
		.override_failure_message("the turned shot is standing on a wall face: %.2f m of clearance" % clearance) \
		.is_greater(1.5)

	# None of it may be bought by putting the camera through a wall. Same
	# layer-2 query test_camera_never_in_geometry.gd uses.
	var query := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 1.5, 0.0), eye)
	query.exclude = [player.get_rid()]
	query.collision_mask = 2
	assert_dict(player.get_world_3d().direct_space_state.intersect_ray(query)) \
		.override_failure_message("the turned shot is through a wall") \
		.is_empty()


## The other half of "turns where it helps": it must also decline where
## turning would help by every measure except the one that matters.
##
## The build this was written against turned these two cells 18.8 deg and
## gained the full authored distance, a normal 14 deg follow angle instead of
## a 55 deg look-down, and 2.4 m of wall clearance instead of 0.4 -- every
## structural number better -- by pointing the frame into the park's
## south-west corner. Window openness 0.45 -> 0.28, and the rendered frame
## had no child in it. camera_rig.gd's ORBIT_VIEW_TOLERANCE forbids the
## trade; this holds it forbidden.
func test_the_shot_declines_to_turn_when_turning_would_cost_the_frame() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var rig: Node3D = Game.camera.get_parent().get_parent()

	for spot in COSTS_MORE_THAN_IT_BUYS:
		await _settle(player, spot[0], spot[1])
		assert_float(absf(rad_to_deg(rig._orbit_yaw))) \
			.override_failure_message("the shot turned %.2f deg at (%.1f, %.1f) to gain room and clearance by pointing the frame into the corner -- the build that did this rendered a frame with no child in it" % [
				absf(rad_to_deg(rig._orbit_yaw)), spot[0], spot[1]]) \
			.is_less(COSTS_MORE_LIMIT_DEG)


## ...and it must not turn a shot that SHOWS the child into one that does
## not, which is a different failure from the one above and was caught at a
## different cell. At (11,-17) the pre-orbit shot is close and steep and
## unlovely, and it does show the child; an earlier build turned it the full
## 32 deg onto a line running down the length of the canopy tree at
## (9.6,-14.6), with the trunk squarely over them.
##
## Half a metre away at (10.5,-17.5) the same turn is right and keeps its
## full 32 deg, so this cannot be satisfied by refusing to turn near trees.
const MUST_KEEP_SHOWING_THE_CHILD := [
	[11.0, -17.0],
	[10.5, -17.5],
	[-3.5, -17.5],
]


func test_the_shot_never_turns_a_visible_child_into_a_hidden_one() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var camera: Camera3D = Game.camera
	var space_state := player.get_world_3d().direct_space_state

	for spot in MUST_KEEP_SHOWING_THE_CHILD:
		await _settle(player, spot[0], spot[1])
		var p := player.global_position
		# Chest height, and layers 1 AND 2 -- a trunk hides the child as
		# completely as a wall does. The same query camera_rig.gd's own
		# _sight_blocked() uses to decide this, asked of the settled result.
		var query := PhysicsRayQueryParameters3D.create(
			camera.global_position, p + Vector3(0.0, 0.85, 0.0))
		query.exclude = [player.get_rid()]
		query.collision_mask = 3
		assert_dict(space_state.intersect_ray(query)) \
			.override_failure_message("the turned shot put something between the camera and the child at (%.1f, %.1f), where the authored shot had them in clear view" % [
				spot[0], spot[1]]) \
			.is_empty()


func test_the_garden_gap_is_left_exactly_as_round_two_tuned_it() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var rig: Node3D = Game.camera.get_parent().get_parent()

	for spot in IN_THE_GARDEN_GAP:
		await _settle(player, spot[0], spot[1])
		assert_float(rad_to_deg(rig._orbit_yaw)) \
			.override_failure_message("the shot was turned inside the garden gap at (%.1f, %.1f): %.2f deg. Round 3 measured this exact move clipping the gap's own corners in five variants." % [
				spot[0], spot[1], rad_to_deg(rig._orbit_yaw)]) \
			.is_between(-SEAM_LIMIT_DEG, SEAM_LIMIT_DEG)


## The smoothness one, and the reason it reads `_orbit_yaw` rather than the
## camera's own heading: after a teleport the camera's heading is moved by
## TWO dampers at once -- `_smoothed_desired` catching up to the new
## position at lambda 7.3, and the orbit turning at lambda 2.0 -- and a
## bound on their sum cannot distinguish an orbit that snapped from one that
## did not. This measures the orbit's own step directly.
##
## Both halves matter. Without the second assertion a build with the orbit
## deleted outright passes this test perfectly: nothing that never moves
## ever moves too fast.
func test_the_shot_eases_into_its_new_angle_rather_than_snapping_to_it() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var rig: Node3D = Game.camera.get_parent().get_parent()

	# Start settled somewhere the orbit is zero, so the swing measured below
	# is the whole swing and not the tail of a previous one.
	await _settle(player, OPEN_GROUND[0][0], OPEN_GROUND[0][1])

	# Then stand at the pinned position WITHOUT letting the rig snap: this
	# is the ordinary in-play path (`_initialized` is long since true), so
	# every step from here is damped.
	player.global_position = Vector3(
		PINNED_BEHIND_THE_STAIRCASE.x, player.locked_y, PINNED_BEHIND_THE_STAIRCASE.y)
	var tree := Engine.get_main_loop() as SceneTree
	var previous: float = rig._orbit_yaw
	var biggest_step := 0.0
	for _i in range(SETTLE_TICKS):
		await tree.physics_frame
		var now: float = rig._orbit_yaw
		biggest_step = maxf(biggest_step, absf(rad_to_deg(now - previous)))
		previous = now

	# At ORBIT_LAMBDA 2.0 and 60 Hz a step is 3.3% of what is left to
	# travel, so the largest single step of even a full 32 deg swing is
	# about 1.05 deg. 2.0 leaves room for the target itself moving as the
	# scores settle, and is far below the ~20 deg a lambda ten times larger
	# would take, or the 30-odd of no damping at all.
	assert_float(biggest_step) \
		.override_failure_message("the shot snapped to its new angle: %.2f deg in a single tick" % biggest_step) \
		.is_less(2.0)
	assert_float(absf(rad_to_deg(rig._orbit_yaw))) \
		.override_failure_message("the shot never turned at all, so the smoothness bound above measured nothing: %.2f deg" % absf(rad_to_deg(rig._orbit_yaw))) \
		.is_greater(8.0)
