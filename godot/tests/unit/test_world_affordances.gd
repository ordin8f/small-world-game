extends GdUnitTestSuite
## Pure-function tests for scripts/logic/world_affordances.gd, mirroring
## test_world_bounds.gd's own style. No scene/runner needed -- these are
## the same geometry queries player.gd/stepping_stones.gd/puddles.gd call
## into every physics tick.

func test_climb_trigger_is_just_outside_the_tower_footprint() -> void:
	assert_bool(WorldAffordances.near_climb_trigger(-3.4, -3.9)).is_true()
	# Deep in the courtyard, nowhere near the tower.
	assert_bool(WorldAffordances.near_climb_trigger(0.0, 0.0)).is_false()


func test_platform_stand_sits_on_top_of_the_deck() -> void:
	assert_float(WorldAffordances.PLATFORM_STAND.y).is_equal_approx(WorldAffordances.PLATFORM_TOP_Y, 0.001)


func test_slide_descends_from_platform_to_the_ground() -> void:
	assert_float(WorldAffordances.SLIDE_START.y).is_greater(WorldAffordances.SLIDE_END.y)
	assert_float(WorldAffordances.SLIDE_END.y).is_equal_approx(0.0, 0.001)


func test_wall_mount_matches_the_two_authored_segments() -> void:
	# Inside the first segment (z -8.0..-3.8).
	assert_bool(WorldAffordances.near_wall_mount(5.4, -6.0)).is_true()
	# Inside the second segment (z -1.8..-0.4).
	assert_bool(WorldAffordances.near_wall_mount(5.4, -1.0)).is_true()
	# In the garden-gap opening between the two segments -- not a wall here.
	assert_bool(WorldAffordances.near_wall_mount(5.4, -3.0)).is_false()
	# Right x, but too far from the wall's own x to mount from the ground.
	assert_bool(WorldAffordances.near_wall_mount(7.0, -6.0)).is_false()


func test_wall_segment_lookup_matches_bootstrap_courtyard_geometry() -> void:
	assert_dict(WorldAffordances.wall_segment_at_z(-5.9)).is_not_empty()
	assert_dict(WorldAffordances.wall_segment_at_z(-1.1)).is_not_empty()
	assert_dict(WorldAffordances.wall_segment_at_z(-3.0)).is_empty()


func test_stone_index_hits_each_authored_stone_and_misses_the_gaps() -> void:
	assert_int(WorldAffordances.stone_index_at(6.1, -2.5)).is_equal(0)
	assert_int(WorldAffordances.stone_index_at(6.9, -3.2)).is_equal(1)
	assert_int(WorldAffordances.stone_index_at(7.7, -3.9)).is_equal(2)
	assert_int(WorldAffordances.stone_index_at(8.4, -4.7)).is_equal(3)
	# A corner of the stones region, outside every stone's capture radius.
	assert_int(WorldAffordances.stone_index_at(5.6, -5.2)).is_equal(-1)


func test_stones_region_bounds_the_imagination_cue_to_the_crossing() -> void:
	assert_bool(WorldAffordances.in_stones_region(7.0, -3.5)).is_true()
	assert_bool(WorldAffordances.in_stones_region(0.0, -3.8)).is_false()  # far away, at Group


func test_puddle_index_hits_each_authored_puddle_and_misses_dry_ground() -> void:
	assert_int(WorldAffordances.puddle_index_at(-1.5, 3.2)).is_equal(0)
	assert_int(WorldAffordances.puddle_index_at(2.1, 0.8)).is_equal(1)
	assert_int(WorldAffordances.puddle_index_at(6.8, -4.2)).is_equal(2)
	assert_int(WorldAffordances.puddle_index_at(0.0, 6.5)).is_equal(-1)  # player start, dry
