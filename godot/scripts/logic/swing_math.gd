class_name SwingMath
extends RefCounted
## Pure pendulum-with-pumping step function for scripts/swing.gd, factored
## out the same way lens_math.gd/camera_profile.gd separate their own pure
## math from the Node scripts that drive a live scene -- direct unit
## testing without a scene_runner.
##
## theta is the swing's angle from vertical (radians, signed, 0 = hanging
## straight down); omega is its angular velocity (radians/sec). `pump` is
## raw player input (-1..1, move_forward - move_back).
##
## FIRST VERSION applied `pump` as a constant-direction force (scaled by
## cos(theta) so it was strongest at the bottom of the arc). That is not
## actually pumping a swing: a force that always points the same way just
## tilts the pendulum to a new offset angle and holds it there -- caught by
## test_swing_math.gd's own test_sustained_pumping_from_rest_builds_real_
## amplitude, which simulates holding pump and asserts amplitude at a
## LATER tick is greater than amplitude at an EARLIER one; the first
## version grew for a moment, then visibly settled back down.
##
## Real playground pumping adds energy in whichever direction the swing is
## ALREADY travelling (timed leg-pumps each half-cycle) -- i.e. negative
## damping synchronized to velocity, not a fixed-direction push. Reusing
## `pump`'s own sign only kicks in right at a standstill (|omega| below
## OMEGA_DEADZONE, true at rest or momentarily at the very top of an arc),
## which is what lets holding the input start the swing moving at all.
const OMEGA_DEADZONE := 0.05

const GRAVITY := 9.8
const LENGTH := 2.1
const DAMPING := 0.22
const PUMP_STRENGTH := 3.1
const MAX_OMEGA := 3.2
const MAX_THETA := 1.15  ## ~66 degrees either side -- a real arc, short of a full loop


## Advances the pendulum by `delta` seconds and returns the next
## {"theta": float, "omega": float}.
static func step(theta: float, omega: float, pump: float, delta: float) -> Dictionary:
	var restoring := -(GRAVITY / LENGTH) * sin(theta)
	var drive_sign := signf(omega) if absf(omega) > OMEGA_DEADZONE else signf(pump)
	var pumping := absf(pump) * PUMP_STRENGTH * drive_sign * cos(theta)
	var next_omega := omega + (restoring + pumping) * delta
	next_omega *= clampf(1.0 - DAMPING * delta, 0.0, 1.0)
	next_omega = clampf(next_omega, -MAX_OMEGA, MAX_OMEGA)
	var next_theta := clampf(theta + next_omega * delta, -MAX_THETA, MAX_THETA)
	# Zero the velocity at the hard angle clamp -- otherwise a pinned theta
	# with nonzero omega just keeps accumulating energy against a wall it can
	# never move past, which reads as the swing silently jamming rather than
	# settling into a real ceiling on how high it can go.
	if is_equal_approx(next_theta, MAX_THETA) or is_equal_approx(next_theta, -MAX_THETA):
		next_omega = 0.0
	return {"theta": next_theta, "omega": next_omega}
