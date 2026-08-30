extends GdUnitTestSuite
## Pure-function tests for scripts/logic/world_affordances.gd, mirroring
## test_world_bounds.gd's own style. No scene/runner needed -- these are
## the same geometry queries player.gd/stepping_stones.gd/puddles.gd call
## into every physics tick.

## Moved 2026-08-30, from a blank tower face to the foot of the staircase
## that now exists -- see WorldAffordances' STAIR_* block. The geometry of
## the staircase itself is checked against the BUILT scene in
## tests/play/test_tower_stairs.gd; these are the reachability facts a pure
## query can answer.
func test_climb_trigger_sits_at_the_foot_of_the_stairs() -> void:
	assert_bool(WorldAffordances.near_climb_trigger(WorldAffordances.CLIMB_TRIGGER.x, WorldAffordances.STAIR_Z)).is_true()
	# In the lane, nowhere near the tower.
	assert_bool(WorldAffordances.near_climb_trigger(0.0, 0.0)).is_false()
	# ...and no longer at the tower's south face, where the SLIDE now has
	# sole use of the approach: walking up to the slide's foot must not
	# teleport the player to the top of it.
	assert_bool(WorldAffordances.near_climb_trigger(-3.4, -11.0)).is_false()


## The trigger is useless if the collider for the thing it belongs to stops
## the player before they reach it. This is the check that would have caught
## the staircase collider being authored a few centimetres too wide.
func test_the_climb_trigger_is_actually_standable_ground() -> void:
	assert_bool(WorldBounds.can_move_to(WorldAffordances.CLIMB_TRIGGER.x, WorldAffordances.CLIMB_TRIGGER.z)).is_true()


func test_platform_stand_sits_on_top_of_the_deck() -> void:
	assert_float(WorldAffordances.PLATFORM_STAND.y).is_equal_approx(WorldAffordances.PLATFORM_TOP_Y, 0.001)
	# On the deck's own footprint, both axes.
	assert_float(absf(WorldAffordances.PLATFORM_STAND.x - WorldAffordances.TOWER_X)).is_less(WorldAffordances.TOWER_FOOTPRINT_HALF)
	assert_float(absf(WorldAffordances.PLATFORM_STAND.z - WorldAffordances.TOWER_Z)).is_less(WorldAffordances.TOWER_FOOTPRINT_HALF)


func test_slide_descends_from_the_deck_edge_to_the_ground() -> void:
	assert_float(WorldAffordances.SLIDE_SURFACE_TOP.y).is_equal_approx(WorldAffordances.PLATFORM_TOP_Y, 0.001)
	assert_float(WorldAffordances.SLIDE_SURFACE_TOP.y).is_greater(WorldAffordances.SLIDE_SURFACE_FOOT.y)
	assert_float(WorldAffordances.SLIDE_END.y).is_equal_approx(0.0, 0.001)
	# Lands clear of the tower's own collider footprint, out in the open.
	assert_float(WorldAffordances.SLIDE_END.z).is_greater(WorldAffordances.TOWER_Z + WorldAffordances.TOWER_FOOTPRINT_HALF)
	assert_bool(WorldBounds.can_move_to(WorldAffordances.SLIDE_END.x, WorldAffordances.SLIDE_END.z)).is_true()


## The deck's south edge is 2.7 m wide and the slide's mouth is 1.25 of it.
## Stepping off the edge anywhere else used to start the ride and snap the
## child up to a metre sideways onto the plank.
func test_only_the_slides_own_mouth_starts_the_ride() -> void:
	var edge: float = WorldAffordances.TOWER_Z + WorldAffordances.TOWER_FOOTPRINT_HALF - 0.1
	assert_bool(WorldAffordances.at_slide_mouth(WorldAffordances.TOWER_X, edge)).is_true()
	assert_bool(WorldAffordances.at_slide_mouth(WorldAffordances.TOWER_X - 1.2, edge)).is_false()
	assert_bool(WorldAffordances.at_slide_mouth(WorldAffordances.TOWER_X + 1.2, edge)).is_false()
	# Middle of the deck, nowhere near the edge.
	assert_bool(WorldAffordances.at_slide_mouth(WorldAffordances.TOWER_X, WorldAffordances.TOWER_Z)).is_false()
	# ...and walking straight off the stairs' arrival point reaches it, so
	# the deck is never a place the player can get stuck standing on.
	assert_bool(WorldAffordances.at_slide_mouth(WorldAffordances.PLATFORM_STAND.x, edge)).is_true()


## Balance verb moved off the tall playground/garden-pocket boundary wall
## (which stays at x=11, just no longer a balance affordance) onto a low
## brick edging around a planting bed by the home threshold --
## world_affordances.gd's own doc comment has the developer's own words on
## why. One continuous run (z 10.45..13.65), unlike the old wall's two
## segments either side of the garden gap, since a small bed's edging has
## no gap to model -- so the "in between" case below is past either end
## instead of a gap in the middle.
func test_edging_mount_matches_its_authored_run() -> void:
	# Inside the run (z 10.45..13.65).
	assert_bool(WorldAffordances.near_edging_mount(-3.7, 12.0)).is_true()
	assert_bool(WorldAffordances.near_edging_mount(-3.7, 11.0)).is_true()
	# Past either end -- not the edging here.
	assert_bool(WorldAffordances.near_edging_mount(-3.7, 10.0)).is_false()
	assert_bool(WorldAffordances.near_edging_mount(-3.7, 14.0)).is_false()
	# Right x, but too far from the edging's own x to mount from the ground.
	assert_bool(WorldAffordances.near_edging_mount(-2.6, 12.0)).is_false()


func test_edging_segment_lookup_matches_bootstrap_courtyard_geometry() -> void:
	assert_dict(WorldAffordances.edging_segment_at_z(12.0)).is_not_empty()
	assert_dict(WorldAffordances.edging_segment_at_z(10.0)).is_empty()
	assert_dict(WorldAffordances.edging_segment_at_z(14.0)).is_empty()


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
