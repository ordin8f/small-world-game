extends GdUnitTestSuite
## Ports tests/logic.test.mjs's EpisodeDirector state-machine cases.

func test_episode_state_machine_rejects_out_of_order_events() -> void:
	var director := EpisodeDirector.new()
	director.start(0.0)
	assert_bool(director.dispatch("ball_picked_up", 10.0)).is_false()
	assert_str(director.state).is_equal(EpisodeDirector.State.ARRIVE)


func test_episode_completes_only_through_the_intended_sequence() -> void:
	var director := EpisodeDirector.new()
	director.start(0.0)
	var events := ["observe", "ball_kicked", "ball_landed", "ball_picked_up", "ball_returned", "joined", "entered_home"]
	for event in events:
		assert_bool(director.dispatch(event, 100.0)).is_true()
	assert_str(director.state).is_equal(EpisodeDirector.State.COMPLETE)
	assert_int(director.history.size()).is_equal(8)
