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


## The park's own four boundaries (2026-08-30 park pass, world_bounds.gd's
## PARK block), pinned the same way the three openings above are: a point
## just inside each wall's clear band that must be traversable, and one
## just outside it that must not be.
##
## The reason this needs an assertion at all is the reason the pass exists.
## The developer's report was "both the left and right hand areas are not
## reachable", and the fix was to move three walls out -- so the exact
## regression to guard is those walls quietly coming back in. Nothing else
## in the suite would notice: tests/play/test_zone_reachability.gd floods
## for the five INTERACTION ZONES, and every one of them sits within 14 m
## of the world's centre line. The whole west lawn could be walled off at
## x=-16 again and every other test here would still pass.
##
## can_move_to() takes the player's own 0.32 m radius off each face, so the
## traversable band is inset by that: west wall inner face -22.4 -> -22.08,
## east -> 21.33, south -23.4 -> -23.08.
func test_the_parks_own_boundaries_sit_where_the_park_pass_put_them() -> void:
	# West wall (x=-23, half_x 0.6). 7 m further out than the wall it
	# replaced at x=-16, which is the openness the developer asked for.
	assert_bool(WorldBounds.can_move_to(-22.0, -12.0)).is_true()
	assert_bool(WorldBounds.can_move_to(-22.2, -12.0)).is_false()
	# The old wall line, now open lawn. z=-9 rather than z=-12: the
	# claustrophobia pass planted a canopy tree at (-15.6, -11.4), whose
	# trunk collider legitimately occupies the old z=-12 witness point. The
	# claim being made here is "x=-16 is inside the park now", not "every
	# point on x=-16 is empty forever", so the witness moves and the claim
	# does not weaken -- but keep this spot clear of planting.
	assert_bool(WorldBounds.can_move_to(-16.0, -9.0)).is_true()
	assert_bool(WorldBounds.can_move_to(-16.0, -17.0)).is_true()

	# Back wall (z=-24, half_z 0.6), 4 m deeper than the z=-20 it replaced.
	assert_bool(WorldBounds.can_move_to(0.0, -23.0)).is_true()
	assert_bool(WorldBounds.can_move_to(0.0, -23.2)).is_false()
	assert_bool(WorldBounds.can_move_to(0.0, -20.0)).is_true()  # the old wall line

	# East wall of the deep band (x=22, half_x 0.35). Only z[-24,-16]: north
	# of that the garden wall at x=11 is still the boundary, and the garden
	# pocket must stay reachable ONLY through its gap.
	assert_bool(WorldBounds.can_move_to(21.2, -20.0)).is_true()
	assert_bool(WorldBounds.can_move_to(21.5, -20.0)).is_false()
	# The old wall line. z=-17.5 rather than z=-20, for the same reason as
	# the west witness above: a park tree now stands at (16.2, -19.4).
	assert_bool(WorldBounds.can_move_to(16.0, -17.5)).is_true()

	# ...and the garden pocket is still sealed from the park's new
	# south-east lawn by its own z=-16 wall, so widening the park did not
	# quietly open a second way in beside the arch.
	assert_bool(WorldBounds.can_move_to(16.5, -16.0)).is_false()
	assert_bool(WorldBounds.can_move_to(20.0, -16.0)).is_false()


## The canopy trees keep TRUNK-sized colliders (claustrophobia pass,
## 2026-08-30). world_bounds.gd's CANOPY TREES block gives each of the six
## a 0.5 m half-extent under a crown roughly 5 m across, and the point of
## the whole pass is that the player walks UNDER them: 33% of the park's
## walkable ground is now beneath a crown, measured by
## tools/_probe_reachability.gd's canopy pass, and every square metre of
## that is only walkable because the collider is the trunk.
##
## This is a live regression risk, not a hypothetical. A collider that
## looks a third the size of the mesh it belongs to reads as a bug, and
## "fixing" it to match the crown would wall off a fifth of the park while
## every other assertion in this suite kept passing -- the five interaction
## zones and the five park corners tests/play/test_zone_reachability.gd
## floods for are all clear of these six trees, so nothing else notices.
##
## Each point below sits 1.5 m from a trunk centre: outside a 0.5 m
## half-extent with room for the player's 0.32 m radius, and inside a
## crown-sized one. Verified by mutation -- setting these half-extents to
## 2.5 fails all six.
func test_canopy_trees_can_be_walked_under() -> void:
	for spot in [
		[-5.5, -5.8],    # the gate tree
		[-11.3, -6.4],   # west path, north
		[-16.1, -13.4],  # west path, mid
		[-3.5, -20.2],   # south walk, west
		[6.1, -20.4],    # south walk, east
		[8.1, -14.6],    # the plaza's east corner
	]:
		assert_bool(WorldBounds.can_move_to(spot[0], spot[1])) 			.override_failure_message(
				"(%.1f, %.1f) is 1.5 m from a canopy trunk and is no longer walkable. "
				% [spot[0], spot[1]]
				+ "A canopy collider has been grown from the trunk to the crown, "
				+ "which turns each of these trees into a 5 m round wall."
			).is_true()
