extends GdUnitTestSuite
## Ports tests/logic.test.mjs's dominant-emotion and EmotionalLens cases.

func test_dominant_emotions_are_derived_rather_than_stored_as_independent_meters() -> void:
	assert_str(EmotionalLens.dominant_emotion({"comfort": 0.2, "energy": 0.8, "curiosity": 0.4})).is_equal("anxious")
	assert_str(EmotionalLens.dominant_emotion({"comfort": 0.3, "energy": 0.4, "curiosity": 0.4})).is_equal("lonely")
	assert_str(EmotionalLens.dominant_emotion({"comfort": 0.6, "energy": 0.5, "curiosity": 0.9})).is_equal("curious")
	assert_str(EmotionalLens.dominant_emotion({"comfort": 0.9, "energy": 0.8, "curiosity": 0.5})).is_equal("happy")


func test_emotional_lens_eases_toward_a_target_and_clamps_values() -> void:
	var lens := EmotionalLens.new({"comfort": 0.0, "energy": 0.0, "curiosity": 0.0})
	lens.set_target({"comfort": 2.0, "energy": -1.0, "curiosity": 0.5})
	lens.update(1.0)
	assert_float(lens.value["comfort"]).is_greater(0.0)
	assert_float(lens.value["comfort"]).is_less_equal(1.0)
	assert_float(lens.target["energy"]).is_equal(0.0)
	assert_float(lens.target["curiosity"]).is_equal(0.5)
