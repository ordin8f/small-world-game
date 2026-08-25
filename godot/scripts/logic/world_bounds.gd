class_name WorldBounds
extends RefCounted
## Verbatim port of src/world.mjs -- palette, static colliders, bounds check.
## Static utility class.

const PALETTE := {
	"plaster": [0.68, 0.62, 0.52],
	"plaster_light": [0.78, 0.71, 0.58],
	"ground": [0.36, 0.37, 0.29],
	"path": [0.66, 0.57, 0.40],
	"wood": [0.34, 0.20, 0.12],
	"wood_light": [0.62, 0.38, 0.20],
	"foliage": [0.18, 0.34, 0.22],
	"foliage_light": [0.34, 0.50, 0.28],
	"slide": [0.80, 0.30, 0.16],
	"chalk": [0.78, 0.76, 0.62],
	"puddle": [0.20, 0.32, 0.37],
	"shadow": [0.06, 0.07, 0.065],
	"warm_light": [1.0, 0.66, 0.28],
	"ball": [0.83, 0.53, 0.18],
}

## Each: {x, z, half_x, half_z} -- an axis-aligned box on the ground plane.
const COLLIDERS := [
	{"x": -10.7, "z": -1.0, "half_x": 0.6, "half_z": 15.0},
	{"x": 10.7, "z": -1.0, "half_x": 0.6, "half_z": 15.0},
	{"x": 0.0, "z": -13.3, "half_x": 11.5, "half_z": 0.6},
	{"x": -3.4, "z": -5.6, "half_x": 1.35, "half_z": 1.35},
	{"x": 3.4, "z": -5.6, "half_x": 1.35, "half_z": 1.35},
	{"x": 5.4, "z": -5.9, "half_x": 0.35, "half_z": 2.1},
	{"x": 5.4, "z": -1.1, "half_x": 0.35, "half_z": 0.7},
	{"x": 8.1, "z": -0.8, "half_x": 2.35, "half_z": 0.35},
	{"x": 8.3, "z": -8.2, "half_x": 1.0, "half_z": 1.0},
	{"x": -7.6, "z": 1.7, "half_x": 0.65, "half_z": 0.65},
]


static func circle_intersects_box(x: float, z: float, radius: float, box: Dictionary) -> bool:
	var nearest_x := LensMath.clamp_value(x, box["x"] - box["half_x"], box["x"] + box["half_x"])
	var nearest_z := LensMath.clamp_value(z, box["z"] - box["half_z"], box["z"] + box["half_z"])
	var dx := x - nearest_x
	var dz := z - nearest_z
	return dx * dx + dz * dz < radius * radius


static func can_move_to(x: float, z: float, radius: float = 0.32) -> bool:
	if x < -10.0 or x > 10.0 or z < -12.5 or z > 12.0:
		return false
	for box in COLLIDERS:
		if circle_intersects_box(x, z, radius, box):
			return false
	return true
