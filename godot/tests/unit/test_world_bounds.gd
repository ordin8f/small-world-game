extends GdUnitTestSuite
## Port of the garden-gap case from tests/logic.test.mjs -- verbatim
## assertions against WorldBounds.can_move_to. Relocated for the
## 2026-08-28 world expansion: the garden wall moved from x=5.4 (a slice
## of the old single room) to x=11 (the playground/garden-pocket boundary
## -- world_bounds.gd's own doc comment), and the wall itself widened in z
## to match the pocket's new z[-16,-4] span, but the shape of the claim is
## identical -- solid either side of a 2 m gap, open through it.
##
## Openness pass (2026-08-29): the gap widened from 2.0 m to 3.4 m, so the
## four original points below no longer pin its width -- z=-8.0 and z=-7.6
## sit well inside a gap of either size and would still pass if someone
## narrowed it back. The edge cases added below are what actually hold the
## new width: a point 0.1 m inside each new opening edge that must be
## traversable, and one 0.1 m outside it that must not be. Together they
## trap the boundary to within 0.2 m on both sides, which the original
## four assertions never did for their own 2 m gap either.
func test_garden_wall_leaves_the_intended_gap_traversable() -> void:
	assert_bool(WorldBounds.can_move_to(11.0, -13.0)).is_false()  # deep segment
	assert_bool(WorldBounds.can_move_to(11.0, -5.5)).is_false()  # near segment
	assert_bool(WorldBounds.can_move_to(11.0, -8.0)).is_true()  # the gap itself
	assert_bool(WorldBounds.can_move_to(11.0, -7.6)).is_true()


## The gap runs z[-9.7, -6.3]. can_move_to() takes the player's own 0.32 m
## radius into account, so the traversable band is inset by that on each
## side: z[-9.38, -6.62]. These four assertions sit either side of both
## insets.
func test_garden_gap_is_the_full_authored_width() -> void:
	assert_bool(WorldBounds.can_move_to(11.0, -9.3)).is_true()  # inside the deep edge
	assert_bool(WorldBounds.can_move_to(11.0, -6.7)).is_true()  # inside the near edge
	assert_bool(WorldBounds.can_move_to(11.0, -9.5)).is_false()  # past the deep edge
	assert_bool(WorldBounds.can_move_to(11.0, -6.5)).is_false()  # past the near edge


## The other two openings between the four rooms, pinned the same way. The
## home doorway (3.6 m between piers at z=15) and the lane (x[-5,5], the
## home->playground passage) are exactly as easy to close by accident as
## the garden gap is, and until this pass neither had any assertion at all.
## tests/play/test_zone_reachability.gd catches a closure of any of the
## three by flooding the real physics world; these catch it in the collider
## data itself, which is faster and points straight at the entry at fault.
func test_home_doorway_and_lane_stay_open() -> void:
	# Doorway: piers span x[-7,-1.8] and x[1.8,7] at z=15.
	assert_bool(WorldBounds.can_move_to(0.0, 15.0)).is_true()  # through the middle
	assert_bool(WorldBounds.can_move_to(1.4, 15.0)).is_true()  # inside the east pier's face
	assert_bool(WorldBounds.can_move_to(1.6, 15.0)).is_false()  # into it
	assert_bool(WorldBounds.can_move_to(-1.6, 15.0)).is_false()  # and the west one

	# Lane: walls at x=+-5, half_x 0.3, so the traversable band is
	# x[-4.38, 4.38] once the player's radius is taken off.
	assert_bool(WorldBounds.can_move_to(0.0, 2.0)).is_true()
	assert_bool(WorldBounds.can_move_to(4.3, 2.0)).is_true()
	assert_bool(WorldBounds.can_move_to(4.5, 2.0)).is_false()
	assert_bool(WorldBounds.can_move_to(-4.5, 2.0)).is_false()
