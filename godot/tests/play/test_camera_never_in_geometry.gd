extends GdUnitTestSuite
## M1.4 play test (GODOT_REBUILD_PLAN.md): drives the real Player through the
## full authored route (start -> watch -> gap -> ball -> group -> door) via
## simulated WASD input (tests/helpers/drive.gd) against the real M1.2
## courtyard geometry and M1.4 camera rig, asserting every physics tick that
## a head->camera raycast (excluding the player, and checking only the
## camera-blocking perimeter -- see the query's collision_mask below) never
## hits geometry, the camera never drops below y=0.6, and it stays within
## the source's
## authored clamps (game.mjs:399-400). This is the exact regression guard
## for Saturday Afternoon's follow camera ending up outside the starting
## room's walls -- the failure this whole rebuild plan was written against.

const HEAD_HEIGHT := 1.5
## Slack added to the source's authored clamps (game.mjs:399-400) purely to
## absorb float-lerp rounding noise (observed ~1e-6 overshoot) -- not a
## relaxation of the actual bound.
const CLAMP_EPSILON := 0.02

## start -> watch -> gap (garden-wall opening, matches test_garden_gap.gd's
## known-traversable point) -> ball -> group -> door, per courtyard.tscn's
## Marker3D key points (tools/_bootstrap_courtyard.gd).
const ROUTE := [
	[0.0, -1.2],   # Watch
	[6.5, -3.0],   # through the garden-wall gap (outbound)
	[8.6, -6.6],   # BallEnd
	[6.5, -3.0],   # back through the gap (inbound) -- straight-line steering
	               # from BallEnd to Group would otherwise cut through the
	               # garden wall itself; a real player has to funnel back
	               # through the same opening, same as the outbound leg.
	[0.0, -3.8],   # Group
	[0.0, 10.8],   # Door
]


func test_camera_stays_clear_of_geometry_along_the_full_route() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)  # let both Player and CameraRig _ready() run

	var player: Node3D = Game.player
	var camera: Camera3D = Game.camera
	assert_object(player).is_not_null()
	assert_object(camera).is_not_null()

	var space_state := player.get_world_3d().direct_space_state
	var exclude := [player.get_rid()]
	# A Dictionary, not raw locals: GDScript lambdas capture outer local
	# variables BY VALUE (a snapshot at closure creation), so `checked_ticks
	# += 1` inside on_tick would silently mutate a private copy invisible
	# to the code after `await DriveRoute.run(...)` below. A Dictionary
	# reference is itself captured by value, but the Dictionary it points
	# to is shared, so mutations through it are visible on both sides.
	var stats := {"checked_ticks": 0, "min_camera_y": INF}

	var on_tick := func() -> void:
		stats["checked_ticks"] += 1
		var head: Vector3 = player.global_position + Vector3(0.0, HEAD_HEIGHT, 0.0)
		var cam_pos: Vector3 = camera.global_position
		stats["min_camera_y"] = minf(stats["min_camera_y"], cam_pos.y)

		# Camera never below the plan's floor, never outside the source's
		# authored horizontal/depth clamps (game.mjs:399-400).
		assert_float(cam_pos.y).is_greater_equal(0.6)
		assert_float(cam_pos.x).is_between(-9.65 - CLAMP_EPSILON, 9.65 + CLAMP_EPSILON)
		assert_float(cam_pos.z).is_between(-12.55 - CLAMP_EPSILON, 11.05 + CLAMP_EPSILON)

		var query := PhysicsRayQueryParameters3D.create(head, cam_pos)
		query.exclude = exclude
		# M3.4: layer 2 only -- the same dedicated "camera-blocking" layer
		# camera_rig.tscn's SpringArm3D itself watches (perimeter walls
		# only; see tools/_bootstrap_courtyard.gd's _wall_collider()).
		# Without this, the query defaults to every physics layer,
		# including small in-courtyard obstacles (a garden wall nub, a
		# bench footprint) that were never meant to represent
		# camera-blocking architecture -- their uniform 2.4m collision
		# height exists purely for player movement (ART_DIRECTION.md:
		# "collision geometry substantially simpler than render
		# geometry") and none of them separate the camera from the
		# world the way the historical Saturday Afternoon bug did.
		query.collision_mask = 2
		var hit := space_state.intersect_ray(query)
		assert_dict(hit).is_empty()

	var ticks := await DriveRoute.run(runner, player, ROUTE, on_tick)

	assert_int(stats["checked_ticks"]).is_equal(ticks)
	assert_int(stats["checked_ticks"]).is_greater(60)  # sanity floor: the route actually ran
	assert_float(stats["min_camera_y"]).is_greater_equal(0.6)
