extends GdUnitTestSuite
## Port of the garden-gap case from tests/logic.test.mjs -- verbatim
## assertions against WorldBounds.can_move_to. Relocated for the
## 2026-08-28 world expansion: the garden wall moved from x=5.4 (a slice
## of the old single room) to x=11 (the playground/garden-pocket boundary
## -- world_bounds.gd's own doc comment), and the wall itself widened in z
## to match the pocket's new z[-16,-4] span, but the shape of the claim is
## identical -- solid either side of a 2 m gap, open through it.
func test_garden_wall_leaves_the_intended_gap_traversable() -> void:
	assert_bool(WorldBounds.can_move_to(11.0, -13.0)).is_false()  # deep segment
	assert_bool(WorldBounds.can_move_to(11.0, -5.5)).is_false()  # near segment
	assert_bool(WorldBounds.can_move_to(11.0, -8.0)).is_true()  # the gap itself
	assert_bool(WorldBounds.can_move_to(11.0, -7.6)).is_true()
