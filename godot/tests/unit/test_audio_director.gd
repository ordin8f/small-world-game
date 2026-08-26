extends GdUnitTestSuite
## M2.5b unit test: AudioDirector.mood_gain(), the pure per-voice target
## gain formula ported from audio.mjs:42-47's setMood(). The rest of
## AudioDirector is side-effecting audio playback, covered by the play
## test instead.

func test_mood_gain_matches_the_source_formula_at_its_bounds() -> void:
	# comfort=0, energy=0 -- the formula's own baseline per drone index.
	assert_float(AudioDirector.mood_gain(0, 0.0, 0.0)).is_equal_approx(0.004, 0.00001)
	assert_float(AudioDirector.mood_gain(1, 0.0, 0.0)).is_equal_approx(0.0055, 0.00001)
	assert_float(AudioDirector.mood_gain(2, 0.0, 0.0)).is_equal_approx(0.007, 0.00001)

	# comfort=1, energy=1 -- both contributions at their EmotionalLens max.
	assert_float(AudioDirector.mood_gain(0, 1.0, 1.0)).is_equal_approx(0.012, 0.00001)
	assert_float(AudioDirector.mood_gain(2, 1.0, 1.0)).is_equal_approx(0.015, 0.00001)


func test_mood_gain_increases_with_comfort_and_energy() -> void:
	var low := AudioDirector.mood_gain(0, 0.2, 0.2)
	var high := AudioDirector.mood_gain(0, 0.8, 0.8)
	assert_float(high).is_greater(low)
