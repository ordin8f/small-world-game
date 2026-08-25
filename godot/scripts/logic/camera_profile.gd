class_name CameraProfile
extends RefCounted
## Verbatim port of src/camera.mjs. Static utility class.
##
## Zones: THRESHOLD (near home) -> APPROACH (mid-courtyard) -> REVEAL
## (playground/garden depth), blended by two independent smoothstep bands on
## the player's world-space z. See GODOT_REBUILD_PLAN.md's source-of-truth
## table for the exact authored numbers this must match.

const THRESHOLD := {
	"distance": 12.0, "height": 3.2, "target_height": 1.15, "fov": 46.0,
	"lateral": 0.55, "lead": 0.5, "authored_yaw": -0.045,
}
const APPROACH := {
	"distance": 14.0, "height": 3.6, "target_height": 1.2, "fov": 48.0,
	"lateral": 0.85, "lead": 1.2, "authored_yaw": 0.035,
}
const REVEAL := {
	"distance": 16.0, "height": 4.0, "target_height": 1.25, "fov": 50.0,
	"lateral": 1.25, "lead": 2.1, "authored_yaw": -0.07,
}


static func damp(current: float, target: float, lambda: float, dt: float) -> float:
	return LensMath.lerp_value(current, target, 1.0 - exp(-lambda * dt))


## Returns {"x": float, "z": float} -- deliberately a Dictionary (not Vector2)
## so callers can't mix up which axis is which; matches the JS {x, z} shape.
static func input_direction(input_x: float, input_z: float, camera_yaw: float) -> Dictionary:
	var magnitude := Vector2(input_x, input_z).length()
	if magnitude < 1e-6:
		return {"x": 0.0, "z": 0.0}

	var nx := input_x / magnitude
	var nz := input_z / magnitude
	var forward_x := -sin(camera_yaw)
	var forward_z := -cos(camera_yaw)
	var right_x := cos(camera_yaw)
	var right_z := -sin(camera_yaw)

	return {"x": right_x * nx + forward_x * nz, "z": right_z * nx + forward_z * nz}


static func _blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {
		"distance": LensMath.lerp_value(a["distance"], b["distance"], t),
		"height": LensMath.lerp_value(a["height"], b["height"], t),
		"target_height": LensMath.lerp_value(a["target_height"], b["target_height"], t),
		"fov": LensMath.lerp_value(a["fov"], b["fov"], t),
		"lateral": LensMath.lerp_value(a["lateral"], b["lateral"], t),
		"lead": LensMath.lerp_value(a["lead"], b["lead"], t),
		"authored_yaw": LensMath.lerp_value(a["authored_yaw"], b["authored_yaw"], t),
	}


static func _smoothstep_bidirectional(edge0: float, edge1: float, value: float) -> float:
	var x: float
	if edge0 < edge1:
		x = LensMath.clamp_value((value - edge0) / (edge1 - edge0))
	else:
		x = LensMath.clamp_value((edge0 - value) / (edge0 - edge1))
	return x * x * (3.0 - 2.0 * x)


static func profile(z: float) -> Dictionary:
	var threshold_to_approach := _smoothstep_bidirectional(7.0, 3.0, z)
	var approach_to_reveal := _smoothstep_bidirectional(-2.0, -5.0, z)
	return _blend(_blend(THRESHOLD, APPROACH, threshold_to_approach), REVEAL, approach_to_reveal)
