extends SceneTree
## THROWAWAY tuning probe for the round-3 seam-yaw fix. Not committed.
## Drives the player THROUGH the gap on realistic headings (not a bare
## teleport, since the fix depends on player.heading) and reports camera
## behavior at each step, plus a stationary check at the worst known point.

func _initialize() -> void:
	await _run()

func _run() -> void:
	var runner := GdUnitSceneRunnerImpl.new("res://scenes/main.tscn", false)
	await runner.simulate_frames(2)
	var game := get_root().get_node("Game")
	var player: Node3D = game.player
	var camera: Camera3D = game.camera
	game.start_episode(0.0)
	var tree := Engine.get_main_loop() as SceneTree

	print("--- driven: playground -> through gap -> ball -> back out ---")
	var space_state := player.get_world_3d().direct_space_state
	var exclude := [player.get_rid()]
	var stats := {"min_ratio": INF, "min_pos": Vector3.ZERO, "max_angle": 0.0, "max_angle_pos": Vector3.ZERO, "hits": 0, "ticks": 0}
	var on_tick := func() -> void:
		stats["ticks"] += 1
		var p: Vector3 = player.global_position
		var c: Vector3 = camera.global_position
		var authored: float = CameraProfile.profile(p.z)["distance"]
		var ratio: float = p.distance_to(c) / authored
		if ratio < stats["min_ratio"]:
			stats["min_ratio"] = ratio
			stats["min_pos"] = p
		var yaw: float = CameraProfile.profile(p.z)["authored_yaw"]
		var back := Vector2(sin(yaw), cos(yaw))
		var offset := Vector2(c.x - p.x, c.z - p.z)
		if offset.length() > 0.05:
			var angle := absf(rad_to_deg(back.angle_to(offset)))
			if angle > stats["max_angle"]:
				stats["max_angle"] = angle
				stats["max_angle_pos"] = p
		var head: Vector3 = p + Vector3(0.0, 1.5, 0.0)
		var query := PhysicsRayQueryParameters3D.create(head, c)
		query.exclude = exclude
		query.collision_mask = 2
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			stats["hits"] += 1
			print("  HIT at player=%s camera=%s hitpos=%s" % [p, c, hit["position"]])

	player.global_position = Vector3(0.0, 0.0, -8.0)
	await DriveRoute.run(runner, player, [[12.0, -8.0], [14.0, -12.0], [12.0, -8.0], [0.0, -11.0]], on_tick)
	print("ticks=%d min_ratio=%.4f at %s max_angle=%.1fdeg at %s hits=%d" % [stats["ticks"], stats["min_ratio"], stats["min_pos"], stats["max_angle"], stats["max_angle_pos"], stats["hits"]])

	print("--- stationary sweep through the gap opening (x=11.32-ish, various z) ---")
	for z in [-6.5, -7.0, -7.5, -8.0, -8.5, -9.0, -9.5]:
		player.global_position = Vector3(11.32, 0.0, z)
		player.heading = 0.0  # stale/arbitrary heading, as if they arrived facing north and stopped
		for _i in range(90):
			await tree.physics_frame
		var p := player.global_position
		var c := camera.global_position
		print("z=%.2f player=(%.2f,%.2f) camera=(%.2f,%.2f,%.2f) dist=%.2f" % [z, p.x, p.z, c.x, c.y, c.z, p.distance_to(c)])

	print("--- stationary, heading EAST (into the pocket) at gap midpoint ---")
	player.global_position = Vector3(11.0, 0.0, -8.0)
	player.heading = -PI / 2.0  # facing +x, see camera_rig.gd's own doc comment for the convention
	for _i in range(90):
		await tree.physics_frame
	var p2 := player.global_position
	var c2 := camera.global_position
	print("player=(%.2f,%.2f) heading=east camera=(%.2f,%.2f,%.2f) dist=%.2f" % [p2.x, p2.z, c2.x, c2.y, c2.z, p2.distance_to(c2)])

	print("--- gap screenshot beat position (static, current heading) ---")
	player.global_position = Vector3(10.46, 0.0, -7.97)
	for _i in range(90):
		await tree.physics_frame
	var p3 := player.global_position
	var c3 := camera.global_position
	print("player=(%.2f,%.2f) camera=(%.2f,%.2f,%.2f) dist=%.2f ratio=%.2f" % [p3.x, p3.z, c3.x, c3.y, c3.z, p3.distance_to(c3), p3.distance_to(c3) / (CameraProfile.profile(p3.z)["distance"] as float)])

	quit(0)
