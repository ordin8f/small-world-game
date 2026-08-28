class_name LensMath
extends RefCounted
## Verbatim port of src/logic.mjs's shared math helpers (clamp/lerp/
## smoothstep/interpolateColor). Static utility class -- call as
## LensMath.clamp(...) etc, no instance needed.


static func clamp_value(value: float, min_v: float = 0.0, max_v: float = 1.0) -> float:
	return min(max_v, max(min_v, value))


static func lerp_value(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


static func smoothstep(edge0: float, edge1: float, value: float) -> float:
	var x := clamp_value((value - edge0) / max(1e-6, edge1 - edge0))
	return x * x * (3.0 - 2.0 * x)


## a and b are 3-element Arrays (or Color-like) of [r, g, b] in 0..1.
static func interpolate_color(a: Array, b: Array, t: float) -> Array:
	return [
		lerp_value(a[0], b[0], t),
		lerp_value(a[1], b[1], t),
		lerp_value(a[2], b[2], t),
	]
