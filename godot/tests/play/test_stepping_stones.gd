extends GdUnitTestSuite
## Gate 0 play test for scripts/stepping_stones.gd: standing on a stone vs.
## in the ground between them (but still among the stones) should visibly
## differ via perception.gd's bounded imagination-cue channel -- and never
## show anything at all outside the stones region.

func test_stone_vs_gap_changes_the_perception_imagination_strength() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var player: Node3D = Game.player
	assert_object(player).is_not_null()
	var perception: Node = runner.scene().find_child("Perception", true, false)
	assert_object(perception).is_not_null()

	var tree := Engine.get_main_loop() as SceneTree

	# On a stone: ordinary, no cue.
	var stone: Dictionary = WorldAffordances.STONES[0]
	player.global_position = Vector3(stone["x"], 0.0, stone["z"])
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_less(0.05)

	# In the gap, still among the stones -- the cue kicks in. Clear of the
	# wall colliders (WALL_X=11, half_x 0.35) and every stone's capture
	# radius, but still inside the stones region. Relocated for the
	# 2026-08-28 world expansion (world_bounds.gd's own doc comment) --
	# same offset from the gap's own midpoint the single-room version's
	# (6.5, -5.1) held from its own gap.
	assert_bool(WorldAffordances.in_stones_region(12.1, -10.3)).is_true()
	assert_int(WorldAffordances.stone_index_at(12.1, -10.3)).is_equal(-1)
	player.global_position = Vector3(12.1, 0.0, -10.3)
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_greater(0.5)

	# Far away entirely -- back to no cue, it dissolves rather than sticking.
	player.global_position = Vector3(0.0, 0.0, 10.0)
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_less(0.05)


func test_imagination_cue_never_touches_authored_colour() -> void:
	# perception.gd's own contract (see its "Gate 0 -- IMAGINATION CUE" doc
	# comment): scalars only, colour is always the authored mood's colour.
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var perception: Node = runner.scene().find_child("Perception", true, false)

	player.global_position = Vector3(12.1, 0.0, -10.3)  # in the gap -- cue active, clear of colliders
	var tree := Engine.get_main_loop() as SceneTree
	for _i in range(90):
		await tree.physics_frame
	assert_float(perception.call("imagination_strength")).is_greater(0.5)

	var base: Resource = perception.call("current_mood")
	var world_env: WorldEnvironment = runner.scene().find_child("WorldEnvironment", true, false)
	var env: Environment = world_env.environment
	assert_bool(env.fog_light_color.is_equal_approx(base.fog_color)).is_true()
	assert_bool(env.ambient_light_color.is_equal_approx(base.ambient_color)).is_true()
	assert_bool(env.background_color.is_equal_approx(base.background_color)).is_true()
