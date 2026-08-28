extends GdUnitTestSuite
## Pure-function tests for scripts/logic/world_affordances.gd, mirroring
## test_world_bounds.gd's own style. No scene/runner needed -- these are
## the same geometry queries player.gd/stepping_stones.gd/puddles.gd call
## into every physics tick.

func test_climb_trigger_is_just_outside_the_tower_footprint() -> void:
	assert_bool(WorldAffordances.near_climb_trigger(-3.4, -11.0)).is_true()
	# In the lane, nowhere near the (relocated) tower.
	assert_bool(WorldAffordances.near_climb_trigger(0.0, 0.0)).is_false()


func test_platform_stand_sits_on_top_of_the_deck() -> void:
	assert_float(WorldAffordances.PLATFORM_STAND.y).is_equal_approx(WorldAffordances.PLATFORM_TOP_Y, 0.001)


func test_slide_descends_from_platform_to_the_ground() -> void:
	assert_float(WorldAffordances.SLIDE_START.y).is_greater(WorldAffordances.SLIDE_END.y)
	assert_float(WorldAffordances.SLIDE_END.y).is_equal_approx(0.0, 0.001)


## Garden wall relocated to x=11 for the 2026-08-28 world expansion
## (world_bounds.gd's own doc comment) -- segments and gap widened/moved
## with it (z -16..-9 / gap -9..-7 / -7..-4), same shape of claim as before.
func test_wall_mount_matches_the_two_authored_segments() -> void:
	# Inside the first (deep) segment (z -16.0..-9.0).
	assert_bool(WorldAffordances.near_wall_mount(11.0, -13.0)).is_true()
	# Inside the second (near) segment (z -7.0..-4.0).
	assert_bool(WorldAffordances.near_wall_mount(11.0, -5.5)).is_true()
	# In the garden-gap opening between the two segments -- not a wall here.
	assert_bool(WorldAffordances.near_wall_mount(11.0, -8.0)).is_false()
	# Right x, but too far from the wall's own x to mount from the ground.
	assert_bool(WorldAffordances.near_wall_mount(12.6, -13.0)).is_false()


func test_wall_segment_lookup_matches_bootstrap_courtyard_geometry() -> void:
	assert_dict(WorldAffordances.wall_segment_at_z(-13.0)).is_not_empty()
	assert_dict(WorldAffordances.wall_segment_at_z(-5.5)).is_not_empty()
	assert_dict(WorldAffordances.wall_segment_at_z(-8.0)).is_empty()


## Stones relocated with the garden gap -- same positions relative to the
## gap's own midpoint (x=11, z=-8) the single-room version held relative
## to its own gap.
func test_stone_index_hits_each_authored_stone_and_misses_the_gaps() -> void:
	assert_int(WorldAffordances.stone_index_at(11.7, -7.7)).is_equal(0)
	assert_int(WorldAffordances.stone_index_at(12.5, -8.4)).is_equal(1)
	assert_int(WorldAffordances.stone_index_at(13.3, -9.1)).is_equal(2)
	assert_int(WorldAffordances.stone_index_at(14.0, -9.9)).is_equal(3)
	# A corner of the stones region, outside every stone's capture radius.
	assert_int(WorldAffordances.stone_index_at(11.2, -10.4)).is_equal(-1)


func test_stones_region_bounds_the_imagination_cue_to_the_crossing() -> void:
	assert_bool(WorldAffordances.in_stones_region(13.0, -9.0)).is_true()
	assert_bool(WorldAffordances.in_stones_region(0.0, -11.0)).is_false()  # far away, at Group


## First two puddles are in the lane (unchanged); the third is the garden
## one, relocated with that pocket.
func test_puddle_index_hits_each_authored_puddle_and_misses_dry_ground() -> void:
	assert_int(WorldAffordances.puddle_index_at(-1.5, 3.2)).is_equal(0)
	assert_int(WorldAffordances.puddle_index_at(2.1, 0.8)).is_equal(1)
	assert_int(WorldAffordances.puddle_index_at(12.4, -9.4)).is_equal(2)
	assert_int(WorldAffordances.puddle_index_at(0.0, 10.0)).is_equal(-1)  # player start, dry
