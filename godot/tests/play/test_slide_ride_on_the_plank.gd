extends GdUnitTestSuite
## The slide's scripted ride must happen ON the plank the player can see.
##
## This is the test that was missing when the developer played the build and
## found the child riding through the slide (2026-08-30: "the slide surface
## doesn't align with the slide itself and needs to be calibrated"). Three
## offsets had stacked up -- the ride started 0.35 m up-slope of the plank's
## top edge, ran at 46.8 degrees against the plank's 50.0, and treated the
## plank's CENTRELINE as its surface -- and every existing test stayed green
## throughout, because they all compared authored constants to other
## authored constants.
##
## So this one deliberately does not. It measures the ride path
## (WorldAffordances.slide_ride_position(), the pure function player.gd
## actually drives) against the plank AS BUILT in scenes/courtyard.tscn --
## a mesh with a baked transform, produced by a separate generator run.
## Those are two independent artifacts, so moving either one without the
## other fails here.
##
## Mutation-checked, because this repo has a documented history of tests that
## measure the wrong thing and a test that passes while the child rides
## through the plank is worse than none. All three mutations below were
## applied, run, and reverted; each fails
## test_the_rider_sits_on_the_plank_surface_the_whole_way_down:
##
##   SLIDE_SURFACE_FOOT.z  -9.1 -> -8.8 (the 0.3 m endpoint shift), scene
##                         left as generated ......... fails by 0.361 m
##   slide_seat_point()    seat lift dropped ......... fails by 0.160 m
##   _slide_plank()        half-thickness drop removed
##                         and the scene regenerated .. fails by 0.141 m
##
## The middle one matters most: it is the mutation a test comparing
## WorldAffordances to itself would sail straight through.

## How far the rider's own node sits above the plank's top face. The seat
## lift is authored once in WorldAffordances; this is only the tolerance.
const HEIGHT_TOLERANCE := 0.03
const SAMPLES := 60

var _plank: MeshInstance3D = null


func before_test() -> void:
	var courtyard: Node3D = auto_free(load("res://scenes/courtyard.tscn").instantiate())
	add_child(courtyard)
	_plank = courtyard.find_child("SlidePlank", true, false) as MeshInstance3D
	assert_object(_plank).is_not_null()


## The whole ride, sampled along its length: at every point the player node
## must be exactly SEATED_RIDER_LIFT above the plank's own top face -- not
## above it at the top and inside it at the bottom, which is what "different
## start points AND different angles" produced.
func test_the_rider_sits_on_the_plank_surface_the_whole_way_down() -> void:
	var worst := 0.0
	var worst_at := 0.0
	for i in range(SAMPLES + 1):
		var t: float = WorldAffordances.SLIDE_RIDE_FRACTION * float(i) / float(SAMPLES)
		var p := WorldAffordances.slide_ride_position(t)
		var expected := _plank_surface_y_at(p.x, p.z) + WorldAffordances.SEATED_RIDER_LIFT
		var error := absf(p.y - expected)
		if error > worst:
			worst = error
			worst_at = t
	assert_float(worst) \
		.override_failure_message("Rider is %.3f m off the plank's top surface at t=%.2f (tolerance %.3f)" % [worst, worst_at, HEIGHT_TOLERANCE]) \
		.is_less(HEIGHT_TOLERANCE)


## Never below it, specifically. An average-correct path that dips through
## the plank halfway down is the exact failure the developer saw, and the
## absolute check above would forgive it if it also rose by as much
## somewhere else.
func test_the_rider_is_never_inside_the_plank() -> void:
	for i in range(SAMPLES + 1):
		var t: float = WorldAffordances.SLIDE_RIDE_FRACTION * float(i) / float(SAMPLES)
		var p := WorldAffordances.slide_ride_position(t)
		assert_float(p.y).is_greater(_plank_surface_y_at(p.x, p.z))


## The ride has to begin on the plank's top edge, not over the deck behind
## it. It used to start at PLATFORM_STAND, 0.35 m up-slope of where the
## plank actually began.
func test_the_ride_begins_on_the_planks_top_edge() -> void:
	var start := WorldAffordances.slide_ride_position(0.0)
	var top_edge := _plank_end_centre(-1.0)
	assert_float(Vector2(start.x - top_edge.x, start.z - top_edge.z).length()).is_less(0.05)


## ...and stays OVER the plank's own footprint the whole way, so the surface
## check above is never measuring an extrapolated plane past the end of a
## plank the rider has already left.
##
## Measured on the point directly under the rider, not on the rider itself:
## the seat lift is vertical while the plank is tilted 50 degrees, so a
## rider correctly sitting on the very top edge is 0.12 m past that edge
## along the plank's own long axis -- over the deck, which is exactly where
## they should be, and not a footprint the plank has to cover.
func test_the_ride_stays_over_the_planks_own_footprint() -> void:
	var xf := _plank.global_transform
	var half_run: float = xf.basis.z.length() * 0.5
	var half_width: float = xf.basis.x.length() * 0.5
	for i in range(SAMPLES + 1):
		var t: float = WorldAffordances.SLIDE_RIDE_FRACTION * float(i) / float(SAMPLES)
		var p := WorldAffordances.slide_ride_position(t)
		var under := Vector3(p.x, _plank_surface_y_at(p.x, p.z), p.z)
		var offset := under - xf.origin
		assert_float(absf(offset.dot(xf.basis.z.normalized()))).is_less(half_run + 0.02)
		assert_float(absf(offset.dot(xf.basis.x.normalized()))).is_less(half_width + 0.02)


## Height of the plank's TOP FACE directly under a world (x, z). The plank is
## a box rotated about X only, so its top face is a plane: take its centre
## (the instance origin pushed half a thickness along the box's own local up)
## and solve the plane equation for y. Reading it off the built mesh rather
## than off WorldAffordances is the entire point of this suite.
func _plank_surface_y_at(x: float, z: float) -> float:
	var xf := _plank.global_transform
	var normal: Vector3 = xf.basis.y.normalized()
	var centre: Vector3 = xf.origin + xf.basis.y * 0.5
	return centre.y - (normal.x * (x - centre.x) + normal.z * (z - centre.z)) / normal.y


## Centre of one end of the plank's top face: `side` -1 is the high (tower)
## end, +1 the low one.
func _plank_end_centre(side: float) -> Vector3:
	var xf := _plank.global_transform
	return xf.origin + xf.basis.y * 0.5 + xf.basis.z * (0.5 * side)
