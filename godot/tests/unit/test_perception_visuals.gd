extends GdUnitTestSuite
## M2.5 unit test (GODOT_REBUILD_PLAN.md's literal accept criterion):
## "FIND_BALL far from group -> lower comfort -> smaller fogNear than
## ARRIVE." Pure logic (EpisodeDirector.emotional_target() +
## EmotionalLens.get_visuals() composition) -- no live scene needed.

func test_find_ball_far_from_group_has_lower_comfort_and_smaller_fog_near_than_arrive() -> void:
	var director := EpisodeDirector.new()

	director.state = EpisodeDirector.State.ARRIVE
	var arrive_target := director.emotional_target(0.0)

	director.state = EpisodeDirector.State.FIND_BALL
	var find_ball_target := director.emotional_target(15.0)  # far from group -> distance_from_group/15 clamps to 1

	assert_float(find_ball_target["comfort"]).is_less(arrive_target["comfort"])

	# get_visuals() reads .value, which the constructor seeds directly --
	# no update()/easing needed to compare the two target compositions.
	var arrive_fog_near: float = EmotionalLens.new(arrive_target).get_visuals()["fog_near"]
	var find_ball_fog_near: float = EmotionalLens.new(find_ball_target).get_visuals()["fog_near"]

	assert_float(find_ball_fog_near).is_less(arrive_fog_near)
