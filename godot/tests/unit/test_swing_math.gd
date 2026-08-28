extends GdUnitTestSuite
## Pure-function tests for scripts/logic/swing_math.gd, mirroring
## test_world_affordances.gd's own style -- no scene/runner needed. Each
## test simulates a short run of fixed-delta steps (60Hz) and asserts on
## the resulting VALUES (amplitude actually growing/decaying, bounds
## actually holding), not just that some flag flipped -- a swing that
## silently never builds height, or one that spins past its own hard
## limit, would both still leave every field "a number" and pass a
## boolean-shaped test.

const DT := 1.0 / 60.0


func _simulate(steps: int, pump: float, start_theta: float = 0.0, start_omega: float = 0.0) -> Dictionary:
	var theta := start_theta
	var omega := start_omega
	for _i in range(steps):
		var result := SwingMath.step(theta, omega, pump, DT)
		theta = result["theta"]
		omega = result["omega"]
	return {"theta": theta, "omega": omega}


func test_at_rest_with_no_pump_stays_at_rest() -> void:
	var result := _simulate(120, 0.0, 0.0, 0.0)
	assert_float(result["theta"]).is_equal_approx(0.0, 0.0001)
	assert_float(result["omega"]).is_equal_approx(0.0, 0.0001)


func test_gravity_alone_swings_a_displaced_seat_back_toward_center() -> void:
	# Released from a tilt with no pumping: the pendulum's own restoring
	# force must carry it back toward vertical, not hold or increase the
	# displacement. Checked well inside the first quarter-swing (the
	# pendulum's period at this amplitude is on the order of 1s, so 20
	# steps @ 60Hz stays unambiguously on the "still descending toward
	# center" side of the arc rather than depending on exactly where a
	# full oscillation cycle happens to land).
	var result := _simulate(20, 0.0, 0.8, 0.0)
	assert_float(result["theta"]).is_less(0.8)
	assert_float(result["theta"]).is_greater(0.0)


func test_sustained_pumping_from_rest_builds_real_amplitude() -> void:
	# The actual "worth doing twice" mechanic: holding pump input from a
	# standstill must measurably build height over time, not just nudge a
	# flag. Checked at two different step counts so this also catches a
	# step function that adds energy once and then plateaus immediately.
	var early := _simulate(30, 1.0, 0.0, 0.0)
	var later := _simulate(150, 1.0, 0.0, 0.0)
	assert_float(absf(early["theta"])).is_greater(0.01)
	assert_float(absf(later["theta"])).is_greater(absf(early["theta"]))


func test_theta_never_exceeds_the_authored_ceiling_even_under_hard_pumping() -> void:
	var result := _simulate(600, 1.0, 0.0, 0.0)
	assert_float(absf(result["theta"])).is_less_equal(SwingMath.MAX_THETA + 0.0001)


func test_omega_never_exceeds_the_authored_ceiling_even_under_hard_pumping() -> void:
	var theta := 0.0
	var omega := 0.0
	var max_seen := 0.0
	for _i in range(600):
		var result := SwingMath.step(theta, omega, 1.0, DT)
		theta = result["theta"]
		omega = result["omega"]
		max_seen = maxf(max_seen, absf(omega))
	assert_float(max_seen).is_less_equal(SwingMath.MAX_OMEGA + 0.0001)


func test_releasing_pump_lets_damping_bleed_a_fast_swing_back_down() -> void:
	# Build real speed first, then stop pumping and confirm damping actually
	# reduces it rather than sustaining a perpetual swing.
	var pumped := _simulate(150, 1.0, 0.0, 0.0)
	var coasted := _simulate(180, 0.0, pumped["theta"], pumped["omega"])
	assert_float(absf(coasted["omega"])).is_less(absf(pumped["omega"]))
