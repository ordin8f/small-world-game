extends GdUnitTestSuite
## Port of tests/camera.test.mjs -- verbatim assertions against CameraProfile.

func test_camera_opens_from_threshold_toward_reveal() -> void:
	var threshold := CameraProfile.profile(6.5)  # player start, near home
	var approach := CameraProfile.profile(0.0)   # mid-courtyard
	var reveal := CameraProfile.profile(-6.0)    # playground / garden depth
	assert_float(threshold["distance"]).is_less(approach["distance"])
	assert_float(approach["distance"]).is_less(reveal["distance"])
	assert_float(threshold["fov"]).is_less(reveal["fov"])
	assert_float(threshold["lead"]).is_less(reveal["lead"])


func test_camera_zones_are_stable_past_their_anchor_points() -> void:
	var deep_threshold := CameraProfile.profile(12.0)  # at the home doorway
	var deep_reveal := CameraProfile.profile(-12.0)    # far garden wall
	assert_float(absf(deep_threshold["distance"] - CameraProfile.profile(7.0)["distance"])).is_less(0.01)
	assert_float(absf(deep_reveal["distance"] - CameraProfile.profile(-5.0)["distance"])).is_less(0.01)


func test_w_is_forward_and_d_is_screen_right_at_neutral_yaw() -> void:
	var forward := CameraProfile.input_direction(0.0, 1.0, 0.0)
	var right := CameraProfile.input_direction(1.0, 0.0, 0.0)
	assert_float(forward["z"]).is_less(-0.99)
	assert_float(absf(forward["x"])).is_less(0.01)
	assert_float(right["x"]).is_greater(0.99)
	assert_float(absf(right["z"])).is_less(0.01)


func test_input_direction_returns_zero_for_no_input() -> void:
	var result := CameraProfile.input_direction(0.0, 0.0, 0.0)
	assert_dict(result).is_equal({"x": 0.0, "z": 0.0})
