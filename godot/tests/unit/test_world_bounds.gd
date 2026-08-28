extends GdUnitTestSuite
## Port of the garden-gap case from tests/logic.test.mjs -- verbatim
## assertions against WorldBounds.can_move_to.

func test_garden_wall_leaves_the_intended_gap_traversable() -> void:
	assert_bool(WorldBounds.can_move_to(5.4, -5.9)).is_false()
	assert_bool(WorldBounds.can_move_to(5.4, -1.1)).is_false()
	assert_bool(WorldBounds.can_move_to(5.4, -3.0)).is_true()
	assert_bool(WorldBounds.can_move_to(5.4, -2.6)).is_true()
