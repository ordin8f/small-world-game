class_name CameraProfile
extends RefCounted
## Zones: THRESHOLD (near home) -> APPROACH (mid-courtyard) -> REVEAL
## (playground/garden depth), blended by two independent smoothstep bands on
## the player's world-space z. GODOT_REBUILD_PLAN.md's source-of-truth table
## has the original src/camera.mjs numbers this was a verbatim port of.
##
## Re-tuned (Gate 1, docs/ART_DIRECTION.md) for a low child-height camera --
## the previous distance/height numbers (12-16 / 3.2-4.0) were an
## adult-height third-person diorama camera scaled down with the character,
## exactly what ART_DIRECTION.md's "Camera as art direction" section says
## not to build. Reference: docs/concept-art/extended/concept_01 (home
## threshold), _04 (journey/child-height) and _05 (return/safety) -- in all
## three the camera sits at roughly the child's own head height, close
## enough that the character reads as a small, near silhouette against a
## much taller architectural frame, not as a distant figure in a wide shot.
## `height`/`target_height` dropped from adult-crane numbers to just above
## the character's own scale; `distance` came down enough that the low
## camera doesn't have to work as hard to keep the child in frame; `fov`
## went up to keep the wide, slightly immersive feel of a close, low lens.
## Relative ordering (threshold < approach < reveal, tested by
## test_camera_profile.gd) is unchanged -- the world still opens up as the
## player moves away from home, just from a much lower vantage.
##
## RECONSIDERED, not changed (camera-fix task, round 2, 2026-08-29) after
## 2ef80f1 brought boundary wall heights down to domestic proportion (home
## 8.2->5.5 m, playground 8.2->4.2 m, garden pocket 7.0->3.0 m -- DEMO_PLAN.md's
## scale-diagnosis entry has the reasoning). The numbers above were tuned
## against child SCALE (concept art references, the character's own 1.08 m
## height), not wall height -- that justification is untouched by the
## retune, and screenshots taken after it (tools/shots.ps1, camera-fix
## task's own report) already read as coherent at these same values without
## touching them, once the garden-gap-seam fixes in camera_rig.gd (a
## separate, narrower problem -- REVEAL's fixed "north" yaw throwing the
## camera into an empty invisible collider near x=11, unrelated to wall
## height) were in place. Raising height back toward the old adult-crane
## numbers would fight ART_DIRECTION.md's low-camera mandate for no
## demonstrated gain; the collision height camera-blocking walls actually
## present to SpringArm3D (_wall_collider() in _bootstrap_courtyard.gd, a
## flat 5.0 m regardless of a wall's RENDERED height) didn't change at all
## in 2ef80f1, so the collision-avoidance margins these values were also
## implicitly tuned against are unchanged too. Left alone on that evidence,
## not by default.
const THRESHOLD := {
	"distance": 5.5, "height": 1.2, "target_height": 0.95, "fov": 50.0,
	"lateral": 0.4, "lead": 0.45, "authored_yaw": -0.045,
}
const APPROACH := {
	"distance": 7.0, "height": 1.5, "target_height": 1.0, "fov": 54.0,
	"lateral": 0.55, "lead": 0.9, "authored_yaw": 0.035,
}
const REVEAL := {
	"distance": 10.5, "height": 2.6, "target_height": 1.1, "fov": 58.0,
	"lateral": 0.45, "lead": 1.2, "authored_yaw": -0.07,
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


## Bands re-tuned for the 2026-08-28 world expansion (world_bounds.gd's
## four-room layout: HOME z[8,16] -> LANE z[-4,8] -> PLAYGROUND z[-20,-4]).
## THRESHOLD->APPROACH now blends exactly across the home/lane seam (z 11
## down to 8, the lane mouth) -- by the time the player has actually
## entered the lane they are fully APPROACH-zoned, mirroring the old
## single-room band's own width (4 m) and the same "starts partway
## through, not saturated" relationship to player.gd's START_POSITION (10)
## the old band held to its own start (6.5). APPROACH->REVEAL now blends
## across the playground's own entrance (z -4, the lane/playground seam)
## down to the Watch marker (z -8) -- REVEAL is fully engaged by the beat
## where the player actually stops to watch the group, same relationship
## the old band held between its z=-2..-5 span and the old Watch/Group
## positions.
static func profile(z: float) -> Dictionary:
	var threshold_to_approach := _smoothstep_bidirectional(11.0, 8.0, z)
	var approach_to_reveal := _smoothstep_bidirectional(-4.0, -8.0, z)
	return _blend(_blend(THRESHOLD, APPROACH, threshold_to_approach), REVEAL, approach_to_reveal)
